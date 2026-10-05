import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ride.dart';
import '../services/database_service.dart';
import '../theme/ride_forge_visuals.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, this.loadTotalStats, this.loadRides});

  final Future<Map<String, dynamic>> Function()? loadTotalStats;
  final Future<List<Ride>> Function()? loadRides;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<_StatsData> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<_StatsData> _loadStats() async {
    final totalStats =
        await (widget.loadTotalStats?.call() ??
            DatabaseService.instance.getTotalStats());
    final rides =
        await (widget.loadRides?.call() ??
            DatabaseService.instance.getAllRides());
    return _StatsData.fromRides(totalStats, rides, DateTime.now());
  }

  Future<void> _refreshStats() async {
    final future = _loadStats();
    setState(() => _statsFuture = future);
    await future;
  }

  String _formatTotalDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  String _formatDateRange(DateTime start, DateTime end) {
    final first = DateFormat('d MMM').format(start);
    final last = DateFormat('d MMM').format(end);
    if (start.year == end.year) return '$first – $last ${end.year}';
    return '${DateFormat('d MMM yyyy').format(start)} – '
        '${DateFormat('d MMM yyyy').format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ride Statistics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh statistics',
            onPressed: _refreshStats,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_StatsData>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 72),
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 44,
                  color: Color(0xFFD6A06A),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Statistics unavailable',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'RideForge could not load your ride data. Pull down to try again.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                TextButton(
                  onPressed: _refreshStats,
                  child: const Text('TRY AGAIN'),
                ),
              ],
            );
          }

          final stats = snapshot.data;
          if (stats == null) {
            return const Center(child: Text('Statistics are unavailable.'));
          }

          return RefreshIndicator(
            onRefresh: _refreshStats,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              children: [
                _overviewCard(stats),
                const SizedBox(height: 24),
                _sectionTitle('Lifetime'),
                const SizedBox(height: 12),
                _metricGrid([
                  _MetricData(
                    icon: Icons.two_wheeler,
                    title: 'Total Rides',
                    value: '${stats.totalRides}',
                    color: const Color(0xFFD6A06A),
                  ),
                  _MetricData(
                    icon: Icons.access_time,
                    title: 'Riding Time',
                    value: _formatTotalDuration(stats.totalDurationSeconds),
                    color: const Color(0xFFB98B66),
                  ),
                  _MetricData(
                    icon: Icons.speed,
                    title: 'Average Speed',
                    value: '${stats.averageSpeed.toStringAsFixed(1)} km/h',
                    color: const Color(0xFFD0A77A),
                  ),
                  _MetricData(
                    icon: Icons.flash_on,
                    title: 'Top Speed',
                    value: '${stats.topSpeed.toStringAsFixed(1)} km/h',
                    color: const Color(0xFFE2B866),
                  ),
                  _MetricData(
                    icon: Icons.alt_route,
                    title: 'Avg. Distance / Ride',
                    value: '${stats.averageDistance.toStringAsFixed(1)} km',
                    color: const Color(0xFFD08D62),
                  ),
                ]),
                const SizedBox(height: 24),
                if (stats.totalRides == 0) ...[
                  const SizedBox(height: 4),
                  const _NoRidesMessage(),
                ] else ...[
                  _sectionTitle('This Week'),
                  const SizedBox(height: 12),
                  _periodSummary(
                    rides: stats.ridesThisWeek,
                    distanceKm: stats.distanceThisWeek,
                    periodLabel: _formatDateRange(
                      stats.weekStart,
                      stats.weekEnd,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DistanceBarChart(
                    title: 'Daily Distance',
                    subtitle: 'Distance ridden each day',
                    periodLabel:
                        'This Week • ${_formatDateRange(stats.weekStart, stats.weekEnd)}',
                    items: stats.weeklyChart,
                    selectedLabel: 'Day',
                    initialSelectedIndex: stats.todayWeekIndex,
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('This Month'),
                  const SizedBox(height: 12),
                  _periodSummary(
                    rides: stats.ridesThisMonth,
                    distanceKm: stats.distanceThisMonth,
                    periodLabel: DateFormat('MMMM yyyy').format(stats.month),
                  ),
                  const SizedBox(height: 12),
                  _DistanceBarChart(
                    title: 'Distance by Week',
                    subtitle: 'Distance ridden during each week of this month',
                    periodLabel: DateFormat('MMMM yyyy').format(stats.month),
                    items: stats.monthlyChart,
                    selectedLabel: 'Week',
                    initialSelectedIndex: stats.currentMonthWeekIndex,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _overviewCard(_StatsData stats) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: RideForgeVisuals.cardDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF402213), Color(0xFF21110B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        radius: 22,
        highlighted: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.route, color: Color(0xFFE1B583), size: 20),
              SizedBox(width: 8),
              Text(
                'ALL-TIME DISTANCE',
                style: TextStyle(
                  color: Color(0xFFE1B583),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  stats.totalDistance.toStringAsFixed(1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 46,
                    height: 1.1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 6),
                child: Text(
                  'km',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${stats.totalRides} ${stats.totalRides == 1 ? 'ride' : 'rides'}  ·  ${_formatTotalDuration(stats.totalDurationSeconds)} riding',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: Color(0xFFF2E6DA),
      ),
    );
  }

  Widget _metricGrid(List<_MetricData> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final cardWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(width: cardWidth, child: _metricCard(metric)),
          ],
        );
      },
    );
  }

  Widget _metricCard(_MetricData metric) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(14),
      decoration: RideForgeVisuals.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(metric.icon, size: 22, color: metric.color),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.value,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            metric.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _periodSummary({
    required int rides,
    required double distanceKm,
    required String periodLabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: RideForgeVisuals.cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _periodValue(
              label: 'RIDES',
              value: '$rides',
              icon: Icons.two_wheeler,
            ),
          ),
          Container(width: 1, height: 38, color: const Color(0xFF513A2B)),
          Expanded(
            child: _periodValue(
              label: 'DISTANCE',
              value: '${distanceKm.toStringAsFixed(1)} km',
              icon: Icons.route,
            ),
          ),
          Container(width: 1, height: 38, color: const Color(0xFF513A2B)),
          Expanded(
            child: Text(
              periodLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodValue({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFD6A06A)),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.white54,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }
}

class _StatsData {
  final int totalRides;
  final double totalDistance;
  final int totalDurationSeconds;
  final double topSpeed;
  final double averageSpeed;
  final double averageDistance;
  final int ridesThisWeek;
  final double distanceThisWeek;
  final int ridesThisMonth;
  final double distanceThisMonth;
  final DateTime month;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int todayWeekIndex;
  final int currentMonthWeekIndex;
  final List<_ChartItem> weeklyChart;
  final List<_ChartItem> monthlyChart;

  const _StatsData({
    required this.totalRides,
    required this.totalDistance,
    required this.totalDurationSeconds,
    required this.topSpeed,
    required this.averageSpeed,
    required this.averageDistance,
    required this.ridesThisWeek,
    required this.distanceThisWeek,
    required this.ridesThisMonth,
    required this.distanceThisMonth,
    required this.month,
    required this.weekStart,
    required this.weekEnd,
    required this.todayWeekIndex,
    required this.currentMonthWeekIndex,
    required this.weeklyChart,
    required this.monthlyChart,
  });

  factory _StatsData.fromRides(
    Map<String, dynamic> totals,
    List<Ride> rides,
    DateTime now,
  ) {
    final totalRides = (totals['totalRides'] as num?)?.toInt() ?? 0;
    final totalDistance = (totals['totalDistance'] as num?)?.toDouble() ?? 0;
    final month = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1);
    final today = _dateOnly(now);
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - DateTime.monday),
    );
    final nextWeek = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 7,
    );

    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 6,
    );
    final weeklyItems = List.generate(7, (index) {
      final day = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + index,
      );
      return _ChartItem(
        label: DateFormat('E').format(day),
        startDate: day,
        endDate: day,
      );
    });
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final monthlyItems = <_ChartItem>[];
    var rangeStart = month;
    while (!rangeStart.isAfter(monthEnd)) {
      final daysUntilSunday = DateTime.sunday - rangeStart.weekday;
      final calendarWeekEnd = DateTime(
        rangeStart.year,
        rangeStart.month,
        rangeStart.day + daysUntilSunday,
      );
      final rangeEnd = calendarWeekEnd.isAfter(monthEnd)
          ? monthEnd
          : calendarWeekEnd;
      monthlyItems.add(
        _ChartItem(
          label: 'W${monthlyItems.length + 1}',
          startDate: rangeStart,
          endDate: rangeEnd,
        ),
      );
      rangeStart = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day + 1);
    }

    var ridesThisWeek = 0;
    var distanceThisWeek = 0.0;
    var ridesThisMonth = 0;
    var distanceThisMonth = 0.0;

    for (final ride in rides) {
      final rideDate = _dateOnly(ride.startTime);
      if (!rideDate.isBefore(weekStart) && rideDate.isBefore(nextWeek)) {
        final dayIndex = rideDate.weekday - DateTime.monday;
        weeklyItems[dayIndex].addRide(ride);
        ridesThisWeek++;
        distanceThisWeek += ride.distance;
      }

      if (!rideDate.isBefore(month) && rideDate.isBefore(nextMonth)) {
        ridesThisMonth++;
        distanceThisMonth += ride.distance;
        final weekIndex = monthlyItems.indexWhere(
          (item) =>
              !rideDate.isBefore(item.startDate) &&
              !rideDate.isAfter(item.endDate),
        );
        if (weekIndex >= 0) monthlyItems[weekIndex].addRide(ride);
      }
    }

    final todayWeekIndex = today.weekday - DateTime.monday;
    final currentMonthWeekIndex = monthlyItems.indexWhere(
      (item) => !today.isBefore(item.startDate) && !today.isAfter(item.endDate),
    );

    return _StatsData(
      totalRides: totalRides,
      totalDistance: totalDistance,
      totalDurationSeconds:
          (totals['totalDurationSeconds'] as num?)?.toInt() ?? 0,
      topSpeed: (totals['topSpeed'] as num?)?.toDouble() ?? 0,
      averageSpeed: (totals['avgSpeed'] as num?)?.toDouble() ?? 0,
      averageDistance: totalRides > 0 ? totalDistance / totalRides : 0,
      ridesThisWeek: ridesThisWeek,
      distanceThisWeek: distanceThisWeek,
      ridesThisMonth: ridesThisMonth,
      distanceThisMonth: distanceThisMonth,
      month: month,
      weekStart: weekStart,
      weekEnd: weekEnd,
      todayWeekIndex: todayWeekIndex,
      currentMonthWeekIndex: currentMonthWeekIndex,
      weeklyChart: weeklyItems,
      monthlyChart: monthlyItems,
    );
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _MetricData {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _MetricData({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });
}

