import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeviceCompatibilityHelper {
  static const MethodChannel _channel =
      MethodChannel('com.kawiish.smartsilent/device_compatibility');

  /// Check whether app is allowed to schedule exact alarms (Android 12/13/14/15)
  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? result = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Request exact alarm permission in system settings (Android 12+)
  static Future<void> requestScheduleExactAlarm() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestScheduleExactAlarm');
    } catch (_) {}
  }

  /// Check if app is on the battery optimization whitelist (unrestricted background)
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Request user to disable battery optimizations for reliable silent timing
  static Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  /// Open manufacturer background/autostart settings (Xiaomi, Oppo, Vivo, Samsung, etc.)
  static Future<bool> openAutoStartSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('openAutoStartSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open app notification settings (Android 13+)
  static Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  /// Get device brand/manufacturer (e.g. "samsung", "xiaomi", "vivo")
  static Future<String> getDeviceManufacturer() async {
    if (!Platform.isAndroid) return 'Unknown';
    try {
      final String? result = await _channel.invokeMethod<String>('getDeviceManufacturer');
      return (result ?? 'Unknown').trim();
    } catch (_) {
      return 'Unknown';
    }
  }

  /// Get precise GPS/Network location directly from Android LocationManager
  static Future<Map<String, double>?> getDeviceLocation() async {
    if (!Platform.isAndroid) return null;
    try {
      final dynamic raw = await _channel.invokeMethod('getDeviceLocation');
      if (raw is Map) {
        final lat = (raw['latitude'] as num?)?.toDouble();
        final lng = (raw['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Request runtime location permission on Android
  static Future<bool> requestLocationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? result = await _channel.invokeMethod<bool>('requestLocationPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Show clean popup to guide user for battery optimization
  static void showBatteryOptimizationDialog({
    required BuildContext context,
    VoidCallback? onDone,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 22),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.battery_charging_full_rounded,
                color: Color(0xFF0284C7),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Background Reliability',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'To ensure Smart Silent triggers accurately during prayer times and meetings when your screen is locked, please allow unrestricted background activity.',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              'Select "Don\'t optimize" or "Allow" in the next screen.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0284C7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              onDone?.call();
            },
            child: const Text('Later', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await requestIgnoreBatteryOptimizations();
              onDone?.call();
            },
            child: const Text('Allow Unrestricted', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
