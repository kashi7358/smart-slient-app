// import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:lottie/lottie.dart';
// import 'package:provider/provider.dart';
// import 'package:smart_silent/Boxes/boxes.dart';
// import 'package:smart_silent/Provider/count_provider.dart';
// import 'package:smart_silent/View/meetings.dart';
// import 'package:smart_silent/models/schedule_model.dart';
// import 'package:sound_mode/permission_handler.dart';
// import 'package:sound_mode/sound_mode.dart';
// import 'package:sound_mode/utils/ringer_mode_statuses.dart';

// import '../constants.dart';

// class HomePage extends StatefulWidget {
//   const HomePage({super.key});

//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   static RingerModeStatus _soundMode = RingerModeStatus.unknown;
//   static ValueNotifier<bool> isDataAvailable = ValueNotifier<bool>(false);

//   bool? updateactivation;
//   bool? updateSoundMode;
//   final nameController = TextEditingController();
//   DateTime startDateTime = DateTime.now();
//   DateTime now = DateTime.now();
//   DateTime endDateTime = DateTime.now();
//   bool isTaskActivated = false;
//   bool isSilentOrVibration = false;
//   int AlarmId = 1;
//   int AlarmId2 = 2;
//   var index = 0;

//   late BannerAd _bannerAd;
//   bool isAdLoaded = false;
//   initBannerAd() {
//     var AdsIdd = 'ca-app-pub-9923979057032791/3153557586';
//     _bannerAd = BannerAd(
//         size: AdSize.banner,
//         adUnitId: AdsIdd,
//         listener: BannerAdListener(
//           onAdLoaded: (ad) {
//             setState(() {
//               isAdLoaded = true;
//             });
//           },
//           onAdFailedToLoad: (ad, error) {},
//         ),
//         request: AdRequest());
//     _bannerAd.load();
//   }

//   @override
//   void initState() {
//     initBannerAd();

//     // TODO: implement initState
//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final provider = Provider.of<CountProvider>(context);

//     return Scaffold(
//       backgroundColor: AppColors.kbg,
//       body: Stack(
//         children: [
//           Container(
//               child: ValueListenableBuilder<Box<ScheduleModel>>(
//             valueListenable: Boxes.getData().listenable(),
//             builder: (context, box, _) {
//               if (box.length > 0) {
//                 // isDataAvailable.value = true;
//                 isDataAvailable.value = true;
//                 print("::if database has value${isDataAvailable.value}");
//                 // provider.updateHasData(box.isNotEmpty);