class _ChartItem {
  final String label;
  final DateTime startDate;
  final DateTime endDate;
  double distanceKm = 0;
  int rides = 0;
  int durationSeconds = 0;
  double topSpeed = 0;

  _ChartItem({
    required this.label,
    required this.startDate,
    required this.endDate,
  });

  void addRide(Ride ride) {
    distanceKm += ride.distance;
    rides++;
    durationSeconds += ride.durationSeconds;
    if (ride.maxSpeed.isFinite && ride.maxSpeed > topSpeed) {
      topSpeed = ride.maxSpeed;
    }
  }

  double? get averageSpeedKmh =>
      durationSeconds > 0 ? distanceKm / (durationSeconds / 3600) : null;
}

class _DistanceBarChart extends StatefulWidget {
  final String title;
  final String subtitle;
  final String periodLabel;
  final List<_ChartItem> items;
  final String selectedLabel;
  final int initialSelectedIndex;

  const _DistanceBarChart({
    required this.title,
    required this.subtitle,
    required this.periodLabel,
    required this.items,
    required this.selectedLabel,
    required this.initialSelectedIndex,
  });

  @override
  State<_DistanceBarChart> createState() => _DistanceBarChartState();
}

class _DistanceBarChartState extends State<_DistanceBarChart> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSelectedIndex
        .clamp(0, widget.items.length - 1)
        .toInt();
  }

  @override
  void didUpdateWidget(covariant _DistanceBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.items.length) {
      _selectedIndex = widget.items.length - 1;
    }
  }

  void _select(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  String _formatRange(DateTime start, DateTime end) {
    final first = DateFormat('d MMM').format(start);
    if (start.year == end.year) {
      return '$first – ${DateFormat('d MMM yyyy').format(end)}';
    }
    return '${DateFormat('d MMM yyyy').format(start)} – '
        '${DateFormat('d MMM yyyy').format(end)}';
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final maximum = items.fold<double>(
      0,
      (current, item) => item.distanceKm.isFinite && item.distanceKm > current
          ? item.distanceKm
          : current,
    );
    final selected = items[_selectedIndex];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      decoration: RideForgeVisuals.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(
            widget.subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 5),
          Text(
            widget.periodLabel,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFD6A06A),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 11),
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < items.length; index++)
                  Expanded(
                    child: _buildBar(
                      item: items[index],
                      index: index,
                      maximum: maximum,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _buildDetails(selected, key: ValueKey(_selectedIndex)),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Tap a bar to see details',
              style: TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar({
    required _ChartItem item,
    required int index,
    required double maximum,
  }) {
    final selected = index == _selectedIndex;
    final heightFactor = maximum <= 0 || item.distanceKm <= 0
        ? 0.025
        : (item.distanceKm / maximum).clamp(0.025, 1.0).toDouble();
    final semanticDate = widget.selectedLabel == 'Day'
        ? DateFormat('EEEE, d MMMM yyyy').format(item.startDate)
        : '${widget.selectedLabel} ${index + 1}, ${_formatRange(item.startDate, item.endDate)}';
    final semanticRides = item.rides == 1 ? '1 ride' : '${item.rides} rides';

    return Semantics(
      button: true,
      selected: selected,
      label:
          '$semanticDate, ${item.distanceKm.toStringAsFixed(1)} kilometers, $semanticRides',
      onTap: () => _select(index),
      child: InkWell(
        onTap: () => _select(index),
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                item.distanceKm.toStringAsFixed(1),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 9,
                  color: selected ? const Color(0xFFE9C092) : Colors.white60,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    heightFactor: heightFactor,
                    widthFactor: 1,
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: selected
                              ? const [Color(0xFFFFD5A6), Color(0xFFC88353)]
                              : const [Color(0xFFD6A06A), Color(0xFF9D623D)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(5),
                        border: selected
                            ? Border.all(
                                color: const Color(0xFFFFE2C2),
                                width: 1,
                              )
                            : null,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? const Color(0xFFE9C092) : Colors.white70,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              SizedBox(
                height: 4,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: selected ? 4 : 0,
                    height: selected ? 4 : 0,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE9C092),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(_ChartItem item, {required Key key}) {
    final heading = widget.selectedLabel == 'Day'
        ? DateFormat('EEEE').format(item.startDate)
        : '${widget.selectedLabel} ${_selectedIndex + 1}';
    final dateText = widget.selectedLabel == 'Day'
        ? DateFormat('d MMMM yyyy').format(item.startDate)
        : _formatRange(item.startDate, item.endDate);

    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: RideForgeVisuals.cardDecoration(
        color: const Color(0xFF2B1C14),
        radius: 12,
        highlighted: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            dateText,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _detailValue(
                'Distance',
                '${item.distanceKm.toStringAsFixed(1)} km',
              ),
              _detailValue(
                'Rides',
                item.rides == 0
                    ? 'No rides'
                    : '${item.rides} ${item.rides == 1 ? 'ride' : 'rides'}',
              ),
              if (item.rides > 0)
                _detailValue(
                  'Riding time',
                  _formatDuration(item.durationSeconds),
                ),
              if (item.averageSpeedKmh case final averageSpeed?)
                _detailValue(
                  'Average speed',
                  '${averageSpeed.toStringAsFixed(1)} km/h',
                ),
              if (item.topSpeed > 0)
                _detailValue(
                  'Top Speed',
                  '${item.topSpeed.toStringAsFixed(1)} km/h',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white54),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _NoRidesMessage extends StatelessWidget {
  const _NoRidesMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: RideForgeVisuals.cardDecoration(),
      child: const Row(
        children: [
          Icon(Icons.two_wheeler, color: Color(0xFFD6A06A), size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No rides yet',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Your ride statistics will appear here after your first ride.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
