import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:betterroads/python_channel.dart';
import 'package:betterroads/services/mapbox_places_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MyApp());

  PythonChannel.exampleFunction('Text sent from Dart.')
      .then((result) {
        log('Result: $result');
      })
      .catchError((error) {
        log('Error: $error');
      });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Better Roads',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MapScreen(),
    );
  }
}

typedef ComputeRouteCallback =
    Future<String> Function({
      required LatLng start,
      required LatLng destination,
    });

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.placesService, this.computeRoute});

  final MapboxPlacesService? placesService;
  final ComputeRouteCallback? computeRoute;

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
    _computeRoute = widget.computeRoute ?? PythonChannel.computeRoute;
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
      if (status != null && status != 'ok') {
        throw const _RouteResponseException('Route calculation failed.');
      }

      final routePoints = _coordinatesFromJsonList(
        decoded['route_points'] ?? decoded['routePoints'],
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Better Roads'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final panelWidth = math.max(
            0.0,
            math.min(440.0, constraints.maxWidth - 32),
          );

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _defaultStart,
                  initialZoom: 13,
                  minZoom: 3,
                  maxZoom: 18,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                    markers: [
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
                    ],
                  ),
                ],
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: panelWidth,
                      child: _StartLocationPanel(
                        controller: _startLocationController,
                        destinationController: _destinationController,
                        focusNode: _startLocationFocusNode,
                        destinationFocusNode: _destinationFocusNode,
                        isSearching: _isSearchingStart,
                        isSearchingDestination: _isSearchingDestination,
                        selectedStartCoordinates: _selectedStartCoordinates,
                        selectedDestinationCoordinates:
                            _selectedDestinationCoordinates,
                        selectedStartLabel: _selectedStartLabel,
                        selectedDestinationLabel: _selectedDestinationLabel,
                        searchError: _startSearchError,
                        destinationSearchError: _destinationSearchError,
                        routeStatusMessage: _routeStatusMessage,
                        isRouteStatusError: _isRouteStatusError,
                        isComputingRoute: _isComputingRoute,
                        showNoResults: _showNoResults,
                        showDestinationNoResults: _showDestinationNoResults,
                        suggestions: _startSuggestions,
                        destinationSuggestions: _destinationSuggestions,
                        onChanged: _onStartLocationChanged,
                        onDestinationChanged: _onDestinationChanged,
                        onClear: _clearStartLocation,
                        onDestinationClear: _clearDestination,
                        onSuggestionSelected: _selectStartLocation,
                        onDestinationSuggestionSelected: _selectDestination,
                        onRouteRequested: _requestRoute,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StartLocationPanel extends StatelessWidget {
  const _StartLocationPanel({
    required this.controller,
    required this.destinationController,
    required this.focusNode,
    required this.destinationFocusNode,
    required this.isSearching,
    required this.isSearchingDestination,
    required this.selectedStartCoordinates,
    required this.selectedDestinationCoordinates,
    required this.selectedStartLabel,
    required this.selectedDestinationLabel,
    required this.searchError,
    required this.destinationSearchError,
    required this.routeStatusMessage,
    required this.isRouteStatusError,
    required this.isComputingRoute,
    required this.showNoResults,
    required this.showDestinationNoResults,
    required this.suggestions,
    required this.destinationSuggestions,
    required this.onChanged,
    required this.onDestinationChanged,
    required this.onClear,
    required this.onDestinationClear,
    required this.onSuggestionSelected,
    required this.onDestinationSuggestionSelected,
    required this.onRouteRequested,
  });

  final TextEditingController controller;
  final TextEditingController destinationController;
  final FocusNode focusNode;
  final FocusNode destinationFocusNode;
  final bool isSearching;
  final bool isSearchingDestination;
  final LatLng selectedStartCoordinates;
  final LatLng selectedDestinationCoordinates;
  final String? selectedStartLabel;
  final String? selectedDestinationLabel;
  final String? searchError;
  final String? destinationSearchError;
  final String? routeStatusMessage;
  final bool isRouteStatusError;
  final bool isComputingRoute;
  final bool showNoResults;
  final bool showDestinationNoResults;
  final List<PlaceSuggestion> suggestions;
  final List<PlaceSuggestion> destinationSuggestions;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onDestinationChanged;
  final VoidCallback onClear;
  final VoidCallback onDestinationClear;
  final ValueChanged<PlaceSuggestion> onSuggestionSelected;
  final ValueChanged<PlaceSuggestion> onDestinationSuggestionSelected;
  final VoidCallback onRouteRequested;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 8,
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('start-location-input'),
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Start location',
                hintText: 'Search address or place',
                prefixIcon: const Icon(Icons.trip_origin),
                suffixIcon: _buildSuffixIcon(),
                border: const OutlineInputBorder(),
              ),
            ),
            if (selectedStartLabel != null) ...[
              const SizedBox(height: 8),
              _SelectedStartSummary(
                coordinates: selectedStartCoordinates,
                label: selectedStartLabel!,
              ),
            ],
            if (searchError != null) ...[
              const SizedBox(height: 8),
              _SearchMessage(
                icon: Icons.error_outline,
                text: searchError!,
                backgroundColor: colorScheme.errorContainer,
                foregroundColor: colorScheme.onErrorContainer,
              ),
            ] else if (showNoResults) ...[
              const SizedBox(height: 8),
              _SearchMessage(
                icon: Icons.search_off,
                text: 'No locations found',
                backgroundColor: colorScheme.surfaceContainerHighest,
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
            ],
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _SuggestionList(
                key: const Key('start-location-suggestions'),
                suggestions: suggestions,
                onSuggestionSelected: onSuggestionSelected,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('destination-input'),
              controller: destinationController,
              focusNode: destinationFocusNode,
              onChanged: onDestinationChanged,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Destination',
                hintText: 'Search destination or enter lat, lng',
                prefixIcon: const Icon(Icons.flag_outlined),
                suffixIcon: _buildDestinationSuffixIcon(),
                border: const OutlineInputBorder(),
              ),
            ),
            if (selectedDestinationLabel != null) ...[
              const SizedBox(height: 8),
              _SelectedStartSummary(
                coordinates: selectedDestinationCoordinates,
                label: selectedDestinationLabel!,
              ),
            ],
            if (destinationSearchError != null) ...[
              const SizedBox(height: 8),
              _SearchMessage(
                icon: Icons.error_outline,
                text: destinationSearchError!,
                backgroundColor: colorScheme.errorContainer,
                foregroundColor: colorScheme.onErrorContainer,
              ),
            ] else if (showDestinationNoResults) ...[
              const SizedBox(height: 8),
              _SearchMessage(
                icon: Icons.search_off,
                text: 'No destinations found',
                backgroundColor: colorScheme.surfaceContainerHighest,
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
            ],
            if (destinationSuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _SuggestionList(
                key: const Key('destination-suggestions'),
                suggestions: destinationSuggestions,
                onSuggestionSelected: onDestinationSuggestionSelected,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('get-route-button'),
                onPressed: isComputingRoute ? null : onRouteRequested,
                icon: isComputingRoute
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.route),
                label: Text(
                  isComputingRoute ? 'Computing route...' : 'Get Route',
                ),
              ),
            ),
            if (routeStatusMessage != null) ...[
              const SizedBox(height: 8),
              _SearchMessage(
                icon: isRouteStatusError
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                text: routeStatusMessage!,
                backgroundColor: isRouteStatusError
                    ? colorScheme.errorContainer
                    : colorScheme.primaryContainer.withValues(alpha: 0.55),
                foregroundColor: isRouteStatusError
                    ? colorScheme.onErrorContainer
                    : colorScheme.onPrimaryContainer,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (isSearching) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (controller.text.isEmpty) {
      return null;
    }

    return IconButton(
      tooltip: 'Clear start location',
      icon: const Icon(Icons.close),
      onPressed: onClear,
    );
  }

  Widget? _buildDestinationSuffixIcon() {
    if (destinationController.text.isEmpty) {
      return null;
    }

    return IconButton(
      key: const Key('clear-destination-input'),
      tooltip: 'Clear destination',
      icon: const Icon(Icons.close),
      onPressed: onDestinationClear,
    );
  }
}

class _SelectedStartSummary extends StatelessWidget {
  const _SelectedStartSummary({required this.coordinates, required this.label});

  final LatLng coordinates;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.my_location,
              size: 18,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label (${coordinates.latitude.toStringAsFixed(5)}, '
                '${coordinates.longitude.toStringAsFixed(5)})',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: foregroundColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: foregroundColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    super.key,
    required this.suggestions,
    required this.onSuggestionSelected,
  });

  final List<PlaceSuggestion> suggestions;
  final ValueChanged<PlaceSuggestion> onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: ListView.separated(
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          itemCount: suggestions.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, color: colorScheme.outlineVariant),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];

            return ListTile(
              dense: true,
              leading: const Icon(Icons.place_outlined),
              title: Text(
                suggestion.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                suggestion.placeName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onSuggestionSelected(suggestion),
            );
          },
        ),
      ),
    );
  }
}

class _RouteResponseException implements Exception {
  const _RouteResponseException(this.message);

  final String message;
}
