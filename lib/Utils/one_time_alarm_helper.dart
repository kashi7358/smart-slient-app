import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_silent/Boxes/boxes.dart';
import 'package:smart_silent/Utils/sound_control_helper.dart';
import 'package:smart_silent/models/schedule_model.dart';

// Top-level VM entry-point callbacks for One-Time Schedules
@pragma('vm:entry-point')
void oneTimeSilentStartCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OneTimeAlarmHelper.handleOneTimeStart(vibrate: false);
}

@pragma('vm:entry-point')
void oneTimeVibrateStartCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OneTimeAlarmHelper.handleOneTimeStart(vibrate: true);
}

@pragma('vm:entry-point')
void oneTimeNormalEndCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OneTimeAlarmHelper.handleOneTimeEnd();
}

// Backward-compatible entry points for previously registered alarms
@pragma('vm:entry-point')
void scheduleSilentCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OneTimeAlarmHelper.handleOneTimeStart(vibrate: false);
}

@pragma('vm:entry-point')
void scheduleVibrateCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OneTimeAlarmHelper.handleOneTimeStart(vibrate: true);
}

@pragma('vm:entry-point')
void scheduleNormalCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OneTimeAlarmHelper.handleOneTimeEnd();
}

class OneTimeAlarmHelper {
  /// Generate deterministic unique start alarm ID for a schedule item (30000-39999 range)
  static int getAlarmId(ScheduleModel item) {
    if (item.key != null && item.key is int) {
      return 30000 + ((item.key as int) % 4000) * 2;
    }
    return 30000 + ((item.Start.millisecondsSinceEpoch ~/ 1000) % 4000) * 2;
  }

  /// Schedule alarm safely with exact mode and fallback for Android 12-15
  static Future<void> scheduleAlarmSafe({
    required DateTime time,
    required int alarmId,
    required Function callback,
  }) async {
    try {
      await AndroidAlarmManager.oneShotAt(
        time,
        alarmId,
        callback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    } catch (_) {
      try {
        await AndroidAlarmManager.oneShotAt(
          time,
          alarmId,
          callback,
          exact: false,
          wakeup: true,
          rescheduleOnReboot: true,
        );
      } catch (_) {}
    }
  }

  /// Called when a One-Time schedule start alarm fires
  static Future<void> handleOneTimeStart({required bool vibrate}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      int targetEndMs = prefs.getInt('latest_active_onetime_end_ms') ?? 0;

      // Find the end time of any currently active one-time schedule
      for (final key in prefs.getKeys()) {
        if (key.startsWith('onetime_') && key.endsWith('_end_ms')) {
          final int endVal = prefs.getInt(key) ?? 0;
          if (endVal > nowMs && (targetEndMs <= nowMs || endVal > targetEndMs)) {
            targetEndMs = endVal;
          }
        }
      }

      if (targetEndMs <= nowMs) {
        targetEndMs = nowMs + (30 * 60 * 1000); // 30 min default fallback
      }

      final DateTime targetEnd = DateTime.fromMillisecondsSinceEpoch(targetEndMs);

      await SoundControlHelper.enterSilentWindow(
        sourceId: 'one_time_schedule',
        endTime: targetEnd,
        vibrate: vibrate,
      );
    } catch (_) {}
  }

  /// Called when a One-Time schedule end alarm fires: restores Normal mode
  static Future<void> handleOneTimeEnd() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final int nowMs = DateTime.now().millisecondsSinceEpoch;

      // Clean up SharedPreferences onetime keys for expired items
      final keysToRemove = <String>[];
      for (final key in prefs.getKeys()) {
        if (key.startsWith('onetime_') && key.endsWith('_end_ms')) {
          final int endVal = prefs.getInt(key) ?? 0;
          if (endVal <= nowMs + 1000) {
            final prefix = key.substring(0, key.length - 7); // 'onetime_XYZ'
            keysToRemove.add(key);
            keysToRemove.add('${prefix}_start_ms');
            keysToRemove.add('${prefix}_vibrate');
          }
        }
      }
      for (final k in keysToRemove) {
        await prefs.remove(k);
      }

