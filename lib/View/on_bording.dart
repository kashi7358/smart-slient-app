import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_silent/constants.dart';
import 'package:smart_silent/Utils/device_compatibility_helper.dart';
import 'package:smart_silent/View/tab_bar.dart';
import 'package:sound_mode/permission_handler.dart';

class OnBordingScreen extends StatefulWidget {
  const OnBordingScreen({super.key});

  @override
  State<OnBordingScreen> createState() => _OnBordingScreenState();
}

class _OnBordingScreenState extends State<OnBordingScreen> with WidgetsBindingObserver {
  final PageController _controller = PageController();
  int _currentPage = 0;

  bool _isDndGranted = false;
  bool _isBatteryOptimized = false;
  bool _canExactAlarms = true;
  bool _showExactAlarmCard = false;
  String _deviceBrand = 'Android';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _fetchDeviceBrand();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _fetchDeviceBrand() async {
    final brand = await DeviceCompatibilityHelper.getDeviceManufacturer();
    if (mounted) {
      setState(() {
        _deviceBrand = brand;
      });
    }
  }

  Future<void> _checkPermissions() async {
    bool dnd = false;
    try {
      dnd = (await PermissionHandler.permissionsGranted.timeout(
            const Duration(milliseconds: 1500),
            onTimeout: () => false,
          )) ??
          false;
    } catch (_) {
      dnd = false;
    }

    if (!dnd) {
      dnd = await DeviceCompatibilityHelper.hasDndPermission();
    }

    final bool battery = await DeviceCompatibilityHelper.isIgnoringBatteryOptimizations();
    final bool exact = await DeviceCompatibilityHelper.canScheduleExactAlarms();

    if (mounted) {
      setState(() {
        _isDndGranted = dnd;
        _isBatteryOptimized = battery;
        _canExactAlarms = exact;
        if (!exact) _showExactAlarmCard = true;
      });
    }
  }

