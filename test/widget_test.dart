// import 'dart:async';
// import 'dart:convert';
//
// // This is a basic Flutter widget test.
// //
// // To perform an interaction with a widget in your test, use the WidgetTester
// // utility in the flutter_test package. For example, you can send tap and scroll
// // gestures. You can also use WidgetTester to find child widgets in the widget
// // tree, read text, and verify that the values of widget properties are correct.
//
// import 'package:flutter_test/flutter_test.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:flutter/material.dart';
// import 'package:latlong2/latlong.dart';
//
// import 'package:betterroads/main.dart';
// import 'package:betterroads/services/mapbox_places_service.dart';
//
// void main() {
//   testWidgets('Map screen loads', (WidgetTester tester) async {
//     // Build our app and trigger a frame.
//     await tester.pumpWidget(const MyApp());
//
//     // Verify the map and start location input are present.
//     expect(find.byType(FlutterMap), findsOneWidget);
//     expect(find.byKey(const Key('start-location-input')), findsOneWidget);
//     expect(find.byKey(const Key('destination-input')), findsOneWidget);
//     expect(find.byKey(const Key('get-route-button')), findsOneWidget);
//   });
//
//   testWidgets('Selects a start location from autocomplete suggestions', (
//     WidgetTester tester,
//   ) async {
//     final placesService = _FakePlacesService([
//       const PlaceSuggestion(
//         id: 'place.1',
//         name: 'Skopje City',
//         placeName: 'Skopje City, North Macedonia',
//         coordinates: LatLng(41.9981, 21.4254),
//       ),
//     ]);
//
//     await tester.pumpWidget(
//       MaterialApp(home: MapScreen(placesService: placesService)),
//     );
//
//     await tester.enterText(
//       find.byKey(const Key('start-location-input')),
//       'Skopje',
//     );
//     await tester.pump(const Duration(milliseconds: 400));
//     await tester.pump();
//
//     expect(find.byKey(const Key('start-location-suggestions')), findsOneWidget);
//     expect(find.text('Skopje City'), findsOneWidget);
//
//     await tester.tap(find.text('Skopje City'));
//     await tester.pump();
//
//     expect(
//       find.text('Skopje City, North Macedonia (41.99810, 21.42540)'),
//       findsOneWidget,
//     );
//     expect(find.textContaining('41.99810'), findsOneWidget);
//     expect(find.textContaining('21.42540'), findsOneWidget);
//   });
//
//   testWidgets('Selects a destination from autocomplete suggestions', (
//     WidgetTester tester,
//   ) async {
//     final placesService = _FakePlacesService([
//       const PlaceSuggestion(
//         id: 'place.2',
//         name: 'Veles',
//         placeName: 'Veles, North Macedonia',
//         coordinates: LatLng(41.7156, 21.7756),
//       ),
//     ]);
//
//     await tester.pumpWidget(
//       MaterialApp(home: MapScreen(placesService: placesService)),
//     );
//
//     await tester.enterText(find.byKey(const Key('destination-input')), 'Veles');
//     await tester.pump(const Duration(milliseconds: 400));
//     await tester.pump();
//
//     expect(find.byKey(const Key('destination-suggestions')), findsOneWidget);
//     final destinationSuggestion = find.descendant(
//       of: find.byKey(const Key('destination-suggestions')),
//       matching: find.text('Veles'),
//     );
//     expect(destinationSuggestion, findsOneWidget);
//
//     await tester.tap(destinationSuggestion);
//     await tester.pump();
//
//     expect(
//       find.text('Veles, North Macedonia (41.71560, 21.77560)'),
//       findsOneWidget,
//     );
//   });
//
//   testWidgets('Destination input accepts coordinates and clears', (
//     WidgetTester tester,
//   ) async {
//     await tester.pumpWidget(
//       MaterialApp(home: MapScreen(placesService: _FakePlacesService([]))),
//     );
//
//     await tester.enterText(
//       find.byKey(const Key('destination-input')),
//       '41.12345, 21.54321',
//     );
//     await tester.pump();
//
//     expect(
//       find.text('Destination coordinates (41.12345, 21.54321)'),
//       findsOneWidget,
//     );
//     expect(find.byKey(const Key('clear-destination-input')), findsOneWidget);
//
//     await tester.tap(find.byKey(const Key('clear-destination-input')));
//     await tester.pump();
//
//     final destinationField = tester.widget<TextField>(
//       find.byKey(const Key('destination-input')),
//     );
//     expect(destinationField.controller?.text, isEmpty);
//     expect(
//       find.text('Destination coordinates (41.12345, 21.54321)'),
//       findsNothing,
//     );
//   });
//
//   testWidgets('Get Route validates selected endpoints', (
//     WidgetTester tester,
//   ) async {
//     await tester.pumpWidget(const MyApp());
//
//     await tester.tap(find.byKey(const Key('get-route-button')));
//     await tester.pump();
//
//     expect(
//       find.text('Select both start and destination first.'),
//       findsOneWidget,
//     );
//   });
//
//   testWidgets('Get Route sends selected coordinates to backend', (
//     WidgetTester tester,
//   ) async {
//     LatLng? requestedStart;
//     LatLng? requestedDestination;
//
//     final placesService = _QueryPlacesService({
//       'Skopje': [
//         const PlaceSuggestion(
//           id: 'place.1',
//           name: 'Skopje City',
//           placeName: 'Skopje City, North Macedonia',
//           coordinates: LatLng(41.9981, 21.4254),
//         ),
//       ],
//       'Veles': [
//         const PlaceSuggestion(
//           id: 'place.2',
//           name: 'Veles',
//           placeName: 'Veles, North Macedonia',
//           coordinates: LatLng(41.7156, 21.7756),
//         ),
//       ],
//     });
//
//     await tester.pumpWidget(
//       MaterialApp(
//         home: MapScreen(
//           placesService: placesService,
//           computeRoute: ({required start, required destination}) async {
//             requestedStart = start;
//             requestedDestination = destination;
//             return _routeResponse(start: start, destination: destination);
//           },
//         ),
//       ),
//     );
//
//     await tester.enterText(
//       find.byKey(const Key('start-location-input')),
//       'Skopje',
//     );
//     await tester.pump(const Duration(milliseconds: 400));
//     await tester.pump();
//     await tester.tap(find.text('Skopje City'));
//     await tester.pump();
//
//     await tester.enterText(find.byKey(const Key('destination-input')), 'Veles');
//     await tester.pump(const Duration(milliseconds: 400));
//     await tester.pump();
//     await tester.tap(
//       find.descendant(
//         of: find.byKey(const Key('destination-suggestions')),
//         matching: find.text('Veles'),
//       ),
//     );
//     await tester.pump();
//
//     await tester.tap(find.byKey(const Key('get-route-button')));
//     await tester.pump();
//     await tester.pump();
//
//     expect(requestedStart, const LatLng(41.9981, 21.4254));
//     expect(requestedDestination, const LatLng(41.7156, 21.7756));
//     expect(find.text('Route generated.'), findsOneWidget);
//     expect(find.byKey(const Key('route-polyline-layer')), findsOneWidget);
//   });
//
//   testWidgets('Get Route shows loading state during computation', (
//     WidgetTester tester,
//   ) async {
//     final routeCompleter = Completer<String>();
//     final placesService = _QueryPlacesService({
//       'Skopje': [
//         const PlaceSuggestion(
//           id: 'place.1',
//           name: 'Skopje City',
//           placeName: 'Skopje City, North Macedonia',
//           coordinates: LatLng(41.9981, 21.4254),
//         ),
//       ],
//     });
//
//     await tester.pumpWidget(
//       MaterialApp(
//         home: MapScreen(
//           placesService: placesService,
//           computeRoute: ({required start, required destination}) {
//             return routeCompleter.future;
//           },
//         ),
//       ),
//     );
//
//     await tester.enterText(
//       find.byKey(const Key('start-location-input')),
//       'Skopje',
//     );
//     await tester.pump(const Duration(milliseconds: 400));
//     await tester.pump();
//     await tester.tap(find.text('Skopje City'));
//     await tester.pump();
//
//     await tester.enterText(
//       find.byKey(const Key('destination-input')),
//       '41.7156, 21.7756',
//     );
//     await tester.pump();
//
//     await tester.tap(find.byKey(const Key('get-route-button')));
//     await tester.pump();
//
//     final routeButton = tester.widget<ElevatedButton>(
//       find.byKey(const Key('get-route-button')),
//     );
//     expect(routeButton.onPressed, isNull);
//     expect(find.text('Computing route...'), findsOneWidget);
//     expect(find.byKey(const Key('route-polyline-layer')), findsNothing);
//
//     routeCompleter.complete(
//       _routeResponse(
//         start: const LatLng(41.9981, 21.4254),
//         destination: const LatLng(41.7156, 21.7756),
//       ),
//     );
//     await tester.pump();
//
//     expect(find.text('Route generated.'), findsOneWidget);
//   });
//
//   testWidgets('Get Route clears previous route while recomputing', (
//     WidgetTester tester,
//   ) async {
//     var requestCount = 0;
//     final secondRequestCompleter = Completer<String>();
//     final placesService = _QueryPlacesService({
//       'Skopje': [
//         const PlaceSuggestion(
//           id: 'place.1',
//           name: 'Skopje City',
//           placeName: 'Skopje City, North Macedonia',
//           coordinates: LatLng(41.9981, 21.4254),
//         ),
//       ],
//     });
//
//     await tester.pumpWidget(
//       MaterialApp(
//         home: MapScreen(
//           placesService: placesService,
//           computeRoute: ({required start, required destination}) {
//             requestCount++;
//             if (requestCount == 1) {
//               return Future.value(
//                 _routeResponse(start: start, destination: destination),
//               );
//             }
//             return secondRequestCompleter.future;
//           },
//         ),
//       ),
//     );
//
//     await tester.enterText(
//       find.byKey(const Key('start-location-input')),
//       'Skopje',
//     );
//     await tester.pump(const Duration(milliseconds: 400));
//     await tester.pump();
//     await tester.tap(find.text('Skopje City'));
//     await tester.pump();
//     await tester.enterText(
//       find.byKey(const Key('destination-input')),
//       '41.7156, 21.7756',
//     );
//     await tester.pump();
//
//     await tester.tap(find.byKey(const Key('get-route-button')));
//     await tester.pump();
//     await tester.pump();
//
//     expect(find.byKey(const Key('route-polyline-layer')), findsOneWidget);
//
//     await tester.tap(find.byKey(const Key('get-route-button')));
//     await tester.pump();
//
//     expect(find.byKey(const Key('route-polyline-layer')), findsNothing);
//     expect(find.text('Computing route...'), findsOneWidget);
//
//     secondRequestCompleter.complete(
//       _routeResponse(
//         start: const LatLng(41.9981, 21.4254),
//         destination: const LatLng(41.7156, 21.7756),
//       ),
//     );
//     await tester.pump();
//
//     expect(find.byKey(const Key('route-polyline-layer')), findsOneWidget);
//   });
//
//   testWidgets('Get Route handles failed route response', (
//     WidgetTester tester,
//   ) async {
//     await _pumpRouteReadyMap(
//       tester,
//       computeRoute: ({required start, required destination}) async {
//         return jsonEncode({'status': 'failed'});
//       },
//     );
//
//     await tester.tap(find.byKey(const Key('get-route-button')));
//     await tester.pump();
//     await tester.pump();
//
//     expect(find.text('Route calculation failed.'), findsOneWidget);
//     expect(find.byKey(const Key('route-polyline-layer')), findsNothing);
//   });
//
//   testWidgets('Get Route handles missing route response', (
//     WidgetTester tester,
//   ) async {
//     await _pumpRouteReadyMap(
//       tester,
//       computeRoute: ({required start, required destination}) async => '',
//     );
//
//     await tester.tap(find.byKey(const Key('get-route-button')));
//     await tester.pump();
//     await tester.pump();
//
//     expect(find.text('No route response received.'), findsOneWidget);
//     expect(find.byKey(const Key('route-polyline-layer')), findsNothing);
//   });
// }
//
// class _FakePlacesService extends MapboxPlacesService {
//   _FakePlacesService(this.results) : super(accessToken: 'test-token');
//
//   final List<PlaceSuggestion> results;
//
//   @override
//   Future<List<PlaceSuggestion>> search(String query, {int limit = 5}) async {
//     return results;
//   }
// }
//
// class _QueryPlacesService extends MapboxPlacesService {
//   _QueryPlacesService(this.resultsByQuery) : super(accessToken: 'test-token');
//
//   final Map<String, List<PlaceSuggestion>> resultsByQuery;
//
//   @override
//   Future<List<PlaceSuggestion>> search(String query, {int limit = 5}) async {
//     return resultsByQuery[query] ?? const [];
//   }
// }
//
// Future<void> _pumpRouteReadyMap(
//   WidgetTester tester, {
//   required ComputeRouteCallback computeRoute,
// }) async {
//   final placesService = _QueryPlacesService({
//     'Skopje': [
//       const PlaceSuggestion(
//         id: 'place.1',
//         name: 'Skopje City',
//         placeName: 'Skopje City, North Macedonia',
//         coordinates: LatLng(41.9981, 21.4254),
//       ),
//     ],
//   });
//
//   await tester.pumpWidget(
//     MaterialApp(
//       home: MapScreen(placesService: placesService, computeRoute: computeRoute),
//     ),
//   );
//
//   await tester.enterText(
//     find.byKey(const Key('start-location-input')),
//     'Skopje',
//   );
//   await tester.pump(const Duration(milliseconds: 400));
//   await tester.pump();
//   await tester.tap(find.text('Skopje City'));
//   await tester.pump();
//   await tester.enterText(
//     find.byKey(const Key('destination-input')),
//     '41.7156, 21.7756',
//   );
//   await tester.pump();
// }
//
// String _routeResponse({required LatLng start, required LatLng destination}) {
//   return jsonEncode({
//     'status': 'ok',
//     'route_points': [
//       {'latitude': start.latitude, 'longitude': start.longitude},
//       {'latitude': 41.9000, 'longitude': 21.5500},
//       {'latitude': destination.latitude, 'longitude': destination.longitude},
//     ],
//   });
// }
