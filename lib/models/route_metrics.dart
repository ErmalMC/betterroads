class RouteMetrics {
  const RouteMetrics({
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final double distanceMeters;
  final int durationSeconds;

  // computed getters for formatted values
  double get distanceKm => distanceMeters / 1000;

  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';

  Duration get duration => Duration(seconds: durationSeconds);

  String get formattedDuration {
    int hours = durationSeconds ~/ 3600;
    int minutes = (durationSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    return '$minutes min';
  }

  factory RouteMetrics.fromJson(Map<String, dynamic> json) {
    final routeData = json['route'] as Map<String, dynamic>;

    return RouteMetrics(
      distanceMeters: (routeData['total_distance_meters'] as num).toDouble(),
      durationSeconds: (routeData['estimated_duration_seconds'] as num).toInt(),
    );
  }
}