import 'dart:async';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_silent/Boxes/boxes.dart';
import 'package:smart_silent/models/repeated_model.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

// Top-level VM entry-point callbacks for Meeting Schedules (slots 0-9)
@pragma('vm:entry-point')
void meetingStart0() async => await MeetingAlarmHelper.onMeetingStart(0);
@pragma('vm:entry-point')
void meetingEnd0() async => await MeetingAlarmHelper.onMeetingEnd(0);

@pragma('vm:entry-point')
void meetingStart1() async => await MeetingAlarmHelper.onMeetingStart(1);
@pragma('vm:entry-point')
void meetingEnd1() async => await MeetingAlarmHelper.onMeetingEnd(1);

@pragma('vm:entry-point')
void meetingStart2() async => await MeetingAlarmHelper.onMeetingStart(2);
@pragma('vm:entry-point')
void meetingEnd2() async => await MeetingAlarmHelper.onMeetingEnd(2);

@pragma('vm:entry-point')
void meetingStart3() async => await MeetingAlarmHelper.onMeetingStart(3);
@pragma('vm:entry-point')
void meetingEnd3() async => await MeetingAlarmHelper.onMeetingEnd(3);

@pragma('vm:entry-point')
void meetingStart4() async => await MeetingAlarmHelper.onMeetingStart(4);
@pragma('vm:entry-point')
void meetingEnd4() async => await MeetingAlarmHelper.onMeetingEnd(4);

@pragma('vm:entry-point')
void meetingStart5() async => await MeetingAlarmHelper.onMeetingStart(5);
@pragma('vm:entry-point')
void meetingEnd5() async => await MeetingAlarmHelper.onMeetingEnd(5);

@pragma('vm:entry-point')
void meetingStart6() async => await MeetingAlarmHelper.onMeetingStart(6);
@pragma('vm:entry-point')
void meetingEnd6() async => await MeetingAlarmHelper.onMeetingEnd(6);

@pragma('vm:entry-point')
void meetingStart7() async => await MeetingAlarmHelper.onMeetingStart(7);
@pragma('vm:entry-point')
void meetingEnd7() async => await MeetingAlarmHelper.onMeetingEnd(7);

@pragma('vm:entry-point')
void meetingStart8() async => await MeetingAlarmHelper.onMeetingStart(8);
@pragma('vm:entry-point')
void meetingEnd8() async => await MeetingAlarmHelper.onMeetingEnd(8);

@pragma('vm:entry-point')
void meetingStart9() async => await MeetingAlarmHelper.onMeetingStart(9);
@pragma('vm:entry-point')
void meetingEnd9() async => await MeetingAlarmHelper.onMeetingEnd(9);

class MeetingAlarmHelper {
  static const int _baseStartId = 20000;
  static const int _baseEndId = 20001;
  static const int maxSlots = 10;

  static final List<Function> _startCallbacks = [
    meetingStart0,
    meetingStart1,
    meetingStart2,
    meetingStart3,
    meetingStart4,
    meetingStart5,
    meetingStart6,
    meetingStart7,
    meetingStart8,
    meetingStart9,
  ];

  static final List<Function> _endCallbacks = [
    meetingEnd0,
    meetingEnd1,
    meetingEnd2,
    meetingEnd3,
    meetingEnd4,
    meetingEnd5,
    meetingEnd6,
    meetingEnd7,
    meetingEnd8,
    meetingEnd9,
  ];

  // Callback executed when a meeting schedule starts
  static Future<void> onMeetingStart(int slot) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('meeting_${slot}_enabled') ?? false;
      if (!enabled) return;

      final now = DateTime.now();
      // Days of week: 0=Sun, 1=Mon, ..., 6=Sat
      final daysString = prefs.getString('meeting_${slot}_days') ?? '0,1,2,3,4,5,6';
      final List<int> allowedDays = daysString
          .split(',')
          .where((e) => e.trim().isNotEmpty)
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .toList();

      final int currentDayOfWeek = now.weekday % 7; // DateTime weekday: 1=Mon..7=Sun -> % 7 gives 0=Sun
      final bool isTodayAllowed = allowedDays.contains(currentDayOfWeek);

