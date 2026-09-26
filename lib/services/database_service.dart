import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../models/ride.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('bike_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE rides (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        distance REAL NOT NULL,
        duration_seconds INTEGER NOT NULL,
        average_speed REAL NOT NULL,
        max_speed REAL NOT NULL,
        route_points TEXT NOT NULL
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // CRUD OPERATIONS
  // ---------------------------------------------------------------------------

  Future<int> insertRide(Ride ride) async {
    final db = await database;
    return await db.insert(
      'rides',
      ride.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Ride>> getAllRides() async {
    final db = await database;
    final result = await db.query(
      'rides',
      orderBy: 'start_time DESC',
    );

    return result.map((map) => Ride.fromMap(map)).toList();
  }

  Future<Ride?> getRideById(int id) async {
    final db = await database;
    final maps = await db.query(
      'rides',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Ride.fromMap(maps.first);
    }
    return null;
  }

  Future<int> deleteRide(int id) async {
    final db = await database;
    return await db.delete(
      'rides',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllRides() async {
    final db = await database;
    return await db.delete('rides');
  }

  // ---------------------------------------------------------------------------
  // AGGREGATE STATS
  // ---------------------------------------------------------------------------

  /// Returns today's total distance and total duration in seconds.
  Future<Map<String, dynamic>> getTodayStats() async {
    final db = await database;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(distance), 0) as total_distance,
        COALESCE(SUM(duration_seconds), 0) as total_duration
      FROM rides
      WHERE start_time LIKE ?
    ''', ['$todayStr%']);

    if (result.isNotEmpty) {
      final totalDist = (result.first['total_distance'] as num?)?.toDouble() ?? 0.0;
      final totalDuration = (result.first['total_duration'] as num?)?.toInt() ?? 0;
      return {
        'totalDistance': totalDist,
        'totalDurationSeconds': totalDuration,
      };
    }

    return {
      'totalDistance': 0.0,
      'totalDurationSeconds': 0,
    };
  }

  /// Returns all-time aggregate stats.
  Future<Map<String, dynamic>> getTotalStats() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_rides,
        COALESCE(SUM(distance), 0) as total_distance,
        COALESCE(SUM(duration_seconds), 0) as total_duration,
        COALESCE(MAX(max_speed), 0) as top_speed,
        COALESCE(AVG(average_speed), 0) as avg_speed
      FROM rides
    ''');

    if (result.isNotEmpty) {
      final row = result.first;
      return {
        'totalRides': (row['total_rides'] as num?)?.toInt() ?? 0,
        'totalDistance': (row['total_distance'] as num?)?.toDouble() ?? 0.0,
        'totalDurationSeconds': (row['total_duration'] as num?)?.toInt() ?? 0,
        'topSpeed': (row['top_speed'] as num?)?.toDouble() ?? 0.0,
        'avgSpeed': (row['avg_speed'] as num?)?.toDouble() ?? 0.0,
      };
    }

    return {
      'totalRides': 0,
      'totalDistance': 0.0,
      'totalDurationSeconds': 0,
      'topSpeed': 0.0,
      'avgSpeed': 0.0,
    };
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
