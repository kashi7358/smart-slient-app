import 'package:day_picker/day_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:smart_silent/constants.dart';
import 'package:smart_silent/models/repeated_model.dart';

import '../Boxes/boxes.dart';

class CreateDaily extends StatefulWidget {
  CreateDaily({super.key});

  @override
  State<CreateDaily> createState() => _CreateDailyState();
}

class _CreateDailyState extends State<CreateDaily> {
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
    print("khan${startDateTime}");
    initBannerAd();
    // TODO: implement initState
    super.initState();
  }

  List<int> SelectedDays = List.empty(growable: true);

  List<DayInWeek> _days = [
    DayInWeek(
      "Mon",
    ),
    DayInWeek(
      "Tue",
    ),
    DayInWeek(
      "Wed",
    ),
    DayInWeek(
      "Thur",
    ),
    DayInWeek(
      "Fri",
    ),
    DayInWeek("Sat"),
    DayInWeek("Sun"),
  ];

  List<String> SelectedDaysIn = List.empty(growable: true);

  @override
  Widget build(BuildContext context) {
    final startHour = startDateTime.hour.toString().padLeft(2, '0');
    final startMinute = startDateTime.minute.toString().padLeft(2, '0');

    final endhour = endDateTime.hour.toString().padLeft(2, '0');
    final endminute = endDateTime.minute.toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text("Create Daily Schedule"),
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
                    onTap: () async {
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
                              Text("Start Time: ${startHour}:$startMinute"),
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
                  InkWell(
                    onTap: () async {
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
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SelectWeekDays(
                      // fontSize: 14,
                      unSelectedDayTextColor: Colors.black,
                      fontWeight: FontWeight.w500,
                      days: _days,
                      daysFillColor:  AppColors.kPrimary,
                      selectedDayTextColor: AppColors.kbg,
                     
                      border: false,
                      boxDecoration: BoxDecoration(
                        color: AppColors.kSecondary,
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      onSelect: (values) {
                        print("my values: ${values}");
                        SelectedDaysIn = values;
                        // setState(() {
                        //   string = values;
                        // });
                        print(":::${SelectedDaysIn}");
                      },
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
                padding: const EdgeInsets.only(bottom: 12.0),
                child: GestureDetector(
                  onTap: () {
                    /////////////////

                    for (var i = 0; i < SelectedDaysIn.length; i++) {
                      switch (SelectedDaysIn[i]) {
                        case "Sun":
                          SelectedDays.add(0);
                          break;
                        case "Mon":
                          SelectedDays.add(1);
                          break;
                        case "Tue":
                          SelectedDays.add(2);
                          break;
                        case "Wed":
                          SelectedDays.add(3);
                          break;
                        case "Thur":
                          SelectedDays.add(4);
                          break;
                        case "Fri":
                          SelectedDays.add(5);
                          break;
                        case "Sat":
                          SelectedDays.add(6);
                          break;
                        default:
                          break;
                      }
                      //SelectedDays.add(i);
                      //print("Index : ${SelectedDays[i]}");
                    }

                    for (var i = 0; i < SelectedDays.length; i++) {
                      print("Index : ${SelectedDays[i]}");
                    }

                    /////////////////////

                    final data = RepeatedModel(
                      name: nameController.text.isEmpty
                          ? "Daily"
                          : nameController.text,
                      Start: DateTime(startDateTime.year, startDateTime.month, startDateTime.day, startDateTime.hour, startDateTime.minute),
                      End: DateTime(endDateTime.year, endDateTime.month, endDateTime.day, endDateTime.hour, endDateTime.minute),
                      isSilentOrVibration: isSelect,
                      isTaskActivated: isTaskActivated,
                      dayInWeek: SelectedDays
                    );
                    final box = Boxes.getDataforDaily();
                    box.add(data);
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
    DateTime? date = DateTime.now();
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
    DateTime? date = DateTime.now();
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
