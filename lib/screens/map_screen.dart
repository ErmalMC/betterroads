import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:betterroads/services/mapbox_places_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/route_api_service.dart';

typedef ComputeRouteCallback =
    Future<String> Function({
      required LatLng start,
      required LatLng destination,
    });

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.placesService,
    this.computeRoute,
    this.routeApiBaseUrl,
  });

  final MapboxPlacesService? placesService;
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

  late final MapboxPlacesService _placesService;
  late final bool _ownsPlacesService;
  late final ComputeRouteCallback _computeRoute;
  late final RouteApiService _routeApiService;

  Timer? _startSearchDebounce;
  Timer? _destinationSearchDebounce;
  List<PlaceSuggestion> _startSuggestions = const [];
  List<PlaceSuggestion> _destinationSuggestions = const [];
  LatLng _selectedStartCoordinates = _defaultStart;
  String? _selectedStartLabel;
  String? _startSearchError;
  String? _destinationSearchError;
  bool _isSearchingStart = false;
  bool _isSearchingDestination = false;
  bool _hasSearchedStart = false;
  bool _hasSearchedDestination = false;
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

  @override
  void initState() {
    super.initState();
    _ownsPlacesService = widget.placesService == null;
    _placesService =
        widget.placesService ?? MapboxPlacesService(proximity: _defaultStart);
    _routeApiService = RouteApiService(baseUrl: widget.routeApiBaseUrl);
    _computeRoute = widget.computeRoute ?? _routeApiService.computeRoute;
  }

  @override
  void dispose() {
    _startSearchDebounce?.cancel();
    _destinationSearchDebounce?.cancel();
    _startLocationController.dispose();
    _destinationController.dispose();
    _startLocationFocusNode.dispose();
    _destinationFocusNode.dispose();
    _mapController.dispose();
    if (_ownsPlacesService) {
      _placesService.dispose();
    }
    _routeApiService.dispose();
    super.dispose();
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
      final suggestions = await _placesService.search(query, limit: 6);
      if (!mounted || requestId != _startSearchRequestId) {
        return;
      }

      setState(() {
        _startSuggestions = suggestions;
        _isSearchingStart = false;
        _hasSearchedStart = true;
      });
    } on MapboxPlacesException catch (error) {
      if (!mounted || requestId != _startSearchRequestId) {
        return;
      }

      setState(() {
        _startSuggestions = const [];
        _isSearchingStart = false;
        _hasSearchedStart = true;
        _startSearchError = error.message;
      });
    } catch (_) {
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

  void _selectStartLocation(PlaceSuggestion suggestion) {
    _startSearchDebounce?.cancel();
    _startSearchRequestId++;

    setState(() {
      _selectedStartCoordinates = suggestion.coordinates;
      _selectedStartLabel = suggestion.placeName;
      _hasSelectedStart = true;
      _routeStatusMessage = null;
      _generatedRoutePoints = const [];
      _startLocationController.text = suggestion.placeName;
      _startLocationController.selection = TextSelection.collapsed(
        offset: suggestion.placeName.length,
      );
      _startSuggestions = const [];
      _startSearchError = null;
      _hasSearchedStart = false;
      _isSearchingStart = false;
    });

    _startLocationFocusNode.unfocus();
    _mapController.move(suggestion.coordinates, math.max(_currentZoom(), 14));
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

  Future<void> _searchDestination(String query) async {
    final requestId = ++_destinationSearchRequestId;

    setState(() {
      _isSearchingDestination = true;
      _destinationSearchError = null;
    });

    try {
      final suggestions = await _placesService.search(query, limit: 6);
      if (!mounted || requestId != _destinationSearchRequestId) {
        return;
      }

      setState(() {
        _destinationSuggestions = suggestions;
        _isSearchingDestination = false;
        _hasSearchedDestination = true;
      });
    } on MapboxPlacesException catch (error) {
      if (!mounted || requestId != _destinationSearchRequestId) {
        return;
      }

      setState(() {
        _destinationSuggestions = const [];
        _isSearchingDestination = false;
        _hasSearchedDestination = true;
        _destinationSearchError = error.message;
      });
    } catch (_) {
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

  void _selectDestination(PlaceSuggestion suggestion) {
    _destinationSearchDebounce?.cancel();
    _destinationSearchRequestId++;

    setState(() {
      _selectedDestinationCoordinates = suggestion.coordinates;
      _selectedDestinationLabel = suggestion.placeName;
      _hasSelectedDestination = true;
      _routeStatusMessage = null;
      _generatedRoutePoints = const [];
      _destinationController.text = suggestion.placeName;
      _destinationController.selection = TextSelection.collapsed(
        offset: suggestion.placeName.length,
      );
      _destinationSuggestions = const [];
      _destinationSearchError = null;
      _hasSearchedDestination = false;
      _isSearchingDestination = false;
    });

    _destinationFocusNode.unfocus();
    _mapController.move(suggestion.coordinates, math.max(_currentZoom(), 14));
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

  void _handleMapTap(LatLng point) {
    setState(() {
      _routeStatusMessage = null;
      _generatedRoutePoints = const [];

      if (!_hasSelectedStart || (_hasSelectedStart && _hasSelectedDestination)) {
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
      return;
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
      );
      final routePoints = _parseRouteResponse(response);
      if (!mounted) {
        return;
      }

      setState(() {
        _generatedRoutePoints = routePoints;
        _routeStatusMessage = 'Route generated.';
        _isRouteStatusError = false;
      });
    } on _RouteResponseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _routeStatusMessage = error.message;
        _isRouteStatusError = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _routeStatusMessage = 'Unable to compute route.';
        _isRouteStatusError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isComputingRoute = false;
        });
      }
    }
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
    final searchPanel = AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      left: 0,
      right: 0,
      top: _isSearchOpen ? 0 : -220,
      child: Material(
        elevation: 4,
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Search locations',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _clearSearch,
                          child: const Text('Clear'),
                        ),
                        IconButton(
                          tooltip: 'Close search',
                          onPressed: _closeSearch,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _startLocationController,
                  decoration: const InputDecoration(
                    labelText: 'Start location (lat, lng)',
                    prefixIcon: Icon(Icons.trip_origin),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  onSubmitted: _handleStartSubmitted,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _destinationController,
                  decoration: const InputDecoration(
                    labelText: 'Destination (lat, lng)',
                    prefixIcon: Icon(Icons.flag),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: _handleEndSubmitted,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isComputingRoute ? null : _requestRoute,
                        child: _isComputingRoute
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Generate route'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final markers = <Marker>[
      Marker(
        point: _selectedStartCoordinates,
        width: 40,
        height: 40,
        child: const Icon(
          Icons.location_on,
          color: Colors.green,
          size: 36,
        ),
      ),
      Marker(
        point: _selectedDestinationCoordinates,
        width: 40,
        height: 40,
        child: const Icon(
          Icons.flag,
          color: Colors.red,
          size: 30,
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Better Roads'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleSearch,
        tooltip: _isSearchOpen ? 'Close search' : 'Open search',
        child: Icon(_isSearchOpen ? Icons.close : Icons.search),
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
              if (_generatedRoutePoints.isNotEmpty)
                PolylineLayer(
                  key: const Key('route-polyline-layer'),
                  polylines: [
                    Polyline(
                      points: _generatedRoutePoints,
                      color: Colors.black.withValues(alpha: 0.8),
                      strokeWidth: 8,
                    ),
                    Polyline(
                      points: _generatedRoutePoints,
                      color: Colors.yellowAccent,
                      strokeWidth: 5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: markers,
              ),
            ],
          ),
          searchPanel,
        ],
      ),
    );
  }
}

class _RouteResponseException implements Exception {
  const _RouteResponseException(this.message);

  final String message;
}

