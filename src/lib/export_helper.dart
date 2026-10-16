import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart' as xml;

import 'database_helper.dart';

class ExportHelper {
  static Future<String> exportToJson(RecordGroup group) async {
    final data = {
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'name': group.name,
      'total_points': group.points.length,
      'points': group.points.map((p) {
        return {
          'latitude': p.latLng.latitude,
          'longitude': p.latLng.longitude,
          'timestamp': p.timestampUtc.toUtc().toIso8601String(),
          'timezone_offset_minutes': p.tzOffsetMinutes,
        };
      }).toList(),
    };

    final content = const JsonEncoder.withIndent('  ').convert(data);

    final file = await _createExportFile(group.name, 'json');

    await file.writeAsString(content, flush: true);
    return file.path;
  }

  static Future<String> exportToGpx(RecordGroup group) async {
    final builder = xml.XmlBuilder();

    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element(
      'gpx',
      attributes: {
        'version': '1.1',
        'creator': 'My Location Record',
        'xmlns': 'http://www.topografix.com/GPX/1/1',
      },
      namespaceUris: {'': 'http://www.topografix.com/GPX/1/1'},
      nest: () {
        builder.element(
          'trk',
          nest: () {
            builder.element('name', nest: () => builder.text(group.name));

            builder.element(
              'extensions',
              nest: () {
                builder.element(
                  'created_at',
                  nest: () =>
                      builder.text(DateTime.now().toUtc().toIso8601String()),
                );
                builder.element(
                  'total_points',
                  nest: () => builder.text(group.points.length.toString()),
                );
              },
            );

            builder.element(
              'trkseg',
              nest: () {
                for (final p in group.points) {
                  builder.element(
                    'trkpt',
                    attributes: {
                      'lat': p.latLng.latitude.toString(),
                      'lon': p.latLng.longitude.toString(),
                    },
                    nest: () {
                      builder.element(
                        'time',
                        nest: () => builder.text(
                          p.timestampUtc.toUtc().toIso8601String(),
                        ),
                      );
                      builder.element(
                        'extensions',
                        nest: () {
                          builder.element(
                            'timezone_offset_minutes',
                            nest: () =>
                                builder.text(p.tzOffsetMinutes.toString()),
                          );
                        },
                      );
                    },
                  );
                }
              },
            );
          },
        );
      },
    );

    final document = builder.buildDocument();
    final content = document.toXmlString(pretty: true, indent: '  ');

    final file = await _createExportFile(group.name, 'gpx');

    await file.writeAsString(content, flush: true);
    return file.path;
  }

