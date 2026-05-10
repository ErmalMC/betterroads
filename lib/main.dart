import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Better Roads',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _initialCenter = LatLng(41.9981, 21.4254);
  static const double _estimatedSpeedKmh = 40;

  LatLng? _start;
  LatLng? _end;
  bool _isSearchOpen = false;

  late final TextEditingController _startController;
  late final TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController();
    _endController = TextEditingController();
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
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
    ];

    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    final availableHeight = MediaQuery.of(context).size.height - topInset - 8;
    final panelHeight = (availableHeight.clamp(160.0, 320.0) as double);

    final searchPanel = AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      left: 0,
      right: 0,
      top: _isSearchOpen ? topInset : topInset - panelHeight - 8,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: panelHeight),
        child: Material(
          elevation: 4,
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            bottom: false,
            top: false,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Search locations',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _clearSearch,
                              child: const Text('Clear'),
                            ),
                            IconButton(
                              tooltip: 'Close search',
                              onPressed: _closeSearch,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _startController,
                      decoration: const InputDecoration(
                        labelText: 'Start location (lat, lng)',
                        prefixIcon: Icon(Icons.trip_origin),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: _handleStartSubmitted,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        onPressed: (_start != null || _end != null) ? _swapLocations : null,
                        icon: const Icon(Icons.swap_vert),
                        label: const Text('Swap'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _endController,
                      decoration: const InputDecoration(
                        labelText: 'Destination (lat, lng)',
                        prefixIcon: Icon(Icons.flag),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: _handleEndSubmitted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final distanceMeters = _routeDistanceMeters();
    final duration = distanceMeters == null ? null : _estimatedDuration(distanceMeters);

    final routeInfoPanel = Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Route info',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('Distance: ${distanceMeters == null ? '--' : _formatDistance(distanceMeters)}'),
              Text('Estimated time: ${duration == null ? '--' : _formatDuration(duration)}'),
            ],
          ),
        ),
      ),
    );

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
              MarkerLayer(
                markers: markers,
              ),
            ],
          ),
          searchPanel,
          routeInfoPanel,
        ],
      ),
    );
  }
}