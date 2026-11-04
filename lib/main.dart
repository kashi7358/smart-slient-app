import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  
  final prefs = await SharedPreferences.getInstance();
  final showHome = prefs.getBool('showHome') ?? false;
  final dndGranted = (await PermissionHandler.permissionsGranted) ?? false;

  // Agar DND permission OFF hai, to lazmi Onboarding screen show hogi
  final bool shouldShowHome = showHome && dndGranted;

  runApp(MyApp(showHome: shouldShowHome));
}

class MyApp extends StatelessWidget {
  final bool showHome;
  const MyApp({Key? key, required this.showHome}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CountProvider(),
      child: MaterialApp(
        title: 'Smart Silent',
        theme: ThemeData(
          primarySwatch: Colors.purple,
        ),
        home: showHome ? const TabBarDemo() : const OnBordingScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