  static Future<String> exportAllRecordsToJson() async {
    final recordName = 'all_location_records';
    final points = await AppDatabase.getAllLocationPoints();

    final data = <String, dynamic>{
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'name': recordName,
      'total_points': points.length,
      'points': points.map((point) {
        return {
          'latitude': point['latitude'],
          'longitude': point['longitude'],
          'timestamp': DateTime.fromMillisecondsSinceEpoch(
            (point['timestamp'] as num).toInt(),
            isUtc: true,
          ).toIso8601String(),
          'timezone_offset_minutes': point['timezone_offset_minutes'] ?? 0,
        };
      }).toList(),
    };

    final content = const JsonEncoder.withIndent('  ').convert(data);

    final file = await _createExportFile(recordName, 'json');
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  static Future<String> exportAllRecordsToGpx() async {
    final recordName = 'all_location_records';
    final points = await AppDatabase.getAllLocationPoints();
    final builder = xml.XmlBuilder();

    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element(
      'gpx',
      attributes: {
        'version': '1.1',
        'creator': 'My Location Record',
        'xmlns': 'http://www.topografix.com/GPX/1/1',
      },
      namespaceUris: {'': 'http://www.topografix.com/GPX/1/1'},
      nest: () {
        builder.element(
          'trk',
          nest: () {
            builder.element('name', nest: () => builder.text(recordName));

            builder.element(
              'extensions',
              nest: () {
                builder.element(
                  'created_at',
                  nest: () =>
                      builder.text(DateTime.now().toUtc().toIso8601String()),
                );
                builder.element(
                  'total_points',
                  nest: () => builder.text(points.length.toString()),
                );
              },
            );

            builder.element(
              'trkseg',
              nest: () {
                for (final point in points) {
                  final timestampMillis = (point['timestamp'] as num).toInt();
                  final utcTime = DateTime.fromMillisecondsSinceEpoch(
                    timestampMillis,
                    isUtc: true,
                  );
                  final offsetMinutes =
                      (point['timezone_offset_minutes'] as num?)?.toInt() ?? 0;

                  builder.element(
                    'trkpt',
                    attributes: {
                      'lat': (point['latitude'] as num).toString(),
                      'lon': (point['longitude'] as num).toString(),
                    },
                    nest: () {
                      builder.element(
                        'time',
                        nest: () => builder.text(utcTime.toIso8601String()),
                      );

                      builder.element(
                        'extensions',
                        nest: () {
                          builder.element(
                            'timezone_offset_minutes',
                            nest: () => builder.text(offsetMinutes.toString()),
                          );
                        },
                      );
                    },
                  );
                }
              },
            );
          },
        );
      },
    );

    final document = builder.buildDocument();
    final content = document.toXmlString(pretty: true, indent: '  ');

    final file = await _createExportFile(recordName, 'gpx');
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  static Future<File> _createExportFile(
    String recordName,
    String extension,
  ) async {
    final directoryPath = await FilePicker.getDirectoryPath();

    final safeName = recordName
        .replaceAll(RegExp(r'[^\w.-]+'), '_')
        .replaceAll(RegExp(r'^\.+'), '');

    final filename =
        '${safeName.isEmpty ? 'location_export' : safeName}.$extension';

    return File('$directoryPath/$filename');
  }

  static Future<int?> importRecord() async {
    final List<PlatformFile> result = await FilePicker.pickFiles(
      type: Platform.isAndroid ? FileType.any : FileType.custom,
      allowedExtensions: Platform.isAndroid ? null : ['json', 'gpx'],
    );

    if (result.isEmpty) return 0;

    final fileItem = result.first;
    String content;

    if (fileItem.path != null && fileItem.path!.isNotEmpty) {
      final file = File(fileItem.path!);
      content = await file.readAsString();
    } else {
      final Uint8List bytes = await fileItem.readAsBytes();
      content = utf8.decode(bytes);
    }

    List<Map<String, dynamic>>? pointsResult;
    if (fileItem.name.toLowerCase().endsWith('.json')) {
      final decoded = jsonDecode(content);

      if (decoded is! Map<String, dynamic> || decoded['points'] is! List) {
        throw const FormatException('Invalid location export JSON.');
      }

      pointsResult = (decoded['points'] as List).map((item) {
        if (item is! Map) {
          throw const FormatException('Invalid point in JSON.');
        }

        final map = Map<String, dynamic>.from(item);

        if (map['timestamp'] is String) {
          map['timestamp'] = DateTime.parse(map['timestamp'])
              .millisecondsSinceEpoch;
        }

        return map;
      }).toList();
    } else if (fileItem.name.toLowerCase().endsWith('.gpx')) {
      final document = xml.XmlDocument.parse(content);

      final trkEl = document.findAllElements('trk').firstOrNull;
      if (trkEl == null) return null;
      
      final trkPts = document.findAllElements('trkpt');

      final List<Map<String, dynamic>> points = [];

      for (final trkPt in trkPts) {
        final latStr = trkPt.getAttribute('lat');
        final lonStr = trkPt.getAttribute('lon');

        if (latStr == null || lonStr == null) continue;

        final latitude = double.parse(latStr);
        final longitude = double.parse(lonStr);

        final timeEl = trkPt.findElements('time').firstOrNull;
        if (timeEl == null) continue;
        final rawTimeElValue = timeEl.innerText.trim();
        int timestamp;
        if (int.tryParse(rawTimeElValue) != null) {
          timestamp = int.parse(rawTimeElValue);
        } else {
          timestamp = DateTime.parse(rawTimeElValue).millisecondsSinceEpoch;
        }

        int offsetMinutes = 0;
        final extensionsEl = trkPt.findElements('extensions').firstOrNull;
        if (extensionsEl != null) {
          final offsetEl = extensionsEl
              .findElements('timezone_offset_minutes')
              .firstOrNull;
          if (offsetEl != null) {
            offsetMinutes = int.tryParse(offsetEl.innerText.trim()) ?? 0;
          }
        }

        points.add({
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': timestamp,
          'timezone_offset_minutes': offsetMinutes,
        });
      }
      pointsResult = points;
    }

    return pointsResult == null ? null : AppDatabase.importLocationPoints(pointsResult);
  }
}
