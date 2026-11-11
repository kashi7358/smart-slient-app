import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_silent/Boxes/boxes.dart';
import 'package:smart_silent/Provider/count_provider.dart';
import 'package:smart_silent/Utils/device_compatibility_helper.dart';
import 'package:smart_silent/Utils/meeting_alarm_helper.dart';
import 'package:smart_silent/Utils/prayer_alarm_helper.dart';
import 'package:smart_silent/View/create_nemaz.dart';
import 'package:smart_silent/View/help.dart';
import 'package:smart_silent/View/on_bording.dart';
import 'package:smart_silent/View/privacy_policy.dart';
import 'package:smart_silent/models/nemaz_model.dart';
import 'package:smart_silent/models/repeated_model.dart';
import 'package:smart_silent/models/schedule_model.dart';
import 'package:sound_mode/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'package:url_launcher/url_launcher.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> with WidgetsBindingObserver {
  bool _isDndGranted = false;
  bool _isBatteryOptimizedIgnored = false;
  bool _canExactAlarms = true;
  String _deviceManufacturer = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    try {
      final dnd = (await PermissionHandler.permissionsGranted) ?? false;
      final battery = await DeviceCompatibilityHelper.isIgnoringBatteryOptimizations();
      final exact = await DeviceCompatibilityHelper.canScheduleExactAlarms();
      final manufacturer = await DeviceCompatibilityHelper.getDeviceManufacturer();
      if (mounted) {
        setState(() {
          _isDndGranted = dnd;
          _isBatteryOptimizedIgnored = battery;
          _canExactAlarms = exact;
          _deviceManufacturer = manufacturer;
        });
      }
    } catch (_) {}
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Reset All Data?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text(
            'This will cancel all active silent alarms, clear saved prayer times and meeting schedules, and reset preferences to default. This action cannot be undone.',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _performReset();
            },
            child: const Text('Reset Everything', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _performReset() async {
    try {
      // 1. Cancel all active system alarms in Android OS
      await PrayerAlarmHelper.cancelAllPrayers();
      await MeetingAlarmHelper.cancelAllMeetings();
      try {
        await SoundMode.setSoundMode(RingerModeStatus.normal);
      } catch (_) {}

      // 2. Clear all Hive database boxes
      final box = await Hive.openBox<ScheduleModel>('schedules');
      await box.clear();
      final box2 = await Hive.openBox<RepeatedModel>('daily');
      await box2.clear();
      final box3 = await Hive.openBox<NemazModel>('nemaz');
      await box3.clear();

      // 3. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('showHome');
      await prefs.remove('prayer_alarms_enabled');
      await prefs.remove('prayer_vibrate_mode');

      if (mounted) {
        Provider.of<CountProvider>(context, listen: false).updateHasData(false);
        Fluttertoast.showToast(msg: "All data & alarms reset successfully!");
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const OnBordingScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Reset failed: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.08),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(context),
                child: const Center(
                  child: Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
                ),
              ),
            ),
          ),
          title: const Text(
            'Settings',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Human-Designed Executive Status Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.notifications_active_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Smart Silent Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Automatically silencing phone during prayers & schedules',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section: CORE PERMISSION & RELIABILITY
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'SYSTEM PERMISSIONS & COMPATIBILITY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
            ),

            // 1. Do Not Disturb Permission Card
            _buildHumanCard(
              icon: Icons.do_not_disturb_on_rounded,
              iconColor: const Color(0xFF0284C7),
              iconBgColor: const Color(0xFFE0F2FE),
              title: 'Do Not Disturb (DND) Access',
              subtitle: _isDndGranted
                  ? 'Permission active. Device will silence automatically.'
                  : 'Tap to allow. Required for automated silent switching.',
              trailingWidget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isDndGranted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isDndGranted ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 13,
                      color: _isDndGranted ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isDndGranted ? 'Allowed' : 'Configure',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isDndGranted ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () async {
                await PermissionHandler.openDoNotDisturbSetting();
                await Future.delayed(const Duration(milliseconds: 500));
                _checkAllPermissions();
              },
            ),

            const SizedBox(height: 10),

            // 2. Battery Optimization (Unrestricted) Card
            _buildHumanCard(
              icon: Icons.battery_charging_full_rounded,
              iconColor: const Color(0xFF10B981),
              iconBgColor: const Color(0xFFD1FAE5),
              title: 'Battery Optimization',
              subtitle: _isBatteryOptimizedIgnored
                  ? 'Unrestricted background active. Alarms will fire on time.'
                  : 'Tap to allow unrestricted battery. Prevents Android from killing alarms.',
              trailingWidget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isBatteryOptimizedIgnored ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isBatteryOptimizedIgnored ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 13,
                      color: _isBatteryOptimizedIgnored ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isBatteryOptimizedIgnored ? 'Allowed' : 'Configure',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isBatteryOptimizedIgnored ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () async {
                await DeviceCompatibilityHelper.requestIgnoreBatteryOptimizations();
                await Future.delayed(const Duration(milliseconds: 500));
                _checkAllPermissions();
              },
            ),

            // 3. Exact Alarms Card (Only shown if permission is missing / blocked)
            if (!_canExactAlarms)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _buildHumanCard(
                  icon: Icons.alarm_on_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBgColor: const Color(0xFFEDE9FE),
                  title: 'Exact Alarms Permission',
                  subtitle: 'Tap to allow exact alarms so prayers & meetings trigger right on time.',
                  trailingWidget: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: Color(0xFFD97706),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Configure',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                  onTap: () async {
                    await DeviceCompatibilityHelper.requestScheduleExactAlarm();
                    await Future.delayed(const Duration(milliseconds: 500));
                    _checkAllPermissions();
                  },
                ),
              ),

            const SizedBox(height: 10),

            // 4. Brand Autostart & Background Guide (Only shown if manufacturer is known and supported)
            if (_deviceManufacturer.isNotEmpty &&
                _deviceManufacturer.toLowerCase() != 'unknown' &&
                !_deviceManufacturer.toLowerCase().contains('unknown'))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildHumanCard(
                  icon: Icons.phonelink_setup_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  iconBgColor: const Color(0xFFFEF3C7),
                  title: '$_deviceManufacturer Background Settings',
                  subtitle: 'Allow Autostart & lock app in memory to prevent your phone from killing silent mode.',
                  trailingWidget: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  onTap: () async {
                    await DeviceCompatibilityHelper.openAutoStartSettings();
                  },
                ),
              ),

            const SizedBox(height: 10),

            // Section: SCHEDULES & SHORTCUTS
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'QUICK SHORTCUTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
            ),

            // Prayer Timings Shortcut Card
            _buildHumanCard(
              icon: Icons.mosque_rounded,
              iconColor: const Color(0xFF0D9488),
              iconBgColor: const Color(0xFFCCFBF1),
              title: 'Prayer Timings & Preferences',
              subtitle: 'Configure daily silent window for Fajr, Zuhr, Asr, Maghrib, and Isha.',
              trailingWidget: const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Color(0xFF94A3B8)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateNemaz()),
                );
              },
            ),

            const SizedBox(height: 10),

            // Help & Guide Card
            _buildHumanCard(
              icon: Icons.help_outline_rounded,
              iconColor: const Color(0xFF8B5CF6),
              iconBgColor: const Color(0xFFEDE9FE),
              title: 'Help & User Guide',
              subtitle: 'Learn how automated silence scheduler works and troubleshooting tips.',
              trailingWidget: const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Color(0xFF94A3B8)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Help()),
                );
              },
            ),

            const SizedBox(height: 20),

            // Section: DATA & PRIVACY
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'DATA & PRIVACY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
            ),

            // Privacy Policy Card
            _buildHumanCard(
              icon: Icons.privacy_tip_outlined,
              iconColor: const Color(0xFF059669),
              iconBgColor: const Color(0xFFD1FAE5),
              title: 'Privacy Policy',
              subtitle: 'Learn how your data is protected offline on your device.',
              trailingWidget: const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Color(0xFF94A3B8)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                );
              },
            ),

            const SizedBox(height: 10),

            // Reset App Data Card (Danger Zone)
            _buildHumanCard(
              icon: Icons.restart_alt_rounded,
              iconColor: const Color(0xFFEF4444),
              iconBgColor: const Color(0xFFFEE2E2),
              title: 'Reset App Data',
              subtitle: 'Cancel all active alarms and restore initial defaults.',
              trailingWidget: const Icon(Icons.chevron_right_rounded, color: Color(0xFFEF4444), size: 22),
              onTap: () => _showResetConfirmation(context),
            ),

            const SizedBox(height: 36),

            // Human Touch App Footer
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Smart Silent • v1.0.7',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Crafted for peaceful prayer and focused moments',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHumanCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    Widget? trailingWidget,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(icon, color: iconColor, size: 23),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailingWidget != null) ...[
                  const SizedBox(width: 10),
                  trailingWidget,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
