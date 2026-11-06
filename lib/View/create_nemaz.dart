import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:smart_silent/Boxes/boxes.dart';
import 'package:smart_silent/Provider/count_provider.dart';
import 'package:smart_silent/models/nemaz_model.dart';

class CreateNemaz extends StatefulWidget {
  const CreateNemaz({super.key});

  @override
  State<CreateNemaz> createState() => _CreateNemazState();
}

class _CreateNemazState extends State<CreateNemaz> {
  // Silent (false) vs Vibrate (true)
  bool isVibrateMode = false;

  TimeOfDay fajarStart = const TimeOfDay(hour: 5, minute: 10);
  TimeOfDay fajarEnd = const TimeOfDay(hour: 5, minute: 45);

  TimeOfDay zoharStart = const TimeOfDay(hour: 13, minute: 15);
  TimeOfDay zoharEnd = const TimeOfDay(hour: 13, minute: 45);

  TimeOfDay asarStart = const TimeOfDay(hour: 17, minute: 10);
  TimeOfDay asarEnd = const TimeOfDay(hour: 17, minute: 45);

  TimeOfDay magribStart = const TimeOfDay(hour: 19, minute: 10);
  TimeOfDay magribEnd = const TimeOfDay(hour: 19, minute: 45);

  TimeOfDay ishaStart = const TimeOfDay(hour: 20, minute: 45);
  TimeOfDay ishaEnd = const TimeOfDay(hour: 21, minute: 15);

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
    _loadExistingSavedTimings();
  }

  // Load existing timings if saved in Hive
  void _loadExistingSavedTimings() {
    try {
      final box = Boxes.getDataforNemaz();
      if (box.isNotEmpty) {
        final existing = box.values.last;
        setState(() {
          fajarStart = TimeOfDay(hour: existing.FajarStart.hour, minute: existing.FajarStart.minute);
          fajarEnd = TimeOfDay(hour: existing.FajarEnd.hour, minute: existing.FajarEnd.minute);

          zoharStart = TimeOfDay(hour: existing.ZoharStart.hour, minute: existing.ZoharStart.minute);
          zoharEnd = TimeOfDay(hour: existing.ZoharEnd.hour, minute: existing.ZoharEnd.minute);

          asarStart = TimeOfDay(hour: existing.AsarStart.hour, minute: existing.AsarStart.minute);
          asarEnd = TimeOfDay(hour: existing.AsarEnd.hour, minute: existing.AsarEnd.minute);

          magribStart = TimeOfDay(hour: existing.MagribStart.hour, minute: existing.MagribStart.minute);
          magribEnd = TimeOfDay(hour: existing.MagribEnd.hour, minute: existing.MagribEnd.minute);

          ishaStart = TimeOfDay(hour: existing.IshaStart.hour, minute: existing.IshaStart.minute);
          ishaEnd = TimeOfDay(hour: existing.IshaEnd.hour, minute: existing.IshaEnd.minute);

          isVibrateMode = existing.isSilentOrVibration;
        });
      }
    } catch (_) {}
  }

  // Time picker dialog helper
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
    return '$hour : $minute';
  }

  Future<void> _saveTimings() async {
    final now = DateTime.now();

    final nemazData = NemazModel(
      forWhichMasjid: "Masjid",
      FajarStart: DateTime(now.year, now.month, now.day, fajarStart.hour, fajarStart.minute),
      FajarEnd: DateTime(now.year, now.month, now.day, fajarEnd.hour, fajarEnd.minute),
      ZoharStart: DateTime(now.year, now.month, now.day, zoharStart.hour, zoharStart.minute),
      ZoharEnd: DateTime(now.year, now.month, now.day, zoharEnd.hour, zoharEnd.minute),
      AsarStart: DateTime(now.year, now.month, now.day, asarStart.hour, asarStart.minute),
      AsarEnd: DateTime(now.year, now.month, now.day, asarEnd.hour, asarEnd.minute),
      MagribStart: DateTime(now.year, now.month, now.day, magribStart.hour, magribStart.minute),
      MagribEnd: DateTime(now.year, now.month, now.day, magribEnd.hour, magribEnd.minute),
      IshaStart: DateTime(now.year, now.month, now.day, ishaStart.hour, ishaStart.minute),
      IshaEnd: DateTime(now.year, now.month, now.day, ishaEnd.hour, ishaEnd.minute),
      isSilentOrVibration: isVibrateMode,
      isFajarTaskActivated: true,
      isZoharTaskActivated: true,
      isAsarTaskActivated: true,
      isMagribTaskActivated: true,
      isIshaTaskActivated: true,
    );

    final box = Boxes.getDataforNemaz();
    await box.clear(); // Keep active set updated
    await box.add(nemazData);

    if (mounted) {
      Provider.of<CountProvider>(context, listen: false).updateHasData(true);
      Fluttertoast.showToast(
        msg: "Prayer Timings Saved Successfully!",
        toastLength: Toast.LENGTH_SHORT,
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
        body: Column(
          children: [
            // Top Mosque Graphic Banner (Matching media_1793945983596_3b5871c2.png)
            _buildTopMosqueHeader(context),

            // Prayer Timing Cards & Mode Settings
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fajar
                    _buildPrayerTimeRow(
                      title: 'Fajar',
                      startTime: fajarStart,
                      endTime: fajarEnd,
                      onPickStart: () async {
                        final res = await _pickTime(fajarStart);
                        if (res != null) setState(() => fajarStart = res);
                      },
                      onPickEnd: () async {
                        final res = await _pickTime(fajarEnd);
                        if (res != null) setState(() => fajarEnd = res);
                      },
                    ),

                    // Zohar
                    _buildPrayerTimeRow(
                      title: 'Zohar',
                      startTime: zoharStart,
                      endTime: zoharEnd,
                      onPickStart: () async {
                        final res = await _pickTime(zoharStart);
                        if (res != null) setState(() => zoharStart = res);
                      },
                      onPickEnd: () async {
                        final res = await _pickTime(zoharEnd);
                        if (res != null) setState(() => zoharEnd = res);
                      },
                    ),

                    // Asar
                    _buildPrayerTimeRow(
                      title: 'Asar',
                      startTime: asarStart,
                      endTime: asarEnd,
                      onPickStart: () async {
                        final res = await _pickTime(asarStart);
                        if (res != null) setState(() => asarStart = res);
                      },
                      onPickEnd: () async {
                        final res = await _pickTime(asarEnd);
                        if (res != null) setState(() => asarEnd = res);
                      },
                    ),

                    // Magrib
                    _buildPrayerTimeRow(
                      title: 'Magrib',
                      startTime: magribStart,
                      endTime: magribEnd,
                      onPickStart: () async {
                        final res = await _pickTime(magribStart);
                        if (res != null) setState(() => magribStart = res);
                      },
                      onPickEnd: () async {
                        final res = await _pickTime(magribEnd);
                        if (res != null) setState(() => magribEnd = res);
                      },
                    ),

                    // Isha
                    _buildPrayerTimeRow(
                      title: 'Isha',
                      startTime: ishaStart,
                      endTime: ishaEnd,
                      onPickStart: () async {
                        final res = await _pickTime(ishaStart);
                        if (res != null) setState(() => ishaStart = res);
                      },
                      onPickEnd: () async {
                        final res = await _pickTime(ishaEnd);
                        if (res != null) setState(() => ishaEnd = res);
                      },
                    ),

                    const SizedBox(height: 10),

                    // Silent Mode Switch
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0, bottom: 6.0),
                      child: Text(
                        'Silent Mode',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    _buildModeToggleCard(
                      label: 'Phone Will automatically Silent',
                      value: !isVibrateMode,
                      onChanged: (val) {
                        setState(() => isVibrateMode = !val);
                      },
                    ),

                    const SizedBox(height: 14),

                    // Vibrate Mode Switch
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0, bottom: 6.0),
                      child: Text(
                        'Vibrate Mode',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    _buildModeToggleCard(
                      label: 'Phone Will automatically Vibrate',
                      value: isVibrateMode,
                      onChanged: (val) {
                        setState(() => isVibrateMode = val);
                      },
                    ),

                    const SizedBox(height: 24),

                    // Save Button
                    GestureDetector(
                      onTap: _saveTimings,
                      child: Container(
                        width: double.infinity,
                        height: 50,
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
                            'Save Prayer Timings',
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

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Top Mosque Header Graphic matching uploaded screenshot
  Widget _buildTopMosqueHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 175,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A8B9A), Color(0xFF4DB99D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Mosque Silhouette Vector
            Positioned.fill(
              child: CustomPaint(
                painter: _HeaderMosquePainter(),
              ),
            ),

            // Back button
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Islamic Date Text banner at bottom of header
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '25 Rajab, 1444',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Single Prayer Card (Start Time : 5 : 10 | End Time : 5 : 45)
  Widget _buildPrayerTimeRow({
    required String title,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required VoidCallback onPickStart,
    required VoidCallback onPickEnd,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 5.0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Start Time
                InkWell(
                  onTap: onPickStart,
                  child: Row(
                    children: [
                      Text(
                        'Start Time : ${_formatTime(startTime)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF389EB4)),
                    ],
                  ),
                ),

                // End Time
                InkWell(
                  onTap: onPickEnd,
                  child: Row(
                    children: [
                      Text(
                        'End Time : ${_formatTime(endTime)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF389EB4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Toggle card for Silent Mode and Vibrate Mode
  Widget _buildModeToggleCard({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF334155),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              value: value,
              activeColor: const Color(0xFF389EB4),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// Vector Painter for Top Mosque silhouette in Header
class _HeaderMosquePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final crescentPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final bottom = size.height;

    // Central Grand Dome
    final domeRect = Rect.fromCenter(
      center: Offset(centerX, bottom - 40),
      width: 78,
      height: 80,
    );
    canvas.drawArc(domeRect, 3.14, 3.14, true, fillPaint);

    // Spire and Crescent over Central Dome
    canvas.drawLine(
      Offset(centerX, bottom - 80),
      Offset(centerX, bottom - 105),
      Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..strokeWidth = 2,
    );
    canvas.drawCircle(Offset(centerX, bottom - 110), 6, crescentPaint);

    // Left Dome
    final leftDomeRect = Rect.fromCenter(
      center: Offset(centerX - 68, bottom - 30),
      width: 44,
      height: 48,
    );
    canvas.drawArc(leftDomeRect, 3.14, 3.14, true, fillPaint);

    // Right Dome
    final rightDomeRect = Rect.fromCenter(
      center: Offset(centerX + 68, bottom - 30),
      width: 44,
      height: 48,
    );
    canvas.drawArc(rightDomeRect, 3.14, 3.14, true, fillPaint);

    // Minarets Left & Right
    final minaretWidth = 10.0;
    canvas.drawRect(Rect.fromLTWH(centerX - 100, bottom - 90, minaretWidth, 90), fillPaint);
    canvas.drawRect(Rect.fromLTWH(centerX + 90, bottom - 90, minaretWidth, 90), fillPaint);
    canvas.drawRect(Rect.fromLTWH(centerX - 130, bottom - 70, minaretWidth, 70), fillPaint);
    canvas.drawRect(Rect.fromLTWH(centerX + 120, bottom - 70, minaretWidth, 70), fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