  Future<void> _finishOnboardingToHome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showHome', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const TabBarDemo(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  Future<void> _requestDndPermission() async {
    await DeviceCompatibilityHelper.openDndSettings();
  }

  Future<void> _requestExactAlarmPermission() async {
    await DeviceCompatibilityHelper.requestScheduleExactAlarm();
  }

  Future<void> _requestBatteryOptimization() async {
    await DeviceCompatibilityHelper.requestIgnoreBatteryOptimizations();
  }

  Future<void> _openAutoStart() async {
    final opened = await DeviceCompatibilityHelper.openAutoStartSettings();
    if (!opened && mounted) {
      Fluttertoast.showToast(
        msg: "Please allow background activity in system settings",
        backgroundColor: const Color(0xFF1E293B),
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFFF8FAFC),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: [
                    _buildWelcomePage(),
                    _buildPermissionsPage(),
                  ],
                ),
              ),
              _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  // Screen 1: Welcome & Value Proposition
  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          // App Logo / Icon Header
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.kPrimary, Color(0xFF2B7A8D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.kPrimary.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_off_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Smart Silent',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Automate your silent hours with pinpoint precision. Never face embarrassing rings during prayer or work.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 32),

          // Feature Highlights
          _buildFeatureTile(
            icon: Icons.mosque_rounded,
            iconColor: AppColors.kPrimary,
            title: 'Prayer Times (Namaz)',
            subtitle: 'Auto-silences during all 5 prayers based on your local mosque or prayer schedule.',
          ),
          const SizedBox(height: 14),
          _buildFeatureTile(
            icon: Icons.business_center_rounded,
            iconColor: const Color(0xFF0284C7),
            title: 'Meetings & Focused Work',
            subtitle: 'Sync quiet hours for recurring office meetings, lectures, and busy hours.',
          ),
          const SizedBox(height: 14),
          _buildFeatureTile(
            icon: Icons.timer_outlined,
            iconColor: const Color(0xFF8B5CF6),
            title: 'One-Time Quiet Windows',
            subtitle: 'Quickly set custom one-off silent periods with optional vibration mode.',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
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
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Screen 2: Reliability & Permissions Hub
  Widget _buildPermissionsPage() {
    final String brandLower = _deviceBrand.toLowerCase();
    String autoStartTitle = 'Exact Background Alarms';
    String autoStartDesc = 'Ensures scheduled timers trigger at the exact second even when locked.';

    if (brandLower.contains('xiaomi') || brandLower.contains('redmi') || brandLower.contains('poco')) {
      autoStartTitle = 'MIUI / HyperOS Auto-Start';
      autoStartDesc = 'Enable Auto-Start in Xiaomi settings so alarms are never killed in background.';
    } else if (brandLower.contains('vivo') || brandLower.contains('iqoo')) {
      autoStartTitle = 'Vivo Auto-Start';
      autoStartDesc = 'Enable background startup in Vivo permission manager for reliable timing.';
    } else if (brandLower.contains('oppo') || brandLower.contains('realme') || brandLower.contains('oneplus')) {
      autoStartTitle = 'ColorOS Startup App';
      autoStartDesc = 'Allow startup in ColorOS Security Center so prayer alarms trigger on time.';
    } else if (brandLower.contains('samsung')) {
      autoStartTitle = 'Samsung Device Care';
      autoStartDesc = 'Exclude Smart Silent from Sleeping Apps for uninterrupted silent transitions.';
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.kPrimary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: AppColors.kPrimary,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Permissions & Reliability',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Grant essential permissions below so Smart Silent can switch your sound profiles accurately on time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Card 1: Do Not Disturb Mode (Essential)
          _buildPermissionCard(
            icon: Icons.do_not_disturb_on_rounded,
            iconColor: AppColors.kPrimary,
            title: 'Do Not Disturb Access',
            badgeText: 'REQUIRED',
            badgeColor: const Color(0xFFE0F2FE),
            badgeTextColor: const Color(0xFF0369A1),
            subtitle: 'Allows Smart Silent to automatically switch ringer between Silent, Vibrate & Normal.',
            isGranted: _isDndGranted,
            grantedText: 'Granted',
            actionText: 'Grant Access',
            onTap: _requestDndPermission,
          ),
          const SizedBox(height: 14),

          // Card 2: Background Reliability (Battery Optimization)
          _buildPermissionCard(
            icon: Icons.battery_charging_full_rounded,
            iconColor: const Color(0xFF0284C7),
            title: 'Background Reliability',
            badgeText: 'RECOMMENDED',
            badgeColor: const Color(0xFFF1F5F9),
            badgeTextColor: const Color(0xFF475569),
            subtitle: 'Prevents Android from stopping your scheduled prayer or meeting timers when screen is off.',
            isGranted: _isBatteryOptimized,
            grantedText: 'Optimized',
            actionText: 'Allow',
            onTap: _requestBatteryOptimization,
          ),
          const SizedBox(height: 14),

          // Card 2b: Exact Alarms (only when permission is missing)
          if (_showExactAlarmCard || !_canExactAlarms) ...[
            _buildPermissionCard(
              icon: Icons.alarm_on_rounded,
              iconColor: AppColors.kPrimaryLight,
              title: 'Exact Alarms Access',
              badgeText: 'REQUIRED',
              badgeColor: AppColors.kSecondary,
              badgeTextColor: AppColors.kPrimary,
              subtitle: 'Ensures prayer and meeting silent timers trigger at the exact scheduled minute.',
              isGranted: _canExactAlarms,
              grantedText: 'Granted',
              actionText: 'Allow',
              onTap: _requestExactAlarmPermission,
            ),
            const SizedBox(height: 14),
          ],

          // Card 3: Auto-Start / OEM Settings
          _buildPermissionCard(
            icon: Icons.phonelink_setup_rounded,
            iconColor: const Color(0xFF6366F1),
            title: autoStartTitle,
            badgeText: _deviceBrand.toUpperCase(),
            badgeColor: const Color(0xFFEEF2FF),
            badgeTextColor: const Color(0xFF4F46E5),
            subtitle: autoStartDesc,
            isGranted: false, // Manufacturer settings cannot be read directly; tapping guides user
            grantedText: 'Configured',
            actionText: 'Configure',
            forceAction: true,
            onTap: _openAutoStart,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required String subtitle,
    required bool isGranted,
    required String grantedText,
    required String actionText,
    required VoidCallback onTap,
    bool forceAction = false,
  }) {
    final bool showGranted = isGranted && !forceAction;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: showGranted ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFE2E8F0),
          width: showGranted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: badgeTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (showGranted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        grantedText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onTap,
                  child: Text(
                    actionText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // Bottom Navigation Controls
  Widget _buildBottomNavigation() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(
          color: AppColors.kbg,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Page Indicator Dots
            Row(
              children: List.generate(2, (index) {
                final bool isActive = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 6),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.kPrimary : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(width: 12),

            // Action Button
            Flexible(
              child: _currentPage == 0
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Get Started',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDndGranted ? AppColors.kPrimary : const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        if (!_isDndGranted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Please grant "Do Not Disturb" permission to enable automatic silent schedules.'),
                              backgroundColor: const Color(0xFF1E293B),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              action: SnackBarAction(
                                label: 'Grant',
                                textColor: AppColors.kPrimaryLight,
                                onPressed: _requestDndPermission,
                              ),
                            ),
                          );
                          _finishOnboardingToHome();
                        } else {
                          _finishOnboardingToHome();
                        }
                      },
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Continue to App',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.check_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
