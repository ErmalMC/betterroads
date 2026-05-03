package com.example.betterroads

import android.content.Context
import com.chaquo.python.PyObject
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform

class PythonBridge(private val context: Context) {

    private fun ensureStarted() {
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(context))
        }
    }

    fun example_function(message: String): String {
        ensureStarted()
        val py = Python.getInstance()
        val module: PyObject = py.getModule("example")
        val result: PyObject = module.callAttr("example_function", message)
        return result.toString()
    }
}
