import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/location.dart';

class PhotonService {
  static Future<List<Location>> searchLocations(String query, {LatLng? locationBias}) async {
    if (query.isEmpty) return [];

    print('!!! photon_service received query: "$query"');

    String url =
        'https://photon.komoot.io/api/?q=$query&limit=5';

    print('!!! base: $url');

    if (locationBias != null) {
      url += '&lat=${locationBias.latitude}&lon=${locationBias.longitude}';
      print('!!! url w/ bias: $url');
    }

    final response = await http.get(Uri.parse(url),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    );

    print('!!! response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch locations');
    }

    final data = jsonDecode(response.body);

    final features = data['features'] as List;

    print('!!! found ${features.length} features');

    return features
        .map((feature) => Location.fromPhoton(feature))
        .toList();
  }

  static Future<Location?> reverseGeocode(double lat, double lon) async {
    try {
      final url = 'https://photon.komoot.io/api/?lat=$lat&lon=$lon';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0'},
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final features = data['features'] as List? ?? [];

      if (features.isEmpty) return null;

      return Location.fromPhoton(features.first);
    } catch (e) {
      print('Reverse geocoding error: $e');
      return null;
    }
  }

}