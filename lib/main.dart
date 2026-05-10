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

  LatLng? _start;
  LatLng? _end;

  void _handleMapTap(LatLng point) {
    setState(() {
      if (_start == null) {
        _start = point;
        _end = null;
        return;
      }
      if (_end == null) {
        _end = point;
        return;
      }
      _start = point;
      _end = null;
    });
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Better Roads'),
      ),
      body: FlutterMap(
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
    );
  }
}