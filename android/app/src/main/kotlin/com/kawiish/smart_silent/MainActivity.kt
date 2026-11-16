package com.kawiish.smartsilent

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.kawiish.smartsilent/device_compatibility"
    private val LOCATION_REQ_CODE = 5001
    private var pendingLocationResult: MethodChannel.Result? = null
    private var activeLocationListener: LocationListener? = null
    private var activeLocationManager: LocationManager? = null
    private var ringerReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                window?.decorView?.isForceDarkAllowed = false
            } catch (_: Exception) {}
        }
        registerRingerObserver()
    }

    override fun onResume() {
        super.onResume()
        handlePossibleManualNormalOverride()
    }

    private fun registerRingerObserver() {
        if (ringerReceiver != null) return
        ringerReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent?.action == AudioManager.RINGER_MODE_CHANGED_ACTION) {
                    val mode = intent.getIntExtra(AudioManager.EXTRA_RINGER_MODE, -1)
                    if (mode == AudioManager.RINGER_MODE_NORMAL) {
                        handlePossibleManualNormalOverride()
                    }
                }
            }
        }
        try {
            val filter = IntentFilter(AudioManager.RINGER_MODE_CHANGED_ACTION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(ringerReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(ringerReceiver, filter)
            }
        } catch (_: Exception) {}
    }

    private fun handlePossibleManualNormalOverride() {
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            if (am.ringerMode != AudioManager.RINGER_MODE_NORMAL) return

            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isManaged = prefs.getBoolean("flutter.app_managed_sound_active", false)
            val lastSetMs = prefs.getLong("flutter.app_last_set_ms", 0L)
            val nowMs = System.currentTimeMillis()
            if (isManaged && (nowMs - lastSetMs) > 3000L) {
                val managedEndMs = prefs.getLong("flutter.app_managed_end_ms", 0L)
                val overrideUntilMs = if (managedEndMs > nowMs) managedEndMs else (nowMs + (30 * 60 * 1000L))
                prefs.edit()
                    .putBoolean("flutter.app_managed_sound_active", false)
                    .putLong("flutter.user_manual_override_ms", nowMs)
                    .putLong("flutter.user_manual_override_until_ms", overrideUntilMs)
                    .apply()
                clearDndIfAllowed()
            }
        } catch (_: Exception) {}
    }

    private fun clearDndIfAllowed() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
                if (nm.isNotificationPolicyAccessGranted &&
                    nm.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL
                ) {
                    nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                }
            } catch (_: Exception) {}
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasLocationPermission" -> {
                    val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    result.success(fine || coarse)
                }
                "requestLocationPermission" -> {
                    val upgradePrecise = call.argument<Boolean>("upgradePrecise") ?: false
                    val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    if (fine || (coarse && !upgradePrecise)) {
                        result.success(true)
                    } else {
                        pendingLocationResult?.let {
                            try { it.success(false) } catch (_: Exception) {}
                        }
                        pendingLocationResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                            LOCATION_REQ_CODE
                        )
                    }
                }
                "getDeviceLocation" -> {
                    val forceFresh = call.argument<Boolean>("forceFresh") ?: false
                    fetchLocation(forceFresh, result)
                }
                "openLocationSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "setNativeRingerMode" -> {
                    val mode = call.argument<String>("mode") ?: "normal"
                    val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    val hasDnd = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        nm?.isNotificationPolicyAccessGranted == true
                    } else {
                        true
                    }

                    if (am != null) {
                        try {
                            when (mode) {
                                "silent" -> {
                                    if (hasDnd) {
                                        am.ringerMode = AudioManager.RINGER_MODE_SILENT
                                        result.success("silent")
                                    } else {
                                        // Seamless fallback to Vibrate without throwing error or forcing DND UI
                                        am.ringerMode = AudioManager.RINGER_MODE_VIBRATE
                                        result.success("vibrate_fallback")
                                    }
                                }
                                "vibrate" -> {
                                    am.ringerMode = AudioManager.RINGER_MODE_VIBRATE
                                    result.success("vibrate")
                                }
                                "normal" -> {
                                    am.ringerMode = AudioManager.RINGER_MODE_NORMAL
                                    clearDndIfAllowed()
                                    result.success("normal")
                                }
                                else -> {
                                    result.success("unknown")
                                }
                            }
                        } catch (e: Exception) {
                            try {
                                am.ringerMode = AudioManager.RINGER_MODE_VIBRATE
                                result.success("vibrate_fallback")
                            } catch (_: Exception) {
                                result.error("RINGER_ERROR", e.message, null)
                            }
                        }
                    } else {
                        result.error("AUDIO_SERVICE_NULL", "AudioManager unavailable", null)
                    }
                }
                "clearDndIfAllowed" -> {
                    clearDndIfAllowed()
                    result.success(true)
                }
                "hasDndPermission" -> {
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        nm?.isNotificationPolicyAccessGranted == true
                    } else {
                        true
                    }
                    result.success(granted)
                }
                "getDeviceManufacturer" -> {
                    val m = Build.MANUFACTURER ?: "Unknown"
                    val formatted = if (m.isNotEmpty()) m.substring(0, 1).uppercase() + m.substring(1).lowercase() else "Unknown"
                    result.success(formatted)
                }
                "canScheduleExactAlarms" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val am = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                        result.success(am?.canScheduleExactAlarms() ?: true)
                    } else {
                        result.success(true)
                    }
                }
                "requestScheduleExactAlarm" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        } catch (_: Exception) {}
                    }
                    result.success(null)
                }
                "isIgnoringBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        result.success(pm?.isIgnoringBatteryOptimizations(packageName) ?: true)
                    } else {
                        result.success(true)
                    }
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        } catch (_: Exception) {
                            try {
                                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            } catch (_: Exception) {}
                        }
                    }
                    result.success(null)
                }
                "openAutoStartSettings" -> {
                    result.success(openManufacturerAutoStart())
                }
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent().apply {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                                data = Uri.parse("package:$packageName")
                            }
                        }
                        startActivity(intent)
                    } catch (_: Exception) {}
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openManufacturerAutoStart(): Boolean {
        val candidates = listOf(
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
            ComponentName("com.letv.android.letvsafe", "com.letv.android.letvsafe.AutobootManageActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
            ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
            ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
            ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity"),
            ComponentName("com.samsung.android.sm", "com.samsung.android.sm.battery.ui.BatteryActivity"),
            ComponentName("com.transsion.phonemaster", "com.itel.autobootmanager.activity.AutoBootMgrActivity")
        )
        for (cn in candidates) {
            try {
                val intent = Intent().setComponent(cn)
                if (packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY) != null) {
                    startActivity(intent)
                    return true
                }
            } catch (_: Exception) {}
        }
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun onDestroy() {
        ringerReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
        ringerReceiver = null
        activeLocationListener?.let { listener ->
            try { activeLocationManager?.removeUpdates(listener) } catch (_: Exception) {}
        }
        activeLocationListener = null
        activeLocationManager = null
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == LOCATION_REQ_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults.any { it == PackageManager.PERMISSION_GRANTED }
            pendingLocationResult?.let {
                try { it.success(granted) } catch (_: Exception) {}
            }
            pendingLocationResult = null
        }
    }

    private fun isDeviceLocationEnabled(lm: LocationManager): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lm.isLocationEnabled
        } else {
            val gps = try { lm.isProviderEnabled(LocationManager.GPS_PROVIDER) } catch (_: Exception) { false }
            val net = try { lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) } catch (_: Exception) { false }
            gps || net
        }
    }

    private fun locationAgeMs(loc: Location): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            (SystemClock.elapsedRealtimeNanos() - loc.elapsedRealtimeNanos) / 1_000_000L
        } else {
            System.currentTimeMillis() - loc.time
        }
    }

    private fun isBetterFix(candidate: Location, currentBest: Location?): Boolean {
        if (currentBest == null) return true
        // Never replace an accurate fix (<= 350m) with a coarse fix (> 350m)
        if (currentBest.accuracy <= 350f && candidate.accuracy > 350f) return false
        val ageDeltaMs = locationAgeMs(currentBest) - locationAgeMs(candidate)
        if (ageDeltaMs > 30_000L) return true
        if (ageDeltaMs < -30_000L) return false
        if (candidate.accuracy < currentBest.accuracy) return true
        val candidateHighPriority = candidate.provider == LocationManager.GPS_PROVIDER ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && candidate.provider == LocationManager.FUSED_PROVIDER)
        if (candidate.accuracy <= currentBest.accuracy + 25f &&
            candidateHighPriority &&
            currentBest.provider == LocationManager.NETWORK_PROVIDER
        ) {
            return true
        }
        return false
    }

    private fun locationToMap(loc: Location): HashMap<String, Any> {
        val map = HashMap<String, Any>()
        map["latitude"] = loc.latitude
        map["longitude"] = loc.longitude
        map["accuracy"] = loc.accuracy.toDouble()
        map["provider"] = loc.provider ?: "unknown"
        map["ageSeconds"] = (locationAgeMs(loc) / 1000L).coerceAtLeast(0L)
        return map
    }

    private fun fetchLocation(forceFresh: Boolean, result: MethodChannel.Result) {
        val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

        if (!fine && !coarse) {
            result.success(mapOf("error" to "permission_denied"))
            return
        }

        if (!fine && coarse) {
            result.success(mapOf("error" to "approximate_only"))
            return
        }

        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (lm == null || !isDeviceLocationEnabled(lm)) {
            result.success(mapOf("error" to "location_disabled"))
            return
        }

        val availableProviders = try { lm.allProviders } catch (_: Exception) { emptyList<String>() }
        val activeProviders = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && availableProviders.contains(LocationManager.FUSED_PROVIDER)) {
            try { if (lm.isProviderEnabled(LocationManager.FUSED_PROVIDER)) activeProviders.add(LocationManager.FUSED_PROVIDER) } catch (_: Exception) {}
        }
        if (availableProviders.contains(LocationManager.GPS_PROVIDER)) {
            try { if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) activeProviders.add(LocationManager.GPS_PROVIDER) } catch (_: Exception) {}
        }
        if (availableProviders.contains(LocationManager.NETWORK_PROVIDER)) {
            try { if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) activeProviders.add(LocationManager.NETWORK_PROVIDER) } catch (_: Exception) {}
        }

        // 1. Inspect recent (<= 5 min) & accurate (<= 200m) cached fixes from active providers
        var recentCache: Location? = null
        try {
            for (provider in activeProviders) {
                val loc = lm.getLastKnownLocation(provider) ?: continue
                if (!loc.hasAccuracy() || loc.accuracy <= 0f || loc.accuracy > 200f) continue
                val ageMs = locationAgeMs(loc)
                if (ageMs < 0L || ageMs > 300_000L) continue
                if (isBetterFix(loc, recentCache)) {
                    recentCache = loc
                }
            }
        } catch (_: SecurityException) {}

        if (!forceFresh && recentCache != null) {
            result.success(locationToMap(recentCache))
            return
        }

        if (activeProviders.isEmpty()) {
            if (recentCache != null) {
                result.success(locationToMap(recentCache))
            } else {
                result.success(mapOf("error" to "location_disabled"))
            }
            return
        }

        // Clean up any previous listener before starting a new live fix request
        activeLocationListener?.let { prev ->
            try { lm.removeUpdates(prev) } catch (_: Exception) {}
        }

        // 2. Request live location updates with accuracy prioritization
        var responded = false
        var bestLiveLocation: Location? = null
        var graceScheduled = false
        val handler = Handler(Looper.getMainLooper())
        var listener: LocationListener? = null
        var timeoutRunnable: Runnable? = null
        var graceRunnable: Runnable? = null

        fun finishWith(payload: Map<String, Any>) {
            if (responded) return
            responded = true
            timeoutRunnable?.let { handler.removeCallbacks(it) }
            graceRunnable?.let { handler.removeCallbacks(it) }
            listener?.let { active ->
                try { lm.removeUpdates(active) } catch (_: Exception) {}
                if (activeLocationListener === active) {
                    activeLocationListener = null
                    activeLocationManager = null
                }
            }
            try {
                result.success(payload)
            } catch (_: Exception) {}
        }

        graceRunnable = Runnable {
            val live = bestLiveLocation
            if (live != null && live.accuracy <= 350f) {
                finishWith(locationToMap(live))
            }
        }

        timeoutRunnable = Runnable {
            val live = bestLiveLocation
            when {
                live != null && live.accuracy <= 350f -> finishWith(locationToMap(live))
                recentCache != null -> finishWith(locationToMap(recentCache))
                live != null -> finishWith(hashMapOf(
                    "error" to "low_accuracy",
                    "accuracy" to live.accuracy.toDouble()
                ))
                else -> finishWith(hashMapOf("error" to "timeout"))
            }
        }

        listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                if (responded) return
                if (!location.hasAccuracy() || location.accuracy <= 0f) return
                val ageMs = locationAgeMs(location)
                if (ageMs < -5_000L || ageMs > 60_000L) return

                if (isBetterFix(location, bestLiveLocation)) {
                    bestLiveLocation = location
                }

                // Good fix (<= 100m): return immediately for fast masjid loading
                if (location.accuracy <= 100f) {
                    finishWith(locationToMap(location))
                } else if (location.accuracy <= 250f && !graceScheduled) {
                    // Moderate fix (e.g. Wi-Fi/network): give GPS/Fused a 1.5s chance to refine
                    graceScheduled = true
                    graceRunnable?.let { handler.postDelayed(it, 1500L) }
                }
            }

            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
        }

        activeLocationListener = listener
        activeLocationManager = lm
        timeoutRunnable?.let { handler.postDelayed(it, 5000L) }

        var subscribedAny = false
        for (p in activeProviders) {
            try {
                listener?.let {
                    lm.requestLocationUpdates(p, 0L, 0f, it, Looper.getMainLooper())
                    subscribedAny = true
                }
            } catch (_: Exception) {}
        }

        if (!subscribedAny) {
            if (recentCache != null) {
                finishWith(locationToMap(recentCache))
            } else {
                finishWith(hashMapOf("error" to "location_disabled"))
            }
        }
    }
}
