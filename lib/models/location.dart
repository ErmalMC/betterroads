class Location {
  final String name;
  final double lat;
  final double lon;

  Location({
    required this.name,
    required this.lat,
    required this.lon,
  });

  factory Location.fromPhoton(Map<String, dynamic> json) {
    final properties = json['properties'];
    final coords = json['geometry']['coordinates'];

    return Location(
      name: properties['name'] ?? 'Unknown',
      lat: coords[1],
      lon: coords[0],
    );
  }
}