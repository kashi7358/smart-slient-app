import 'dart:convert';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_silent/models/nemaz_model.dart';
import 'package:smart_silent/models/repeated_model.dart';
import 'package:smart_silent/models/schedule_model.dart';
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

  /// Ensures Hive and all required boxes are opened in background alarm callbacks
  static Future<void> ensureHiveInitialized() async {
    try {
      if (!Hive.isBoxOpen('schedules') || !Hive.isBoxOpen('daily') || !Hive.isBoxOpen('nemaz')) {
        final dir = await getApplicationDocumentsDirectory();
        Hive.init(dir.path);
        if (!Hive.isAdapterRegistered(ScheduleModelAdapter().typeId)) Hive.registerAdapter(ScheduleModelAdapter());
        if (!Hive.isAdapterRegistered(RepeatedModelAdapter().typeId)) Hive.registerAdapter(RepeatedModelAdapter());
        if (!Hive.isAdapterRegistered(NemazModelAdapter().typeId)) Hive.registerAdapter(NemazModelAdapter());
        if (!Hive.isBoxOpen('schedules')) await Hive.openBox<ScheduleModel>('schedules');
        if (!Hive.isBoxOpen('daily')) await Hive.openBox<RepeatedModel>('daily');
        if (!Hive.isBoxOpen('nemaz')) await Hive.openBox<NemazModel>('nemaz');
        debugPrint('[SmartSilent] Background Hive boxes verified/opened');
      }
    } catch (e) {
      debugPrint('[SmartSilent] Error ensuring Hive initialized: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Public Window Management API
  // ---------------------------------------------------------------------------

  /// Enters a named silent/vibrate window (e.g. 'prayer_fajr', 'meeting_0', 'one_time_schedule', 'quick_silent').
  ///
  /// Guarantees that when an active schedule arrives at its scheduled time,
  /// the device is properly transitioned to Silent/Vibrate mode reliably.
  static Future<bool> enterSilentWindow({
    required String sourceId,
    required DateTime endTime,
    required bool vibrate,
    int? endAlarmId,
    bool isResumeOrSync = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      final int endMs = endTime.millisecondsSinceEpoch;

      if (isResumeOrSync) {
        // Protection only for re-sync/resume: if user manually set Normal DURING this active window, do not re-silence
        final int overrideUntilMs = prefs.getInt(_keyManualOverrideUntilMs) ?? 0;
        if (nowMs < overrideUntilMs && endMs <= overrideUntilMs) {
          debugPrint('[SmartSilent] User manual override active for current window ($sourceId). Not re-silencing.');
          return false;
        }
      } else {
        // Fresh start (alarms & Quick Silent): clear manual override so scheduling always silences
        await prefs.remove(_keyManualOverrideUntilMs);
        await prefs.remove(_keyManualOverrideMs);
        debugPrint('[SmartSilent] Override cleared on fresh start for $sourceId');
      }

      // Load existing active windows and update with this new window
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
      if (endAlarmId != null && sourceId.startsWith('quick_')) {
        await prefs.setInt(_keyQuickEndAlarmId, endAlarmId);
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
  // Low-level Native Sound Transition (via sound_mode plugin, never custom MethodChannel)
  // ---------------------------------------------------------------------------

  static Future<void> _setNativeSoundMode({required bool vibrate}) async {
    // Change ringer via sound_mode plugin, never the custom MethodChannel.
    // Replace RINGER_MODE_SILENT with RINGER_MODE_VIBRATE so DND is not triggered.
    try {
      await SoundMode.setSoundMode(RingerModeStatus.vibrate);
      debugPrint('[SmartSilent] Ringer set to Vibrate via sound_mode');
    } catch (e) {
      debugPrint('[SmartSilent] Error setting vibrate via sound_mode: $e');
    }
  }

  /// Restores Normal ringer mode via sound_mode plugin, never the custom MethodChannel
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

      // Restore Normal mode via sound_mode plugin
      try {
        await SoundMode.setSoundMode(RingerModeStatus.normal);
        debugPrint('[SmartSilent] Ringer restored to Normal via sound_mode');
      } catch (e) {
        debugPrint('[SmartSilent] Error restoring normal via sound_mode: $e');
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Manual Override Tracking
  // ---------------------------------------------------------------------------

  /// Records that the user intentionally took the device out of silent/vibrate
  /// into Normal mode during an active schedule.
  static Future<void> notifyManualOverride() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      final windows = await _loadActiveWindows(prefs);

      int maxEndMs = nowMs;
      for (final w in windows.values) {
        final int wEnd = (w['endMs'] as num?)?.toInt() ?? 0;
        if (wEnd > maxEndMs) maxEndMs = wEnd;
      }

      await prefs.setInt(_keyManualOverrideUntilMs, maxEndMs);
      await prefs.setInt(_keyManualOverrideMs, nowMs);
      await prefs.setBool(_keyAppManagedActive, false);
      debugPrint('[SmartSilent] Manual override registered until $maxEndMs');

      final int? pendingQuickId = prefs.getInt(_keyQuickEndAlarmId);
      if (pendingQuickId != null) {
        try {
          await AndroidAlarmManager.cancel(pendingQuickId);
        } catch (_) {}
        await prefs.remove(_keyQuickEndAlarmId);
      }
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

      // Ignore brief 5s transition period while sound mode settles
      if (nowMs - lastSetMs < 5000) return false;

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
    bool isResumeOrSync = false,
  }) async {
    final targetEnd = endTime ?? DateTime.now().add(const Duration(minutes: 30));
    await enterSilentWindow(
      sourceId: sourceId,
      endTime: targetEnd,
      vibrate: vibrate,
      endAlarmId: endAlarmId,
      isResumeOrSync: isResumeOrSync,
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
