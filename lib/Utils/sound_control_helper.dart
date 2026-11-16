import 'dart:convert';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

/// Enterprise Multi-Source Sound State Coordinator & Arbiter.
///
/// Coordinates app-initiated Silent/Vibrate transitions across overlapping
/// schedules (Prayer times, Weekly Meetings, One-Time events, Quick Silent).
///
/// Guarantees:
/// 1. Strict respect for User Manual Overrides: If the user takes the device
///    out of silent mode during an active schedule, the app WILL NOT force
///    the phone back into silent mode for that window.
/// 2. Overlap Arbitration: An ending schedule (e.g. Prayer ending at 1:45 PM)
///    will NEVER restore Normal mode if another schedule (e.g. Meeting until 2:00 PM)
///    is still currently active.
/// 3. Robust Error Fallback: If DND permission is restricted, gracefully falls back
///    to Vibrate mode so the device is never loudly ringing in sacred/quiet hours.
class SoundControlHelper {
  static const MethodChannel _platformChannel =
      MethodChannel('com.kawiish.smartsilent/device_compatibility');

  static const String _keyAppManagedActive = 'app_managed_sound_active';
  static const String _keyAppLastSetMs = 'app_last_set_ms';
  static const String _keyAppManagedEndMs = 'app_managed_end_ms';
  static const String _keyQuickEndAlarmId = 'active_quick_end_alarm_id';
  static const String _keyManualOverrideUntilMs = 'user_manual_override_until_ms';
  static const String _keyManualOverrideMs = 'user_manual_override_ms';
  static const String _keyActiveWindowsJson = 'active_sound_windows_json';

  // ---------------------------------------------------------------------------
  // Internal Registry Operations
  // ---------------------------------------------------------------------------

