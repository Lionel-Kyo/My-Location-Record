import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'database_helper.dart';
import 'export_helper.dart';
import 'map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LocationRecorderApp());
}

class LocationRecorderApp extends StatelessWidget {
  const LocationRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Recorder',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF9C27B0),
              brightness: Brightness.dark,
            ).copyWith(
              primary: const Color(0xFFBA68C8),
              secondary: const Color(0xFFCE93D8),
              surface: const Color(0xFF1E1E1E),
            ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B1B1B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(color: Color(0xFF1E1E1E), elevation: 2),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel(
    'com.example.my_location_record/service',
  );

  int _intervalSeconds = 60;
  int _startHour = 6;

  bool _isTracking = false;
  bool _isBusy = false;

  List<RecordGroup> _records = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadSettings();
    _syncTrackingStatus();
    _loadRecords();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTrackingStatus();
      _loadRecords();
    }
  }

  Future<void> _loadSettings() async {
    final interval = await AppDatabase.getIntervalSeconds();
    final hour = await AppDatabase.getStartHour();

    if (mounted) {
      setState(() {
        _intervalSeconds = interval;
        _startHour = hour;
      });
    }
  }

  Future<void> _syncTrackingStatus() async {
    try {
      final result = await platform.invokeMapMethod<String, dynamic>(
        'getTrackingStatus',
      );

      if (!mounted || result == null) return;

      setState(() {
        _isTracking = result['isRecording'] as bool? ?? false;
      });
    } on PlatformException catch (e) {
      debugPrint('Could not check tracking status: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('Tracking status method unavailable: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadRecords() async {
    if (_isBusy) return;
    try {
      final records = await AppDatabase.getRecordsGrouped(
        startHour: _startHour,
      );

      if (!mounted) return;

      setState(() => _records = records);
    } catch (e) {
      _showMessage('Failed to load records: $e');
    }
  }

  Future<bool> _checkLocationPermissions() async {
    var locationStatus = await Permission.location.status;

    if (!locationStatus.isGranted) {
      locationStatus = await Permission.location.request();
    }

    if (!locationStatus.isGranted) {
      _showMessage('Location permission is required to record locations.');
      return false;
    }

    // Background location is needed for recording when the app
    // is not in the foreground.
    var alwaysStatus = await Permission.locationAlways.status;

    if (!alwaysStatus.isGranted) {
      alwaysStatus = await Permission.locationAlways.request();
    }

    if (!alwaysStatus.isGranted) {
      _showMessage(
        'Allow background location access in Settings '
        'to record locations while the app is in the background.',
      );
      return false;
    }

    return true;
  }

  Future<void> _toggleTracking() async {
    if (_isBusy) return;

    setState(() => _isBusy = true);

    try {
      if (_isTracking) {
        await platform.invokeMethod<void>('stopService');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await _syncTrackingStatus();

        setState(() => _isTracking = false);
        _showMessage('Recording stopped.');
      } else {
        final hasPermission = await _checkLocationPermissions();

        if (!hasPermission) return;

        await platform.invokeMethod<void>('startService', {
          'interval_seconds': _intervalSeconds,
        });

        await Future<void>.delayed(const Duration(milliseconds: 500));

        await _syncTrackingStatus();

        if (mounted && _isTracking) {
          _showMessage('Recording started.');
        } else if (mounted) {
          _showMessage(
            'The service started, but location updates are not confirmed.',
          );
        }
      }
    } on PlatformException catch (e) {
      _showMessage(
        'Unable to ${_isTracking ? 'stop' : 'start'} recording: '
        '${e.message ?? e.code}',
      );
    } on MissingPluginException {
      _showMessage(
        'The Android recording service is not connected. '
        'Check MainActivity.kt and the method channel.',
      );
    } catch (e) {
      _showMessage('Recording error: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _showIntervalInputDialog() async {
    if (_isTracking || _isBusy) return;

    final controller = TextEditingController(text: _intervalSeconds.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set Interval (Seconds)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: 'Enter seconds (15 - 86400)',
            helperText: 'Min: 15, Max: 86400 (1 day)',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 15 && value <= 86400) {
                Navigator.pop(dialogContext, value);
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a value between 15 and 86400'),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _intervalSeconds = result;
      });
      AppDatabase.saveSettings(intervalSeconds: result);
    }
  }

  String _formatInterval(int seconds) {
    if (seconds < 60) {
      return '$seconds sec';
    } else if (seconds < 3600) {
      final mins = seconds / 60.0;
      return '${mins.toStringAsFixed(1)} min';
    } else {
      final hours = seconds / 3600.0;
      return '${hours.toStringAsFixed(1)} hour${hours == 1.0 ? '' : 's'}';
    }
  }

  Future<void> _exportRecord(RecordGroup record, String format) async {
    try {
      final path = format == 'json'
          ? await ExportHelper.exportToJson(record)
          : await ExportHelper.exportToGpx(record);

      if (!mounted) return;

      _showMessage('Exported to $path');
    } catch (e) {
      _showMessage('Export failed: $e');
    }
  }

  Future<void> _deleteRecord(RecordGroup record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Record?'),
        content: Text(
          'Delete "${record.name}" and its '
          '${record.points.length} location points? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final deleted = await AppDatabase.deleteRecordGroup(record);

      await _loadRecords();

      _showMessage('Deleted $deleted location points.');
    } catch (e) {
      _showMessage('Failed to delete record: $e');
    }
  }

  Future<void> _clearAllRecords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all records?'),
        content: const Text(
          'This permanently deletes all recorded location points. '
          'Export a backup first if you want to keep them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final deleted = await AppDatabase.clearAllRecords();
      await _loadRecords();

      _showMessage('Deleted $deleted location points.');
    } catch (e) {
      _showMessage('Failed to clear records: $e');
    }
  }

  Future<void> _onExportAllRecords() async {
    if (_isBusy) return;

    final format = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Choose Export Format',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('JSON Format'),
              subtitle: const Text(
                'Includes custom metadata and raw timestamps',
              ),
              onTap: () => Navigator.pop(context, 'json'),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('GPX Format'),
              subtitle: const Text(
                'Standard track format with offset extensions',
              ),
              onTap: () => Navigator.pop(context, 'gpx'),
            ),
          ],
        ),
      ),
    );

    if (format == null) return;

    setState(() => _isBusy = true);

    try {
      String path;
      if (format == 'json') {
        path = await ExportHelper.exportAllRecordsToJson();
      } else {
        path = await ExportHelper.exportAllRecordsToGpx();
      }

      _showMessage('All records exported to $path');
    } catch (e) {
      _showMessage('Export failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _importRecord() async {
    try {
      final imported = await ExportHelper.importRecord();

      if (imported == null || !mounted) {
        _showMessage('Import failed: Incorrect data format.');
        return;
      }

      await _loadRecords();
      _showMessage('Imported $imported location points.');
    } catch (e) {
      _showMessage('Import failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Recorder'),
        actions: [
          IconButton(
            tooltip: 'Refresh records',
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recording Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Interval:'),
                          OutlinedButton.icon(
                            onPressed: (_isTracking || _isBusy)
                                ? null
                                : _showIntervalInputDialog,
                            icon: const Icon(Icons.timer, size: 18),
                            label: Text(
                              _formatInterval(_intervalSeconds),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9C27B0),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Daily recording boundary'),
                          ),
                          DropdownButton<int>(
                            value: _startHour,
                            items: List.generate(24, (hour) {
                              final label =
                                  '${hour.toString().padLeft(2, '0')}:00';

                              return DropdownMenuItem<int>(
                                value: hour,
                                child: Text(label),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;

                              setState(() => _startHour = value);
                              _loadRecords();
                              AppDatabase.saveSettings(startHour: value);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _toggleTracking,
                  style: FilledButton.styleFrom(
                    backgroundColor: _isTracking
                        ? Colors.red.shade800
                        : const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                  ),
                  icon: _isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isTracking
                              ? Icons.stop_circle
                              : Icons.fiber_manual_record,
                        ),
                  label: Text(
                    _isBusy
                        ? 'Please wait...'
                        : _isTracking
                        ? 'Stop Recording'
                        : 'Start Recording',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Saved Records',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${_records.length} records',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _records.isEmpty
                    ? const Center(
                        child: Text(
                          'No records yet.\nStart recording to collect locations.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _records.length,
                        itemBuilder: (context, index) {
                          final record = _records[index];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.route),
                              title: Text(record.name),
                              subtitle: Text(
                                '${record.points.length} points recorded',
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MapScreen(recordGroup: record),
                                  ),
                                );
                              },
                              trailing: PopupMenuButton<String>(
                                tooltip: 'Record options',
                                onSelected: (action) {
                                  switch (action) {
                                    case 'json':
                                    case 'gpx':
                                      _exportRecord(record, action);
                                      break;

                                    case 'delete':
                                      _deleteRecord(record);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'json',
                                    child: ListTile(
                                      leading: Icon(Icons.data_object),
                                      title: Text('Export JSON'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'gpx',
                                    child: ListTile(
                                      leading: Icon(Icons.map_outlined),
                                      title: Text('Export GPX'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  PopupMenuDivider(),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      title: Text(
                                        'Delete Record',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _importRecord,
                    icon: const Icon(Icons.file_open),
                    label: const Text('Import Record'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _clearAllRecords,
                    icon: const Icon(Icons.delete_forever),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    label: const Text('Clear All Records'),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _onExportAllRecords,
                    icon: const Icon(Icons.download),
                    label: const Text('Export All Records'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loadRecords,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Records'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
