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

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  static const LatLng _start = LatLng(41.9981, 21.4254);
  static const LatLng _end = LatLng(42.0048, 21.4118);
  static const List<LatLng> _sampleRoute = [
    _start,
    LatLng(42.0002, 21.4215),
    LatLng(42.0026, 21.4182),
    LatLng(42.0040, 21.4143),
    _end,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Better Roads'),
      ),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: _start,
          initialZoom: 13,
          minZoom: 3,
          maxZoom: 18,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'betterroads',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: _sampleRoute,
                color: Colors.black.withOpacity(0.8),
                strokeWidth: 8,
              ),
              Polyline(
                points: _sampleRoute,
                color: Colors.yellowAccent,
                strokeWidth: 5,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _start,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.green,
                  size: 36,
                ),
              ),
              Marker(
                point: _end,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.flag,
                  color: Colors.red,
                  size: 30,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}