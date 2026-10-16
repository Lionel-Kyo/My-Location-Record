import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'database_helper.dart';

class MapScreen extends StatefulWidget {
  final RecordGroup recordGroup;

  const MapScreen({super.key, required this.recordGroup});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  late final List<LocationPoint> _validPoints;
  List<LocationPoint> _selectedPoints = [];

  @override
  void initState() {
    super.initState();

    _validPoints = widget.recordGroup.points.where((point) {
      final lat = point.latLng.latitude;
      final lon = point.latLng.longitude;
      return lat.isFinite &&
          lon.isFinite &&
          lat >= -90 &&
          lat <= 90 &&
          lon >= -180 &&
          lon <= 180;
    }).toList();
  }

  void _moveNorth() {
    _mapController.rotate(0);
  }

  void _backToFirstPoint() {
    if (_validPoints.isEmpty) return;
    _mapController.move(_validPoints.first.latLng, 15);
  }

  String _formatTimestamp(LocationPoint point) {
    final utcTime = point.timestampUtc;
    final recordedClockTime = utcTime.add(
      Duration(minutes: point.tzOffsetMinutes),
    );

    return '${recordedClockTime.year.toString().padLeft(4, '0')}-'
        '${recordedClockTime.month.toString().padLeft(2, '0')}-'
        '${recordedClockTime.day.toString().padLeft(2, '0')} '
        '${recordedClockTime.hour.toString().padLeft(2, '0')}:'
        '${recordedClockTime.minute.toString().padLeft(2, '0')}:'
        '${recordedClockTime.second.toString().padLeft(2, '0')} '
        '(Offset: ${point.tzOffsetMinutes >= 0 ? '+' : ''}${point.tzOffsetMinutes}m)';
  }

  void _handleMapTap(LatLng tappedLatLng) {
    const distanceCalculator = Distance();
    const double thresholdMeters = 35.0;

    final nearbyPoints = _validPoints.where((point) {
      final distance = distanceCalculator.as(
        LengthUnit.Meter,
        tappedLatLng,
        point.latLng,
      );
      return distance <= thresholdMeters;
    }).toList();

    nearbyPoints.sort((a, b) => b.timestampUtc.compareTo(a.timestampUtc));

    setState(() {
      _selectedPoints = nearbyPoints;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPoints = _validPoints.isNotEmpty;
    final latLngList = _validPoints.map((p) => p.latLng).toList();
    final uniquePoints = latLngList.toSet().toList();
    final canFitBounds = uniquePoints.length > 1;

    return Scaffold(
      appBar: AppBar(title: Text(widget.recordGroup.name)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: hasPoints
                        ? _validPoints.first.latLng
                        : const LatLng(22.3529, 113.9745),
                    initialZoom: 15,
                    initialCameraFit: canFitBounds
                        ? CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints(uniquePoints),
                            padding: const EdgeInsets.all(48),
                          )
                        : null,
                    onTap: (_, tappedLatLng) {
                      _handleMapTap(tappedLatLng);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.my_location_record',
                    ),
                    if (_validPoints.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: latLngList,
                            color: const Color(0xFFBA68C8),
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                    if (hasPoints)
                      MarkerLayer(
                        markers: _validPoints.map((point) {
                          final isFirst = point == _validPoints.first;
                          final isLast = point == _validPoints.last;
                          final isSelected = _selectedPoints.contains(point);

                          Color color = Colors.blue;
                          if (isFirst) color = Colors.green;
                          if (isLast) color = Colors.red;
                          if (isSelected) color = const Color(0xFFFFB74D);

                          return Marker(
                            point: point.latLng,
                            width: 36,
                            height: 36,
                            child: GestureDetector(
                              onTap: () {
                                _handleMapTap(point.latLng);
                              },
                              child: Icon(
                                Icons.location_on,
                                color: color,
                                size: isSelected ? 44 : 32,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),

                if (_selectedPoints.isNotEmpty)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 80,
                    child: Card(
                      color: Theme.of(context).colorScheme.surface,
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      color: Color(0xFFBA68C8),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_selectedPoints.length} point(s) nearby',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () =>
                                      setState(() => _selectedPoints = []),
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 140),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _selectedPoints.length,
                                itemBuilder: (context, index) {
                                  final pt = _selectedPoints[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      _formatTimestamp(pt),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  right: 16,
                  top: _selectedPoints.isNotEmpty ? 160 : 16,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'northButton',
                        tooltip: 'Move to North',
                        onPressed: _moveNorth,
                        child: const Icon(Icons.navigation),
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton.small(
                        heroTag: 'firstPointButton',
                        tooltip: 'Back to first point',
                        onPressed: hasPoints ? _backToFirstPoint : null,
                        child: const Icon(Icons.first_page),
                      ),
                    ],
                  ),
                ),

                if (!hasPoints)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor
                            .withValues(alpha: 0.85),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No valid location points found.\n\n'
                              'Start recording and refresh your records.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${_validPoints.length} location points',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
