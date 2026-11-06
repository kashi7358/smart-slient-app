import 'dart:async';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:smart_silent/Provider/count_provider.dart';
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

  // for one time
  Hive.registerAdapter(ScheduleModelAdapter());
  await Hive.openBox<ScheduleModel>("schedules");

  // for repeated
  Hive.registerAdapter(RepeatedModelAdapter());
  await Hive.openBox<RepeatedModel>("daily");

  // for nemaz
  Hive.registerAdapter(NemazModelAdapter());
  await Hive.openBox<NemazModel>("nemaz");

  await AndroidAlarmManager.initialize();

  // Check DND permission with a quick timeout so app never hangs on logo/splash
  bool isDndGranted = false;
  try {
    isDndGranted = (await PermissionHandler.permissionsGranted.timeout(
          const Duration(milliseconds: 600),
          onTimeout: () => false,
        )) ??
        false;
  } catch (_) {
    isDndGranted = false;
  }

  // Jab tak permission allow nahi hogi, OnBordingScreen dikhayenge
  runApp(MyApp(showHome: isDndGranted));
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
        // Direct home assignment guarantees frame 1 render without hanging
        home: shouldShowHome ? const TabBarDemo() : const OnBordingScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
