package com.example.betterroads

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.betterroads/python"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val py = Python.getInstance()
        val module = py.getModule("example")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "example_function" -> {
                        val message = call.argument<String>("message")
                        val pyResult = module.callAttr("example_function", message)
                        result.success(pyResult.toString())
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("PYTHON_ERROR", e.message, null)
            }
        }
    }
}
