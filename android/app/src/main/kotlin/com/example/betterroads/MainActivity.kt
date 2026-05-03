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
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("PYTHON_ERROR", e.message, null)
            }
        }
    }
}
