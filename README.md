# 🏍️ Bike Tracker

> A professional GPS-powered motorcycle & bicycle tracking application built with Flutter, featuring real-time speed monitoring, offline ride storage, and interactive OpenStreetMap route visualization.

---

## 📱 Screenshots

| Home Screen | Live Tracking | Ride Summary |
|---|---|---|
| Today's Activity | Live GPS + Speed | Stats & Save |

| Ride History | Trip Details | Settings |
|---|---|---|
| Past Rides List | Saved Route Map | Units & Wakelock |

---

## ✨ Features

### 🛣️ Live GPS Tracking
- Real-time speed display in **km/h** or **mph**
- Live route drawn on **OpenStreetMap** using polyline
- Animated location marker following your position
- **Pause / Resume** ride support

### 🗃️ Offline Ride Storage
- All rides saved locally using **SQLite** (`sqflite`)
- Stores: distance, duration, average speed, max speed, start/end timestamps
- Full GPS route coordinates serialized as **JSON** — route is replayable after the ride

### 📊 Post-Ride Summary
- Distance, Duration, Average Speed, Max Speed
- Count of GPS trace points recorded
- **SAVE RIDE** with loading spinner and green success confirmation
- **DISCARD RIDE** with confirmation dialog to prevent accidental deletion

### 📜 Ride History
- Chronological list of all saved rides
- Pull-to-refresh support
- Swipe card tap → opens full **Trip Details** screen
- Delete individual rides with confirmation

### 🗺️ Trip Details (Interactive Saved Route)
- Full **OpenStreetMap** rendering of your saved polyline route
- 🟢 **Green** start marker and 🏁 **Checkered** finish marker
- Full metrics: date, time range, distance, duration, avg speed, max speed
- GPS accuracy info showing trace point count

### 📈 Overall Statistics Dashboard
- Total kilometers ever ridden
- Total ride count
- Lifetime top speed
- Overall average speed
- Average distance per ride

### ⚙️ Settings Screen
- **Unit Toggle**: Metric (`km`, `km/h`) ↔ Imperial (`mi`, `mph`) — affects all screens live
- **Keep Screen Awake** toggle using `wakelock_plus`
- **Background Ride Tracking** detects and records rides while RideForge is running in the background
- **Clear All Ride History** with safety confirmation

### 🔋 Background Tracking & Reliability
- Android **Foreground Service** keeps GPS active when screen is locked or app is minimized
- Persistent notification: *"🏍️ Bike Tracker Active - Tracking your ride in the background"*
- Keep RideForge running in the background for reliable automatic tracking. Do not force-close the app.

### 🛡️ GPS Noise Filtering (No Fake Distance!)
- **Accuracy gate**: ignores fixes with GPS error > 25m (common indoors)
- **Speed deadband**: below 1.8 km/h is treated as stationary
- **Movement verification**: distance only counted when speed ≥ 1.8 km/h AND displacement ≥ 5m
- Result: **0.00 km** when you are sitting still — no satellite drift accumulation

---

## 🏗️ Architecture

```
lib/
├── main.dart                        # App entry, theme, 3-tab navigation
├── models/
│   └── ride.dart                    # Ride data model + JSON route serialization
├── screens/
│   ├── tracking_screen.dart         # Live GPS tracking screen
│   ├── trip_summary_screen.dart     # Post-ride save/discard screen
│   ├── trip_details_screen.dart     # Saved ride route map viewer
│   ├── history_screen.dart          # Ride history list
│   ├── stats_screen.dart            # Lifetime statistics dashboard
│   └── settings_screen.dart         # User preferences
└── services/
    ├── location_service.dart        # GPS permission & positioning
    ├── database_service.dart        # SQLite CRUD + aggregate queries
    └── settings_service.dart        # SharedPreferences + unit conversion
```

### Data Flow

```
GPS Sensor → LocationService → TrackingScreen
    ↓ (noise filtered)
_updateRideData() → PolylineLayer (live map)
    ↓
STOP RIDE → TripSummaryScreen → DatabaseService.insertRide()
    ↓
HistoryScreen ← DatabaseService.getAllRides()
TripDetailsScreen ← DatabaseService.getRideById()
StatsScreen ← DatabaseService.getTotalStats()
HomeScreen ← DatabaseService.getTodayStats()
```

---

## 🛠️ Tech Stack

| Technology | Usage |
|---|---|
| **Flutter** 3.x | Cross-platform mobile framework |
| **Dart** | Programming language |
| **geolocator** `^14.0.3` | GPS location stream & permissions |
| **maplibre_gl** `^0.27.1` | OpenStreetMap-compatible vector maps via OpenFreeMap |
| **latlong2** `^0.10.1` | Geographic coordinate types |
| **sqflite** `^2.4.1` | Local SQLite database |
| **path** `^1.9.0` | File system path utilities |
| **intl** `^0.19.0` | Date & time formatting |
| **shared_preferences** `^2.3.5` | User settings persistence |
| **wakelock_plus** `^1.2.11` | Screen-on during active rides |

---

## 📐 Database Schema

```sql
CREATE TABLE rides (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    start_time       TEXT NOT NULL,    -- ISO 8601 DateTime
    end_time         TEXT NOT NULL,    -- ISO 8601 DateTime
    distance         REAL NOT NULL,    -- kilometers
    duration_seconds INTEGER NOT NULL, -- total seconds
    average_speed    REAL NOT NULL,    -- km/h
    max_speed        REAL NOT NULL,    -- km/h
    route_points     TEXT NOT NULL     -- JSON: [{lat, lng}, ...]
);
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `>=3.13.4`
- Android Studio or VS Code with Flutter extension
- Android device with GPS enabled (physical device recommended)

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/bike-tracker.git

# 2. Navigate to project folder
cd bike-tracker

# 3. Install dependencies
flutter pub get

# 4. Connect your Android device and run
flutter run
```

### Build Release APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 📋 Android Permissions

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

---

## 🧪 Key Engineering Challenges Solved

### 1. GPS Satellite Drift Rejection
Indoor and stationary GPS sensors wander 2–6 meters between readings due to signal multipath. The app implements a **multi-condition movement gate** (accuracy + speed + displacement thresholds) so a parked bike reads exactly **0.00 km**.

### 2. Average Speed Mathematical Integrity
The formula $\bar{v} = \frac{d}{t}$ is only applied after sufficient distance (≥ 20m) and time (≥ 3 seconds), and the calculated average is capped at `maxSpeed` to prevent physically impossible values from GPS noise.

### 3. Android Background Tracking
Standard Flutter apps are killed by Android's Doze mode when the screen turns off. This app uses **Geolocator's AndroidSettings** with `ForegroundNotificationConfig` to run a persistent foreground service that keeps tracking alive.

### 4. Route Coordinate Persistence
GPS route traces (`List<Position>`) are serialized to a **JSON array** stored as a single SQLite TEXT column. On retrieval, they deserialize back to `List<LatLng>` for map replay — no extra junction table needed.

---

## 🗺️ Roadmap / Future Enhancements

- [ ] Custom app launcher icon
- [ ] Elevation profile chart per ride
- [ ] Weekly/monthly ride calendar view
- [ ] GPX file export for sharing with Strava/Garmin
- [ ] Google Play Store release

---

## 👨‍💻 Author

**Syed** — Built with Flutter, passion for motorcycles, and clean engineering.

> Portfolio Project | September 2026

---

## 📄 License

This project is for personal and portfolio use. Feel free to reference the architecture.
