import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../widgets/route_info_panel.dart';
import '../widgets/search_panel.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _initialCenter = LatLng(41.9981, 21.4254);
  static const double _estimatedSpeedKmh = 40;

  // Mock route used for progress tracking.
  static const List<LatLng> _mockRoute = [
    LatLng(41.9981, 21.4254),
    LatLng(41.9994, 21.4240),
    LatLng(42.0008, 21.4224),
    LatLng(42.0023, 21.4203),
    LatLng(42.0036, 21.4178),
    LatLng(42.0048, 21.4118),
  ];

  LatLng? _start;
  LatLng? _end;
  LatLng? _currentLocation;
  bool _isSearchOpen = false;

  Timer? _mockLocationTimer;
  int _mockRouteIndex = 0;

  late final TextEditingController _startController;
  late final TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController();
    _endController = TextEditingController();
    _startMockLocationUpdates();
  }

  @override
  void dispose() {
    _mockLocationTimer?.cancel();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _startMockLocationUpdates() {
    _mockLocationTimer?.cancel();
    _mockRouteIndex = 0;
    _currentLocation = _mockRoute.first;
    _mockLocationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_mockRouteIndex >= _mockRoute.length - 1) {
        return;
      }
      setState(() {
        _mockRouteIndex += 1;
        _currentLocation = _mockRoute[_mockRouteIndex];
      });
    });
  }

  void _handleMapTap(LatLng point) {
    setState(() {
      if (_start == null) {
        _start = point;
        _end = null;
        _startController.text = _formatLatLng(point);
        _endController.clear();
        return;
      }
      if (_end == null) {
        _end = point;
        _endController.text = _formatLatLng(point);
        return;
      }
      _start = point;
      _end = null;
      _startController.text = _formatLatLng(point);
      _endController.clear();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchOpen = !_isSearchOpen;
    });
  }

  void _closeSearch() {
    setState(() {
      _isSearchOpen = false;
    });
  }

  void _clearSearch() {
    setState(() {
      _start = null;
      _end = null;
      _startController.clear();
      _endController.clear();
      _startMockLocationUpdates();
    });
  }

  void _swapLocations() {
    setState(() {
      final previousStart = _start;
      _start = _end;
      _end = previousStart;
      final startText = _startController.text;
      _startController.text = _endController.text;
      _endController.text = startText;
    });
  }

  String _formatLatLng(LatLng point) {
    return '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
  }

  LatLng? _parseLatLng(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parts = trimmed.split(',');
    if (parts.length != 2) {
      return null;
    }
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) {
      return null;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  void _handleStartSubmitted(String value) {
    final parsed = _parseLatLng(value);
    if (parsed == null) {
      return;
    }
    setState(() {
      _start = parsed;
      _startController.text = _formatLatLng(parsed);
      _startMockLocationUpdates();
    });
  }

  void _handleEndSubmitted(String value) {
    final parsed = _parseLatLng(value);
    if (parsed == null) {
      return;
    }
    setState(() {
      _end = parsed;
      _endController.text = _formatLatLng(parsed);
      _startMockLocationUpdates();
    });
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  double? _routeDistanceMeters() {
    if (_start == null || _end == null) {
      return null;
    }
    final distance = const Distance();
    return distance.as(LengthUnit.Meter, _start!, _end!);
  }

  Duration? _estimatedDuration(double meters) {
    final hours = (meters / 1000) / _estimatedSpeedKmh;
    return Duration(minutes: (hours * 60).round());
  }

  int? _closestRouteSegmentIndex(List<LatLng> route, LatLng location) {
    if (route.length < 2) {
      return null;
    }
    final distance = const Distance();
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < route.length - 1; i++) {
      final projection = _projectPointOnSegment(location, route[i], route[i + 1]);
      final d = distance.as(LengthUnit.Meter, location, projection);
      if (d < bestDistance) {
        bestDistance = d;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  LatLng _projectPointOnSegment(LatLng point, LatLng start, LatLng end) {
    final startLat = start.latitude;
    final startLng = start.longitude;
    final endLat = end.latitude;
    final endLng = end.longitude;
    final dx = endLng - startLng;
    final dy = endLat - startLat;
    if (dx == 0 && dy == 0) {
      return start;
    }
    final t = ((point.longitude - startLng) * dx + (point.latitude - startLat) * dy) / (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);
    return LatLng(startLat + dy * clamped, startLng + dx * clamped);
  }

  List<LatLng> _completedRoute(List<LatLng> route, LatLng? location) {
    if (location == null || route.length < 2) {
      return const [];
    }
    final index = _closestRouteSegmentIndex(route, location);
    if (index == null) {
      return const [];
    }
    return route.sublist(0, index + 1);
  }

  List<LatLng> _remainingRoute(List<LatLng> route, LatLng? location) {
    if (location == null || route.length < 2) {
      return route;
    }
    final index = _closestRouteSegmentIndex(route, location);
    if (index == null) {
      return route;
    }
    return route.sublist(index + 1);
  }

  @override
  Widget build(BuildContext context) {
    final completedRoute = _completedRoute(_mockRoute, _currentLocation);
    final remainingRoute = _remainingRoute(_mockRoute, _currentLocation);

    final markers = <Marker>[
      if (_start != null)
        Marker(
          point: _start!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.location_on,
            color: Colors.green,
            size: 36,
          ),
        ),
      if (_end != null)
        Marker(
          point: _end!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.flag,
            color: Colors.red,
            size: 30,
          ),
        ),
      if (_currentLocation != null)
        Marker(
          point: _currentLocation!,
          width: 28,
          height: 28,
          child: const Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 24,
          ),
        ),
    ];

    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    final availableHeight = MediaQuery.of(context).size.height - topInset - 8;
    final panelHeight = (availableHeight.clamp(160.0, 320.0) as double);

    final searchPanel = SearchPanel(
      isOpen: _isSearchOpen,
      topInset: topInset,
      panelHeight: panelHeight,
      startController: _startController,
      endController: _endController,
      onClear: _clearSearch,
      onClose: _closeSearch,
      onStartSubmitted: _handleStartSubmitted,
      onEndSubmitted: _handleEndSubmitted,
      onSwap: _swapLocations,
      canSwap: _start != null || _end != null,
    );

    final distanceMeters = _routeDistanceMeters();
    final duration = distanceMeters == null ? null : _estimatedDuration(distanceMeters);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Better Roads'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleSearch,
        tooltip: _isSearchOpen ? 'Close search' : 'Open search',
        child: Icon(_isSearchOpen ? Icons.close : Icons.search),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 13,
              minZoom: 3,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (_, point) => _handleMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'betterroads',
              ),
              PolylineLayer(
                polylines: [
                  if (remainingRoute.isNotEmpty)
                    Polyline(
                      points: remainingRoute,
                      color: Colors.black.withOpacity(0.7),
                      strokeWidth: 6,
                    ),
                  if (completedRoute.isNotEmpty)
                    Polyline(
                      points: completedRoute,
                      color: Colors.greenAccent,
                      strokeWidth: 6,
                    ),
                ],
              ),
              MarkerLayer(
                markers: markers,
              ),
            ],
          ),
          searchPanel,
          RouteInfoPanel(
            distanceText: distanceMeters == null ? '--' : _formatDistance(distanceMeters),
            durationText: duration == null ? '--' : _formatDuration(duration),
          ),
        ],
      ),
    );
  }
}