      if (isTodayAllowed) {
        final isVibrate = prefs.getBool('meeting_${slot}_vibrate') ?? false;
        if (isVibrate) {
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

      // Automatically re-arm start alarm for tomorrow
      final startH = prefs.getInt('meeting_${slot}_start_h') ?? 9;
      final startM = prefs.getInt('meeting_${slot}_start_m') ?? 0;
      final tomorrowStart = DateTime(now.year, now.month, now.day + 1, startH, startM);

      final startAlarmId = _baseStartId + (slot * 2);
      await AndroidAlarmManager.oneShotAt(
        tomorrowStart,
        startAlarmId,
        _startCallbacks[slot],
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    } catch (_) {}
  }

  // Callback executed when a meeting schedule ends
  static Future<void> onMeetingEnd(int slot) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('meeting_${slot}_enabled') ?? false;
      if (!enabled) return;

      final now = DateTime.now();
      final daysString = prefs.getString('meeting_${slot}_days') ?? '0,1,2,3,4,5,6';
      final List<int> allowedDays = daysString
          .split(',')
          .where((e) => e.trim().isNotEmpty)
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .toList();

      final int currentDayOfWeek = now.weekday % 7;
      final bool isTodayAllowed = allowedDays.contains(currentDayOfWeek);

      if (isTodayAllowed) {
        try {
          await SoundMode.setSoundMode(RingerModeStatus.normal);
        } catch (_) {}
      }

      // Automatically re-arm end alarm for tomorrow
      final endH = prefs.getInt('meeting_${slot}_end_h') ?? 10;
      final endM = prefs.getInt('meeting_${slot}_end_m') ?? 0;
      final tomorrowEnd = DateTime(now.year, now.month, now.day + 1, endH, endM);

      final endAlarmId = _baseEndId + (slot * 2);
      await AndroidAlarmManager.oneShotAt(
        tomorrowEnd,
        endAlarmId,
        _endCallbacks[slot],
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    } catch (_) {}
  }

  // Sync all meetings currently in Hive Box to exact Android AlarmManager alarms
  static Future<void> syncAllMeetings() async {
    try {
      final box = Boxes.getDataforDaily();
      final items = box.values.toList().cast<RepeatedModel>();
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      for (int slot = 0; slot < maxSlots; slot++) {
        final startAlarmId = _baseStartId + (slot * 2);
        final endAlarmId = _baseEndId + (slot * 2);

        if (slot < items.length) {
          final item = items[slot];
          if (item.isTaskActivated) {
            // Save configuration to SharedPreferences for background isolate
            await prefs.setBool('meeting_${slot}_enabled', true);
            await prefs.setBool('meeting_${slot}_vibrate', item.isSilentOrVibration);
            await prefs.setInt('meeting_${slot}_start_h', item.Start.hour);
            await prefs.setInt('meeting_${slot}_start_m', item.Start.minute);
            await prefs.setInt('meeting_${slot}_end_h', item.End.hour);
            await prefs.setInt('meeting_${slot}_end_m', item.End.minute);

            final days = item.dayInWeek ?? [0, 1, 2, 3, 4, 5, 6];
            await prefs.setString('meeting_${slot}_days', days.join(','));

            // Calculate target start time
            DateTime targetStart = DateTime(now.year, now.month, now.day, item.Start.hour, item.Start.minute);
            DateTime targetEnd = DateTime(now.year, now.month, now.day, item.End.hour, item.End.minute);

            if (targetStart.isBefore(now)) {
              targetStart = targetStart.add(const Duration(days: 1));
            }
            if (targetEnd.isBefore(now)) {
              targetEnd = targetEnd.add(const Duration(days: 1));
            }

            // Schedule start alarm
            try {
              await AndroidAlarmManager.cancel(startAlarmId);
            } catch (_) {}
            await AndroidAlarmManager.oneShotAt(
              targetStart,
              startAlarmId,
              _startCallbacks[slot],
              exact: true,
              wakeup: true,
              rescheduleOnReboot: true,
            );

            // Schedule end alarm
            try {
              await AndroidAlarmManager.cancel(endAlarmId);
            } catch (_) {}
            await AndroidAlarmManager.oneShotAt(
              targetEnd,
              endAlarmId,
              _endCallbacks[slot],
              exact: true,
              wakeup: true,
              rescheduleOnReboot: true,
            );
            continue;
          }
        }

        // Deactivated or beyond current meetings list -> cancel
        await prefs.setBool('meeting_${slot}_enabled', false);
        try {
          await AndroidAlarmManager.cancel(startAlarmId);
        } catch (_) {}
        try {
          await AndroidAlarmManager.cancel(endAlarmId);
        } catch (_) {}
      }
    } catch (_) {}
  }

  // Cancel all meeting alarms and reset state
  static Future<void> cancelAllMeetings() async {
    final prefs = await SharedPreferences.getInstance();
    for (int slot = 0; slot < maxSlots; slot++) {
      await prefs.setBool('meeting_${slot}_enabled', false);
      final startAlarmId = _baseStartId + (slot * 2);
      final endAlarmId = _baseEndId + (slot * 2);
      try {
        await AndroidAlarmManager.cancel(startAlarmId);
      } catch (_) {}
      try {
        await AndroidAlarmManager.cancel(endAlarmId);
      } catch (_) {}
    }
  }

  // App launch hook to ensure all meeting alarms are active
  static Future<void> verifyAlarmsOnAppLaunch() async {
    await syncAllMeetings();
  }
}