//                 return ListView.builder(
//                   itemCount: box.length,
//                   // reverse: true,
//                   // shrinkWrap: true,
//                   itemBuilder: (context, index) {
//                     var data = box.values.toList().cast<ScheduleModel>();
//                     return Card(
//                       child: Padding(
//                         padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
//                         child: InkWell(
//                           onTap: () {
//                             _update(
//                               data[index],
//                               data[index].name.toString(),
//                               data[index].Start.toString(),
//                               data[index].End.toString(),
//                               data[index].isSilentOrVibration,
//                               data[index].isTaskActivated,
//                             );
//                           },
//                           onLongPress: () {
//                             showDialog(
//                                 context: context,
//                                 builder: (BuildContext context) {
//                                   return AlertDialog(
//                                     backgroundColor: AppColors.kSecondary,
//                                     title: Text("Delete"),
//                                     content: Text("Are You Sure?"),
//                                     actions: [
//                                       TextButton(
//                                           onPressed: () {
//                                             Navigator.pop(context);
//                                           },
//                                           child: Text("No",
//                                               style: TextStyle(
//                                                   color: AppColors.kPrimary))),
//                                       TextButton(
//                                           onPressed: () {
//                                             deleteTask(data[index]);
//                                             if (data.length < 0) {
//                                               provider
//                                                   .updateHasData(box.isEmpty);
//                                             } else {
//                                               provider.updateHasData(
//                                                   box.isNotEmpty);
//                                             }
//                                             AndroidAlarmManager.cancel(AlarmId);
//                                             AndroidAlarmManager.cancel(
//                                                 AlarmId2);
//                                             Navigator.pop(context);
//                                           },
//                                           child: Text("Yes",
//                                               style: TextStyle(
//                                                   color: AppColors.kPrimary)))
//                                     ],
//                                   );
//                                 });
//                           },
//                           child: Row(
//                             children: [
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 mainAxisAlignment: MainAxisAlignment.start,
//                                 children: [
//                                   SizedBox(
//                                     height:
//                                         MediaQuery.of(context).size.height / 30,
//                                   ),
//                                   Row(
//                                     children: [
//                                       Icon(Icons.share_arrival_time_outlined),
//                                       SizedBox(
//                                         width: 8,
//                                       ),
//                                       SingleChildScrollView(
//                                           scrollDirection: Axis.horizontal,
//                                           child: Text(
//                                               data[index].name.toString())),
//                                     ],
//                                   ),
//                                   SizedBox(
//                                     height: 8,
//                                   ),
//                                   Text(
//                                     "Start: ${data[index].Start.hour.toString().padLeft(2, '0')}:${data[index].Start.minute.toString().padLeft(2, '0')}  ${data[index].Start.day.toString()}/${data[index].Start.month.toString()}/${data[index].Start.year.toString()}",
//                                     style: TextStyle(
//                                         color: AppColors.kPrimary,
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 16),
//                                   ),
//                                   SizedBox(
//                                     height: 4,
//                                   ),
//                                   Text(
//                                     "End:   ${data[index].End.hour.toString().padLeft(2, '0')}:${data[index].End.minute.toString().padLeft(2, '0')}  ${data[index].End.day.toString()}/${data[index].End.month.toString()}/${data[index].End.year.toString()}",
//                                     style: TextStyle(
//                                         color: AppColors.kPrimary,
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 16),
//                                   ),
//                                 ],
//                               ),
//                               Spacer(),
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.end,
//                                 mainAxisAlignment: MainAxisAlignment.end,
//                                 children: [
//                                   PopupMenuButton<int>(
//                                     onSelected: (value) {
//                                       if (value == 1) {
//                                         deleteTask(data[index]);
//                                         if (data.length < 0) {
//                                           provider.updateHasData(box.isEmpty);
//                                         } else {
//                                           provider
//                                               .updateHasData(box.isNotEmpty);
//                                         }
//                                         AndroidAlarmManager.cancel(AlarmId);
//                                         AndroidAlarmManager.cancel(AlarmId2);
//                                       } else if (value == 2) {
//                                         _update(
//                                           data[index],
//                                           data[index].name.toString(),
//                                           data[index].Start.toString(),
//                                           data[index].End.toString(),
//                                           data[index].isSilentOrVibration,
//                                           data[index].isTaskActivated,
//                                         );
//                                       }
//                                     },
//                                     itemBuilder: (context) => [
//                                       PopupMenuItem(
//                                         value: 1,
//                                         child: Text(
//                                           "Delete",
//                                           style: TextStyle(
//                                               color: AppColors.kPrimary),
//                                         ),
//                                       ),
//                                       PopupMenuItem(
//                                         value: 2,
//                                         child: Text(
//                                           "Update",
//                                           style: TextStyle(
//                                               color: AppColors.kPrimary),
//                                         ),
//                                       ),
//                                     ],
//                                     color: AppColors.kSecondary,
//                                     child: const Icon(Icons.more_vert),
//                                   ),
                                  
//                                   SizedBox(
//                                     height:
//                                         MediaQuery.of(context).size.height / 70,
//                                   ),
//                                   Switch(
//                                     value: data[index].isTaskActivated,
//                                     onChanged: (value) {
//                                       setState(() {
//                                         data[index].isTaskActivated = value;
//                                       });

//                                       if (data[index].isTaskActivated == true &&
//                                           data[index].isSilentOrVibration ==
//                                               false) {
//                                         AndroidAlarmManager.oneShotAt(
//                                             data[index].Start,
//                                             AlarmId,
//                                             setSilentMode);
//                                         print("at Silent mode");
//                                       } else if (data[index].isTaskActivated ==
//                                               true &&
//                                           data[index].isSilentOrVibration ==
//                                               true) {
//                                         AndroidAlarmManager.oneShotAt(
//                                             data[index].Start,
//                                             AlarmId,
//                                             setVibrateMode);
//                                         print("at vibration mode");
//                                       }
//                                       if (data[index].isTaskActivated ==
//                                           false) {
//                                         AndroidAlarmManager.oneShot(
//                                             Duration(seconds: 0),
//                                             AlarmId,
//                                             setNormalMode);
//                                       }
//                                       print("before  normal mode");
//                                       // if(data[index].isTaskActivated== true && now == data[index].End ){
//                                       AndroidAlarmManager.oneShotAt(
//                                           data[index].End,
//                                           AlarmId2,
//                                           setNormalMode);
//                                       // AndroidAlarmManager.cancel(AlarmId);
//                                       // }
//                                       print("after normal mode");

//                                       updateActivation(data[index],
//                                           data[index].isTaskActivated);

