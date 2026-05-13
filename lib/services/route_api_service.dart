import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteApiService {
  RouteApiService({
    String? baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl ?? _defaultBaseUrl,
        _client = client ?? http.Client();

  static const String _defaultBaseUrl = String.fromEnvironment(
    'ROUTE_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  final String _baseUrl;
  final http.Client _client;

  Future<String> computeRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/route');
    final payload = {
      'origin_lat': start.latitude,
      'origin_lon': start.longitude,
      'dest_lat': destination.latitude,
      'dest_lon': destination.longitude,
      'mode': 'driving',
    };

    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TimeoutException(
        'Route API failed with status ${response.statusCode}.',
      );
    }

    return response.body;
  }

  void dispose() {
    _client.close();
  }
}

