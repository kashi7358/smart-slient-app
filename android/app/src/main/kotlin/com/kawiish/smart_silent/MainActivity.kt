package com.kawiish.smartsilent

import android.content.Context
import android.location.Location
import android.location.LocationManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.kawiish.smartsilent/device_compatibility"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceLocation" -> {
                    try {
                        val loc = getBestLocation()
                        if (loc != null) {
                            val map = HashMap<String, Double>()
                            map["latitude"] = loc.latitude
                            map["longitude"] = loc.longitude
                            result.success(map)
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "getDeviceManufacturer" -> {
                    result.success(android.os.Build.MANUFACTURER ?: "Unknown")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getBestLocation(): Location? {
        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        var bestLocation: Location? = null

        val providers = lm.getProviders(true)
        for (provider in providers) {
            try {
                val l = lm.getLastKnownLocation(provider) ?: continue
                if (bestLocation == null || l.accuracy < bestLocation.accuracy) {
                    bestLocation = l
                }
            } catch (_: SecurityException) {
            }
        }
        return bestLocation
    }
}
