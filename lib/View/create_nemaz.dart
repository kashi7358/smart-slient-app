import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:smart_silent/Provider/count_provider.dart';
import 'package:smart_silent/View/nemaz.dart';
import 'package:smart_silent/constants.dart';
import 'package:smart_silent/models/nemaz_model.dart';

import '../Boxes/boxes.dart';

class CreateNemaz extends StatefulWidget {
  CreateNemaz({super.key});

  @override
  State<CreateNemaz> createState() => _CreateNemazState();
}

class _CreateNemazState extends State<CreateNemaz> {
  // final nameController = TextEditingController();
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
  late BannerAd _bannerAd;
  bool isAdLoaded = false;

  final masjidNameController = TextEditingController();
  bool isFajarTaskActivated = false;
  bool isZoharTaskActivated = false;
  bool isAsarTaskActivated = false;
  bool isIshaTaskActivated = false;
  bool isMagribTaskActivated = false;

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
    final provider = Provider.of<CountProvider>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        title: Text("Create Prayers Schedule"),
        backgroundColor: AppColors.kSecondary,
        foregroundColor: AppColors.kPrimary,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            Container(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  children: [
                    Container(
                      margin: EdgeInsets.all(12),
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.kSecondary,
                        borderRadius: BorderRadius.circular(29),
                      ),
                      child: TextFormField(
                        controller: masjidNameController,
                        decoration: InputDecoration(
                            hintText: "Enter Task Name",
                            border: InputBorder.none),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        pickEveryThing("Fajar");
                      },
                      child: Container(
                        height: MediaQuery.of(context).size.height / 15,
                        margin: EdgeInsets.all(12),
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppColors.kSecondary,
                          borderRadius: BorderRadius.circular(29),
                        ),
                        child: Row(
                          children: [
                            Text("Fajar: "),
                            SizedBox(
                              width: 10,
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    "Start Time: ${startDateTimeFajar.hour.toString().padLeft(2, '0')}:${startDateTimeFajar.minute.toString().padLeft(2, '0')} "),
                                SizedBox(
                                  height: 2,
                                ),
                              ],
                            ),
                            Spacer(),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    "End Time: ${endDateTimeFajar.hour.toString().padLeft(2, '0')}:${endDateTimeFajar.minute.toString().padLeft(2, '0')} "),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        // pickStartDateAndTime();
                        pickEveryThing("Zohar");
                      },
                      child: Container(
                        height: MediaQuery.of(context).size.height / 15,
                        margin: EdgeInsets.all(12),
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppColors.kSecondary,
                          borderRadius: BorderRadius.circular(29),
                        ),
                        child: Row(
                          children: [
                            Text("Zohar: "),
                            SizedBox(
                              width: 10,
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    "Start Time: ${startDateTimeZohar.hour.toString().padLeft(2, '0')}:${startDateTimeZohar.minute.toString().padLeft(2, '0')} "),
                              ],
                            ),
                            Spacer(),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    "End Time: ${endDateTimeZohar.hour.toString().padLeft(2, '0')}:${endDateTimeZohar.minute.toString().padLeft(2, '0')} "),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        // pickStartDateAndTime();
                        pickEveryThing("Asar");
                      },
                      child: Container(
                        height: MediaQuery.of(context).size.height / 15,
                        margin: EdgeInsets.all(12),
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppColors.kSecondary,
                          borderRadius: BorderRadius.circular(29),
                        ),
                        child: Row(
                          children: [
                            Text("Asar: "),
                            SizedBox(
                              width: 10,
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    "Start Time: ${startDateTimeAsar.hour.toString().padLeft(2, '0')}:${startDateTimeAsar.minute.toString().padLeft(2, '0')} "),
                              ],
                            ),
                            Spacer(),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    "End Time: ${endDateTimeAsar.hour.toString().padLeft(2, '0')}:${endDateTimeAsar.minute.toString().padLeft(2, '0')} "),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        // pickStartDateAndTime();
                        pickEveryThing("Magrib");
                      },
                      child: Container(
                        height: MediaQuery.of(context).size.height / 15,
                        margin: EdgeInsets.all(12),
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppColors.kSecondary,
                          borderRadius: BorderRadius.circular(29),
                        ),
                        child: Row(
                          children: [
                            Text("Magrib: "),
                            SizedBox(
                              width: 10,
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    "Start Time: ${startDateTimeMagrib.hour.toString().padLeft(2, '0')}:${startDateTimeMagrib.minute.toString().padLeft(2, '0')} "),
                              ],
                            ),
                            Spacer(),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    "End Time: ${endDateTimeMagrib.hour.toString().padLeft(2, '0')}:${endDateTimeMagrib.minute.toString().padLeft(2, '0')} "),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        // pickStartDateAndTime();
                        pickEveryThing("Isha");
                      },
                      child: Container(
                        height: MediaQuery.of(context).size.height / 15,
                        margin: EdgeInsets.all(12),
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppColors.kSecondary,
                          borderRadius: BorderRadius.circular(29),
                        ),
                        child: Row(
                          children: [
                            Text("Isha: "),
                            SizedBox(
                              width: 10,
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    "Start Time: ${startDateTimeIsha.hour.toString().padLeft(2, '0')}:${startDateTimeIsha.minute.toString().padLeft(2, '0')} "),
                              ],
                            ),
                            Spacer(),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    "End Time: ${endDateTimeIsha.hour.toString().padLeft(2, '0')}:${endDateTimeIsha.minute.toString().padLeft(2, '0')} "),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: MediaQuery.of(context).size.height / 15,
                      margin: EdgeInsets.all(12),
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.kSecondary,
                        borderRadius: BorderRadius.circular(29),
                      ),
                      child: Row(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Silent Mode"),
                              SizedBox(
                                height: 2,
                              ),
                              Text("Phone will Automatically Silent"),
                            ],
                          ),
                          Spacer(),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Switch(
                                value: !isSelect,
                                onChanged: (value) {
                                  setState(() {
                                    isSelect = !value;
                                  });
                                },
                                activeTrackColor:
                                    Color.fromARGB(255, 133, 104, 173),
                                activeColor: AppColors.kPrimary,
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: MediaQuery.of(context).size.height / 15,
                      margin: EdgeInsets.all(12),
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.kSecondary,
                        borderRadius: BorderRadius.circular(29),
                      ),
                      child: Row(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Vibrate Mode"),
                              SizedBox(
                                height: 2,
                              ),
                              Text("Phone will Automatically Vibrate"),
                            ],
                          ),
                          Spacer(),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Switch(
                                value: isSelect,
                                onChanged: (value) {
                                  setState(() {
                                    isSelect = value;
                                    print(isSelect);
                                  });
                                },
                                activeTrackColor:
                                    Color.fromARGB(255, 133, 104, 173),
                                activeColor: AppColors.kPrimary,
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height / 10,
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    final data = NemazModel(
                      forWhichMasjid: masjidNameController.text,
                      FajarStart: DateTime(
                          startDateTimeFajar.year,
                          startDateTimeFajar.month,
                          startDateTimeFajar.day,
                          startDateTimeFajar.hour,
                          startDateTimeFajar.minute),
                      FajarEnd: DateTime(
                          endDateTimeFajar.year,
                          endDateTimeFajar.month,
                          endDateTimeFajar.day,
                          endDateTimeFajar.hour,
                          endDateTimeFajar.minute),
                      ZoharStart: DateTime(
                          startDateTimeZohar.year,
                          startDateTimeZohar.month,
                          startDateTimeZohar.day,
                          startDateTimeZohar.hour,
                          startDateTimeZohar.minute),
                      ZoharEnd: DateTime(
                          endDateTimeZohar.year,
                          endDateTimeZohar.month,
                          endDateTimeZohar.day,
                          endDateTimeZohar.hour,
                          endDateTimeZohar.minute),
                      AsarStart: DateTime(
                          startDateTimeAsar.year,
                          startDateTimeAsar.month,
                          startDateTimeAsar.day,
                          startDateTimeAsar.hour,
                          startDateTimeAsar.minute),
                      AsarEnd: DateTime(
                          endDateTimeAsar.year,
                          endDateTimeAsar.month,
                          endDateTimeAsar.day,
                          endDateTimeAsar.hour,
                          endDateTimeAsar.minute),
                      MagribStart: DateTime(
                          startDateTimeMagrib.year,
                          startDateTimeMagrib.month,
                          startDateTimeMagrib.day,
                          startDateTimeMagrib.hour,
                          startDateTimeMagrib.minute),
                      MagribEnd: DateTime(
                          endDateTimeMagrib.year,
                          endDateTimeMagrib.month,
                          endDateTimeMagrib.day,
                          endDateTimeMagrib.hour,
                          endDateTimeMagrib.minute),
                      IshaStart: DateTime(
                          startDateTimeIsha.year,
                          startDateTimeIsha.month,
                          startDateTimeIsha.day,
                          startDateTimeIsha.hour,
                          startDateTimeIsha.minute),
                      IshaEnd: DateTime(
                          endDateTimeIsha.year,
                          endDateTimeIsha.month,
                          endDateTimeIsha.day,
                          endDateTimeIsha.hour,
                          endDateTimeIsha.minute),
                      isSilentOrVibration: isSelect,
                      isFajarTaskActivated: isFajarTaskActivated,
                      isZoharTaskActivated: isZoharTaskActivated,
                      isAsarTaskActivated: isAsarTaskActivated,
                      isMagribTaskActivated: isMagribTaskActivated,
                      isIshaTaskActivated: isIshaTaskActivated,
                    );

                    final box = Boxes.getDataforNemaz();
                    box.add(data);
                    provider.updateHasData(box.isNotEmpty);

                    masjidNameController.clear();

                    Navigator.of(context).pop();
                    // Navigator.of(context).pushReplacement(
                    //     MaterialPageRoute(builder: (context) => Nemaz()));
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width / 1.4,
                    height: MediaQuery.of(context).size.height / 15,
                    decoration: BoxDecoration(
                        color: AppColors.kPrimary,
                        borderRadius: BorderRadius.circular(29)),
                    child: Center(
                        child: Text(
                      "SAVE",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.kbg),
                    )),
                  ),
                ),
              ),
            )
          ],
        ),
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

///////////////////////////////////////////////////////////////////////////////////////////////
  ///
  Future<TimeOfDay?> pickStartTime() => showTimePicker(
      helpText: 'Select Start Time',
      context: context,
      initialTime: TimeOfDay(
          hour: startDateTimeFajar.hour, minute: startDateTimeFajar.minute));
  Future<TimeOfDay?> pickEndTime() => showTimePicker(
      helpText: 'Select End Time',
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