      final latestEnd = prefs.getInt('latest_active_onetime_end_ms') ?? 0;
      if (latestEnd <= nowMs + 1000) {
        await prefs.remove('latest_active_onetime_end_ms');
        await prefs.remove('latest_active_onetime_vibrate');
      }

      // 1. Leave silent window for one_time_schedule
      await SoundControlHelper.leaveSilentWindow(sourceId: 'one_time_schedule');

      // 2. Unconditionally restore Normal mode when one-time window ends
      await SoundControlHelper.restoreNormalMode(onlyIfAppManaged: false);

      // 3. Mark any expired schedules as deactivated in Hive
      try {
        if (Hive.isBoxOpen('schedules')) {
          final box = Boxes.getData();
          final now = DateTime.now();
          for (var item in box.values) {
            if (item.isTaskActivated && item.End.isBefore(now)) {
              item.isTaskActivated = false;
              await item.save();
            }
          }
        }
      } catch (_) {}
    } catch (_) {}
  }

  /// Register alarms and track state for a One-Time schedule
  static Future<void> scheduleOneTime(ScheduleModel item) async {
    final startAlarmId = getAlarmId(item);
    final endAlarmId = startAlarmId + 1;
    final now = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('onetime_${item.key}_start_ms', item.Start.millisecondsSinceEpoch);
    await prefs.setInt('onetime_${item.key}_end_ms', item.End.millisecondsSinceEpoch);
    await prefs.setBool('onetime_${item.key}_vibrate', item.isSilentOrVibration);
    await prefs.setInt('latest_active_onetime_end_ms', item.End.millisecondsSinceEpoch);
    await prefs.setBool('latest_active_onetime_vibrate', item.isSilentOrVibration);

    if (item.Start.isAfter(now)) {
      await scheduleAlarmSafe(
        time: item.Start,
        alarmId: startAlarmId,
        callback: item.isSilentOrVibration
            ? oneTimeVibrateStartCallback
            : oneTimeSilentStartCallback,
      );
    } else if (item.End.isAfter(now)) {
      // Currently within schedule: enter silent window immediately
      try {
        await SoundControlHelper.enterSilentWindow(
          sourceId: 'one_time_schedule',
          endTime: item.End,
          vibrate: item.isSilentOrVibration,
          endAlarmId: endAlarmId,
        );
      } catch (_) {}
    }

    if (item.End.isAfter(now)) {
      await scheduleAlarmSafe(
        time: item.End,
        alarmId: endAlarmId,
        callback: oneTimeNormalEndCallback,
      );
    }
  }

  /// Cancel all alarms and restore normal mode if currently active
  static Future<void> cancelOneTime(ScheduleModel item) async {
    final startAlarmId = getAlarmId(item);
    final endAlarmId = startAlarmId + 1;
    final now = DateTime.now();

    try {
      await AndroidAlarmManager.cancel(startAlarmId);
      await AndroidAlarmManager.cancel(endAlarmId);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onetime_${item.key}_start_ms');
    await prefs.remove('onetime_${item.key}_end_ms');
    await prefs.remove('onetime_${item.key}_vibrate');

    if (now.isAfter(item.Start) && now.isBefore(item.End)) {
      await SoundControlHelper.leaveSilentWindow(sourceId: 'one_time_schedule');
      await SoundControlHelper.restoreNormalMode(onlyIfAppManaged: false);
    }
  }

  /// Verifies all active One-Time schedules on app launch or boot
  static Future<void> verifyAlarmsOnAppLaunch() async {
    try {
      final box = Boxes.getData();
      if (box.isEmpty) return;

      final now = DateTime.now();

      for (var item in box.values) {
        if (!item.isTaskActivated) continue;

        // If schedule has already expired in the past, deactivate it
        if (item.End.isBefore(now)) {
          item.isTaskActivated = false;
          await item.save();
          continue;
        }

        await scheduleOneTime(item);
      }
    } catch (_) {}
  }
}
