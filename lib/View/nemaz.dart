import 'dart:math';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:smart_silent/Boxes/boxes.dart';
import 'package:smart_silent/Provider/count_provider.dart';
import 'package:smart_silent/View/create_nemaz.dart';
import 'package:smart_silent/models/nemaz_model.dart';
import 'package:sound_mode/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

import '../constants.dart';

class Nemaz extends StatefulWidget {
  const Nemaz({super.key});

  @override
  State<Nemaz> createState() => _NemazState();
}

class _NemazState extends State<Nemaz> {
  bool isSelect = false;
  DateTime startDateTimeFajar = DateTime.now();
  DateTime startDateTimeZohar = DateTime.now();
  DateTime startDateTimeAsar = DateTime.now();
  DateTime startDateTimeMagrib = DateTime.now();
  DateTime startDateTimeIsha = DateTime.now();

  DateTime endDateTimeFajar = DateTime.now();
  DateTime endDateTimeZohar = DateTime.now();
  DateTime endDateTimeAsar = DateTime.now();
  DateTime endDateTimeMagrib = DateTime.now();
  DateTime endDateTimeIsha = DateTime.now();

  static ValueNotifier<bool> isDataAvailable = ValueNotifier<bool>(false);

  bool? updateFajaractivation;
  bool? updateZoharactivation;
  bool? updateAsaractivation;
  bool? updateMagribactivation;
  bool? updateIshaactivation;
  bool? updateSoundMode;
  final nameController = TextEditingController();
  DateTime now = DateTime.now();
  DateTime startDateTime = DateTime.now();

  DateTime endDateTime = DateTime.now();
  // bool isTaskActivated = false;
  // bool isSilentOrVibration = false;
  // int AlarmID = Random().nextInt(0x7FFFFFFF);
  // int AlarmID2 = Random().nextInt(0x7FFFFFFF);

  var index = 0;

  late BannerAd _bannerAd;
  bool isAdLoaded = false;

  int fajarAlarmId = Random().nextInt(0x7FFFFFFF);
  int zoharAlarmId = Random().nextInt(0x7FFFFFFF);
  int asarAlarmId = Random().nextInt(0x7FFFFFFF);
  int magribAlarmId = Random().nextInt(0x7FFFFFFF);
  int ishaAlarmId = Random().nextInt(0x7FFFFFFF);

