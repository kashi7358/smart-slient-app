import 'dart:async';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

// Top-level VM entry-point callbacks for AndroidAlarmManager
// Each callback sets the sound mode AND automatically schedules the next day's exact alarm

@pragma('vm:entry-point')
void fajrStartCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrayerAlarmHelper.handlePrayerStart(1001, 'fajr', fajrStartCallback);
}

@pragma('vm:entry-point')
void fajrEndCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrayerAlarmHelper.handlePrayerEnd(1002, 'fajr', fajrEndCallback);
}

@pragma('vm:entry-point')
void zoharStartCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrayerAlarmHelper.handlePrayerStart(1003, 'zohar', zoharStartCallback);
}

@pragma('vm:entry-point')
void zoharEndCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrayerAlarmHelper.handlePrayerEnd(1004, 'zohar', zoharEndCallback);
}

@pragma('vm:entry-point')
void asarStartCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrayerAlarmHelper.handlePrayerStart(1005, 'asar', asarStartCallback);
}

@pragma('vm:entry-point')
void asarEndCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrayerAlarmHelper.handlePrayerEnd(1006, 'asar', asarEndCallback);
}

@pragma('vm:entry-point')
void magribStartCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrayerAlarmHelper.handlePrayerStart(1007, 'magrib', magribStartCallback);
}

@pragma('vm:entry-point')
void magribEndCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrayerAlarmHelper.handlePrayerEnd(1008, 'magrib', magribEndCallback);
}

@pragma('vm:entry-point')
void ishaStartCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrayerAlarmHelper.handlePrayerStart(1009, 'isha', ishaStartCallback);
}

@pragma('vm:entry-point')
void ishaEndCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrayerAlarmHelper.handlePrayerEnd(1010, 'isha', ishaEndCallback);
}

class PrayerAlarmHelper {
  // Safe alarm scheduler with Android 12-15 fallback
  static Future<void> _safeOneShotAt(
    DateTime time,
    int id,
    Function callback,
  ) async {
    try {
      await AndroidAlarmManager.oneShotAt(
        time,
        id,
        callback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    } catch (_) {
      try {
        await AndroidAlarmManager.oneShotAt(
          time,
          id,
          callback,
          exact: false,
          wakeup: true,
          rescheduleOnReboot: true,
        );
      } catch (_) {}
    }
  }

  // Handles prayer start: sets Silent / Vibrate and re-arms for tomorrow
  static Future<void> handlePrayerStart(int alarmId, String prayerKey, Function callback) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('prayer_alarms_enabled') ?? true;
      if (!enabled) return;

      final isVibrate = prefs.getBool('prayer_vibrate_mode') ?? false;

      // 1. Set Silent or Vibrate mode
      if (isVibrate) {
        try {
          await SoundMode.setSoundMode(RingerModeStatus.vibrate);
        } catch (_) {}
      } else {
        try {
          await SoundMode.setSoundMode(RingerModeStatus.silent);
        } catch (_) {
          // If DND permission is missing or restricted, fallback to Vibrate so device is never loud!
          try {
            await SoundMode.setSoundMode(RingerModeStatus.vibrate);
          } catch (_) {}
        }
      }

      // 2. Re-arm for tomorrow at the exact same hour and minute
      final hour = prefs.getInt('${prayerKey}_start_h') ?? 5;
      final minute = prefs.getInt('${prayerKey}_start_m') ?? 19;
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1, hour, minute);

