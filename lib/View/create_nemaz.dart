import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_silent/Boxes/boxes.dart';
import 'package:smart_silent/Provider/count_provider.dart';
import 'package:smart_silent/Utils/hijri_helper.dart';
import 'package:smart_silent/Utils/prayer_alarm_helper.dart';
import 'package:smart_silent/View/setings.dart';
import 'package:smart_silent/models/nemaz_model.dart';
import 'package:sound_mode/permission_handler.dart';

class CreateNemaz extends StatefulWidget {
  const CreateNemaz({super.key});

  @override
  State<CreateNemaz> createState() => _CreateNemazState();
}

class _CreateNemazState extends State<CreateNemaz> {
  // Silent (false) vs Vibrate (true)
  bool isVibrateMode = false;
  bool isSmartMode = true;

  TimeOfDay fajarStart = const TimeOfDay(hour: 5, minute: 19);
  TimeOfDay fajarEnd = const TimeOfDay(hour: 5, minute: 40);

  TimeOfDay zoharStart = const TimeOfDay(hour: 13, minute: 19);
  TimeOfDay zoharEnd = const TimeOfDay(hour: 13, minute: 40);

  TimeOfDay asarStart = const TimeOfDay(hour: 15, minute: 19);
  TimeOfDay asarEnd = const TimeOfDay(hour: 15, minute: 40);

  TimeOfDay magribStart = const TimeOfDay(hour: 17, minute: 19);
  TimeOfDay magribEnd = const TimeOfDay(hour: 17, minute: 40);

  TimeOfDay ishaStart = const TimeOfDay(hour: 19, minute: 19);
  TimeOfDay ishaEnd = const TimeOfDay(hour: 19, minute: 40);

