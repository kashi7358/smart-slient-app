import 'package:android_power_manager/android_power_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_silent/View/on_bording.dart';
import 'package:sound_mode/permission_handler.dart';

import '../Provider/count_provider.dart';
import '../constants.dart';
import '../models/nemaz_model.dart';
import '../models/repeated_model.dart';
import '../models/schedule_model.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String _isIgnoringBatteryOptimizations = 'Unknown';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CountProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.kbg,
      appBar: AppBar(
        title: Text("Settings"),
        backgroundColor: AppColors.kSecondary,
        foregroundColor: AppColors.kPrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
                leading: Icon(Icons.dnd_forwardslash),
                title: Text(
                  'DND',
                  textScaleFactor: 1.5,
                ),
                // trailing: Icon(Icons.done),
                subtitle: Text(
                    'Find and Allow donot disturb mode.Otherwise App may not work properly.'),
                selected: true,
                onTap: () {
                  openDoNotDisturbSettings();
                }),
          ),
          SizedBox(
            height: 10,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
              leading: Icon(Icons.battery_alert),
              title: Text(
                'Battery Saver',
                textScaleFactor: 1.5,
              ),
              subtitle:
                  Text('Set to no restriction so that schedules can excute.'),
              selected: true,
              onTap: () async {
                final success = await AndroidPowerManager
                    .requestIgnoreBatteryOptimizations();
                if (success ?? false) {
                  String isIgnoringBatteryOptimizations =
                      await _checkBatteryOptimizations();
                  setState(() {
                    _isIgnoringBatteryOptimizations =
                        isIgnoringBatteryOptimizations;
                  });
                } else {
                  print("good to goo");
                }
              },
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
              leading: Icon(Icons.restore),
              title: Text(
                'Reset',
                textScaleFactor: 1.5,
              ),
              subtitle: Text('Remove schedules and Reset settings'),
              selected: true,
              onTap: () async {
                final box = await Hive.openBox<ScheduleModel>('schedules');
                await box.clear();
                final box2 = await Hive.openBox<RepeatedModel>('daily');
                await box2.clear();
                final box3 = await Hive.openBox<NemazModel>('nemaz');
                await box3.clear();

                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('showHome');
                provider.updateHasData(false);
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => OnBordingScreen()));
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _checkBatteryOptimizations() async {
    String isIgnoringBatteryOptimizations;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      isIgnoringBatteryOptimizations =
          '${await AndroidPowerManager.isIgnoringBatteryOptimizations}';
    } on PlatformException {
      isIgnoringBatteryOptimizations = 'Failed to get platform version.';
    }
    return isIgnoringBatteryOptimizations;
  }

  Future<void> openDoNotDisturbSettings() async {
    await PermissionHandler.openDoNotDisturbSetting();
  }

  void deleteTask(ScheduleModel scheduleModel) async {
    await scheduleModel.delete();
  }
}
