package com.example.betterroads

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.betterroads/python"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val pythonBridge = PythonBridge(this.applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "example_function" -> {
                        val message = call.argument<String>("message") ?: ""
                        val pythonResponse = pythonBridge.exampleFunction(message)
                        result.success(pythonResponse)
                    }
                    "compute_route" -> {
                        val startLatitude = call.argument<Double>("start_latitude")
                        val startLongitude = call.argument<Double>("start_longitude")
                        val destinationLatitude = call.argument<Double>("destination_latitude")
                        val destinationLongitude = call.argument<Double>("destination_longitude")

                        if (
                            startLatitude == null ||
                            startLongitude == null ||
                            destinationLatitude == null ||
                            destinationLongitude == null
                        ) {
                            result.error("INVALID_ARGUMENTS", "Route coordinates are required", null)
                        } else {
                            val pythonResponse = pythonBridge.computeRoute(
                                startLatitude,
                                startLongitude,
                                destinationLatitude,
                                destinationLongitude
                            )
                            result.success(pythonResponse)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("PYTHON_ERROR", e.message, null)
            }
        }
    }
}
