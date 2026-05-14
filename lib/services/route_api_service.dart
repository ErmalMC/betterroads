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

  // Default to the hosted route API. Can still be overridden via
  // the ROUTE_API_BASE_URL environment variable when needed.
  static const String _defaultBaseUrl = String.fromEnvironment(
    'ROUTE_API_BASE_URL',
    defaultValue: 'https://least-curved-road.azurewebsites.net',
  );

  final String _baseUrl;
  final http.Client _client;

  Future<String> computeRoute({
    required LatLng start,
    required LatLng destination,
    String mode = 'driving', // 'driving' or 'walking'
  }) async {
    final uri = Uri.parse('$_baseUrl/api/route');
    final payload = {
      'origin_lat': start.latitude,
      'origin_lon': start.longitude,
      'dest_lat': destination.latitude,
      'dest_lon': destination.longitude,
      'mode': mode,
    };

    final response = await _client
        .post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    )
        // allow a bit more time for network requests to the remote API
        .timeout(const Duration(seconds: 30));

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