      await _safeOneShotAt(tomorrow, alarmId, callback);
    } catch (_) {}
  }

  // Handles prayer end: sets Normal mode and re-arms for tomorrow
  static Future<void> handlePrayerEnd(int alarmId, String prayerKey, Function callback) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('prayer_alarms_enabled') ?? true;
      if (!enabled) return;

      // 1. Set Normal mode
      try {
        await SoundMode.setSoundMode(RingerModeStatus.normal);
      } catch (_) {}

      // 2. Re-arm for tomorrow at the exact same hour and minute
      final hour = prefs.getInt('${prayerKey}_end_h') ?? 5;
      final minute = prefs.getInt('${prayerKey}_end_m') ?? 40;
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1, hour, minute);

      await _safeOneShotAt(tomorrow, alarmId, callback);
    } catch (_) {}
  }

  // Schedule all 5 prayers with exact alarms and auto-daily repeating
  static Future<void> scheduleAllPrayers({
    required TimeOfDay fajarStart,
    required TimeOfDay fajarEnd,
    required TimeOfDay zoharStart,
    required TimeOfDay zoharEnd,
    required TimeOfDay asarStart,
    required TimeOfDay asarEnd,
    required TimeOfDay magribStart,
    required TimeOfDay magribEnd,
    required TimeOfDay ishaStart,
    required TimeOfDay ishaEnd,
    required bool isVibrateMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Save all timings and settings in SharedPreferences
    await prefs.setBool('prayer_alarms_enabled', true);
    await prefs.setBool('prayer_vibrate_mode', isVibrateMode);

    await prefs.setInt('fajr_start_h', fajarStart.hour);
    await prefs.setInt('fajr_start_m', fajarStart.minute);
    await prefs.setInt('fajr_end_h', fajarEnd.hour);
    await prefs.setInt('fajr_end_m', fajarEnd.minute);

    await prefs.setInt('zohar_start_h', zoharStart.hour);
    await prefs.setInt('zohar_start_m', zoharStart.minute);
    await prefs.setInt('zohar_end_h', zoharEnd.hour);
    await prefs.setInt('zohar_end_m', zoharEnd.minute);

    await prefs.setInt('asar_start_h', asarStart.hour);
    await prefs.setInt('asar_start_m', asarStart.minute);
    await prefs.setInt('asar_end_h', asarEnd.hour);
    await prefs.setInt('asar_end_m', asarEnd.minute);

    await prefs.setInt('magrib_start_h', magribStart.hour);
    await prefs.setInt('magrib_start_m', magribStart.minute);
    await prefs.setInt('magrib_end_h', magribEnd.hour);
    await prefs.setInt('magrib_end_m', magribEnd.minute);

    await prefs.setInt('isha_start_h', ishaStart.hour);
    await prefs.setInt('isha_start_m', ishaStart.minute);
    await prefs.setInt('isha_end_h', ishaEnd.hour);
    await prefs.setInt('isha_end_m', ishaEnd.minute);

    // 2. Cancel previous prayer alarms to ensure clean slate
    for (int id = 1001; id <= 1010; id++) {
      try {
        await AndroidAlarmManager.cancel(id);
      } catch (_) {}
    }

    final prayersConfig = [
      {'key': 'fajr', 'start': fajarStart, 'end': fajarEnd, 'startId': 1001, 'endId': 1002, 'startCb': fajrStartCallback, 'endCb': fajrEndCallback},
      {'key': 'zohar', 'start': zoharStart, 'end': zoharEnd, 'startId': 1003, 'endId': 1004, 'startCb': zoharStartCallback, 'endCb': zoharEndCallback},
      {'key': 'asar', 'start': asarStart, 'end': asarEnd, 'startId': 1005, 'endId': 1006, 'startCb': asarStartCallback, 'endCb': asarEndCallback},
      {'key': 'magrib', 'start': magribStart, 'end': magribEnd, 'startId': 1007, 'endId': 1008, 'startCb': magribStartCallback, 'endCb': magribEndCallback},
      {'key': 'isha', 'start': ishaStart, 'end': ishaEnd, 'startId': 1009, 'endId': 1010, 'startCb': ishaStartCallback, 'endCb': ishaEndCallback},
    ];

    final now = DateTime.now();
    bool isCurrentlyInsideAnyPrayer = false;

    // 3. Schedule exact oneShotAt alarms for each prayer
    for (final cfg in prayersConfig) {
      final startTod = cfg['start'] as TimeOfDay;
      final endTod = cfg['end'] as TimeOfDay;
      final startAlarmId = cfg['startId'] as int;
      final endAlarmId = cfg['endId'] as int;
      final startCb = cfg['startCb'] as Function;
      final endCb = cfg['endCb'] as Function;

      DateTime targetStart = DateTime(now.year, now.month, now.day, startTod.hour, startTod.minute);
      DateTime targetEnd = DateTime(now.year, now.month, now.day, endTod.hour, endTod.minute);

      // Check if current time is inside this prayer interval
      final bool inside = (now.isAfter(targetStart) || now.isAtSameMomentAs(targetStart)) && now.isBefore(targetEnd);

      if (inside) {
        isCurrentlyInsideAnyPrayer = true;
        // Start alarm target moves to tomorrow
        targetStart = targetStart.add(const Duration(days: 1));
        // End alarm stays today at targetEnd
      } else {
        if (targetStart.isBefore(now)) {
          targetStart = targetStart.add(const Duration(days: 1));
        }
        if (targetEnd.isBefore(now)) {
          targetEnd = targetEnd.add(const Duration(days: 1));
        }
      }

      // Schedule Start Alarm
      await _safeOneShotAt(targetStart, startAlarmId, startCb);

      // Schedule End Alarm
      await _safeOneShotAt(targetEnd, endAlarmId, endCb);
    }

    // 4. If current time is inside prayer time, turn on silent/vibrate right now!
    if (isCurrentlyInsideAnyPrayer) {
      if (isVibrateMode) {
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
  }

  // Cancel all prayer alarms
  static Future<void> cancelAllPrayers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prayer_alarms_enabled', false);

    for (int id = 1001; id <= 1010; id++) {
      try {
        await AndroidAlarmManager.cancel(id);
      } catch (_) {}
    }

    try {
      await SoundMode.setSoundMode(RingerModeStatus.normal);
    } catch (_) {}
  }

  // Verify and re-ensure alarms on app launch/resume
  static Future<void> verifyAlarmsOnAppLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('prayer_alarms_enabled') ?? false;
    if (!enabled) return;

    final fajarStart = TimeOfDay(hour: prefs.getInt('fajr_start_h') ?? 5, minute: prefs.getInt('fajr_start_m') ?? 19);
    final fajarEnd = TimeOfDay(hour: prefs.getInt('fajr_end_h') ?? 5, minute: prefs.getInt('fajr_end_m') ?? 40);

    final zoharStart = TimeOfDay(hour: prefs.getInt('zohar_start_h') ?? 13, minute: prefs.getInt('zohar_start_m') ?? 19);
    final zoharEnd = TimeOfDay(hour: prefs.getInt('zohar_end_h') ?? 13, minute: prefs.getInt('zohar_end_m') ?? 40);

    final asarStart = TimeOfDay(hour: prefs.getInt('asar_start_h') ?? 15, minute: prefs.getInt('asar_start_m') ?? 19);
    final asarEnd = TimeOfDay(hour: prefs.getInt('asar_end_h') ?? 15, minute: prefs.getInt('asar_end_m') ?? 40);

    final magribStart = TimeOfDay(hour: prefs.getInt('magrib_start_h') ?? 17, minute: prefs.getInt('magrib_start_m') ?? 19);
    final magribEnd = TimeOfDay(hour: prefs.getInt('magrib_end_h') ?? 17, minute: prefs.getInt('magrib_end_m') ?? 40);

    final ishaStart = TimeOfDay(hour: prefs.getInt('isha_start_h') ?? 19, minute: prefs.getInt('isha_start_m') ?? 19);
    final ishaEnd = TimeOfDay(hour: prefs.getInt('isha_end_h') ?? 19, minute: prefs.getInt('isha_end_m') ?? 40);

    final isVibrate = prefs.getBool('prayer_vibrate_mode') ?? false;

    await scheduleAllPrayers(
      fajarStart: fajarStart,
      fajarEnd: fajarEnd,
      zoharStart: zoharStart,
      zoharEnd: zoharEnd,
      asarStart: asarStart,
      asarEnd: asarEnd,
      magribStart: magribStart,
      magribEnd: magribEnd,
      ishaStart: ishaStart,
      ishaEnd: ishaEnd,
      isVibrateMode: isVibrate,
    );
  }
}
