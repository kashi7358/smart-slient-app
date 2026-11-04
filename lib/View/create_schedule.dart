import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:smart_silent/Provider/count_provider.dart';
import 'package:smart_silent/constants.dart';
import 'package:smart_silent/models/schedule_model.dart';

import '../Boxes/boxes.dart';

class CreateSchedule extends StatefulWidget {
  CreateSchedule({super.key});

  @override
  State<CreateSchedule> createState() => _CreateScheduleState();
}

class _CreateScheduleState extends State<CreateSchedule> {
  final nameController = TextEditingController();
  bool isSelect = false;
  DateTime startDateTime = DateTime.now();
  DateTime endDateTime = DateTime.now();
  bool isTaskActivated = false;
  late BannerAd _bannerAd;
  bool isAdLoaded = false;


  
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

    final startHour = startDateTime.hour.toString().padLeft(2, '0');
    final startMinute = startDateTime.minute.toString().padLeft(2, '0');

    final endhour = endDateTime.hour.toString().padLeft(2, '0');
    final endminute = endDateTime.minute.toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text("Create New"),
        backgroundColor: AppColors.kSecondary,
        foregroundColor: AppColors.kPrimary,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            Container(
              child: ListView(
                children: [
                  Container(
                    margin: EdgeInsets.all(12),
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.kSecondary,
                      borderRadius: BorderRadius.circular(29),
                    ),
                    child: TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                          hintText: "Enter Task Name",
                          border: InputBorder.none),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      // pickStartDateAndTime();
                      pickEveryThing();
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
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Start Time: ${startHour}:${startMinute} "),
                              SizedBox(
                                height: 2,
                              ),
                              Text(
                                  "Start Date: ${startDateTime.day}/${startDateTime.month}/${startDateTime.year}"),
                            ],
                          ),
                          Spacer(),
                          InkWell(
                            onTap: () {
                              pickStartDateAndTime();
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Icon(
                                  Icons.alarm_add,
                                  color: AppColors.kPrimary,
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      pickEndDateAndTime();
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
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("End Time: ${endhour}:${endminute} "),
                              SizedBox(
                                height: 2,
                              ),
                              Text(
                                  "End Date: ${endDateTime.day}/${endDateTime.month}/${endDateTime.year}"),
                            ],
                          ),
                          Spacer(),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.alarm_add,
                                color: AppColors.kPrimary,
                              )
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
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    final data = ScheduleModel(
                        name: nameController.text.isEmpty?"One Time":nameController.text,
                        Start: DateTime(
                            startDateTime.year,
                            startDateTime.month,
                            startDateTime.day,
                            startDateTime.hour,
                            startDateTime.minute),
                        // "${startDateTime.year}-${startDateTime.month}-${startDateTime.day} ${startHour}:${startMinute}",

                        End: DateTime(
                            endDateTime.year,
                            endDateTime.month,
                            endDateTime.day,
                            endDateTime.hour,
                            endDateTime.minute),
                        // "${endDateTime.year}-${endDateTime.month}-${endDateTime.day} ${endhour}:${endminute}",

                        isSilentOrVibration: isSelect,
                        isTaskActivated: isTaskActivated,
                        quickTime: 0);
                    final box = Boxes.getData();
                    box.add(data);
                    provider.updateHasData(box.isNotEmpty);

                    nameController.clear();
                    Navigator.of(context).pop();
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

  Future<DateTime?> pickStartDate() => showDatePicker(
    helpText: 'Select Start Date',
      context: context,
      initialDate: startDateTime,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100));

  Future<TimeOfDay?> pickStartTime() => showTimePicker(
    helpText: 'Select Start Time',

      context: context,
      initialTime:
          TimeOfDay(hour: startDateTime.hour, minute: startDateTime.minute));

  Future<void> pickEveryThing() async {
    DateTime? date = await pickStartDate();
    if (date == null) return;

    TimeOfDay? time = await pickStartTime();
    if (time == null) return;

    var datetime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      startDateTime = datetime;
    });
    pickEndDateAndTime();
  }

  Future<void> pickStartDateAndTime() async {
    DateTime? date = await pickStartDate();
    if (date == null) return;

    TimeOfDay? time = await pickStartTime();
    if (time == null) return;

    var datetime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      startDateTime = datetime;
    });
  }

  // ENd time and date Code

  Future<DateTime?> pickEndDate() => showDatePicker(
        helpText: 'Select End Date',

      context: context,
      initialDate: endDateTime,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100));

  Future<TimeOfDay?> pickEndTime() => showTimePicker(
        helpText: 'Select End Time',

      context: context,
      initialTime:
          TimeOfDay(hour: endDateTime.hour, minute: endDateTime.minute));

  Future<void> pickEndDateAndTime() async {
    DateTime? date = await pickEndDate();
    if (date == null) return;

    TimeOfDay? time = await pickEndTime();
    if (time == null) return;

    var datetime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      endDateTime = datetime;
    });
  }
}
