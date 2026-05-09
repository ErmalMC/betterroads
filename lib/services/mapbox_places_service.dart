import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapboxPlacesException implements Exception {
  const MapboxPlacesException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.id,
    required this.name,
    required this.placeName,
    required this.coordinates,
  });

  final String id;
  final String name;
  final String placeName;
  final LatLng coordinates;

  static PlaceSuggestion? fromJson(Map<String, dynamic> json) {
    final coordinates =
        _readRoutableCoordinates(json) ?? _readGeometryCoordinates(json);
    if (coordinates == null) {
      return null;
    }

    final placeName = json['place_name'] as String? ?? '';
    final name = json['text'] as String? ?? placeName;

    return PlaceSuggestion(
      id: json['id'] as String? ?? placeName,
      name: name,
      placeName: placeName.isEmpty ? name : placeName,
      coordinates: coordinates,
    );
  }

  static LatLng? _readRoutableCoordinates(Map<String, dynamic> json) {
    final properties = json['properties'];
    if (properties is! Map<String, dynamic>) {
      return null;
    }

    final routablePoints = properties['routable_points'];
    if (routablePoints is! List || routablePoints.isEmpty) {
      return null;
    }

    final firstPoint = routablePoints.first;
    if (firstPoint is! Map<String, dynamic>) {
      return null;
    }

    return _latLngFromLngLat(firstPoint['coordinates']);
  }

  static LatLng? _readGeometryCoordinates(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    if (geometry is! Map<String, dynamic>) {
      return null;
    }

    return _latLngFromLngLat(geometry['coordinates']);
  }

  static LatLng? _latLngFromLngLat(Object? value) {
    if (value is! List || value.length < 2) {
      return null;
    }

    final longitude = _toDouble(value[0]);
    final latitude = _toDouble(value[1]);
    if (latitude == null || longitude == null) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  static double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}

class MapboxPlacesService {
  static const defaultAccessToken =
      'HERE_GOES_API_KEY(starting with pk.)';

  MapboxPlacesService({
    http.Client? client,
    this.accessToken = const String.fromEnvironment(
      'MAPBOX_ACCESS_TOKEN',
      defaultValue: defaultAccessToken,
    ),
    this.proximity,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final String accessToken;
  final LatLng? proximity;
  final http.Client _client;
  final bool _ownsClient;

  bool get hasAccessToken => accessToken.trim().isNotEmpty;

  Future<List<PlaceSuggestion>> search(String query, {int limit = 5}) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 3) {
      return const [];
    }
    if (!hasAccessToken) {
      throw const MapboxPlacesException(
        'Missing Mapbox access token. Run with --dart-define=MAPBOX_ACCESS_TOKEN=your_token.',
      );
    }

    final response = await _client.get(_searchUri(trimmedQuery, limit: limit));
    if (response.statusCode != 200) {
      throw MapboxPlacesException(_errorMessage(response));
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const MapboxPlacesException(
        'Mapbox returned an unexpected result.',
      );
    }

    final features = body['features'];
    if (features is! List) {
      return const [];
    }

    return features
        .whereType<Map<String, dynamic>>()
        .map(PlaceSuggestion.fromJson)
        .nonNulls
        .toList(growable: false);
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Uri _searchUri(String query, {required int limit}) {
    final parameters = <String, String>{
      'access_token': accessToken,
      'autocomplete': 'true',
      'limit': limit.clamp(1, 10).toString(),
      'routing': 'true',
      'types':
          'country,region,postcode,district,place,locality,neighborhood,address',
    };

    if (proximity != null) {
      parameters['proximity'] =
          '${proximity!.longitude},${proximity!.latitude}';
    }

    return Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json',
    ).replace(queryParameters: parameters);
  }

  String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final message = body['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } on FormatException {
      // Fall through to the generic status message below.
    }

    return 'Mapbox search failed (${response.statusCode}).';
  }
}