  late BannerAd _bannerAd;
  bool isAdLoaded = false;
  String hijriDateText = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadHijriDate();
    initBannerAd();
    _loadExistingSavedTimings();
  }

  @override
  void dispose() {
    try {
      if (isAdLoaded) {
        _bannerAd.dispose();
      }
    } catch (_) {}
    super.dispose();
  }

  void _loadHijriDate() {
    setState(() {
      hijriDateText = HijriDate.formatCurrentDate();
    });
  }

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

  // Load existing timings if saved in Hive
  Future<void> _loadExistingSavedTimings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isSmartMode = prefs.getBool('smart_prayer_mode') ?? true;

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
              primary: Color(0xFF0284C7),
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
    return '$hour:$minute';
  }

  // Calculate next occurrence for prayer time
  DateTime _getNextOccurrence(TimeOfDay tod) {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  // Check if current time falls between start and end
  bool _isCurrentTimeInside(TimeOfDay start, TimeOfDay end) {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;

    if (endMin >= startMin) {
      return nowMin >= startMin && nowMin < endMin;
    } else {
      // Overnight interval
      return nowMin >= startMin || nowMin < endMin;
    }
  }

  // Save Timings to Hive and schedule real Android background alarms
  Future<void> _saveTimingsAndScheduleAlarms({bool showToastMessage = true}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // 1. Check Do Not Disturb (DND) permissions
      final bool isGranted = (await PermissionHandler.permissionsGranted) ?? false;
      if (!isGranted) {
        Fluttertoast.showToast(
          msg: "Please allow Do Not Disturb (DND) so phone can be silenced during prayer!",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: const Color(0xFFEF4444),
          textColor: Colors.white,
        );
        await PermissionHandler.openDoNotDisturbSetting();
      }

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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('smart_prayer_mode', isSmartMode);

      final box = Boxes.getDataforNemaz();
      await box.clear();
      await box.add(nemazData);

      // 2. Schedule exact background alarms via PrayerAlarmHelper with daily auto-repeat
      await PrayerAlarmHelper.scheduleAllPrayers(
        fajarStart: fajarStart,
        fajarEnd: fajarEnd,
        zoharStart: zoharStart,
        zoharEnd: zoharEnd,
        asarStart: asarStart,
        asarEnd: asarEnd,
        magribStart: magribStart,
        magribEnd: magribEnd,
        ishaStart: ishaStart,
        ishaEnd: ishaEnd,
        isVibrateMode: isVibrateMode,
      );

      if (mounted) {
        Provider.of<CountProvider>(context, listen: false).updateHasData(true);
        if (showToastMessage) {
          Fluttertoast.showToast(
            msg: "Prayer Timings & Auto-Silent Alarms Saved Successfully!",
            toastLength: Toast.LENGTH_SHORT,
            backgroundColor: const Color(0xFF0284C7),
            textColor: Colors.white,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Saved timings. Note: $e",
          toastLength: Toast.LENGTH_SHORT,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Interactive Bottom Sheet to edit Start & End times for a prayer
  void _openPrayerTimeEditor({
    required String title,
    required TimeOfDay currentStart,
    required TimeOfDay currentEnd,
    required Function(TimeOfDay start, TimeOfDay end) onSave,
  }) {
    TimeOfDay tempStart = currentStart;
    TimeOfDay tempEnd = currentEnd;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$title Prayer Times',
                          style: const TextStyle(
                            fontSize: 18.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Start Time Box
                    InkWell(
                      onTap: () async {
                        final res = await _pickTime(tempStart);
                        if (res != null) {
                          setModalState(() => tempStart = res);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.access_time_rounded,
                                      color: Color(0xFF0284C7), size: 20),
                                ),
                                const SizedBox(width: 14),
                                const Text(
                                  'Start Time',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _formatTime(tempStart),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // End Time Box
                    InkWell(
                      onTap: () async {
                        final res = await _pickTime(tempEnd);
                        if (res != null) {
                          setModalState(() => tempEnd = res);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D9488).withOpacity(0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.update_rounded,
                                      color: Color(0xFF0D9488), size: 20),
                                ),
                                const SizedBox(width: 14),
                                const Text(
                                  'End Time',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _formatTime(tempEnd),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          final startMinutes = tempStart.hour * 60 + tempStart.minute;
                          final endMinutes = tempEnd.hour * 60 + tempEnd.minute;
                          if (endMinutes <= startMinutes) {
                            Fluttertoast.showToast(
                              msg: "End time must be after start time",
                              backgroundColor: Colors.redAccent,
                              textColor: Colors.white,
                            );
                            return;
                          }
                          onSave(tempStart, tempEnd);
                          Navigator.pop(ctx);
                          _saveTimingsAndScheduleAlarms(showToastMessage: true);
                        },
                        child: const Text(
                          'Update Prayer Times',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
        backgroundColor: const Color(0xFFF3F7FA),
        body: Column(
          children: [
            // Top Mosque Graphic Banner with back & settings buttons (zero overflow)
            _buildTopMosqueHeader(context),

            // Scrollable Prayer Timing Settings list matching Image exactly
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Fajr Card (Soft cyan tint icon, mosque)
                    _buildPrayerCard(
                      name: 'Fajr',
                      icon: Icons.mosque_rounded,
                      iconBgColor: const Color(0xFFE0F7FA),
                      iconColor: const Color(0xFF0284C7),
                      startTime: fajarStart,
                      endTime: fajarEnd,
                      onTap: () {
                        _openPrayerTimeEditor(
                          title: 'Fajr',
                          currentStart: fajarStart,
                          currentEnd: fajarEnd,
                          onSave: (start, end) {
                            setState(() {
                              fajarStart = start;
                              fajarEnd = end;
                            });
                          },
                        );
                      },
                    ),

                    // Zuhr Card (Soft green tint icon, sun)
                    _buildPrayerCard(
                      name: 'Zuhr',
                      icon: Icons.wb_sunny_rounded,
                      iconBgColor: const Color(0xFFE8F5E9),
                      iconColor: const Color(0xFF2E7D32),
                      startTime: zoharStart,
                      endTime: zoharEnd,
                      onTap: () {
                        _openPrayerTimeEditor(
                          title: 'Zuhr',
                          currentStart: zoharStart,
                          currentEnd: zoharEnd,
                          onSave: (start, end) {
                            setState(() {
                              zoharStart = start;
                              zoharEnd = end;
                            });
                          },
                        );
                      },
                    ),

                    // Asr Card (Soft peach/orange tint icon, afternoon sun)
                    _buildPrayerCard(
                      name: 'Asr',
                      icon: Icons.wb_twilight_rounded,
                      iconBgColor: const Color(0xFFFFF3E0),
                      iconColor: const Color(0xFFE65100),
                      startTime: asarStart,
                      endTime: asarEnd,
                      onTap: () {
                        _openPrayerTimeEditor(
                          title: 'Asr',
                          currentStart: asarStart,
                          currentEnd: asarEnd,
                          onSave: (start, end) {
                            setState(() {
                              asarStart = start;
                              asarEnd = end;
                            });
                          },
                        );
                      },
                    ),

                    // Maghrib Card (Soft purple/violet tint icon, sunset)
                    _buildPrayerCard(
                      name: 'Maghrib',
                      icon: Icons.nights_stay_rounded,
                      iconBgColor: const Color(0xFFF3E5F5),
                      iconColor: const Color(0xFF7B1FA2),
                      startTime: magribStart,
                      endTime: magribEnd,
                      onTap: () {
                        _openPrayerTimeEditor(
                          title: 'Maghrib',
                          currentStart: magribStart,
                          currentEnd: magribEnd,
                          onSave: (start, end) {
                            setState(() {
                              magribStart = start;
                              magribEnd = end;
                            });
                          },
                        );
                      },
                    ),

                    // Isha Card (Deep navy/indigo tint icon, moon)
                    _buildPrayerCard(
                      name: 'Isha',
                      icon: Icons.nightlight_round,
                      iconBgColor: const Color(0xFFE8EAF6),
                      iconColor: const Color(0xFF283593),
                      startTime: ishaStart,
                      endTime: ishaEnd,
                      onTap: () {
                        _openPrayerTimeEditor(
                          title: 'Isha',
                          currentStart: ishaStart,
                          currentEnd: ishaEnd,
                          onSave: (start, end) {
                            setState(() {
                              ishaStart = start;
                              ishaEnd = end;
                            });
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 6),

                    // Smart Mode Toggle Card (matching Image exactly)
                    _buildToggleCard(
                      title: 'Smart Mode',
                      subtitle: 'Auto adjust times',
                      icon: Icons.notifications_active_rounded,
                      iconBgColor: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      value: isSmartMode,
                      onChanged: (val) {
                        setState(() => isSmartMode = val);
                        _saveTimingsAndScheduleAlarms(showToastMessage: false);
                      },
                    ),

                    // Silent Mode Toggle Card (matching Image exactly)
                    _buildToggleCard(
                      title: 'Silent Mode',
                      subtitle: isVibrateMode ? 'Device will vibrate during prayers' : 'Device will stay silent during prayers',
                      icon: Icons.notifications_off_rounded,
                      iconBgColor: const Color(0xFFEDE9FE),
                      iconColor: const Color(0xFF7C3AED),
                      value: !isVibrateMode,
                      onChanged: (val) {
                        setState(() => isVibrateMode = !val);
                        _saveTimingsAndScheduleAlarms(showToastMessage: false);
                      },
                    ),

                    const SizedBox(height: 20),

                    // Prominent Save Prayer Timings Button (Requested by User)
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF0D9488)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _saveTimingsAndScheduleAlarms(showToastMessage: true),
                          child: Center(
                            child: _isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 21),
                                      SizedBox(width: 8),
                                      Text(
                                        'Save Prayer Timings',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Top Mosque Header graphic with enhanced artwork, centered title & date, and balanced action buttons
  Widget _buildTopMosqueHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFCEEEFA),
            Color(0xFFE4F5FC),
            Color(0xFFF3F9FC),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Enhanced Multi-Layered Mosque Silhouette & Celestial Vector Artwork
            Positioned.fill(
              child: CustomPaint(
                painter: _TopHeaderMosquePainter(),
              ),
            ),

            // Top Bar: Back (Left), Title & Hijri Date (Center), Settings (Right)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back Button (Sleek elevated circular button)
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E3A8A).withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFF1E3A8A),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Center: Title + Dynamic Hijri Date Badge
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Prayer Timings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  color: Color(0xFF0284C7),
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  hijriDateText,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F766E),
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Settings Button on Top Right (Matching elevated circular gear button)
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Settings()),
                        );
                      },
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E3A8A).withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.settings_rounded,
                            color: Color(0xFF1E3A8A),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Single Prayer Card with robust overflow prevention
  Widget _buildPrayerCard({
    required String name,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBF0F5), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Left Icon Badge in circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                ),
                const SizedBox(width: 14),

                // Name & Start/End time (FittedBox to prevent any horizontal overflow)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Start Time : ${_formatTime(startTime)}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              height: 12,
                              width: 1.2,
                              color: const Color(0xFFCBD5E1),
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            Text(
                              'End Time : ${_formatTime(endTime)}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Trailing Chevron Right
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Toggle Card for Smart Mode & Silent Mode
  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBF0F5), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Left Icon Badge in circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 24),
            ),
          ),
          const SizedBox(width: 14),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Cupertino Switch toggle
          CupertinoSwitch(
            value: value,
            activeColor: const Color(0xFF0284C7),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// Enhanced Multi-Layered Custom Painter for Top Mosque Skyline, Moon, Stars & Waves
class _TopHeaderMosquePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bottom = size.height;
    final centerX = size.width * 0.50;

    // 1. Soft atmospheric clouds in the sky
    final cloudPaint = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..style = PaintingStyle.fill;

    _drawCloud(canvas, Offset(size.width * 0.22, 28), 24, cloudPaint);
    _drawCloud(canvas, Offset(size.width * 0.78, 22), 20, cloudPaint);
    _drawCloud(canvas, Offset(size.width * 0.88, 38), 16, cloudPaint);

    // 2. Luminous Crescent Moon & Star in Upper Right
    final moonCenter = Offset(size.width * 0.68, 32);
    final moonGlow = Paint()
      ..color = const Color(0xFFFBBF24).withOpacity(0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(moonCenter, 16, moonGlow);

    final moonPaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.55)
      ..style = PaintingStyle.fill;

    final moonPath = Path()
      ..addArc(Rect.fromCircle(center: moonCenter, radius: 10), -math.pi * 0.5, math.pi * 1.5)
      ..arcToPoint(
        Offset(moonCenter.dx, moonCenter.dy - 10),
        radius: const Radius.circular(7.8),
        clockwise: false,
      );
    canvas.drawPath(moonPath, moonPaint);

    // Morning star beside the moon
    _drawStar(canvas, Offset(size.width * 0.73, 26), 4.5, const Color(0xFF0284C7).withOpacity(0.55));
    _drawStar(canvas, Offset(size.width * 0.35, 34), 3.5, const Color(0xFF0284C7).withOpacity(0.35));

    // 3. Layer 1: Distant Background Mosque Silhouettes (Pale Cyan)
    final distantPaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.12)
      ..style = PaintingStyle.fill;

    _drawMinaret(canvas, centerX - 148, 85, 8, bottom, distantPaint);
    _drawMinaret(canvas, centerX + 140, 85, 8, bottom, distantPaint);
    _drawDome(canvas, centerX - 110, bottom - 18, 42, 44, distantPaint);
    _drawDome(canvas, centerX + 110, bottom - 18, 42, 44, distantPaint);

    // 4. Layer 2: Midground Mosque Elements (Medium Cyan)
    final midPaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.22)
      ..style = PaintingStyle.fill;

    _drawMinaret(canvas, centerX - 118, 102, 9.5, bottom, midPaint);
    _drawMinaret(canvas, centerX + 108, 102, 9.5, bottom, midPaint);
    _drawDome(canvas, centerX - 62, bottom - 22, 54, 56, midPaint);
    _drawDome(canvas, centerX + 62, bottom - 22, 54, 56, midPaint);

    // 5. Layer 3: Foreground Grand Central Mosque (Rich Cyan with Details)
    final fgPaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.36)
      ..style = PaintingStyle.fill;

    // Central Grand Dome
    _drawDome(canvas, centerX, bottom - 24, 94, 96, fgPaint);

    // Crescent finial on central dome
    final finialPaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(centerX, bottom - 72), Offset(centerX, bottom - 98), finialPaint);
    canvas.drawCircle(Offset(centerX, bottom - 100), 3.5, fgPaint);

    // Foreground Primary Twin Minarets
    _drawDetailedMinaret(canvas, centerX - 82, 120, 12, bottom, fgPaint);
    _drawDetailedMinaret(canvas, centerX + 70, 120, 12, bottom, fgPaint);

    // Grand Arched Facade Wall across bottom
    final wallHeight = 26.0;
    canvas.drawRect(Rect.fromLTWH(centerX - 130, bottom - wallHeight, 260, wallHeight), fgPaint);

    // Moorish Arches on wall facade
    final archCutPaint = Paint()
      ..color = const Color(0xFFE4F5FC).withOpacity(0.7)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 9; i++) {
      final archX = centerX - 110 + (i * 24.0);
      final archPath = Path()
        ..moveTo(archX, bottom)
        ..lineTo(archX, bottom - 14)
        ..arcToPoint(Offset(archX + 10, bottom - 14), radius: const Radius.circular(5))
        ..lineTo(archX + 10, bottom)
        ..close();
      canvas.drawPath(archPath, archCutPaint);
    }

    // 6. Sweeping Organic Cyan/Mint Waves at Header Bottom
    final wave1 = Paint()
      ..color = const Color(0xFF0EA5E9).withOpacity(0.30)
      ..style = PaintingStyle.fill;

    final pathWave1 = Path()
      ..moveTo(0, bottom - 26)
      ..cubicTo(size.width * 0.28, bottom - 46, size.width * 0.62, bottom - 12, size.width, bottom - 22)
      ..lineTo(size.width, bottom)
      ..lineTo(0, bottom)
      ..close();
    canvas.drawPath(pathWave1, wave1);

    final wave2 = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.38)
      ..style = PaintingStyle.fill;

    final pathWave2 = Path()
      ..moveTo(0, bottom - 18)
      ..cubicTo(size.width * 0.35, bottom - 32, size.width * 0.72, bottom - 4, size.width, bottom - 14)
      ..lineTo(size.width, bottom)
      ..lineTo(0, bottom)
      ..close();
    canvas.drawPath(pathWave2, wave2);

    final wave3 = Paint()
      ..color = const Color(0xFFF3F7FA)
      ..style = PaintingStyle.fill;

    final pathWave3 = Path()
      ..moveTo(0, bottom - 10)
      ..cubicTo(size.width * 0.38, bottom - 20, size.width * 0.75, bottom, size.width, bottom - 6)
      ..lineTo(size.width, bottom)
      ..lineTo(0, bottom)
      ..close();
    canvas.drawPath(pathWave3, wave3);
  }

  void _drawDome(Canvas canvas, double cx, double cy, double w, double h, Paint paint) {
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
    canvas.drawArc(rect, math.pi, math.pi, true, paint);
  }

  void _drawMinaret(Canvas canvas, double x, double totalH, double width, double bottom, Paint paint) {
    final spireH = 20.0;
    final shaftH = totalH - spireH;
    canvas.drawRect(Rect.fromLTWH(x, bottom - shaftH, width, shaftH), paint);

    final spire = Path()
      ..moveTo(x - 2, bottom - shaftH)
      ..lineTo(x + width / 2, bottom - totalH)
      ..lineTo(x + width + 2, bottom - shaftH)
      ..close();
    canvas.drawPath(spire, paint);
  }

  void _drawDetailedMinaret(Canvas canvas, double x, double totalH, double width, double bottom, Paint paint) {
    final spireH = 26.0;
    final shaftH = totalH - spireH;
    // Shaft
    canvas.drawRect(Rect.fromLTWH(x, bottom - shaftH, width, shaftH), paint);

    // Balcony 1
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 3.5, bottom - shaftH * 0.75, width + 7, 5),
        const Radius.circular(2),
      ),
      paint,
    );

    // Balcony 2 (Upper)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 3, bottom - shaftH, width + 6, 5),
        const Radius.circular(2),
      ),
      paint,
    );

    // Pointed Spire
    final spire = Path()
      ..moveTo(x - 1, bottom - shaftH - 5)
      ..lineTo(x + width / 2, bottom - totalH)
      ..lineTo(x + width + 1, bottom - shaftH - 5)
      ..close();
    canvas.drawPath(spire, paint);

    // Spire finial
    canvas.drawCircle(Offset(x + width / 2, bottom - totalH - 2), 2.2, paint);
  }

  void _drawCloud(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(Offset(center.dx - radius * 0.7, center.dy + radius * 0.25), radius * 0.65, paint);
    canvas.drawCircle(Offset(center.dx + radius * 0.75, center.dy + radius * 0.2), radius * 0.7, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double r, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + r, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + r)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - r, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - r)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