  initBannerAd() {
    var AdsIdd = 'ca-app-pub-9923979057032791/3153557586';
    _bannerAd = BannerAd(
        size: AdSize.banner,
        adUnitId: AdsIdd,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            setState(() {
              isAdLoaded = true;
            });
          },
          onAdFailedToLoad: (ad, error) {},
        ),
        request: AdRequest());
    _bannerAd.load();
  }

  @override
  void initState() {
    initBannerAd();

    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CountProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.kbg,
      body: Stack(
        children: [
          Container(
              child: ValueListenableBuilder<Box<NemazModel>>(
            valueListenable: Boxes.getDataforNemaz().listenable(),
            builder: (context, box, _) {
              if (box.length > 0) {
                // isDataAvailable.value = true;
                isDataAvailable.value = true;
                print("::if database has value${isDataAvailable.value}");
                // provider.updateHasData(box.isNotEmpty);

                return ListView.builder(
                  itemCount: box.length,
                  // reverse: true,
                  // shrinkWrap: true,
                  itemBuilder: (context, index) {
                    var data = box.values.toList().cast<NemazModel>();
                    return Container(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: InkWell(
                          onTap: () {
                            // _update(
                            //   data[index],
                            //   data[index].name.toString(),
                            //   data[index].Start.toString(),
                            //   data[index].End.toString(),
                            //   data[index].isSilentOrVibration,
                            //   data[index].isTaskActivated,
                            // );
                          },
                          onLongPress: () {
                            showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    backgroundColor: AppColors.kSecondary,
                                    title: Text("Delete"),
                                    content: Text("Are You Sure?"),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: Text("No",
                                              style: TextStyle(
                                                  color: AppColors.kPrimary))),
                                      TextButton(
                                          onPressed: () {
                                            deleteTask(data[index]);
                                            provider.updateHasData(box.isNotEmpty);
                                            AndroidAlarmManager.cancel(
                                                fajarAlarmId);
                                            AndroidAlarmManager.cancel(
                                                zoharAlarmId);
                                            AndroidAlarmManager.cancel(
                                                asarAlarmId);
                                            AndroidAlarmManager.cancel(
                                                magribAlarmId);
                                            AndroidAlarmManager.cancel(
                                                ishaAlarmId);
                                            Navigator.pop(context);
                                          },
                                          child: Text("Yes",
                                              style: TextStyle(
                                                  color: AppColors.kPrimary)))
                                    ],
                                  );
                                });
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              InkWell(
                                onTap: () {
                                  deleteTask(data[index]);
                                  provider.updateHasData(box.isNotEmpty);
                                  AndroidAlarmManager.cancel(fajarAlarmId);
                                  AndroidAlarmManager.cancel(zoharAlarmId);
                                  AndroidAlarmManager.cancel(asarAlarmId);
                                  AndroidAlarmManager.cancel(magribAlarmId);
                                  AndroidAlarmManager.cancel(ishaAlarmId);
                                },
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 0, 12, 12),
                                  child: Icon(
                                    Icons.cancel_outlined,
                                    color: AppColors.kPrimary,
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  data[index].forWhichMasjid.isNotEmpty
                                      ? Container(
                                          padding: EdgeInsets.all(8),
                                          height: 50,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: AppColors.kSecondary,
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(30)),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.mosque,
                                                color: AppColors.kPrimary,
                                              ),
                                              SizedBox(
                                                width: 8,
                                              ),
                                              Text(data[index].forWhichMasjid),
                                            ],
                                          ))
                                      : SizedBox(),
                                  SizedBox(
                                    height: 8,
                                  ),
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: AppColors.kSecondary,
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(30)),
                                    ),
                                    child: Row(
                                      children: [
                                        ImageIcon(
                                            AssetImage(
                                              'assets/images/sunrise.png',
                                            ),
                                            color: AppColors.kPrimary),
                                        SizedBox(
                                          width: 8,
                                        ),
                                        Text(
                                          'Fajar',
                                          style: TextStyle(
                                              color: AppColors.kPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        Text(
                                          "         Start:${data[index].FajarStart.hour.toString().padLeft(2, '0')}:${data[index].FajarStart.minute.toString().padLeft(2, '0')}",
                                        ),
                                        Text(
                                          "   End:${data[index].FajarEnd.hour.toString().padLeft(2, '0')}:${data[index].FajarEnd.minute.toString().padLeft(2, '0')}",
                                        ),
                                        Spacer(),
                                        Switch(
                                          value:
                                              data[index].isFajarTaskActivated,
                                          onChanged: (value) {
                                            setState(() {
                                              data[index].isFajarTaskActivated =
                                                  value;
                                            });

                                            var customStartTime = DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                                data[index].FajarStart.hour,
                                                data[index].FajarStart.minute);
                                            var customEndTime = DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                                data[index].FajarEnd.hour,
                                                data[index].FajarEnd.minute);

                                            if (data[index]
                                                        .isFajarTaskActivated ==
                                                    true &&
                                                data[index]
                                                        .isSilentOrVibration ==
                                                    false) {
                                              AndroidAlarmManager.periodic(
                                                  Duration(days: 1),
                                                  Random().nextInt(
                                                      0x7FFFFFFF),
                                                  startAt: customStartTime,
                                                  setSilentMode);
                                              print(
                                                  "at Silent mode nemaz fajar ");
                                            } else if (data[index]
                                                        .isFajarTaskActivated ==
                                                    true &&
                                                data[index]
                                                        .isSilentOrVibration ==
                                                    true) {
                                              AndroidAlarmManager.periodic(
                                                  Duration(days: 1),
                                                  Random().nextInt(
                                                      0x7FFFFFFF),
                                                  startAt: customStartTime,
                                                  setVibrateMode);
                                              print(
                                                  "at vibration mode nemaz fajar");
                                            }
                                            if (data[index]
                                                    .isFajarTaskActivated ==
                                                false) {
                                              AndroidAlarmManager.oneShot(
                                                  Duration(seconds: 0),
                                                  Random().nextInt(
                                                      0x7FFFFFFF),
                                                  setNormalMode);
                                            }

                                            print("after normal mode fajar");
                                            AndroidAlarmManager.periodic(
                                                Duration(days: 1),
                                                Random()
                                                    .nextInt(0x7FFFFFFF),
                                                startAt: customEndTime,
                                                setNormalMode);

                                            updateFajarActivation(
                                                data[index],
                                                data[index]
                                                    .isFajarTaskActivated);
                                          },
                                          activeTrackColor: Color.fromARGB(
                                              255, 133, 104, 173),
                                          activeColor: AppColors.kPrimary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 8,
                                  ),
                                  //////////////////////////////////////
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: AppColors.kSecondary,
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(30)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.wb_sunny_outlined,
                                          color: AppColors.kPrimary,
                                        ),
                                        SizedBox(
                                          width: 8,
                                        ),
                                        Text(
                                          'Zohar',
                                          style: TextStyle(
                                              color: AppColors.kPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        Text(
                                          "       Start:${data[index].ZoharStart.hour.toString().padLeft(2, '0')}:${data[index].ZoharStart.minute.toString().padLeft(2, '0')}",
                                        ),
                                        Text(
                                          "   End:${data[index].ZoharEnd.hour.toString().padLeft(2, '0')}:${data[index].ZoharEnd.minute.toString().padLeft(2, '0')}",
                                        ),
                                        Spacer(),
                                        Switch(
                                          value:
                                              data[index].isZoharTaskActivated,
                                          onChanged: (value) {
                                            setState(() {
                                              data[index].isZoharTaskActivated =
                                                  value;
                                            });

                                            var customStartTime = DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                                data[index].ZoharStart.hour,
                                                data[index].ZoharStart.minute);
                                            var customEndTime = DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                                data[index].ZoharEnd.hour,
                                                data[index].ZoharEnd.minute);

                                            if (data[index]
                                                        .isZoharTaskActivated ==
                                                    true &&
                                                data[index]
                                                        .isSilentOrVibration ==
                                                    false) {
                                              AndroidAlarmManager.periodic(
                                                  Duration(days: 1),
                                                  Random().nextInt(
                                                      0x7FFFFFFF),
                                                  startAt: customStartTime,
                                                  setSilentMode);
                                              print(
                                                  "at Silent mode nemaz zohar ");
                                            } else if (data[index]
                                                        .isZoharTaskActivated ==
                                                    true &&
                                                data[index]
                                                        .isSilentOrVibration ==
                                                    true) {
                                              AndroidAlarmManager.periodic(
                                                  Duration(days: 1),
                                                  Random().nextInt(
                                                      0x7FFFFFFF),
                                                  startAt: customStartTime,
                                                  setVibrateMode);
                                              print(
                                                  "at vibration mode nemaz zohar");
                                            }
                                            if (data[index]
                                                    .isZoharTaskActivated ==
                                                false) {
                                              AndroidAlarmManager.oneShot(
                                                  Duration(seconds: 0),
                                                  Random().nextInt(
                                                      0x7FFFFFFF),
                                                  setNormalMode);
                                            }
                                            print(
                                                "before  normal mode nemaz zohar");
                                            print("after normal mode zohar");
                                            AndroidAlarmManager.periodic(
                                                Duration(days: 1),
                                                Random()
                                                    .nextInt(0x7FFFFFFF),
                                                startAt: customEndTime,
                                                setNormalMode);

                                            updateZoharActivation(
                                                data[index],
                                                data[index]
                                                    .isZoharTaskActivated);

                                            print("NOW$now");
                                          },
                                          activeTrackColor: Color.fromARGB(
                                              255, 133, 104, 173),
                                          activeColor: AppColors.kPrimary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 8,
                                  ), //////////////////////////////////////
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: AppColors.kSecondary,
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(30)),
                                    ),
                                    child: Row(
                                      children: [
                                        ImageIcon(
                                            AssetImage(
                                              'assets/images/noon.png',
                                            ),
                                            color: AppColors.kPrimary),
                                        SizedBox(
                                          width: 8,
                                        ),
                                        Text(
                                          'Asar',
                                          style: TextStyle(
                                              color: AppColors.kPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        Text(
                                          "         Start:${data[index].AsarStart.hour.toString().padLeft(2, '0')}:${data[index].AsarStart.minute.toString().padLeft(2, '0')}",
                                        ),
                                        Text(
                                          "    End:${data[index].AsarEnd.hour.toString().padLeft(2, '0')}:${data[index].AsarEnd.minute.toString().padLeft(2, '0')}",
                                        ),
                                        Spacer(),
                                        Switch(
                                          value:
                                              data[index].isAsarTaskActivated,
                                          onChanged: (value) {
                                            setState(() {
                                              data[index].isAsarTaskActivated =
                                                  value;
                                            });
                                            var customStartTime = DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                                data[index].AsarStart.hour,
                                                data[index].AsarStart.minute);
                                            var customEndTime = DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                                data[index].AsarEnd.hour,
                                                data[index].AsarEnd.minute);

                                            if (data[index]
                                                        .isAsarTaskActivated ==
                                                    true &&
                                                data[index]
                                                        .isSilentOrVibration ==
                                                    false) {
                                              AndroidAlarmManager.periodic(
                                                  Duration(days: 1),
                                                  Random().nextInt(
                                                      0x7FFFFFFF),
                                                  startAt: customStartTime,
                                                  setSilentMode);
                                              print(
                                                  "at Silent mode nemaz asar");
                                            } else if (data[index]
                                                        .isAsarTaskActivated ==
                                                    true &&
                                                data[index]
                                                        .isSilentOrVibration ==
                                                    true) {
                                              AndroidAlarmManager.periodic(
                                                  Duration(days: 1),
                                                  Random().nextInt(
                                                      0x7FFFFFFF),
                                                  startAt: customStartTime,
                                                  setVibrateMode);
                                              print(
                                                  "at vibration mode nemaz asar");
                                            }
                                            if (data[index]
                                                    .isAsarTaskActivated ==
                                                false) {
                                              AndroidAlarmManager.oneShot(
                                                  Duration(seconds: 0),
                                                  Random().nextInt(
                                                      0x7FFFFFFF),
                                                  setNormalMode);
                                            }
                                            print(
                                                "before  normal mode nemaz asar");
                                            print("after normal mode");
                                            AndroidAlarmManager.periodic(
                                                Duration(days: 1),
                                                Random()
                                                    .nextInt(0x7FFFFFFF),
                                                startAt: customEndTime,
                                                setNormalMode);

                                            updateAsarActivation(
                                                data[index],
                                                data[index]
                                                    .isAsarTaskActivated);

                                            print("NOW$now");
                                          },
                                          activeTrackColor: Color.fromARGB(
                                              255, 133, 104, 173),
                                          activeColor: AppColors.kPrimary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 8,
                                  ),
                                  //////////////////////////////////////
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: AppColors.kSecondary,
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(30)),
                                    ),
                                    child: Row(
                                      children: [
                                        ImageIcon(
                                            AssetImage(
                                              'assets/images/magrib.png',
                                            ),
                                            color: AppColors.kPrimary),
                                        SizedBox(
                                          width: 8,
                                        ),
                                        Text(
                                          'Magrib',
                                          style: TextStyle(
                                              color: AppColors.kPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        Text(
                                          "    Start:${data[index].MagribStart.hour.toString().padLeft(2, '0')}:${data[index].MagribStart.minute.toString().padLeft(2, '0')}",
                                        ),
                                        Text(
                                          "    End:${data[index].MagribEnd.hour.toString().padLeft(2, '0')}:${data[index].MagribEnd.minute.toString().padLeft(2, '0')}",
                                        ),
                                        Spacer(),
                                        Switch(
                                          value:
                                              data[index].isMagribTaskActivated,
                                          onChanged: (value) {
                                            setState(() {
                                              data[index]
                                                      .isMagribTaskActivated =
                                                  value;
                                            });
                                            var customStartTime = DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                                data[index].MagribStart.hour,
                                                data[index].MagribStart.minute);
                                            var customEndTime = DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                                data[index].MagribEnd.hour,
                                                data[index].MagribEnd.minute);

                                            if (data[index]
                                                        .isMagribTaskActivated ==
                                                    true &&
                                                data[index]
                                                        .isSilentOrVibration ==
                                                    false) {
                                              AndroidAlarmManager.periodic(
                                                  Duration(days: 1),
                                                  Random().nextInt(
                                                      0x7FFFFFFF),
                                                  startAt: customStartTime,
                                                  setSilentMode);
                                              print(
                                                  "at Silent mode nemaz magrib");
                                            } else if (data[index]
                                                        .isMagribTaskActivated ==
                                                    true &&
                                                data[index]
                                                        .isSilentOrVibration ==
                                                    true) {
                                              AndroidAlarmManager.periodic(
                                                  Duration(days: 1),
                                                  Random().nextInt(
                                                      0x7FFFFFFF),
                                                  startAt: customStartTime,
                                                  setVibrateMode);
                                              print(
                                                  "at vibration mode nemaz magrib");
                                            }
                                            if (data[index]
                                                    .isMagribTaskActivated ==
                                                false) {
                                              AndroidAlarmManager.oneShot(
                                                  Duration(seconds: 0),
                                                  Random().nextInt(
                                                      0x7FFFFFFF),
                                                  setNormalMode);
                                            }
                                            print(
                                                "before  normal mode nemaz magrib");
                                            print("after normal mode magrib");
                                            AndroidAlarmManager.periodic(
                                                Duration(days: 1),
                                                Random()
                                                    .nextInt(0x7FFFFFFF),
                                                startAt: customEndTime,
                                                setNormalMode);

                                            updateMagribActivation(
                                                data[index],
                                                data[index]
                                                    .isMagribTaskActivated);

                                            print("NOW$now");
                                          },
                                          activeTrackColor: Color.fromARGB(
                                              255, 133, 104, 173),
                                          activeColor: AppColors.kPrimary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 8,
                                  ),
                                  //////////////////////////////////////
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: AppColors.kSecondary,
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(30)),
                                    ),
                                    child: Row(
                                      children: [
                                        ImageIcon(
                                            AssetImage(
                                              'assets/images/sleep-mode.png',
                                            ),
                                            color: AppColors.kPrimary),
                                        SizedBox(
                                          width: 8,
                                        ),
                                        Text(
                                          'Isha',
                                          style: TextStyle(
                                              color: AppColors.kPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        Text(
                                          "         Start:${data[index].IshaStart.hour.toString().padLeft(2, '0')}:${data[index].IshaStart.minute.toString().padLeft(2, '0')}",
                                        ),
                                        Text(
                                          "     End:${data[index].IshaEnd.hour.toString().padLeft(2, '0')}:${data[index].IshaEnd.minute.toString().padLeft(2, '0')}",
                                        ),
                                        Spacer(),
                                        Switch(
                                          value:
                                              data[index].isIshaTaskActivated,
                                          onChanged: (value) {
                                            setState(() {
                                              data[index].isIshaTaskActivated =
                                                  value;
                                            });
                                            var customStartTime = DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                                data[index].IshaStart.hour,
                                                data[index].IshaStart.minute);
                                            var customEndTime = DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                                data[index].IshaEnd.hour,
                                                data[index].IshaEnd.minute);

                                            if (data[index]
                                                        .isIshaTaskActivated ==
                                                    true &&
                                                data[index]
                                                        .isSilentOrVibration ==
                                                    false) {
                                              AndroidAlarmManager.periodic(
                                                  Duration(days: 1),
                                                  Random().nextInt(
                                                      0x7FFFFFFF),
                                                  startAt: customStartTime,
                                                  setSilentMode);
                                              print(
                                                  "at Silent mode nemaz isha");
                                            } else if (data[index]
                                                        .isIshaTaskActivated ==
                                                    true &&
                                                data[index]
                                                        .isSilentOrVibration ==
                                                    true) {
                                              AndroidAlarmManager.periodic(
                                                  Duration(days: 1),
                                                  Random().nextInt(
                                                      0x7FFFFFFF),
                                                  startAt: customStartTime,
                                                  setVibrateMode);
                                              print(
                                                  "at vibration mode nemaz isha");
                                            }
                                            if (data[index]
                                                    .isIshaTaskActivated ==
                                                false) {
                                              AndroidAlarmManager.oneShot(
                                                  Duration(seconds: 0),
                                                  Random().nextInt(
                                                      0x7FFFFFFF),
                                                  setNormalMode);
                                            }
                                            print(
                                                "before  normal mode nemaz isha");
                                            print(
                                                "after normal mode nemaz isha");
                                            AndroidAlarmManager.periodic(
                                                Duration(days: 1),
                                                Random()
                                                    .nextInt(0x7FFFFFFF),
                                                startAt: customEndTime,
                                                setNormalMode);

                                            updateIshaActivation(
                                                data[index],
                                                data[index]
                                                    .isIshaTaskActivated);

                                            print("NOW$now");
                                          },
                                          activeTrackColor: Color.fromARGB(
                                              255, 133, 104, 173),
                                          activeColor: AppColors.kPrimary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Divider(
                                    color: AppColors.kPrimary,
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              } else {
                // isDataAvailable.value = false;
                isDataAvailable.value = false;
                print("::if empty ${isDataAvailable.value}");
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Center(child: Lottie.asset('assets/nemaz.json')),
                );
              }
            },
          )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.kPrimary,
        child: Icon(Icons.mosque_outlined),
        onPressed: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (context) => CreateNemaz()));
        },
      ),
      bottomNavigationBar: isAdLoaded
          ? Container(
              decoration: BoxDecoration(color: Colors.transparent),
              height: _bannerAd.size.height.toDouble(),
              width: _bannerAd.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd),
            )
          : SizedBox(),
    );
  }

  void deleteTask(NemazModel nemazModel) async {
    await nemazModel.delete();
    AndroidAlarmManager.oneShot(Duration(seconds: 0), 23, setNormalMode);
    AndroidAlarmManager.oneShot(Duration(seconds: 0), 24, setNormalMode);
    AndroidAlarmManager.cancel(25);
    AndroidAlarmManager.cancel(26);
  }

  void updateFajarActivation(NemazModel nemazModel, bool activate) async {
    updateFajaractivation = activate;
    nemazModel.isFajarTaskActivated = updateFajaractivation!;
    await nemazModel.save();
  }

  void updateZoharActivation(NemazModel nemazModel, bool activate) async {
    updateZoharactivation = activate;
    nemazModel.isZoharTaskActivated = updateZoharactivation!;
    await nemazModel.save();
  }

  void updateAsarActivation(NemazModel nemazModel, bool activate) async {
    updateAsaractivation = activate;
    nemazModel.isAsarTaskActivated = updateAsaractivation!;
    await nemazModel.save();
  }

  void updateMagribActivation(NemazModel nemazModel, bool activate) async {
    updateMagribactivation = activate;
    nemazModel.isMagribTaskActivated = updateMagribactivation!;
    await nemazModel.save();
  }

  void updateIshaActivation(NemazModel nemazModel, bool activate) async {
    updateIshaactivation = activate;
    nemazModel.isIshaTaskActivated = updateIshaactivation!;
    await nemazModel.save();
  }

  void updateSilentMode(NemazModel nemazModel, bool activate) async {
    updateSoundMode = activate;
    nemazModel.isSilentOrVibration = updateSoundMode!;
    await nemazModel.save();
  }

  void updateSoundModee(NemazModel nemazModel, bool activate) async {
    updateSoundMode = activate;
    nemazModel.isSilentOrVibration = updateSoundMode!;
    await nemazModel.save();
  }

  // Future<void> _update(RepeatedModel repeatedModel, String name, String Start,
  //     String End, bool isSorV, bool isTaskActivatedd) async
  //     {
  //   var startHour = startDateTime.hour.toString().padLeft(2, '0');
  //   final startMinute = startDateTime.minute.toString().padLeft(2, '0');
  //   final endhour = endDateTime.hour.toString().padLeft(2, '0');
  //   final endminute = endDateTime.minute.toString().padLeft(2, '0');
  //   var Startt =
  //       "${startHour}:${startMinute}  ${startDateTime.day}/${startDateTime.month}/${startDateTime.year}";
  //   var endd =
  //       "${endhour}:${endminute}  ${startDateTime.day}/${startDateTime.month}/${startDateTime.year}";
  //   nameController.text = name;
  //   Startt = Start;
  //   endd = End;
  //   isSilentOrVibration = isSorV;
  //   isTaskActivated = isTaskActivatedd;
  //   return showDialog(
  //       context: context,
  //       builder: (context) {
  //         return AlertDialog(
  //           title: Text("Edit Schedule"),
  //           content: SingleChildScrollView(
  //               child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             mainAxisAlignment: MainAxisAlignment.start,
  //             children: [
  //               TextFormField(
  //                 controller: nameController,
  //                 decoration: InputDecoration(hintText: "Enter Title"),
  //               ),
  //               SizedBox(
  //                 height: 40,
  //               ),
  //               GestureDetector(
  //                 onTap: () {
  //                   pickEveryThing();
  //                 },
  //                 child: Row(
  //                   children: const [
  //                     Icon(Icons.edit_calendar),
  //                     Spacer(),
  //                     Text("Select End Date and Time"),
  //                     // "Start : ${Startt}"
  //                     // "Start Time:     ${startHour}:${startMinute}  ${startDateTime.day}/${startDateTime.month}/${startDateTime.year} "
  //                   ],
  //                 ),
  //               ),
  //               SizedBox(
  //                 height: 40,
  //               ),
  //               GestureDetector(
  //                 onTap: () {
  //                   pickEndDateAndTime();
  //                 },
  //                 child: Row(
  //                   children: const [
  //                     Icon(Icons.edit_calendar),
  //                     Spacer(),
  //                     Text("Select End Date and Time"),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           )),
  //           actions: [
  //             TextButton(
  //                 onPressed: () {
  //                   Navigator.pop(context);
  //                 },
  //                 child: Text("Cancel",
  //                     style: TextStyle(color: AppColors.kBlack))),
  //             TextButton(
  //                 onPressed: () {
  //                   repeatedModel.name = nameController.text.toString();
  //                   repeatedModel.Start = DateTime(
  //                       startDateTime.year,
  //                       startDateTime.month,
  //                       startDateTime.day,
  //                       startDateTime.hour,
  //                       startDateTime.minute);
  //                   // "${startDateTime.hour}:${startDateTime.minute}  ${startDateTime.day.toString()}/${startDateTime.month.toString()}/${startDateTime.year.toString()}";
  //                   repeatedModel.End = DateTime(
  //                     endDateTime.year,
  //                     endDateTime.month,
  //                     endDateTime.day,
  //                     endDateTime.hour,
  //                     endDateTime.minute,
  //                   );
  //                   // "${endDateTime.hour}:${endDateTime.minute}  ${endDateTime.day.toString()}/${endDateTime.month.toString()}/${endDateTime.year.toString()}";
  //                   repeatedModel.isSilentOrVibration = isSilentOrVibration;
  //                   repeatedModel.save();
  //                   if (repeatedModel.isTaskActivated == true &&
  //                       repeatedModel.isSilentOrVibration == false) {
  //                     AndroidAlarmManager.oneShotAt(
  //                         repeatedModel.Start, AlarmId, setSilentMode);
  //                     print("at Silent mode");
  //                   } else if (repeatedModel.isTaskActivated == true &&
  //                       repeatedModel.isSilentOrVibration == true) {
  //                     AndroidAlarmManager.oneShotAt(
  //                         repeatedModel.Start, AlarmId, setVibrateMode);
  //                     print("at vibration mode");
  //                   }
  //                   if (repeatedModel.isTaskActivated == false) {
  //                     AndroidAlarmManager.oneShot(
  //                         Duration(seconds: 0), AlarmId, setNormalMode);
  //                   }
  //                   print("before  normal mode");
  //                   // if(data[index].isTaskActivated== true && now == data[index].End ){
  //                   AndroidAlarmManager.oneShotAt(
  //                       repeatedModel.End, AlarmId2, setNormalMode);
  //                   // AndroidAlarmManager.cancel(AlarmId);
  //                   // }
  //                   print("after normal mode");
  //                   Navigator.pop(context);
  //                 },
  //                 child: Text(
  //                   "Ok",
  //                   style: TextStyle(color: AppColors.kBlack),
  //                 )),
  //           ],
  //         );
  //       });
  // }

  Future<void> openDoNotDisturbSettings() async {
    await PermissionHandler.openDoNotDisturbSetting();
  }

  @pragma('vm:entry-point')
  static Future<void> setSilentMode() async {
    print("Silent method Called for repeated");
    try {
      await SoundMode.setSoundMode(RingerModeStatus.silent);
    } on PlatformException {
      print('Do Not Disturb access permissions required!');
      Fluttertoast.showToast(
        msg: "Allow DND permissions from settings!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        textColor: AppColors.kPrimary,
        backgroundColor: AppColors.kSecondary,
        // fontSize: 16.0
      );
      await PermissionHandler.openDoNotDisturbSetting();
    }
  }

  @pragma('vm:entry-point')
  static Future<void> setNormalMode() async {
    print("normal mode called for repeated");
    try {
      await SoundMode.setSoundMode(RingerModeStatus.normal);
    } on PlatformException {
      print('Do Not Disturb access permissions required!');
      Fluttertoast.showToast(
        msg: "Allow DND permissions from settings!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        textColor: AppColors.kPrimary,
        backgroundColor: AppColors.kSecondary,
        // fontSize: 16.0
      );
      await PermissionHandler.openDoNotDisturbSetting();
    }
  }

  @pragma('vm:entry-point')
  static Future<void> setVibrateMode() async {
    print("vibration mode called for repeated");
    try {
      await SoundMode.setSoundMode(RingerModeStatus.vibrate);
    } on PlatformException {
      print('Do Not Disturb access permissions required!');
      Fluttertoast.showToast(
        msg: "Allow DND permissions from settings!",
        toastLength: Toast.LENGTH_LONG,
        
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        textColor: AppColors.kPrimary,
        backgroundColor: AppColors.kSecondary,
        // fontSize: 16.0
      );
      await PermissionHandler.openDoNotDisturbSetting();
    }
  }
