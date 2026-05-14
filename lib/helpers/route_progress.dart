import 'package:latlong2/latlong.dart';

class RouteProgressHelper {
  const RouteProgressHelper();

  int? closestRouteSegmentIndex(List<LatLng> route, LatLng location) {
    if (route.length < 2) {
      return null;
    }
    final distance = const Distance();
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < route.length - 1; i++) {
      final projection = _projectPointOnSegment(location, route[i], route[i + 1]);
      final d = distance.as(LengthUnit.Meter, location, projection);
      if (d < bestDistance) {
        bestDistance = d;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  List<LatLng> completedRoute(List<LatLng> route, LatLng? location) {
    if (location == null || route.length < 2) {
      return const [];
    }
    final index = closestRouteSegmentIndex(route, location);
    if (index == null) {
      return const [];
    }
    return route.sublist(0, index + 1);
  }

  List<LatLng> remainingRoute(List<LatLng> route, LatLng? location) {
    if (location == null || route.length < 2) {
      return route;
    }
    final index = closestRouteSegmentIndex(route, location);
    if (index == null) {
      return route;
    }
    return route.sublist(index + 1);
  }

  LatLng _projectPointOnSegment(LatLng point, LatLng start, LatLng end) {
    final startLat = start.latitude;
    final startLng = start.longitude;
    final endLat = end.latitude;
    final endLng = end.longitude;
    final dx = endLng - startLng;
    final dy = endLat - startLat;
    if (dx == 0 && dy == 0) {
      return start;
    }
    final t = ((point.longitude - startLng) * dx + (point.latitude - startLat) * dy) / (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);
    return LatLng(startLat + dy * clamped, startLng + dx * clamped);
  }
}

