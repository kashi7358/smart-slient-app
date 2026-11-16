import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_silent/Provider/count_provider.dart';
import 'package:smart_silent/Utils/device_compatibility_helper.dart';
import 'package:smart_silent/Utils/meeting_alarm_helper.dart';
import 'package:smart_silent/Utils/one_time_alarm_helper.dart';
import 'package:smart_silent/Utils/prayer_alarm_helper.dart';
import 'package:smart_silent/View/on_bording.dart';
import 'package:smart_silent/View/tab_bar.dart';
import 'package:smart_silent/models/nemaz_model.dart';
import 'package:smart_silent/models/repeated_model.dart';
import 'package:smart_silent/models/schedule_model.dart';
import 'package:sound_mode/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  var directory = await getApplicationDocumentsDirectory();
  Hive.init(directory.path);

  Hive.registerAdapter(ScheduleModelAdapter());
  Hive.registerAdapter(RepeatedModelAdapter());
  Hive.registerAdapter(NemazModelAdapter());
  await Future.wait([
    Hive.openBox<ScheduleModel>("schedules"),
    Hive.openBox<RepeatedModel>("daily"),
    Hive.openBox<NemazModel>("nemaz"),
  ]);

  await AndroidAlarmManager.initialize();

  // Ensure default prayer schedule and background alarms are seeded on first launch
  await _ensureDefaultPrayerScheduleInitialized();

  // Verify alarms asynchronously without delaying app launch
  PrayerAlarmHelper.verifyAlarmsOnAppLaunch().catchError((_) {});
  MeetingAlarmHelper.verifyAlarmsOnAppLaunch().catchError((_) {});
  OneTimeAlarmHelper.verifyAlarmsOnAppLaunch().catchError((_) {});

  final prefs = await SharedPreferences.getInstance();
  final bool hasCompletedOnboarding = prefs.getBool('showHome') ?? false;

  bool isDndGranted = false;
  try {
    isDndGranted = (await PermissionHandler.permissionsGranted.timeout(
          const Duration(milliseconds: 1500),
          onTimeout: () => false,
        )) ??
        false;
  } catch (_) {
    isDndGranted = false;
  }

  if (!isDndGranted) {
    try {
      isDndGranted = await DeviceCompatibilityHelper.hasDndPermission();
    } catch (_) {}
  }

  // If user already completed onboarding or permission is granted, launch directly to Home
  final bool shouldShowHome = hasCompletedOnboarding || isDndGranted;

  runApp(MyApp(showHome: shouldShowHome));
}

Future<void> _ensureDefaultPrayerScheduleInitialized() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final nemazBox = Hive.box<NemazModel>("nemaz");

    final bool? userExplicitEnabled = prefs.getBool('prayer_alarms_enabled');
    if (userExplicitEnabled == false) {
      return;
    }

    if (nemazBox.isEmpty) {
      final now = DateTime.now();
      final defaultNemaz = NemazModel(
        FajarStart: DateTime(now.year, now.month, now.day, 5, 19),
        FajarEnd: DateTime(now.year, now.month, now.day, 5, 40),
        ZoharStart: DateTime(now.year, now.month, now.day, 13, 19),
        ZoharEnd: DateTime(now.year, now.month, now.day, 13, 40),
        AsarStart: DateTime(now.year, now.month, now.day, 15, 19),
        AsarEnd: DateTime(now.year, now.month, now.day, 15, 40),
        MagribStart: DateTime(now.year, now.month, now.day, 17, 19),
        MagribEnd: DateTime(now.year, now.month, now.day, 17, 40),
        IshaStart: DateTime(now.year, now.month, now.day, 19, 19),
        IshaEnd: DateTime(now.year, now.month, now.day, 19, 40),
        isSilentOrVibration: false,
        isFajarTaskActivated: true,
        isZoharTaskActivated: true,
        isAsarTaskActivated: true,
        isMagribTaskActivated: true,
        isIshaTaskActivated: true,
        forWhichMasjid: "Masjid",
      );

      await nemazBox.add(defaultNemaz);
      await prefs.setBool('prayer_alarms_enabled', true);
    }
  } catch (_) {}
}

class MyApp extends StatelessWidget {
  final bool? showHome;
  const MyApp({Key? key, this.showHome}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool shouldShowHome = showHome ?? false;
    return ChangeNotifierProvider(
      create: (_) => CountProvider(),
      child: MaterialApp(
        title: 'Smart Silent',
        theme: ThemeData(
          primarySwatch: Colors.purple,
        ),
        home: shouldShowHome ? const TabBarDemo() : const OnBordingScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