//  static Future<void> Check() async {
//     print("Check mode called");
//   }
  // Widget BuildSheet() {
  //   final countProvider = Provider.of<CountProvider>(context, listen: false);
  //   return StatefulBuilder(builder:
  //       (BuildContext context, StateSetter setState /*You can rename this!*/) {
  //     return DraggableScrollableSheet(
  //       initialChildSize: 1,
  //       minChildSize: 0.3,
  //       maxChildSize: 1,
  //       builder: (BuildContext context, ScrollController scrollController) {
  //         return Container(
  //           child: ListView(controller: scrollController, children: [
  //             InkWell(
  //               onTap: () {
  //                 pickEveryThing("Fajar");
  //               },
  //               child: Container(
  //                 height: MediaQuery.of(context).size.height / 15,
  //                 margin: EdgeInsets.all(12),
  //                 padding: EdgeInsets.symmetric(horizontal: 20),
  //                 decoration: BoxDecoration(
  //                   color: AppColors.kcontainer,
  //                   borderRadius: BorderRadius.circular(29),
  //                 ),
  //                 child: Row(
  //                   children: [
  //                     Text("Fajar: "),
  //                     SizedBox(
  //                       width: 10,
  //                     ),
  //                     Column(
  //                       mainAxisAlignment: MainAxisAlignment.center,
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         Text(
  //                             "Start Time: ${startDateTimeFajar.hour.toString().padLeft(2, '0')}:${startDateTimeFajar.minute.toString().padLeft(2, '0')} "),
  //                         SizedBox(
  //                           height: 2,
  //                         ),
  //                       ],
  //                     ),
  //                     Spacer(),
  //                     Column(
  //                       mainAxisAlignment: MainAxisAlignment.center,
  //                       crossAxisAlignment: CrossAxisAlignment.end,
  //                       children: [
  //                         Text(
  //                             "End Time: ${endDateTimeFajar.hour.toString().padLeft(2, '0')}:${endDateTimeFajar.minute.toString().padLeft(2, '0')} "),
  //                       ],
  //                     )
  //                   ],
  //                 ),
  //               ),
  //             ),
  //             InkWell(
  //               onTap: () {
  //                 // pickStartDateAndTime();
  //                 pickEveryThing("Zohar");
  //               },
  //               child: Container(
  //                 height: MediaQuery.of(context).size.height / 15,
  //                 margin: EdgeInsets.all(12),
  //                 padding: EdgeInsets.symmetric(horizontal: 20),
  //                 decoration: BoxDecoration(
  //                   color: AppColors.kcontainer,
  //                   borderRadius: BorderRadius.circular(29),
  //                 ),
  //                 child: Row(
  //                   children: [
  //                     Text("Zohar: "),
  //                     SizedBox(
  //                       width: 10,
  //                     ),
  //                     Column(
  //                       mainAxisAlignment: MainAxisAlignment.center,
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         Text(
  //                             "Start Time: ${startDateTimeZohar.hour.toString().padLeft(2, '0')}:${startDateTimeZohar.minute.toString().padLeft(2, '0')} "),
  //                       ],
  //                     ),
  //                     Spacer(),
  //                     Column(
  //                       mainAxisAlignment: MainAxisAlignment.center,
  //                       crossAxisAlignment: CrossAxisAlignment.end,
  //                       children: [
  //                         Text(
  //                             "End Time: ${endDateTimeZohar.hour.toString().padLeft(2, '0')}:${endDateTimeZohar.minute.toString().padLeft(2, '0')} "),
  //                       ],
  //                     )
  //                   ],
  //                 ),
  //               ),
  //             ),
  //             InkWell(
  //               onTap: () {
  //                 // pickStartDateAndTime();
  //                 pickEveryThing("Asar");
  //               },
  //               child: Container(
  //                 height: MediaQuery.of(context).size.height / 15,
  //                 margin: EdgeInsets.all(12),
  //                 padding: EdgeInsets.symmetric(horizontal: 20),
  //                 decoration: BoxDecoration(
  //                   color: AppColors.kcontainer,
  //                   borderRadius: BorderRadius.circular(29),
  //                 ),
  //                 child: Row(
  //                   children: [
  //                     Text("Asar: "),
  //                     SizedBox(
  //                       width: 10,
  //                     ),
  //                     Column(
  //                       mainAxisAlignment: MainAxisAlignment.center,
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         Text(
  //                             "Start Time: ${startDateTimeAsar.hour.toString().padLeft(2, '0')}:${startDateTimeAsar.minute.toString().padLeft(2, '0')} "),
  //                       ],
  //                     ),
  //                     Spacer(),
  //                     Column(
  //                       mainAxisAlignment: MainAxisAlignment.center,
  //                       crossAxisAlignment: CrossAxisAlignment.end,
  //                       children: [
  //                         Text(
  //                             "End Time: ${endDateTimeAsar.hour.toString().padLeft(2, '0')}:${endDateTimeAsar.minute.toString().padLeft(2, '0')} "),
  //                       ],
  //                     )
  //                   ],
  //                 ),
  //               ),
  //             ),
  //             InkWell(
  //               onTap: () {
  //                 // pickStartDateAndTime();
  //                 pickEveryThing("Magrib");
  //               },
  //               child: Container(
  //                 height: MediaQuery.of(context).size.height / 15,
  //                 margin: EdgeInsets.all(12),
  //                 padding: EdgeInsets.symmetric(horizontal: 20),
  //                 decoration: BoxDecoration(
  //                   color: AppColors.kcontainer,
  //                   borderRadius: BorderRadius.circular(29),
  //                 ),
  //                 child: Row(
  //                   children: [
  //                     Text("Magrib: "),
  //                     SizedBox(
  //                       width: 10,
  //                     ),
  //                     Column(
  //                       mainAxisAlignment: MainAxisAlignment.center,
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         Text(
  //                             "Start Time: ${startDateTimeMagrib.hour.toString().padLeft(2, '0')}:${startDateTimeMagrib.minute.toString().padLeft(2, '0')} "),
  //                       ],
  //                     ),
  //                     Spacer(),
  //                     Column(
  //                       mainAxisAlignment: MainAxisAlignment.center,
  //                       crossAxisAlignment: CrossAxisAlignment.end,
  //                       children: [
  //                         Text(
  //                             "End Time: ${endDateTimeMagrib.hour.toString().padLeft(2, '0')}:${endDateTimeMagrib.minute.toString().padLeft(2, '0')} "),
  //                       ],
  //                     )
  //                   ],
  //                 ),
  //               ),
  //             ),
  //             InkWell(
  //               onTap: () {
  //                 // pickStartDateAndTime();
  //                 pickEveryThing("Isha");
  //               },
  //               child: Container(
  //                 height: MediaQuery.of(context).size.height / 15,
  //                 margin: EdgeInsets.all(12),
  //                 padding: EdgeInsets.symmetric(horizontal: 20),
  //                 decoration: BoxDecoration(
  //                   color: AppColors.kcontainer,
  //                   borderRadius: BorderRadius.circular(29),
  //                 ),
  //                 child: Row(
  //                   children: [
  //                     Text("Isha: "),
  //                     SizedBox(
  //                       width: 10,
  //                     ),
  //                     Column(
  //                       mainAxisAlignment: MainAxisAlignment.center,
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         Text(
  //                             "Start Time: ${startDateTimeIsha.hour.toString().padLeft(2, '0')}:${startDateTimeIsha.minute.toString().padLeft(2, '0')} "),
  //                       ],
  //                     ),
  //                     Spacer(),
  //                     Column(
  //                       mainAxisAlignment: MainAxisAlignment.center,
  //                       crossAxisAlignment: CrossAxisAlignment.end,
  //                       children: [
  //                         Text(
  //                             "End Time: ${endDateTimeIsha.hour.toString().padLeft(2, '0')}:${endDateTimeIsha.minute.toString().padLeft(2, '0')} "),
  //                       ],
  //                     )
  //                   ],
  //                 ),
  //               ),
  //             ),
  //             Container(
  //               height: MediaQuery.of(context).size.height / 15,
  //               margin: EdgeInsets.all(12),
  //               padding: EdgeInsets.symmetric(horizontal: 20),
  //               decoration: BoxDecoration(
  //                 color: AppColors.kcontainer,
  //                 borderRadius: BorderRadius.circular(29),
  //               ),
  //               child: Row(
  //                 children: [
  //                   Column(
  //                     mainAxisAlignment: MainAxisAlignment.center,
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Text("Silent Mode"),
  //                       SizedBox(
  //                         height: 2,
  //                       ),
  //                       Text("Phone will Automatically Silent"),
  //                     ],
  //                   ),
  //                   Spacer(),
  //                   Column(
  //                     mainAxisAlignment: MainAxisAlignment.center,
  //                     crossAxisAlignment: CrossAxisAlignment.end,
  //                     children: [
  //                       Switch(
  //                         value: !isSelect,
  //                         onChanged: (value) {
  //                           setState(() {
  //                             isSelect = !value;
  //                           });
  //                         },
  //                         activeTrackColor: Color.fromARGB(255, 133, 104, 173),
  //                         activeColor: AppColors.kBlack,
  //                       )
  //                     ],
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             Container(
  //               height: MediaQuery.of(context).size.height / 15,
  //               margin: EdgeInsets.all(12),
  //               padding: EdgeInsets.symmetric(horizontal: 20),
  //               decoration: BoxDecoration(
  //                 color: AppColors.kcontainer,
  //                 borderRadius: BorderRadius.circular(29),
  //               ),
  //               child: Row(
  //                 children: [
  //                   Column(
  //                     mainAxisAlignment: MainAxisAlignment.center,
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Text("Vibrate Mode"),
  //                       SizedBox(
  //                         height: 2,
  //                       ),
  //                       Text("Phone will Automatically Vibrate"),
  //                     ],
  //                   ),
  //                   Spacer(),
  //                   Column(
  //                     mainAxisAlignment: MainAxisAlignment.center,
  //                     crossAxisAlignment: CrossAxisAlignment.end,
  //                     children: [
  //                       Switch(
  //                         value: isSelect,
  //                         onChanged: (value) {
  //                           setState(() {
  //                             isSelect = value;
  //                             print("jiiiiiiii$isSelect");
  //                           });
  //                         },
  //                         activeTrackColor: Color.fromARGB(255, 133, 104, 173),
  //                         activeColor: AppColors.kBlack,
  //                       )
  //                     ],
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ]),
  //         );
  //       },
  //     );
  //   });
  // }

///////////////////////////////////////////////////////////////////////////////////////////////
  ///
  Future<TimeOfDay?> pickStartTime() => showTimePicker(
      // helpText: 'Select Start Time',
      context: context,
      initialTime: TimeOfDay(
          hour: startDateTimeFajar.hour, minute: startDateTimeFajar.minute));
  Future<TimeOfDay?> pickEndTime() => showTimePicker(
      // helpText: 'Select End Time',
      context: context,
      initialTime: TimeOfDay(
          hour: endDateTimeFajar.hour, minute: endDateTimeFajar.minute));

  Future<void> pickEndDateAndTime(String whichNemaz) async {
    DateTime date = DateTime.now();
    if (date == null) return;

    TimeOfDay? time = await pickEndTime();
    if (time == null) return;

    var datetime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (whichNemaz == "Fajar") {
      setState(() {
        endDateTimeFajar = datetime;
      });
    } else if (whichNemaz == "Zohar") {
      setState(() {
        endDateTimeZohar = datetime;
      });
    } else if (whichNemaz == "Asar") {
      setState(() {
        endDateTimeAsar = datetime;
      });
    } else if (whichNemaz == "Magrib") {
      setState(() {
        endDateTimeMagrib = datetime;
      });
    } else if (whichNemaz == "Isha") {
      setState(() {
        endDateTimeIsha = datetime;
      });
    }
  }

  Future<void> pickEveryThing(String whichNemaz) async {
    DateTime date = DateTime.now();
    if (date == null) return;

    TimeOfDay? time = await pickStartTime();
    if (time == null) return;

    var datetime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (whichNemaz == "Fajar") {
      setState(() {
        startDateTimeFajar = datetime;
      });
    } else if (whichNemaz == "Zohar") {
      setState(() {
        startDateTimeZohar = datetime;
      });
    } else if (whichNemaz == "Asar") {
      setState(() {
        startDateTimeAsar = datetime;
      });
    } else if (whichNemaz == "Magrib") {
      setState(() {
        startDateTimeMagrib = datetime;
      });
    } else if (whichNemaz == "Isha") {
      setState(() {
        startDateTimeIsha = datetime;
      });
    }

    pickEndDateAndTime(whichNemaz);
  }
  ///////////////////////////////////////////////
}