  static Future<Map<String, Map<String, dynamic>>> _loadActiveWindows(SharedPreferences prefs) async {
    try {
      final raw = prefs.getString(_keyActiveWindowsJson);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final Map<String, Map<String, dynamic>> result = {};
        decoded.forEach((key, value) {
          if (value is Map) {
            result[key.toString()] = Map<String, dynamic>.from(value);
          }
        });
        return result;
      }
    } catch (_) {}
    return {};
  }

  static Future<void> _saveActiveWindows(
    SharedPreferences prefs,
    Map<String, Map<String, dynamic>> windows,
  ) async {
    try {
      if (windows.isEmpty) {
        await prefs.remove(_keyActiveWindowsJson);
      } else {
        await prefs.setString(_keyActiveWindowsJson, jsonEncode(windows));
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Public Window Management API
  // ---------------------------------------------------------------------------

  /// Enters a named silent/vibrate window (e.g. 'prayer_fajr', 'meeting_0', 'quick_silent').
  ///
  /// If the user previously manually took the phone out of silent mode for this
  /// period, this function registers the window for tracking but REFUSES to re-silence
  /// the phone, honoring the user's manual intent.
  static Future<bool> enterSilentWindow({
    required String sourceId,
    required DateTime endTime,
    required bool vibrate,
    int? endAlarmId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      final int endMs = endTime.millisecondsSinceEpoch;

      // 1. Check if user manually took phone to Normal mode during the current window
      final int overrideUntilMs = prefs.getInt(_keyManualOverrideUntilMs) ?? 0;
      final bool isOverrideActive = (nowMs < overrideUntilMs);

      // 2. Load existing active windows and update with this new window
      final windows = await _loadActiveWindows(prefs);

      // Clean out expired windows
      windows.removeWhere((id, data) {
        final int wEnd = (data['endMs'] as num?)?.toInt() ?? 0;
        return wEnd <= nowMs;
      });

      windows[sourceId] = {
        'startMs': nowMs,
        'endMs': endMs,
        'vibrate': vibrate,
        'alarmId': endAlarmId,
      };

      await _saveActiveWindows(prefs, windows);

      // Track max end time among all active windows
      int maxEndMs = endMs;
      for (final w in windows.values) {
        final int wEnd = (w['endMs'] as num?)?.toInt() ?? 0;
        if (wEnd > maxEndMs) maxEndMs = wEnd;
      }

      await prefs.setInt(_keyAppManagedEndMs, maxEndMs);
      if (endAlarmId != null) {
        await prefs.setInt(_keyQuickEndAlarmId, endAlarmId);
      }

      // If user manually un-silenced during this active period, DO NOT RE-SILENCE!
      if (isOverrideActive) {
        return false;
      }

      // 3. Apply silent or vibrate mode
      await prefs.setInt(_keyAppLastSetMs, nowMs);
      await prefs.setBool(_keyAppManagedActive, true);

      await _setNativeSoundMode(vibrate: vibrate);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Leaves a named silent window (e.g. prayer window ends or meeting ends).
  ///
  /// If ANY other window is still active, Normal mode is NOT restored.
  /// Normal mode is only restored when all active windows have concluded.
  static Future<void> leaveSilentWindow({
    required String sourceId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      final windows = await _loadActiveWindows(prefs);

      // Remove this source and any other expired sources
      windows.remove(sourceId);
      windows.removeWhere((id, data) {
        final int wEnd = (data['endMs'] as num?)?.toInt() ?? 0;
        return wEnd <= nowMs;
      });

      // If one_time_schedule is ending, ensure any orphaned one-time or legacy quick_silent is cleared
      if (sourceId == 'one_time_schedule') {
        final int? quickAlarmId = prefs.getInt(_keyQuickEndAlarmId);
        if (quickAlarmId == null && windows.containsKey('quick_silent')) {
          windows.remove('quick_silent');
        }
      }

      await _saveActiveWindows(prefs, windows);

      // If other windows are still running, keep device silent/vibrate!
      if (windows.isNotEmpty) {
        // Check if any remaining window requires vibrate mode
        bool anyVibrate = false;
        int maxRemainingEndMs = 0;
        for (final w in windows.values) {
          if (w['vibrate'] == true) anyVibrate = true;
          final int wEnd = (w['endMs'] as num?)?.toInt() ?? 0;
          if (wEnd > maxRemainingEndMs) maxRemainingEndMs = wEnd;
        }

        await prefs.setInt(_keyAppManagedEndMs, maxRemainingEndMs);

        // Ensure sound mode remains in sync (only if user hasn't overridden)
        final int overrideUntil = prefs.getInt(_keyManualOverrideUntilMs) ?? 0;
        if (nowMs >= overrideUntil) {
          await _setNativeSoundMode(vibrate: anyVibrate);
        }
        return;
      }

      // All active windows have finished -> Restore Normal Mode
      await prefs.remove(_keyAppManagedEndMs);
      await prefs.remove(_keyQuickEndAlarmId);
      await prefs.remove(_keyManualOverrideUntilMs);

      await restoreNormalMode(onlyIfAppManaged: false);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Low-level Native Sound Transition
  // ---------------------------------------------------------------------------

  static Future<void> _setNativeSoundMode({required bool vibrate}) async {
    // 1. Try native AudioManager first (bypasses sound_mode package permission crashes)
    try {
      final String modeStr = vibrate ? 'vibrate' : 'silent';
      final dynamic res = await _platformChannel.invokeMethod('setNativeRingerMode', {'mode': modeStr});
      if (res != null) return;
    } catch (_) {}

    // 2. Secondary fallback to sound_mode plugin if native channel is unavailable
    if (vibrate) {
      try {
        await SoundMode.setSoundMode(RingerModeStatus.vibrate);
      } catch (_) {}
    } else {
      try {
        await SoundMode.setSoundMode(RingerModeStatus.silent);
      } catch (_) {
        try {
          await SoundMode.setSoundMode(RingerModeStatus.vibrate);
        } catch (_) {}
      }
    }
  }

  /// Restores Normal ringer mode and clears system DND if permitted.
  static Future<void> restoreNormalMode({bool onlyIfAppManaged = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final bool isManaged = prefs.getBool(_keyAppManagedActive) ?? false;
      if (onlyIfAppManaged && !isManaged) {
        return;
      }

      await prefs.setBool(_keyAppManagedActive, false);
      await prefs.setInt(_keyAppLastSetMs, DateTime.now().millisecondsSinceEpoch);
      await prefs.remove(_keyQuickEndAlarmId);

      // 1. Native restore
      try {
        await _platformChannel.invokeMethod('setNativeRingerMode', {'mode': 'normal'});
      } catch (_) {}

      // 2. Fallback
      try {
        await SoundMode.setSoundMode(RingerModeStatus.normal);
      } catch (_) {}

      try {
        await _platformChannel.invokeMethod('clearDndIfAllowed');
      } catch (_) {}
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Manual Override Tracking
  // ---------------------------------------------------------------------------

  /// Records that the user intentionally took the device out of silent/vibrate
  /// into Normal mode. Locks out automatic re-silencing until the current
  /// active window interval finishes.
  static Future<void> notifyManualOverride() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      final windows = await _loadActiveWindows(prefs);

      int maxEndMs = nowMs + (30 * 60 * 1000); // 30 min default fallback
      for (final w in windows.values) {
        final int wEnd = (w['endMs'] as num?)?.toInt() ?? 0;
        if (wEnd > maxEndMs) maxEndMs = wEnd;
      }

      await prefs.setInt(_keyManualOverrideUntilMs, maxEndMs);
      await prefs.setInt(_keyManualOverrideMs, nowMs);
      await prefs.setBool(_keyAppManagedActive, false);

      final int? pendingQuickId = prefs.getInt(_keyQuickEndAlarmId);
      if (pendingQuickId != null) {
        try {
          await AndroidAlarmManager.cancel(pendingQuickId);
        } catch (_) {}
        await prefs.remove(_keyQuickEndAlarmId);
      }

      try {
        await _platformChannel.invokeMethod('clearDndIfAllowed');
      } catch (_) {}
    } catch (_) {}
  }

  /// Checks whether the user manually returned the phone to Normal mode in
  /// Android system settings or volume keys while a managed silent mode was active.
  static Future<bool> syncManualOverrideState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final bool isManaged = prefs.getBool(_keyAppManagedActive) ?? false;
      if (!isManaged) return true;

      final int lastSetMs = prefs.getInt(_keyAppLastSetMs) ?? 0;
      final int nowMs = DateTime.now().millisecondsSinceEpoch;

      // Ignore brief 3s transition period while sound mode settles
      if (nowMs - lastSetMs < 3000) return false;

      final current = await SoundMode.ringerModeStatus;
      if (current == RingerModeStatus.normal) {
        await notifyManualOverride();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Backward-Compatible Facade
  // ---------------------------------------------------------------------------

  static Future<void> applySilentOrVibrate({
    required bool vibrate,
    DateTime? endTime,
    int? endAlarmId,
    String sourceId = 'quick_silent',
  }) async {
    final targetEnd = endTime ?? DateTime.now().add(const Duration(minutes: 30));
    await enterSilentWindow(
      sourceId: sourceId,
      endTime: targetEnd,
      vibrate: vibrate,
      endAlarmId: endAlarmId,
    );
  }

  static Future<void> markAppManagedMode({
    DateTime? endTime,
    int? endAlarmId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_keyAppLastSetMs, nowMs);
      await prefs.setBool(_keyAppManagedActive, true);
      if (endTime != null) {
        await prefs.setInt(_keyAppManagedEndMs, endTime.millisecondsSinceEpoch);
      }
      if (endAlarmId != null) {
        await prefs.setInt(_keyQuickEndAlarmId, endAlarmId);
      }
    } catch (_) {}
  }
}
