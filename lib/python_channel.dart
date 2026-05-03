import 'dart:ffi';

import 'package:flutter/services.dart';

class PythonChannel {
    static const MethodChannel _channel = MethodChannel('com.example.betterroads/python');

    static Future<String> exampleFunction(String message) async {
    final result = await _channel.invokeMethod<String>('example_function', {'message': message});
    return result ?? '';
    }
}
