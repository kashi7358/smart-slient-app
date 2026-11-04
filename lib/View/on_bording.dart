import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_silent/View/tab_bar.dart';
import 'package:sound_mode/permission_handler.dart';

class OnBordingScreen extends StatefulWidget {
  const OnBordingScreen({super.key});

  @override
  State<OnBordingScreen> createState() => _OnBordingScreenState();
}

class _OnBordingScreenState extends State<OnBordingScreen> with WidgetsBindingObserver {
  final PageController _controller = PageController();
  bool _isWaitingForDnd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isWaitingForDnd) {
      _checkPermissionOnResume();
    }
  }

  Future<void> _checkPermissionOnResume() async {
    final bool isGranted = (await PermissionHandler.permissionsGranted) ?? false;
    if (!mounted) return;

    _isWaitingForDnd = false;
    if (isGranted) {
      Fluttertoast.showToast(
        msg: "Permission granted successfully!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      await _completeOnboarding();
    } else {
      Fluttertoast.showToast(
        msg: "Please allow Do Not Disturb permission to proceed",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showHome', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const TabBarDemo()),
    );
  }

  // Handle Screen 2 "Next" button click
  Future<void> _handleScreenTwoNext() async {
    final bool isGranted = (await PermissionHandler.permissionsGranted) ?? false;
    if (isGranted) {
      await _completeOnboarding();
    } else {
      if (!mounted) return;
      _showDndPermissionDialog();
    }
  }

  // Permission popup dialog
  void _showDndPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF389EB4).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.do_not_disturb_on_rounded,
                  color: Color(0xFF389EB4),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Permission Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Smart Silent needs "Do Not Disturb" access to automatically silence and restore your phone during scheduled prayer times and meetings.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                  height: 1.45,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Please allow this permission in system settings to continue.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Fluttertoast.showToast(
                  msg: "DND permission is required to continue!",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                );
              },
              child: const Text(
                'Not Now',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF389EB4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                elevation: 0,
              ),
              onPressed: () async {
                _isWaitingForDnd = true;
                Navigator.of(dialogContext).pop();
                await PermissionHandler.openDoNotDisturbSetting();
              },
              child: const Text(
                'Allow Permission',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF8CE5FE),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: WillPopScope(
        onWillPop: () async {
          if (_controller.page != null && _controller.page! > 0.5) {
            _controller.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            return false;
          }
          return true;
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF8CE5FE),
          body: Stack(
            children: [
              // Background subtle concentric ripple waves and sparkles
              Positioned.fill(
                child: CustomPaint(
                  painter: _WaveBackgroundPainter(),
                ),
              ),
              SafeArea(
                top: true,
                bottom: true,
                child: PageView(
                  controller: _controller,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildPageOne(size),
                    _buildPageTwo(size),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Screen 1: Welcome
  Widget _buildPageOne(Size size) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildPageLayout(
          size: size,
          constraints: constraints,
          imagePath: 'assets/images/onboarding 1.png',
          title: 'Welcome',
          subtitleWidget: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
            child: Text(
              'Keep Your Phone Silent when you are busy and\nstay safe from embarrasing moments',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: (size.width * 0.038).clamp(13.0, 16.0),
                color: const Color(0xFF334155),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          buttonLabel: 'Get Started',
          onButtonPressed: () {
            _controller.nextPage(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOut,
            );
          },
        );
      },
    );
  }

  // Screen 2: Do Not Disturb Access
  Widget _buildPageTwo(Size size) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildPageLayout(
          size: size,
          constraints: constraints,
          imagePath: 'assets/images/onboarding 2.png',
          title: 'Do Not Disturb Access',
          subtitleWidget: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
            child: Column(
              children: [
                Text(
                  'We need this Permissions only for the first time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: (size.width * 0.034).clamp(12.0, 15.0),
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Please Allow don't distrub mode. Otherwise\nApp may not work Properly.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: (size.width * 0.036).clamp(13.0, 15.5),
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          buttonLabel: 'Next',
          onButtonPressed: _handleScreenTwoNext,
        );
      },
    );
  }

  // Shared responsive page layout: centers image cleanly and ensures safe area is never violated
  Widget _buildPageLayout({
    required Size size,
    required BoxConstraints constraints,
    required String imagePath,
    required String title,
    required Widget subtitleWidget,
    required String buttonLabel,
    required VoidCallback onButtonPressed,
  }) {
    // For normal/large screens, use Flex Column with Expanded to perfectly center the image
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Hero Illustration Image - Centered horizontally and vertically
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.45,
                  maxWidth: constraints.maxWidth * 0.85,
                ),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: (size.width * 0.072).clamp(22.0, 28.0),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Subtitle
          subtitleWidget,
          const SizedBox(height: 28),
          // Action Button
          _buildActionButton(
            label: buttonLabel,
            size: size,
            onTap: onButtonPressed,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );

    // If device height is exceptionally small (e.g. landscape or small phone), wrap in scroll view
    if (constraints.maxHeight < 520) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: content),
        ),
      );
    }

    return content;
  }

  // Reusable custom rounded action button with arrow icon
  Widget _buildActionButton({
    required String label,
    required Size size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size.width * 0.58,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF389EB4),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter to render subtle background wave arcs and sparkles matching the design
class _WaveBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Concentric wave arcs from top area
    final center = Offset(size.width * 0.15, size.height * 0.08);
    canvas.drawCircle(center, size.width * 0.45, strokePaint);
    canvas.drawCircle(center, size.width * 0.72, strokePaint);
    canvas.drawCircle(center, size.width * 1.02, strokePaint);

    // Decorative sparkles / diamond stars
    final starPaint = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..style = PaintingStyle.fill;

    _drawSparkle(canvas, Offset(size.width * 0.12, size.height * 0.18), 4.5, starPaint);
    _drawSparkle(canvas, Offset(size.width * 0.22, size.height * 0.18), 3.0, starPaint);
    _drawSparkle(canvas, Offset(size.width * 0.84, size.height * 0.18), 4.5, starPaint);
    _drawSparkle(canvas, Offset(size.width * 0.94, size.height * 0.18), 3.0, starPaint);
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.55, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.55, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
