import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:smart_silent/Boxes/boxes.dart';
import 'package:smart_silent/Provider/count_provider.dart';
import 'package:smart_silent/models/schedule_model.dart';
import 'package:sound_mode/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

// Public entry-points for AndroidAlarmManager
@pragma('vm:entry-point')
void scheduleSilentCallback() async {
  try {
    await SoundMode.setSoundMode(RingerModeStatus.silent);
  } catch (_) {}
}

@pragma('vm:entry-point')
void scheduleVibrateCallback() async {
  try {
    await SoundMode.setSoundMode(RingerModeStatus.vibrate);
  } catch (_) {}
}

@pragma('vm:entry-point')
void scheduleNormalCallback() async {
  try {
    await SoundMode.setSoundMode(RingerModeStatus.normal);
  } catch (_) {}
}

class CreateSchedule extends StatefulWidget {
  const CreateSchedule({super.key});

  @override
  State<CreateSchedule> createState() => _CreateScheduleState();
}

class _CreateScheduleState extends State<CreateSchedule> {
  final nameController = TextEditingController();
  bool isVibrateMode = false; // false = Silent, true = Vibrate
  DateTime startDateTime = DateTime.now().add(const Duration(minutes: 5));
  DateTime endDateTime = DateTime.now().add(const Duration(minutes: 35));

  BannerAd? _bannerAd;
  bool isAdLoaded = false;

  void initBannerAd() {
    const adsId = 'ca-app-pub-9923979057032791/3153557586';
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: adsId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
      request: const AdRequest(),
    );
    _bannerAd?.load();
  }

  @override
  void initState() {
    super.initState();
    initBannerAd();
  }

  @override
  void dispose() {
    nameController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '$hour:$minute $ampm, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _pickStartDateAndTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: startDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF389EB4),
            onPrimary: Colors.white,
            onSurface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: startDateTime.hour, minute: startDateTime.minute),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF389EB4),
            onPrimary: Colors.white,
            onSurface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    setState(() {
      startDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (endDateTime.isBefore(startDateTime)) {
        endDateTime = startDateTime.add(const Duration(minutes: 30));
      }
    });
  }

  Future<void> _pickEndDateAndTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: endDateTime.isBefore(startDateTime) ? startDateTime : endDateTime,
      firstDate: startDateTime,
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF389EB4),
            onPrimary: Colors.white,
            onSurface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: endDateTime.hour, minute: endDateTime.minute),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF389EB4),
            onPrimary: Colors.white,
            onSurface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    final pickedEnd = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (pickedEnd.isBefore(startDateTime)) {
      Fluttertoast.showToast(msg: "End time must be after start time!");
      return;
    }

    setState(() {
      endDateTime = pickedEnd;
    });
  }

  Future<void> _saveSchedule() async {
    final title = nameController.text.trim().isEmpty ? "One Time Schedule" : nameController.text.trim();

    if (endDateTime.isBefore(startDateTime)) {
      Fluttertoast.showToast(msg: "End time must be after start time!");
      return;
    }

    // Check DND permission
    final isGranted = await PermissionHandler.permissionsGranted;
    if (isGranted != true) {
      Fluttertoast.showToast(
        msg: "Please allow Do Not Disturb permission!",
        backgroundColor: const Color(0xFF389EB4),
        textColor: Colors.white,
      );
      await PermissionHandler.openDoNotDisturbSetting();
      return;
    }

    final data = ScheduleModel(
      name: title,
      Start: startDateTime,
      End: endDateTime,
      isSilentOrVibration: isVibrateMode,
      isTaskActivated: true,
      quickTime: 0,
    );

    final box = Boxes.getData();
    await box.add(data);

    if (mounted) {
      Provider.of<CountProvider>(context, listen: false).updateHasData(box.isNotEmpty);
    }

    final int alarmIdStart = (startDateTime.millisecondsSinceEpoch ~/ 1000) % 100000;
    final int alarmIdEnd = alarmIdStart + 1;

    try {
      await AndroidAlarmManager.oneShotAt(
        startDateTime,
        alarmIdStart,
        isVibrateMode ? scheduleVibrateCallback : scheduleSilentCallback,
        exact: true,
        wakeup: true,
      );
    } catch (_) {
      try {
        await AndroidAlarmManager.oneShotAt(
          startDateTime,
          alarmIdStart,
          isVibrateMode ? scheduleVibrateCallback : scheduleSilentCallback,
          exact: false,
          wakeup: true,
        );
      } catch (_) {}
    }

    try {
      await AndroidAlarmManager.oneShotAt(
        endDateTime,
        alarmIdEnd,
        scheduleNormalCallback,
        exact: true,
        wakeup: true,
      );
    } catch (_) {
      try {
        await AndroidAlarmManager.oneShotAt(
          endDateTime,
          alarmIdEnd,
          scheduleNormalCallback,
          exact: false,
          wakeup: true,
        );
      } catch (_) {}
    }

    Fluttertoast.showToast(
      msg: "Schedule created successfully!",
      backgroundColor: const Color(0xFF389EB4),
      textColor: Colors.white,
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Create One Time',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF349CA9), Color(0xFF4DB99D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF389EB4).withOpacity(0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.alarm_add_rounded, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'One Time Schedule',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Phone will auto-silent during this single upcoming event',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // 1. Task Name Input
                    const Text(
                      'Schedule Title',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_calendar_rounded, color: Color(0xFF389EB4), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: nameController,
                              style: const TextStyle(fontSize: 14.5, color: Color(0xFF1E293B)),
                              decoration: const InputDecoration(
                                hintText: "e.g. Doctor Appointment, Exam, Movie",
                                hintStyle: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 2. Start Date and Time
                    const Text(
                      'Start Date & Time',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickStartDateAndTime,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF389EB4).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.play_circle_outline_rounded, color: Color(0xFF389EB4), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Starts at',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDateTime(startDateTime),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 22),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3. End Date and Time
                    const Text(
                      'End Date & Time',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickEndDateAndTime,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF389EB4).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.stop_circle_outlined, color: Color(0xFF389EB4), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ends at',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDateTime(endDateTime),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 22),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 4. Sound Mode Selector
                    const Text(
                      'Phone Sound Mode',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isVibrateMode = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: !isVibrateMode ? const Color(0xFF389EB4) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: !isVibrateMode ? const Color(0xFF389EB4) : const Color(0xFFCBD5E1),
                                ),
                                boxShadow: [
                                  if (!isVibrateMode)
                                    BoxShadow(
                                      color: const Color(0xFF389EB4).withOpacity(0.28),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.volume_off_rounded,
                                    size: 19,
                                    color: !isVibrateMode ? Colors.white : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Silent Mode',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: !isVibrateMode ? Colors.white : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isVibrateMode = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: isVibrateMode ? const Color(0xFF389EB4) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isVibrateMode ? const Color(0xFF389EB4) : const Color(0xFFCBD5E1),
                                ),
                                boxShadow: [
                                  if (isVibrateMode)
                                    BoxShadow(
                                      color: const Color(0xFF389EB4).withOpacity(0.28),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.vibration_rounded,
                                    size: 19,
                                    color: isVibrateMode ? Colors.white : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Vibrate Mode',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: isVibrateMode ? Colors.white : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // 5. Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveSchedule,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF389EB4),
                          elevation: 3,
                          shadowColor: const Color(0xFF389EB4).withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 21),
                            SizedBox(width: 8),
                            Text(
                              'SAVE SCHEDULE',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Banner Ad at Bottom
            if (isAdLoaded && _bannerAd != null)
              Container(
                alignment: Alignment.center,
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }
}
