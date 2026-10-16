import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:latlong2/latlong.dart';

class LocationPoint {
  final int id;
  final LatLng latLng;
  final DateTime timestampUtc;
  final int tzOffsetMinutes;

  LocationPoint({
    required this.id,
    required this.latLng,
    required this.timestampUtc,
    required this.tzOffsetMinutes,
  });
}

class RecordGroup {
  final String name;
  final List<LocationPoint> points;

  RecordGroup({required this.name, required this.points});
}

class AppDatabase {
  static Database? _db;

  static const String _table = 'location_points';
  static const String _settingsTable = 'app_settings';
  static const int _databaseVersion = 3;

  static Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'locations.db');

    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _ensureSchema(db);
      },
      onOpen: (db) async {
        await _ensureSchema(db);
      },
    );

    return _db!;
  }

  static Future<void> _createTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        timezone_offset_minutes INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_settingsTable (
        key TEXT PRIMARY KEY,
        value INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _ensureSchema(DatabaseExecutor db) async {
    await _createTable(db);

    final columns = await db.rawQuery('PRAGMA table_info($_table)');
    final columnNames = columns
        .map((column) => column['name'] as String)
        .toSet();

    if (!columnNames.contains('timezone_offset_minutes')) {
      await db.execute('''
        ALTER TABLE $_table
        ADD COLUMN timezone_offset_minutes INTEGER NOT NULL DEFAULT 0
      ''');
    }
  }

  static Future<List<RecordGroup>> getRecordsGrouped({int? startHour}) async {
    final db = await database;

    final effectiveStartHour = startHour ?? await getStartHour();

    final maps = await db.query(_table, orderBy: 'timestamp ASC');
    final groupedMap = <String, List<LocationPoint>>{};

    for (final map in maps) {
      final timestampMillis = (map['timestamp'] as num).toInt();
      final offsetMinutes =
          (map['timezone_offset_minutes'] as num?)?.toInt() ?? 0;

      final utcTime = DateTime.fromMillisecondsSinceEpoch(
        timestampMillis,
        isUtc: true,
      );

      final recordedClockTime = utcTime.add(Duration(minutes: offsetMinutes));

      final adjustedTime = recordedClockTime.hour < effectiveStartHour
          ? recordedClockTime.subtract(const Duration(days: 1))
          : recordedClockTime;

      final dateStr =
          '${adjustedTime.year.toString().padLeft(4, '0')}-'
          '${adjustedTime.month.toString().padLeft(2, '0')}-'
          '${adjustedTime.day.toString().padLeft(2, '0')}';

      final start = effectiveStartHour.toString().padLeft(2, '0');
      final end = (effectiveStartHour - 1 + 24) % 24;
      final endLabel = end.toString().padLeft(2, '0');

      final recordName = '$dateStr ($start:00–$endLabel:59)';

      groupedMap.putIfAbsent(recordName, () => []);

      groupedMap[recordName]!.add(
        LocationPoint(
          id: (map['id'] as num).toInt(),
          latLng: LatLng(
            (map['latitude'] as num).toDouble(),
            (map['longitude'] as num).toDouble(),
          ),
          timestampUtc: utcTime,
          tzOffsetMinutes: offsetMinutes,
        ),
      );
    }

    return groupedMap.entries
        .map((entry) => RecordGroup(name: entry.key, points: entry.value))
        .toList().
        reversed
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getAllLocationPoints() async {
    final db = await database;

    return db.query('location_points', orderBy: 'timestamp ASC');
  }

  static Future<int> deleteRecordGroup(RecordGroup record) async {
    final db = await database;

    if (record.points.isEmpty) return 0;

    final ids = record.points.map((point) => point.id).toList();

    return db.delete(
      'location_points',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  static Future<int> clearAllRecords() async {
    final db = await database;
    return db.delete('location_points');
  }

  static Future<int> importLocationPoints(List<Map<String, dynamic>> points) async {
    final db = await database;

    return db.transaction((txn) async {
      var imported = 0;

      for (final point in points) {
        final latitude = (point['latitude'] as num?)?.toDouble();
        final longitude = (point['longitude'] as num?)?.toDouble();
        final timestamp = point['timestamp'];

        if (latitude == null ||
            longitude == null ||
            !latitude.isFinite ||
            !longitude.isFinite ||
            latitude < -90 ||
            latitude > 90 ||
            longitude < -180 ||
            longitude > 180 ||
            timestamp is! num) {
          throw const FormatException('Invalid location point in JSON.');
        }

        await txn.insert('location_points', {
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': timestamp.toInt(),
          'timezone_offset_minutes':
              (point['timezone_offset_minutes'] as num?)?.toInt() ?? 0,
        });

        imported++;
      }

      return imported;
    });
  }

  static Future<void> saveSettings({int? intervalSeconds, int? startHour}) async {
    final db = await database;
    await db.transaction((txn) async {
      if (intervalSeconds != null) {
        await txn.insert(_settingsTable, {
          'key': 'interval_seconds',
          'value': intervalSeconds,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (startHour != null) {
        await txn.insert(_settingsTable, {
          'key': 'start_hour',
          'value': startHour,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<int> getIntervalSeconds({int defaultValue = 60}) async {
    final db = await database;
    final result = await db.query(
      _settingsTable,
      where: 'key = ?',
      whereArgs: ['interval_seconds'],
    );
    if (result.isNotEmpty) {
      return (result.first['value'] as num).toInt();
    }
    return defaultValue;
  }

  static Future<int> getStartHour({int defaultValue = 6}) async {
    final db = await database;
    final result = await db.query(
      _settingsTable,
      where: 'key = ?',
      whereArgs: ['start_hour'],
    );
    if (result.isNotEmpty) {
      return (result.first['value'] as num).toInt();
    }
    return defaultValue;
  }
}
