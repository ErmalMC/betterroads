import 'dart:async';

import 'package:latlong2/latlong.dart';

class MockLocationService {
  MockLocationService({required List<LatLng> route}) : _route = route;

  final List<LatLng> _route;
  Timer? _timer;
  int _index = 0;

  LatLng get currentLocation => _route[_index];

  Stream<LatLng> start({Duration interval = const Duration(seconds: 1)}) {
    _timer?.cancel();
    _index = 0;
    final controller = StreamController<LatLng>();
    controller.add(_route[_index]);
    _timer = Timer.periodic(interval, (_) {
      if (_index >= _route.length - 1) {
        controller.close();
        _timer?.cancel();
        return;
      }
      _index += 1;
      controller.add(_route[_index]);
    });
    controller.onCancel = () {
      _timer?.cancel();
    };
    return controller.stream;
  }

  void stop() {
    _timer?.cancel();
  }
}

