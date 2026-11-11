import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:smart_silent/models/repeated_model.dart';
import 'package:smart_silent/Utils/meeting_alarm_helper.dart';

import '../Boxes/boxes.dart';

class CreateDaily extends StatefulWidget {
  const CreateDaily({super.key});

  @override
  State<CreateDaily> createState() => _CreateDailyState();
}

class _CreateDailyState extends State<CreateDaily> {
  final TextEditingController nameController = TextEditingController();

  // Mode: false = Silent, true = Vibrate
  bool isVibrateMode = false;

  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 30);

  // Selected day indices (0 = Sun, 1 = Mon, ..., 6 = Sat)
  // Default to weekdays: Mon, Tue, Wed, Thu, Fri
  final Set<int> _selectedDays = {1, 2, 3, 4, 5};

  final List<Map<String, dynamic>> _daysConfig = const [
    {'label': 'Sun', 'index': 0},
    {'label': 'Mon', 'index': 1},
    {'label': 'Tue', 'index': 2},
    {'label': 'Wed', 'index': 3},
    {'label': 'Thu', 'index': 4},
    {'label': 'Fri', 'index': 5},
    {'label': 'Sat', 'index': 6},
  ];

  late BannerAd _bannerAd;
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
        onAdFailedToLoad: (ad, error) {},
      ),
      request: const AdRequest(),
    );
    _bannerAd.load();
  }

  @override
  void initState() {
    super.initState();
    initBannerAd();
  }

  @override
  void dispose() {
    nameController.dispose();
    try {
      if (isAdLoaded) {
        _bannerAd.dispose();
      }
    } catch (_) {}
    super.dispose();
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initialTime) async {
    return await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF389EB4),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _saveSchedule() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter a meeting or schedule name");
      return;
    }

    if (_selectedDays.isEmpty) {
      Fluttertoast.showToast(msg: "Please select at least one day");
      return;
    }

    final now = DateTime.now();
    final startDateTime = DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
    final endDateTime = DateTime(now.year, now.month, now.day, endTime.hour, endTime.minute);

    final data = RepeatedModel(
      name: name,
      Start: startDateTime,
      End: endDateTime,
      isSilentOrVibration: isVibrateMode,
      isTaskActivated: true,
      dayInWeek: _selectedDays.toList()..sort(),
    );

    final box = Boxes.getDataforDaily();
    await box.add(data);
    await MeetingAlarmHelper.syncAllMeetings();

    if (mounted) {
      Fluttertoast.showToast(
        msg: "Meeting Schedule Saved Successfully!",
        backgroundColor: const Color(0xFF389EB4),
        textColor: Colors.white,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
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
            'Create Meeting Schedule',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meeting Title
              const Text(
                'Meeting / Task Name',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: nameController,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.business_center_outlined, color: Color(0xFF389EB4), size: 22),
                    hintText: 'e.g., Weekly Team Sync, Class, Gym',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Time Selection (Start & End)
              const Text(
                'Schedule Timings',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Start Time
                  Expanded(
                    child: _buildTimePickerCard(
                      label: 'Start Time',
                      time: startTime,
                      onTap: () async {
                        final res = await _pickTime(startTime);
                        if (res != null) setState(() => startTime = res);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // End Time
                  Expanded(
                    child: _buildTimePickerCard(
                      label: 'End Time',
                      time: endTime,
                      onTap: () async {
                        final res = await _pickTime(endTime);
                        if (res != null) setState(() => endTime = res);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Repeat Days
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Repeat Days',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_selectedDays.length == 7) {
                          _selectedDays.clear();
                        } else {
                          _selectedDays.addAll([0, 1, 2, 3, 4, 5, 6]);
                        }
                      });
                    },
                    child: Text(
                      _selectedDays.length == 7 ? 'Clear All' : 'Select All',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF389EB4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _daysConfig.map((day) {
                    final isSelected = _selectedDays.contains(day['index']);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedDays.remove(day['index']);
                          } else {
                            _selectedDays.add(day['index']);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF389EB4) : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF389EB4).withOpacity(0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            day['label'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 22),

              // Silent / Vibrate Mode
              const Text(
                'Sound Mode',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),

              // Silent Toggle
              _buildModeToggle(
                title: 'Silent Mode',
                subtitle: 'Phone will automatically be Silent',
                value: !isVibrateMode,
                onChanged: (val) => setState(() => isVibrateMode = !val),
              ),
              const SizedBox(height: 10),

              // Vibrate Toggle
              _buildModeToggle(
                title: 'Vibrate Mode',
                subtitle: 'Phone will automatically Vibrate',
                value: isVibrateMode,
                onChanged: (val) => setState(() => isVibrateMode = val),
              ),

              const SizedBox(height: 32),

              // Save Button
              GestureDetector(
                onTap: _saveSchedule,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF389EB4),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF389EB4).withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Save Meeting Schedule',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: isAdLoaded
            ? Container(
                decoration: const BoxDecoration(color: Colors.transparent),
                height: _bannerAd.size.height.toDouble(),
                width: _bannerAd.size.width.toDouble(),
                child: AdWidget(ad: _bannerAd),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildTimePickerCard({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(time),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Icon(Icons.access_time_rounded, color: Color(0xFF389EB4), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF389EB4),
            activeTrackColor: const Color(0xFF389EB4).withOpacity(0.35),
          ),
        ],
      ),
    );
  }
}
