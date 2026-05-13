import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class PythonChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.example.betterroads/python',
  );

  static Future<String> exampleFunction(String message) async {
    final result = await _channel.invokeMethod<String>('example_function', {
      'message': message,
    });
    return result ?? '';
  }

  static Future<String> computeRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    final arguments = {
      'start_latitude': start.latitude,
      'start_longitude': start.longitude,
      'destination_latitude': destination.latitude,
      'destination_longitude': destination.longitude,
    };

    try {
      final result = await _channel.invokeMethod<String>(
        'compute_route',
        arguments,
      );
      return result ?? '';
    } on MissingPluginException {
      return jsonEncode({
        'status': 'ok',
        'start': {'latitude': start.latitude, 'longitude': start.longitude},
        'destination': {
          'latitude': destination.latitude,
          'longitude': destination.longitude,
        },
      });
    }
  }
}
