import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_metrics.dart';
import '../services/route_api_service.dart';
import '../services/photon_service.dart';
import '../models/location.dart';
import '../widgets/route_info_panel.dart';

typedef ComputeRouteCallback =
    Future<String> Function({
      required LatLng start,
      required LatLng destination,
      String mode,
    });

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.computeRoute, this.routeApiBaseUrl});

  final ComputeRouteCallback? computeRoute;
  final String? routeApiBaseUrl;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _defaultStart = LatLng(41.9981, 21.4254);
  static const LatLng _defaultDestination = LatLng(42.0048, 21.4118);

  final MapController _mapController = MapController();
  final TextEditingController _startLocationController =
      TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _startLocationFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  late final ComputeRouteCallback _computeRoute;
  late final RouteApiService _routeApiService;
  LatLng? _userCurrentLocation;
  LatLng? _searchBiasLocation;
  Timer? _startSearchDebounce;
  Timer? _destinationSearchDebounce;
  List<Location> _startSuggestions = const [];
  List<Location> _destinationSuggestions = const [];
  LatLng _selectedStartCoordinates = _defaultStart;
  String? _selectedStartLabel;
  String? _startSearchError;
  String? _destinationSearchError;
  bool _isSearchingStart = false;
  bool _isSearchingDestination = false;
  bool _hasSearchedStart = false;
  bool _hasSearchedDestination = false;
  bool _isLoadingLocation = false;
  String _routeDistance = '';
  String _routeDuration = '';
  String _routeMode = 'driving'; // 'driving' or 'walking'
  bool _hasRouteInfo = false;
  int _startSearchRequestId = 0;
  int _destinationSearchRequestId = 0;
  LatLng _selectedDestinationCoordinates = _defaultDestination;
  String? _selectedDestinationLabel;
  bool _hasSelectedStart = false;
  bool _hasSelectedDestination = false;
  bool _isComputingRoute = false;
  String? _routeStatusMessage;
  bool _isRouteStatusError = false;
  List<LatLng> _generatedRoutePoints = const [];
  StreamSubscription<Position>? _positionSubscription;
  bool _followUser = true;
  bool _isSearchOpen = const bool.fromEnvironment('FLUTTER_TEST');

  bool get _showNoResults {
    return _hasSearchedStart &&
        !_isSearchingStart &&
        _startSearchError == null &&
        _startLocationController.text.trim().length >= 3 &&
        _startSuggestions.isEmpty;
  }

  bool get _showDestinationNoResults {
    return _hasSearchedDestination &&
        !_isSearchingDestination &&
        _destinationSearchError == null &&
        _destinationController.text.trim().length >= 3 &&
        _destinationSuggestions.isEmpty;
  }

  String _getDisplayName(Location location) {
    if (location.name.isNotEmpty && location.name != 'Unknown') {
      return location.name;
    }
    return '${location.lat.toStringAsFixed(5)}, ${location.lon.toStringAsFixed(5)}';
  }

  @override
  void initState() {
    super.initState();
    _routeApiService = RouteApiService(baseUrl: widget.routeApiBaseUrl);
    _computeRoute = widget.computeRoute ?? _routeApiService.computeRoute;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getAndRecenterToCurrentLocation();
    });
  }

  @override
  void dispose() {
    _startSearchDebounce?.cancel();
    _positionSubscription?.cancel();
    _destinationSearchDebounce?.cancel();
    _startLocationController.dispose();
    _destinationController.dispose();
    _startLocationFocusNode.dispose();
    _destinationFocusNode.dispose();
    _mapController.dispose();
    _routeApiService.dispose();
    super.dispose();
  }

  void _startLiveLocationTracking() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // update every 5 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((Position position) {
      final newLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _userCurrentLocation = newLatLng;
      });


      if (_followUser) {
        _mapController.move(newLatLng, _currentZoom());
      }
    });
  }

  void _onStartLocationChanged(String value) {
    _startSearchDebounce?.cancel();
    final query = value.trim();

    setState(() {
      _selectedStartLabel = null;
      _hasSelectedStart = false;
      _routeStatusMessage = null;
      _generatedRoutePoints = const [];
      _startSearchError = null;
      _hasSearchedStart = false;
    });

    if (query == 'Current Location') {
      _startSearchRequestId++;
      setState(() {
        _isSearchingStart = false;
        _startSuggestions = const [];
      });
      return;
    }

    if (query.length < 3) {
      _startSearchRequestId++;
      setState(() {
        _isSearchingStart = false;
        _startSuggestions = const [];
      });
      return;
    }

    _startSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchStartLocation(query),
    );
  }

  Future<void> _searchStartLocation(String query) async {
    final requestId = ++_startSearchRequestId;

    setState(() {
      _isSearchingStart = true;
      _startSearchError = null;
    });

    try {
      print('Searching for: $query');

      final locations = await PhotonService.searchLocations(
        query,
        locationBias: _userCurrentLocation,
      );

      print('Got ${locations.length} results');

      if (!mounted || requestId != _startSearchRequestId) {
        return;
      }

      setState(() {
        _startSuggestions = locations;
        _isSearchingStart = false;
        _hasSearchedStart = true;
      });
    } catch (error) {
      if (!mounted || requestId != _startSearchRequestId) {
        return;
      }

      setState(() {
        _startSuggestions = const [];
        _isSearchingStart = false;
        _hasSearchedStart = true;
        _startSearchError = 'Unable to load location suggestions.';
      });
    }
  }

  void _selectStartLocation(Location location) {
    _startSearchDebounce?.cancel();
    _startSearchRequestId++;

    final selectedPoint = LatLng(location.lat, location.lon);
    final displayName = _getDisplayName(location);

    setState(() {
      _selectedStartCoordinates = selectedPoint;
      _selectedStartLabel = displayName;
      _hasSelectedStart = true;
      _routeStatusMessage = null;
      _generatedRoutePoints = const [];
      _startLocationController.text = displayName;
      _startLocationController.selection = TextSelection.collapsed(
        offset: displayName.length,
      );
      _startSuggestions = const [];
      _startSearchError = null;
      _hasSearchedStart = false;
      _isSearchingStart = false;
    });

    _startLocationFocusNode.unfocus();
    _mapController.move(selectedPoint, math.max(_currentZoom(), 14));
  }

  void _clearStartLocation() {
    _startSearchDebounce?.cancel();
    _startSearchRequestId++;

    setState(() {
      _startLocationController.clear();
      _selectedStartCoordinates = _defaultStart;
      _selectedStartLabel = null;
      _hasSelectedStart = false;
      _routeStatusMessage = null;
      _generatedRoutePoints = const [];
      _startSuggestions = const [];
      _startSearchError = null;
      _hasSearchedStart = false;
      _isSearchingStart = false;
    });
  }

  void _swapStartAndDestination() {
    if (!_hasSelectedStart || !_hasSelectedDestination) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select both start and destination first'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      final tempCoordinates = _selectedStartCoordinates;
      _selectedStartCoordinates = _selectedDestinationCoordinates;
      _selectedDestinationCoordinates = tempCoordinates;

      final tempLabel = _selectedStartLabel;
      _selectedStartLabel = _selectedDestinationLabel;
      _selectedDestinationLabel = tempLabel;

      final tempText = _startLocationController.text;
      _startLocationController.text = _destinationController.text;
      _destinationController.text = tempText;

      _routeStatusMessage = null;
      _generatedRoutePoints = const [];

      _hasSelectedStart = true;
      _hasSelectedDestination = true;
    });

    _mapController.move(_selectedStartCoordinates, _currentZoom());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Start and destination swapped'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _toggleRouteMode() {
    setState(() {
      _routeMode = _routeMode == 'driving' ? 'walking' : 'driving';
    });
    _requestRoute(); // recalculate with new mode
  }

  void _onDestinationChanged(String value) {
    _destinationSearchDebounce?.cancel();
    final query = value.trim();
    final coordinates = _parseCoordinates(value);

    setState(() {
      _selectedDestinationLabel = null;
      _hasSelectedDestination = false;
      _routeStatusMessage = null;
      _generatedRoutePoints = const [];
      _destinationSearchError = null;
      _hasSearchedDestination = false;

      if (coordinates != null) {
        _destinationSearchRequestId++;
        _selectedDestinationCoordinates = coordinates;
        _selectedDestinationLabel = 'Destination coordinates';
        _hasSelectedDestination = true;
        _destinationSuggestions = const [];
        _isSearchingDestination = false;
        return;
      }

      _destinationSuggestions = const [];
    });

    if (coordinates != null) {
      return;
    }

    if (query.length < 3) {
      _destinationSearchRequestId++;
      setState(() {
        _isSearchingDestination = false;
      });
      return;
    }

    _destinationSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchDestination(query),
    );
  }

  void _parseRouteInfo(String response) {
    try {
      final decoded = jsonDecode(response);
      final routeMetrics = RouteMetrics.fromJson(decoded);

      setState(() {
        _routeDistance = routeMetrics.formattedDistance;
        _routeDuration = routeMetrics.formattedDuration;
        _hasRouteInfo = true;
      });
    } catch (e) {
      print('Error parsing route info: $e');
      setState(() {
        _hasRouteInfo = false;
      });
    }
  }

  Future<void> _searchDestination(String query) async {
    final requestId = ++_destinationSearchRequestId;

    setState(() {
      _isSearchingDestination = true;
      _destinationSearchError = null;
    });

    try {
      final locations = await PhotonService.searchLocations(
        query,
        locationBias: _userCurrentLocation,
      );
      if (!mounted || requestId != _destinationSearchRequestId) {
        return;
      }

      setState(() {
        _destinationSuggestions = locations;
        _isSearchingDestination = false;
        _hasSearchedDestination = true;
      });
    } catch (error) {
      if (!mounted || requestId != _destinationSearchRequestId) {
        return;
      }

      setState(() {
        _destinationSuggestions = const [];
        _isSearchingDestination = false;
        _hasSearchedDestination = true;
        _destinationSearchError = 'Unable to load destination suggestions.';
      });
    }
  }

  void _selectDestination(Location location) {
    _destinationSearchDebounce?.cancel();
    _destinationSearchRequestId++;

    final selectedPoint = LatLng(location.lat, location.lon);
    final displayName = _getDisplayName(location);

    setState(() {
      _selectedDestinationCoordinates = selectedPoint;
      _selectedDestinationLabel = displayName;
      _hasSelectedDestination = true;
      _routeStatusMessage = null;
      _generatedRoutePoints = const [];
      _destinationController.text = displayName;
      _destinationController.selection = TextSelection.collapsed(
        offset: displayName.length,
      );
      _destinationSuggestions = const [];
      _destinationSearchError = null;
      _hasSearchedDestination = false;
      _isSearchingDestination = false;
    });

    _destinationFocusNode.unfocus();
    _mapController.move(selectedPoint, math.max(_currentZoom(), 14));
  }

  void _clearDestination() {
    _destinationSearchDebounce?.cancel();
    _destinationSearchRequestId++;

    setState(() {
      _destinationController.clear();
      _selectedDestinationCoordinates = _defaultDestination;
      _selectedDestinationLabel = null;
      _hasSelectedDestination = false;
      _routeStatusMessage = null;
      _generatedRoutePoints = const [];
      _destinationSuggestions = const [];
      _destinationSearchError = null;
      _hasSearchedDestination = false;
      _isSearchingDestination = false;
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchOpen = !_isSearchOpen;
    });
  }

  void _closeSearch() {
    setState(() {
      _isSearchOpen = false;
    });
  }

  void _clearSearch() {
    setState(() {
      _selectedStartCoordinates = _defaultStart;
      _selectedDestinationCoordinates = _defaultDestination;
      _selectedStartLabel = null;
      _selectedDestinationLabel = null;
      _hasSelectedStart = false;
      _hasSelectedDestination = false;
      _startLocationController.clear();
      _destinationController.clear();
      _routeStatusMessage = null;
      _generatedRoutePoints = const [];
      _startSuggestions = const [];
      _destinationSuggestions = const [];
      _startSearchError = null;
      _destinationSearchError = null;
    });
  }

  Future<void> _getAndRecenterToCurrentLocation() async {
    if (_isLoadingLocation) return;

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enable location services'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Location permission denied'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission permanently denied'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print('Current position: ${position.latitude}, ${position.longitude}');

      final currentLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _userCurrentLocation = currentLatLng;
        _isLoadingLocation = false;
      });

      _startLiveLocationTracking();

      _mapController.move(currentLatLng, _currentZoom());
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _setStartToCurrentLocation() {
    if (_userCurrentLocation != null) {
      setState(() {
        _selectedStartCoordinates = _userCurrentLocation!;
        _selectedStartLabel = 'Current Location';
        _hasSelectedStart = true;
        _startLocationController.text = 'Current Location';
        _routeStatusMessage = null;
        _generatedRoutePoints = const [];
        _startSuggestions = const [];
        _startSearchError = null;
        _hasSearchedStart = false;
        _isSearchingStart = false;
      });

      _startLocationFocusNode.unfocus();
      _mapController.move(_userCurrentLocation!, math.max(_currentZoom(), 14));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Starting point set to your current location'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to get current location. Please tap the location button first.',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _handleMapTap(LatLng point) {
    setState(() {
      _routeStatusMessage = null;
      _generatedRoutePoints = const [];

      if (!_hasSelectedStart ||
          (_hasSelectedStart && _hasSelectedDestination)) {
        _selectedStartCoordinates = point;
        _selectedStartLabel = 'Selected on map';
        _hasSelectedStart = true;
        _hasSelectedDestination = false;
        _startLocationController.text =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
        _destinationController.clear();
        return;
      }

      _selectedDestinationCoordinates = point;
      _selectedDestinationLabel = 'Selected on map';
      _hasSelectedDestination = true;
      _destinationController.text =
          '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    });
  }

  Future<void> _requestRoute() async {
    if (_isComputingRoute) {
      return;
    }

    if (!_hasSelectedStart || !_hasSelectedDestination) {
      setState(() {
        _routeStatusMessage = 'Select both start and destination first.';
        _isRouteStatusError = true;
      });
      return; // show that user needs to put locations
    }

    setState(() {
      _isComputingRoute = true;
      _generatedRoutePoints = const [];
      _routeStatusMessage = null;
      _isRouteStatusError = false;
    });

    try {
      final response = await _computeRoute(
        start: _selectedStartCoordinates,
        destination: _selectedDestinationCoordinates,
        mode: _routeMode,
      );
      final routePoints = _parseRouteResponse(response);
      if (!mounted) {
        return;
      }

      setState(() {
        _generatedRoutePoints = routePoints;
        _isRouteStatusError = false;
      });

      _parseRouteInfo(response);
      _fitRouteOnScreen(routePoints);
      _closeSearch(); // close panel and show route
    } on _RouteResponseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _routeStatusMessage = error.message;
        _isRouteStatusError = true;
      });
      // Search panel stays open
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _routeStatusMessage = 'Unable to compute route.';
        _isRouteStatusError = true;
      });
      // Search panel stays open
    } finally {
      if (mounted) {
        setState(() {
          _isComputingRoute = false;
        });
      }
    }
  }

  void _fitRouteOnScreen(List<LatLng> routePoints) {
    if (routePoints.isEmpty) return;

    // calculate center of the route
    double sumLat = 0;
    double sumLng = 0;

    for (final point in routePoints) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }

    final centerLat = sumLat / routePoints.length;
    final centerLng = sumLng / routePoints.length;
    final center = LatLng(centerLat, centerLng);

    // move to center with zoom level 13 (adjust if want)
    _mapController.move(center, 14);
  }

  void _handleStartSubmitted(String value) {
    final coordinates = _parseCoordinates(value);
    if (coordinates == null) {
      setState(() {
        _routeStatusMessage = 'Enter coordinates as "lat, lng".';
        _isRouteStatusError = true;
      });
      return;
    }

    _startSearchDebounce?.cancel();
    _startSearchRequestId++;

    setState(() {
      _selectedStartCoordinates = coordinates;
      _selectedStartLabel = 'Start coordinates';
      _hasSelectedStart = true;
      _routeStatusMessage = null;
      _generatedRoutePoints = const [];
      _startSuggestions = const [];
      _startSearchError = null;
      _hasSearchedStart = false;
      _isSearchingStart = false;
    });

    _mapController.move(coordinates, math.max(_currentZoom(), 14));
  }

  void _handleEndSubmitted(String value) {
    final coordinates = _parseCoordinates(value);
    if (coordinates == null) {
      setState(() {
        _routeStatusMessage = 'Enter coordinates as "lat, lng".';
        _isRouteStatusError = true;
      });
      return;
    }

    _destinationSearchDebounce?.cancel();
    _destinationSearchRequestId++;

    setState(() {
      _selectedDestinationCoordinates = coordinates;
      _selectedDestinationLabel = 'Destination coordinates';
      _hasSelectedDestination = true;
      _routeStatusMessage = null;
      _generatedRoutePoints = const [];
      _destinationSuggestions = const [];
      _destinationSearchError = null;
      _hasSearchedDestination = false;
      _isSearchingDestination = false;
    });

    _mapController.move(coordinates, math.max(_currentZoom(), 14));
  }

  LatLng? _parseCoordinates(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'[\s,]+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length != 2) {
      return null;
    }
    final latitude = double.tryParse(parts[0]);
    final longitude = double.tryParse(parts[1]);
    if (latitude == null || longitude == null) {
      return null;
    }
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  List<LatLng> _parseRouteResponse(String response) {
    if (response.trim().isEmpty) {
      throw const _RouteResponseException('No route response received.');
    }

    try {
      final decoded = jsonDecode(response);
      if (decoded is! Map<String, dynamic>) {
        throw const _RouteResponseException('Route response was invalid.');
      }

      final status = decoded['status'];
      if (status != null && status != 'ok' && status != 'success') {
        throw const _RouteResponseException('Route calculation failed.');
      }

      final routePoints = _coordinatesFromJsonList(
        decoded['route_points'] ??
            decoded['routePoints'] ??
            decoded['route']?['polyline'],
      );
      if (routePoints.length >= 2) {
        return routePoints;
      }

      final start = _coordinateFromJson(decoded['start']);
      final destination = _coordinateFromJson(decoded['destination']);
      if (start != null && destination != null) {
        return _fallbackRoutePoints(start, destination);
      }
    } on _RouteResponseException {
      rethrow;
    } catch (_) {
      throw const _RouteResponseException('Route response was invalid.');
    }

    throw const _RouteResponseException('No route found for those locations.');
  }

  List<LatLng> _coordinatesFromJsonList(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map(_coordinateFromJson)
        .whereType<LatLng>()
        .toList(growable: false);
  }

  LatLng? _coordinateFromJson(Object? value) {
    if (value is Map) {
      final latitude = _doubleFromJson(value['latitude'] ?? value['lat']);
      final longitude = _doubleFromJson(value['longitude'] ?? value['lng']);
      if (latitude != null && longitude != null) {
        return LatLng(latitude, longitude);
      }
    }

    if (value is List && value.length >= 2) {
      final latitude = _doubleFromJson(value[0]);
      final longitude = _doubleFromJson(value[1]);
      if (latitude != null && longitude != null) {
        return LatLng(latitude, longitude);
      }
    }

    return null;
  }

  double? _doubleFromJson(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  List<LatLng> _fallbackRoutePoints(LatLng start, LatLng destination) {
    final firstMidpoint = LatLng(
      (start.latitude * 2 + destination.latitude) / 3,
      (start.longitude * 2 + destination.longitude) / 3,
    );
    final secondMidpoint = LatLng(
      (start.latitude + destination.latitude * 2) / 3,
      (start.longitude + destination.longitude * 2) / 3,
    );

    return [start, firstMidpoint, secondMidpoint, destination];
  }

  double _currentZoom() {
    try {
      return _mapController.camera.zoom;
    } catch (_) {
      return 13;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightBlueTheme = Theme.of(context).copyWith(
      primaryColor: const Color(0xFF4A90E2),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4A90E2),
        primary: const Color(0xFF4A90E2),
        secondary: const Color(0xFF7AB8F5),
        surface: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A90E2),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );

    final searchPanel = AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      left: 12,
      right: 12,
      top: _isSearchOpen ? 12 : -500,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A90E2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Plan your route',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2C3E50),
                                ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _clearSearch,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF4A90E2),
                            ),
                            child: const Text('Clear all'),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              tooltip: 'Close search',
                              onPressed: _closeSearch,
                              icon: const Icon(Icons.close, size: 20),
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Start Location Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _startLocationController,
                      decoration: InputDecoration(
                        labelText: 'Start location',
                        labelStyle: TextStyle(color: Colors.grey.shade600),
                        prefixIcon: const Icon(
                          Icons.trip_origin,
                          color: Color(0xFF4A90E2),
                          size: 22,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: _onStartLocationChanged,
                      onSubmitted: _handleStartSubmitted,
                    ),
                  ),
                  if (_showNoResults)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'No results found',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (_startSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _startSuggestions.length,
                        itemBuilder: (context, index) {
                          final location = _startSuggestions[index];
                          return InkWell(
                            onTap: () => _selectStartLocation(location),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getDisplayName(location),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${location.lat.toStringAsFixed(4)}, ${location.lon.toStringAsFixed(4)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (_userCurrentLocation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton.icon(
                        onPressed: _setStartToCurrentLocation,
                        icon: const Icon(Icons.my_location, size: 18),
                        label: const Text('Use my current location'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4A90E2),
                          side: const BorderSide(color: Color(0xFF4A90E2)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Destination Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _destinationController,
                      decoration: InputDecoration(
                        labelText: 'Destination',
                        labelStyle: TextStyle(color: Colors.grey.shade600),
                        prefixIcon: const Icon(
                          Icons.flag,
                          color: Color(0xFFE74C3C),
                          size: 22,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onChanged: _onDestinationChanged,
                      onSubmitted: _handleEndSubmitted,
                    ),
                  ),
                  if (_showDestinationNoResults)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'No results found',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (_destinationSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _destinationSuggestions.length,
                        itemBuilder: (context, index) {
                          final location = _destinationSuggestions[index];
                          return InkWell(
                            onTap: () => _selectDestination(location),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getDisplayName(location),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${location.lat.toStringAsFixed(4)}, ${location.lon.toStringAsFixed(4)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Generate Route Button with Swap button next to it
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: ElevatedButton(
                          onPressed: _isComputingRoute ? null : _requestRoute,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isComputingRoute
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.route, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Generate route',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: (_hasSelectedStart && _hasSelectedDestination)
                              ? const Color(0xFF4A90E2).withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                (_hasSelectedStart && _hasSelectedDestination)
                                ? const Color(0xFF4A90E2).withValues(alpha: 0.3)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: IconButton(
                          onPressed:
                              (_hasSelectedStart && _hasSelectedDestination)
                              ? _swapStartAndDestination
                              : null,
                          icon: const Icon(Icons.swap_horiz, size: 24),
                          tooltip: 'Swap start and destination',
                          color: (_hasSelectedStart && _hasSelectedDestination)
                              ? const Color(0xFF4A90E2)
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  if (_routeStatusMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isRouteStatusError
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isRouteStatusError
                                ? Colors.red.shade200
                                : Colors.green.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isRouteStatusError
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              color: _isRouteStatusError
                                  ? Colors.red
                                  : Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _routeStatusMessage!,
                                style: TextStyle(
                                  color: _isRouteStatusError
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final markers = <Marker>[
      Marker(
        point: _selectedStartCoordinates,
        width: 50,
        height: 50,
        child: const Icon(
          Icons.location_on,
          color: Colors.green,
          size: 42,
          shadows: [
            Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black26),
          ],
        ),
      ),
      Marker(
        point: _selectedDestinationCoordinates,
        width: 50,
        height: 50,
        child: const Icon(
          Icons.flag,
          color: Colors.red,
          size: 36,
          shadows: [
            Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black26),
          ],
        ),
      ),
    ];

    return Theme(
      data: lightBlueTheme,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Better Roads',
            style: TextStyle(
              color: const Color(0xFF2C3E50),
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _clearSearch,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear all',
              color: const Color(0xFF4A90E2),
            ),
          ],
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: _toggleSearch,
                tooltip: _isSearchOpen ? 'Close search' : 'Open search',
                backgroundColor: _isSearchOpen
                    ? Colors.grey.shade700
                    : const Color(0xFF4A90E2),
                child: Icon(_isSearchOpen ? Icons.close : Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: _isLoadingLocation
                    ? null
                    : _getAndRecenterToCurrentLocation,
                tooltip: 'Get my location',
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4A90E2),
                child: _isLoadingLocation
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF4A90E2),
                          ),
                        ),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultStart,
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
                if (_userCurrentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _userCurrentLocation!,
                        width: 80,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedOpacity(
                              opacity: 0.5,
                              duration: const Duration(seconds: 1),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(
                                    0xFF4A90E2,
                                  ).withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF4A90E2),
                              ),
                            ),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (_generatedRoutePoints.isNotEmpty)
                  PolylineLayer(
                    key: const Key('route-polyline-layer'),
                    polylines: [
                      Polyline(
                        points: _generatedRoutePoints,
                        color: const Color(0xFF4A90E2).withValues(alpha: 0.4),
                        strokeWidth: 10,
                      ),
                      Polyline(
                        points: _generatedRoutePoints,
                        color: const Color(0xFF4A90E2),
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                MarkerLayer(markers: markers),
              ],
            ),
            searchPanel,
            // route info panel
            if (_hasRouteInfo && _generatedRoutePoints.isNotEmpty && !_isSearchOpen)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: RouteInfoPanel(
                  distanceText: _routeDistance,
                  durationText: _routeDuration,
                  currentMode: _routeMode,
                  onModeToggle: _toggleRouteMode,
                ),
              ),
            //hint text for map tap
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Tap on map to select locations',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteResponseException implements Exception {
  const _RouteResponseException(this.message);

  final String message;
}