//                                       //to delete
//                                       AndroidAlarmManager.oneShotAt(
//                                           data[index].End,
//                                           AlarmId2,
//                                           setNormalMode);
//                                     },
//                                     activeTrackColor:
//                                         Color.fromARGB(255, 133, 104, 173),
//                                     activeColor: AppColors.kPrimary,
//                                   ),
//                                   Text(data[index].isTaskActivated
//                                       ? "Activated"
//                                       : "Deactivated")
//                                 ],
//                               )
//                             ],
//                           ),
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               } else {
//                 // isDataAvailable.value = false;
//                 isDataAvailable.value = false;
//                 print("::if empty ${isDataAvailable.value}");
//                 return Padding(
//                   padding: const EdgeInsets.all(12.0),
//                   child: Center(child: Lottie.asset('assets/lottie.json')),
//                 );
//               }
//               // print("if database has anything${isDataAvailable.value}");
// // return Container();
//             },
//           )),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         backgroundColor: AppColors.kPrimary,
//         onPressed: () {
//           // Navigator.push(
//           //   context,
//           //   MaterialPageRoute(
//           //       builder: (context) => CreateSchedule(
//           //             update: false,
//           //           )),
//           // );
//           showModalBottomSheet(
//               shape: RoundedRectangleBorder(
//                   borderRadius:
//                       BorderRadius.vertical(top: Radius.circular(25))),
//               context: context,
//               builder: (context) => BuildSheet());
//         },
//         child: Icon(
//           Icons.add,
//         ),
//       ),
//       floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
//       bottomNavigationBar: FittedBox(
//         fit: BoxFit.fill,
//         child: Container(
//           alignment: Alignment.bottomCenter,
//           height: isAdLoaded
//               ? _bannerAd.size.height.toDouble() +
//                   MediaQuery.of(context).size.height / 7.5
        
//               : MediaQuery.of(context).size.height / 7.5,
//           padding: EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: AppColors.kSecondary,
//             borderRadius: BorderRadius.only(
//                 topLeft: Radius.circular(30), topRight: Radius.circular(30)),
//           ),
//           child: SingleChildScrollView(
//             scrollDirection: Axis.vertical,
//             child: Column(
//               children: [
//                 Row(
//                   children: [
//                     Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: Text("Quick Silent",
//                             style: TextStyle(
//                               color: Colors.black,
//                             )))
//                   ],
//                 ),
//                 SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: Row(
//                     children: [
//                       InkWell(
//                         onTap: () {
//                           DateTime endTimeAddittion = DateTime.now();
//                           var data = ScheduleModel(
//                               name: "Quick 5m",
//                               Start: DateTime.now(),
//                               End: DateTime(
//                                   endTimeAddittion.year,
//                                   endTimeAddittion.month,
//                                   endTimeAddittion.day,
//                                   endTimeAddittion.hour,
//                                   endTimeAddittion.minute + 5),
//                               isSilentOrVibration: isSilentOrVibration,
//                               isTaskActivated: true,
//                               quickTime: 5);
//                           final box = Boxes.getData();
//                           box.add(data);
//                           provider.updateHasData(box.isNotEmpty);
      
//                           AndroidAlarmManager.oneShotAt(
//                               data.Start, AlarmId, setSilentMode);
//                           print("at Silent mode");
//                           print("before  normal mode");
//                           AndroidAlarmManager.oneShotAt(
//                               data.End, AlarmId2, setNormalMode);
//                           print("after normal mode");
//                         },
//                         child: Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Center(
//                             child: Container(
//                                 padding: EdgeInsets.all(8),
//                                 decoration: BoxDecoration(
//                                   color: AppColors.kPrimary,
//                                   borderRadius: BorderRadius.all(
//                                     Radius.circular(30),
//                                   ),
//                                 ),
//                                 child: Text("5 min",
//                                     style: TextStyle(color: AppColors.kbg))),
//                           ),
//                         ),
//                       ),
//                       InkWell(
//                         onTap: () {
//                           DateTime endTimeAddittion = DateTime.now();
//                           var data = ScheduleModel(
//                               name: "Quick 10m",
//                               Start: DateTime.now(),
//                               End: DateTime(
//                                   endTimeAddittion.year,
//                                   endTimeAddittion.month,
//                                   endTimeAddittion.day,
//                                   endTimeAddittion.hour,
//                                   endTimeAddittion.minute + 10),
//                               isSilentOrVibration: isSilentOrVibration,
//                               isTaskActivated: true,
//                               quickTime: 5);
//                           final box = Boxes.getData();
//                           box.add(data);
//                           provider.updateHasData(box.isNotEmpty);
      
//                           AndroidAlarmManager.oneShotAt(
//                               data.Start, AlarmId, setSilentMode);
//                           print("at Silent mode");
//                           print("before  normal mode");
//                           AndroidAlarmManager.oneShotAt(
//                               data.End, AlarmId2, setNormalMode);
//                           print("after normal mode");
//                         },
//                         child: Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Center(
//                             child: Container(
//                                 padding: EdgeInsets.all(8),
//                                 decoration: BoxDecoration(
//                                   color: AppColors.kPrimary,
//                                   borderRadius: BorderRadius.all(
//                                     Radius.circular(30),
//                                   ),
//                                 ),
//                                 child: Text("10 min",
//                                     style: TextStyle(color: AppColors.kbg))),
//                           ),
//                         ),
//                       ),
//                       InkWell(
//                         onTap: () {
//                           DateTime endTimeAddittion = DateTime.now();
//                           var data = ScheduleModel(
//                               name: "Quick 30m",
//                               Start: DateTime.now(),
//                               End: DateTime(
//                                   endTimeAddittion.year,
//                                   endTimeAddittion.month,
//                                   endTimeAddittion.day,
//                                   endTimeAddittion.hour,
//                                   endTimeAddittion.minute + 30),
//                               isSilentOrVibration: isSilentOrVibration,
//                               isTaskActivated: true,
//                               quickTime: 5);
//                           final box = Boxes.getData();
//                           box.add(data);
//                           provider.updateHasData(box.isNotEmpty);
      
//                           AndroidAlarmManager.oneShotAt(
//                               data.Start, AlarmId, setSilentMode);
//                           print("at Silent mode");
//                           print("before  normal mode");
//                           AndroidAlarmManager.oneShotAt(
//                               data.End, AlarmId2, setNormalMode);
//                           print("after normal mode");
//                         },
//                         child: Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Center(
//                             child: Container(
//                                 padding: EdgeInsets.all(8),
//                                 decoration: BoxDecoration(
//                                   color: AppColors.kPrimary,
//                                   borderRadius: BorderRadius.all(
//                                     Radius.circular(30),
//                                   ),
//                                 ),
//                                 child: Text("30 min",
//                                     style: TextStyle(color: AppColors.kbg))),
//                           ),
//                         ),
//                       ),
//                       InkWell(
//                         onTap: () {
//                           DateTime endTimeAddittion = DateTime.now();
//                           var data = ScheduleModel(
//                               name: "Quick 1 hour",
//                               Start: DateTime.now(),
//                               End: DateTime(
//                                   endTimeAddittion.year,
//                                   endTimeAddittion.month,
//                                   endTimeAddittion.day,
//                                   endTimeAddittion.hour,
//                                   endTimeAddittion.minute + 60),
//                               isSilentOrVibration: isSilentOrVibration,
//                               isTaskActivated: true,
//                               quickTime: 5);
//                           final box = Boxes.getData();
//                           box.add(data);
//                           provider.updateHasData(box.isNotEmpty);
      
//                           AndroidAlarmManager.oneShotAt(
//                               data.Start, AlarmId, setSilentMode);
//                           print("at Silent mode");
//                           print("before  normal mode");
//                           AndroidAlarmManager.oneShotAt(
//                               data.End, AlarmId2, setNormalMode);
//                           print("after normal mode");
//                         },
//                         child: Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Center(
//                             child: Container(
//                                 padding: EdgeInsets.all(8),
//                                 decoration: BoxDecoration(
//                                   color: AppColors.kPrimary,
//                                   borderRadius: BorderRadius.all(
//                                     Radius.circular(30),
//                                   ),
//                                 ),
//                                 child: Text("1 hour",
//                                     style: TextStyle(color: AppColors.kbg))),
//                           ),
//                         ),
//                       ),
//                       InkWell(
//                         onTap: () {
//                           DateTime endTimeAddittion = DateTime.now();
//                           var data = ScheduleModel(
//                               name: "Quick 2 hours",
//                               Start: DateTime.now(),
//                               End: DateTime(
//                                   endTimeAddittion.year,
//                                   endTimeAddittion.month,
//                                   endTimeAddittion.day,
//                                   endTimeAddittion.hour,
//                                   endTimeAddittion.minute + 120),
//                               isSilentOrVibration: isSilentOrVibration,
//                               isTaskActivated: true,
//                               quickTime: 5);
//                           final box = Boxes.getData();
//                           box.add(data);
//                           provider.updateHasData(box.isNotEmpty);
      
//                           AndroidAlarmManager.oneShotAt(
//                               data.Start, AlarmId, setSilentMode);
//                           print("at Silent mode");
//                           print("before  normal mode");
//                           AndroidAlarmManager.oneShotAt(
//                               data.End, AlarmId2, setNormalMode);
//                           print("after normal mode");
//                         },
//                         child: Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Center(
//                             child: Container(
//                                 padding: EdgeInsets.all(8),
//                                 decoration: BoxDecoration(
//                                   color: AppColors.kPrimary,
//                                   borderRadius: BorderRadius.all(
//                                     Radius.circular(30),
//                                   ),
//                                 ),
//                                 child: Text("2 hours",
//                                     style: TextStyle(color: AppColors.kbg))),
//                           ),
//                         ),
//                       ),
//                       InkWell(
//                         onTap: () {
//                           DateTime endTimeAddittion = DateTime.now();
//                           var data = ScheduleModel(
//                               name: "Quick 3 hours",
//                               Start: DateTime.now(),
//                               End: DateTime(
//                                   endTimeAddittion.year,
//                                   endTimeAddittion.month,
//                                   endTimeAddittion.day,
//                                   endTimeAddittion.hour,
//                                   endTimeAddittion.minute + 180),
//                               isSilentOrVibration: isSilentOrVibration,
//                               isTaskActivated: true,
//                               quickTime: 5);
//                           final box = Boxes.getData();
//                           box.add(data);
//                           provider.updateHasData(box.isNotEmpty);
      
//                           AndroidAlarmManager.oneShotAt(
//                               data.Start, AlarmId, setSilentMode);
//                           print("at Silent mode");
//                           print("before  normal mode");
//                           AndroidAlarmManager.oneShotAt(
//                               data.End, AlarmId2, setNormalMode);
//                           print("after normal mode");
//                         },
//                         child: Padding(
//                           padding: const EdgeInsets.all(6.0),
//                           child: Center(
//                             child: Container(
//                                 padding: EdgeInsets.all(8),
//                                 decoration: BoxDecoration(
//                                   color: AppColors.kPrimary,
//                                   borderRadius: BorderRadius.all(
//                                     Radius.circular(30),
//                                   ),
//                                 ),
//                                 child: Text("3 hours",
//                                     style: TextStyle(color: AppColors.kbg))),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Row(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     isAdLoaded
//                         ? Container(
//                             decoration: BoxDecoration(color: Colors.transparent),
//                             height: _bannerAd.size.height.toDouble(),
//                             width: _bannerAd.size.width.toDouble(),
//                             child: AdWidget(ad: _bannerAd),
//                           )
//                         : SizedBox(),
//                   ],
//                 )
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   void deleteTask(ScheduleModel scheduleModel) async {
//     await scheduleModel.delete();
//     AndroidAlarmManager.oneShot(Duration(seconds: 0), AlarmId2, setNormalMode);
//     AndroidAlarmManager.oneShot(Duration(seconds: 0), AlarmId, setNormalMode);
//     AndroidAlarmManager.cancel(AlarmId);
//     AndroidAlarmManager.cancel(AlarmId2);
//   }

//   void updateActivation(ScheduleModel scheduleModel, bool activate) async {
//     updateactivation = activate;
//     scheduleModel.isTaskActivated = updateactivation!;
//     await scheduleModel.save();
//   }

//   void updateSilentMode(ScheduleModel scheduleModel, bool activate) async {
//     updateSoundMode = activate;
//     scheduleModel.isSilentOrVibration = updateSoundMode!;
//     await scheduleModel.save();
//   }

//   void updateSoundModee(ScheduleModel scheduleModel, bool activate) async {
//     updateSoundMode = activate;
//     scheduleModel.isSilentOrVibration = updateSoundMode!;
//     await scheduleModel.save();
//   }

//   Future<void> _update(ScheduleModel scheduleModel, String name, String Start,
//       String End, bool isSorV, bool isTaskActivatedd) async {
//     var startHour = startDateTime.hour.toString().padLeft(2, '0');
//     final startMinute = startDateTime.minute.toString().padLeft(2, '0');
//     final endhour = endDateTime.hour.toString().padLeft(2, '0');
//     final endminute = endDateTime.minute.toString().padLeft(2, '0');
//     var Startt =
//         "${startHour}:${startMinute}  ${startDateTime.day}/${startDateTime.month}/${startDateTime.year}";

//     var endd =
//         "${endhour}:${endminute}  ${startDateTime.day}/${startDateTime.month}/${startDateTime.year}";

//     nameController.text = name;
//     Startt = Start;
//     endd = End;
//     isSilentOrVibration = isSorV;
//     isTaskActivated = isTaskActivatedd;

//     return showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             backgroundColor: AppColors.kSecondary,
//             title: Text("Edit Schedule"),
//             content: SingleChildScrollView(
//                 child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.start,
//               children: [
//                 TextFormField(
//                   controller: nameController,
//                   decoration: InputDecoration(hintText: "Enter Title"),
//                 ),
//                 SizedBox(
//                   height: 40,
//                 ),
//                 GestureDetector(
//                   onTap: () {
//                     pickStartDateAndTime();
//                   },
//                   child: Row(
//                     children: const [
//                       Icon(Icons.edit_calendar),
//                       Spacer(),
//                       Text("Select End Date and Time"),
//                       // "Start : ${Startt}"
//                       // "Start Time:     ${startHour}:${startMinute}  ${startDateTime.day}/${startDateTime.month}/${startDateTime.year} "
//                     ],
//                   ),
//                 ),
//                 SizedBox(
//                   height: 40,
//                 ),
//                 GestureDetector(
//                   onTap: () {
//                     pickEndDateAndTime();
//                   },
//                   child: Row(
//                     children: const [
//                       Icon(Icons.edit_calendar),
//                       Spacer(),
//                       Text("Select End Date and Time"),
//                     ],
//                   ),
//                 ),
//               ],
//             )),
//             actions: [
//               TextButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                   },
//                   child: Text("Cancel",
//                       style: TextStyle(color: AppColors.kPrimary))),
//               TextButton(
//                   onPressed: () {
//                     scheduleModel.name = nameController.text.toString();
//                     scheduleModel.Start = DateTime(
//                         startDateTime.year,
//                         startDateTime.month,
//                         startDateTime.day,
//                         startDateTime.hour,
//                         startDateTime.minute);
//                     // "${startDateTime.hour}:${startDateTime.minute}  ${startDateTime.day.toString()}/${startDateTime.month.toString()}/${startDateTime.year.toString()}";
//                     scheduleModel.End = DateTime(
//                       endDateTime.year,
//                       endDateTime.month,
//                       endDateTime.day,
//                       endDateTime.hour,
//                       endDateTime.minute,
//                     );
//                     // "${endDateTime.hour}:${endDateTime.minute}  ${endDateTime.day.toString()}/${endDateTime.month.toString()}/${endDateTime.year.toString()}";
//                     scheduleModel.isSilentOrVibration = isSilentOrVibration;
//                     scheduleModel.save();

//                     if (scheduleModel.isTaskActivated == true &&
//                         scheduleModel.isSilentOrVibration == false) {
//                       AndroidAlarmManager.oneShotAt(
//                           scheduleModel.Start, AlarmId, setSilentMode);
//                       print("at Silent mode");
//                     } else if (scheduleModel.isTaskActivated == true &&
//                         scheduleModel.isSilentOrVibration == true) {
//                       AndroidAlarmManager.oneShotAt(
//                           scheduleModel.Start, AlarmId, setVibrateMode);
//                       print("at vibration mode");
//                     }
//                     if (scheduleModel.isTaskActivated == false) {
//                       AndroidAlarmManager.oneShot(
//                           Duration(seconds: 0), AlarmId, setNormalMode);
//                     }
//                     print("before  normal mode");
//                     // if(data[index].isTaskActivated== true && now == data[index].End ){
//                     AndroidAlarmManager.oneShotAt(
//                         scheduleModel.End, AlarmId2, setNormalMode);
//                     // AndroidAlarmManager.cancel(AlarmId);
//                     // }
//                     print("after normal mode");

//                     Navigator.pop(context);
//                   },
//                   child: Text(
//                     "Ok",
//                     style: TextStyle(color: AppColors.kPrimary),
//                   )),
//             ],
//           );
//         });
//   }

//   Future<DateTime?> pickStartDate() => showDatePicker(
//         context: context,
//         initialDate: startDateTime,
//         firstDate: DateTime(1900),
//         lastDate: DateTime(2100),
//       );

//   Future<TimeOfDay?> pickStartTime() => showTimePicker(
//       context: context,
//       initialTime:
//           TimeOfDay(hour: startDateTime.hour, minute: startDateTime.minute));

//   Future<void> pickStartDateAndTime() async {
//     DateTime? date = await pickStartDate();
//     if (date == null) return;

//     TimeOfDay? time = await pickStartTime();
//     if (time == null) return;

//     var datetime =
//         DateTime(date.year, date.month, date.day, time.hour, time.minute);
//     setState(() {
//       startDateTime = datetime;
//     });
//   }

//   // ENd time and date Code

//   Future<DateTime?> pickEndDate() => showDatePicker(
//       context: context,
//       initialDate: endDateTime,
//       firstDate: DateTime(1900),
//       lastDate: DateTime(2100));

//   Future<TimeOfDay?> pickEndTime() => showTimePicker(
//       context: context,
//       initialTime:
//           TimeOfDay(hour: endDateTime.hour, minute: endDateTime.minute));

//   Future<void> pickEndDateAndTime() async {
//     DateTime? date = await pickEndDate();
//     if (date == null) return;

//     TimeOfDay? time = await pickEndTime();
//     if (time == null) return;

//     var datetime =
//         DateTime(date.year, date.month, date.day, time.hour, time.minute);
//     setState(() {
//       endDateTime = datetime;
//     });
//   }

//   Future<void> openDoNotDisturbSettings() async {
//     await PermissionHandler.openDoNotDisturbSetting();
//   }

//   @pragma('vm:entry-point')
//   static Future<void> setSilentMode() async {
//     print("Silent method Called");
//     RingerModeStatus status;
//     try {
//       status = await SoundMode.setSoundMode(RingerModeStatus.silent);
//       _soundMode = status;

//       // setState(() {
//       //   _soundMode = status;
//       // });
//     } on PlatformException {
//       print('Do Not Disturb access permissions required!');
//       Fluttertoast.showToast(
//         msg: "Allow DND permissions from settings!",
//         toastLength: Toast.LENGTH_LONG,
//         gravity: ToastGravity.CENTER,
//         timeInSecForIosWeb: 1,
//         textColor: AppColors.kPrimary,
//         backgroundColor: AppColors.kSecondary,
//         // fontSize: 16.0
//       );
//     }
//   }

//   @pragma('vm:entry-point')
//   static Future<void> setNormalMode() async {
//     print("normal mode called");
//     RingerModeStatus status;

//     try {
//       status = await SoundMode.setSoundMode(RingerModeStatus.normal);
//       _soundMode = status;

//       // setState(() {
//       //   _soundMode = status;
//       // });
//     } on PlatformException {
//       print('Do Not Disturb access permissions required!');
//       Fluttertoast.showToast(
//         msg: "Allow DND permissions from settings!",
//         toastLength: Toast.LENGTH_LONG,
//         gravity: ToastGravity.CENTER,
//         timeInSecForIosWeb: 1,
//         textColor: AppColors.kPrimary,
//         backgroundColor: AppColors.kSecondary,
//         // fontSize: 16.0
//       );
//     }
//   }

//   @pragma('vm:entry-point')
//   static Future<void> setVibrateMode() async {
//     print("vibration mode called");

//     RingerModeStatus status;

//     try {
//       status = await SoundMode.setSoundMode(RingerModeStatus.vibrate);
//       _soundMode = status;

//       // setState(() {
//       //   _soundMode = status;
//       // });
//     } on PlatformException {
//       print('Do Not Disturb access permissions required!');
//       Fluttertoast.showToast(
//         msg: "Allow DND permissions from settings!",
//         toastLength: Toast.LENGTH_LONG,
//         gravity: ToastGravity.CENTER,
//         timeInSecForIosWeb: 1,
//         textColor: AppColors.kPrimary,
//         backgroundColor: AppColors.kSecondary,
//         // fontSize: 16.0
//       );
//     }
//   }
// //  static Future<void> Check() async {
// //     print("Check mode called");

// //   }
//   Widget BuildSheet() {
//     final countProvider = Provider.of<CountProvider>(context, listen: false);

//     return Center(
//       child: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(8),
//           //padding: EdgeInsets.only(left: 5, right: 5, top: 32),
//           child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       InkWell(
//                         onTap: () {
//                           Navigator.of(context).pop();
//                           Navigator.of(context).push(MaterialPageRoute(
//                               builder: (context) => CreateSchedule()));
//                         },
//                         child: Container(
//                           // padding: EdgeInsets.all(10),
//                           // ignore: sort_child_properties_last
//                           child: Center(
//                             child: SingleChildScrollView(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.center,
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     Icons.calendar_month_outlined,
//                                     color: AppColors.kPrimary,
//                                     size: 52,
//                                   ),
//                                   SizedBox(
//                                     height: MediaQuery.of(context).size.height /
//                                         100,
//                                   ),
//                                   Text(
//                                     "Calendar",
//                                     style: TextStyle(
//                                         fontSize: 15,
//                                         color: AppColors.kPrimary,
//                                         fontWeight: FontWeight.bold),
//                                   ),
//                                   SizedBox(
//                                     height:
//                                         MediaQuery.of(context).size.height / 50,
//                                   ),
//                                   Text(
//                                     "Choose Date and Time for one time",
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: AppColors.kPrimary,
//                                       // fontWeight: FontWeight.bold
//                                     ),
//                                   )
//                                 ],
//                               ),
//                             ),
//                           ),
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(29),
//                             color: AppColors.kSecondary,

//                             // border: Border.all(color: Colors.grey)
//                           ),

//                           height: MediaQuery.of(context).size.height / 5,
//                           width: MediaQuery.of(context).size.width / 1.5,
//                         ),
//                       ),
//                       SizedBox(
//                         width: MediaQuery.of(context).size.width / 40,
//                       ),
//                       // InkWell(
//                       //   onTap: () {
//                       //     Navigator.of(context).pop();
//                       //     Navigator.of(context).push(MaterialPageRoute(
//                       //         builder: (context) => CreateDaily()));
//                       //   },
//                       //   child: Container(
//                       //     //padding: EdgeInsets.all(29),
//                       //     child: Center(
//                       //       child: SingleChildScrollView(
//                       //         child: Column(
//                       //           crossAxisAlignment: CrossAxisAlignment.center,
//                       //           mainAxisAlignment: MainAxisAlignment.center,
//                       //           children: [
//                       //             Icon(
//                       //               Icons.av_timer,
//                       //               color: AppColors.kBlack,
//                       //               size: 52,
//                       //             ),
//                       //             SizedBox(
//                       //               height: MediaQuery.of(context).size.height /
//                       //                   100,
//                       //             ),
//                       //             Text(
//                       //               "Set Daily",
//                       //               style: TextStyle(
//                       //                   fontSize: 15,
//                       //                   color: AppColors.kBlack,
//                       //                   fontWeight: FontWeight.bold),
//                       //             )
//                       //           ],
//                       //         ),
//                       //       ),
//                       //     ),
//                       //     decoration: BoxDecoration(
//                       //       color: AppColors.kcontainer,
//                       //       // border: Border.all(color: Colors.grey)
//                       //       borderRadius: BorderRadius.circular(29),
//                       //     ),

//                       //     height: MediaQuery.of(context).size.height / 5,
//                       //     width: MediaQuery.of(context).size.width / 2.5,
//                       //   ),
//                       // )
//                     ],
//                   ),
//                 ),
//                 SizedBox(
//                   height: 1,
//                 ),
//                 SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       InkWell(
//                         onTap: () {},
//                         child: Container(
//                           //padding: EdgeInsets.all(15),
//                           // ignore: sort_child_properties_last
//                           child: Center(
//                             child: SingleChildScrollView(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.center,
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.center,
//                                     children: <Widget>[
//                                       Consumer<CountProvider>(
//                                         builder: (BuildContext context, value,
//                                             Widget? child) {
//                                           return Text(
//                                             "${countProvider.count.toString()}m",
//                                             style: Theme.of(context)
//                                                 .textTheme
//                                                 .headlineMedium,
//                                           );
//                                         },
//                                       ),
//                                     ],
//                                   ),
//                                   SizedBox(
//                                     height:
//                                         MediaQuery.of(context).size.height / 15,
//                                   ),
//                                   Padding(
//                                     padding:
//                                         const EdgeInsets.fromLTRB(24, 8, 24, 0),
//                                     child: Row(
//                                       children: [
//                                         IconButton(
//                                             onPressed: () =>
//                                                 countProvider.decremenCounter(),
//                                             icon: Icon(
//                                               Icons.remove_circle,
//                                               color: AppColors.kPrimary,
//                                               size: 52,
//                                             )),
//                                         Spacer(),
//                                         IconButton(
//                                             onPressed: () => countProvider
//                                                 .incrementCounter(),
//                                             icon: Icon(
//                                               Icons.add_circle,
//                                               color: AppColors.kPrimary,
//                                               size: 52,
//                                             )),
//                                       ],
//                                     ),
//                                   )
//                                 ],
//                               ),
//                             ),
//                           ),
//                           decoration: BoxDecoration(
//                               color: AppColors.kSecondary,
//                               // border: Border.all(color: Colors.grey)
//                               borderRadius: BorderRadius.circular(29),
//                               border: Border.all(
//                                   color: Color.fromARGB(255, 255, 255, 255))),
//                           height: MediaQuery.of(context).size.height / 4.5,
//                           width: MediaQuery.of(context).size.width / 2,
//                         ),
//                       ),
//                       SizedBox(
//                         width: MediaQuery.of(context).size.width / 40,
//                         height: MediaQuery.of(context).size.height / 4,
//                       ),
//                       // Container
//                       InkWell(
//                         onTap: () {
//                           DateTime endTimeAddittion = DateTime.now();
//                           var data = ScheduleModel(
//                               name: "Quick ${countProvider.count.toString()}m",
//                               Start: DateTime.now(),
//                               End: DateTime(
//                                   endTimeAddittion.year,
//                                   endTimeAddittion.month,
//                                   endTimeAddittion.day,
//                                   endTimeAddittion.hour,
//                                   endTimeAddittion.minute +
//                                       countProvider.count),
//                               isSilentOrVibration: isSilentOrVibration,
//                               isTaskActivated: true,
//                               quickTime: 5);
//                           final box = Boxes.getData();
//                           box.add(data);
//                           countProvider.updateHasData(box.isNotEmpty);

//                           AndroidAlarmManager.oneShotAt(
//                               data.Start, AlarmId, setSilentMode);
//                           print("at Silent mode");
//                           print("before  normal mode");
//                           AndroidAlarmManager.oneShotAt(
//                               data.End, AlarmId2, setNormalMode);
//                           print("after normal mode");
//                           Navigator.of(context).pop();
//                         },
//                         child: Container(
//                           //padding: EdgeInsets.all(29),
//                           child: Center(
//                             child: SingleChildScrollView(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.center,
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     Icons.volume_off,
//                                     color: AppColors.kPrimary,
//                                     size: 52,
//                                   ),
//                                   SizedBox(
//                                     height: 10,
//                                     // height: MediaQuery.of(context).size.height /100,
//                                   ),
//                                   Consumer<CountProvider>(
//                                     builder: (BuildContext context, value,
//                                         Widget? child) {
//                                       return Text(
//                                         "Silent for [${countProvider.count.toString()} mins]",
//                                         style: TextStyle(
//                                             fontSize: 15,
//                                             color: AppColors.kPrimary,
//                                             fontWeight: FontWeight.bold),
//                                       );
//                                     },
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           decoration: BoxDecoration(
//                             color: AppColors.kSecondary,
//                             // border: Border.all(color: Colors.grey)
//                             borderRadius: BorderRadius.circular(29),
//                           ),
//                           height: MediaQuery.of(context).size.height / 5,
//                           width: MediaQuery.of(context).size.width / 3,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(),
//               ]),
//         ),
//       ),
//     );
//   }
// }