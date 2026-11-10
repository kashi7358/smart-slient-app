import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sound_mode/permission_handler.dart';

class Help extends StatefulWidget {
  const Help({super.key});

  @override
  State<Help> createState() => _HelpState();
}

class _HelpState extends State<Help> {
  int _selectedCategoryIndex = 0;

  final List<Map<String, dynamic>> _guides = [
    {
      'title': 'Prayer Times (Namaz)',
      'icon': Icons.mosque_rounded,
      'color': Color(0xFF0284C7),
      'steps': [
        {
          'number': '1',
          'title': 'Open Prayer Timings',
          'desc': 'Tap the Prayer card on the Home dashboard or open "Prayer Timings" from the side menu.',
        },
        {
          'number': '2',
          'title': 'Set Start & End Times',
          'desc': 'Tap any prayer (Fajr, Zuhr, Asr, Maghrib, Isha) to adjust the exact start and end time window.',
        },
        {
          'number': '3',
          'title': 'Select Mode (Silent or Vibrate)',
          'desc': 'Toggle between completely Silent Mode (0 volume) or discreet Vibrate Mode as per your preference.',
        },
        {
          'number': '4',
          'title': 'Automatic Daily Repeating',
          'desc': 'Once saved, Smart Silent automatically silences your phone every single day during prayer times and restores normal ringer mode right after.',
        },
      ],
    },
    {
      'title': 'Meeting Schedules',
      'icon': Icons.business_center_rounded,
      'color': Color(0xFF0D9488),
      'steps': [
        {
          'number': '1',
          'title': 'Create a New Meeting',
          'desc': 'Open "Meeting Schedules" from the drawer and tap the (+) Floating Action Button.',
        },
        {
          'number': '2',
          'title': 'Enter Name & Times',
          'desc': 'Provide a title (e.g. Office Standup, Class, Client Call) and pick the exact start and end times.',
        },
        {
          'number': '3',
          'title': 'Select Active Weekdays',
          'desc': 'Choose the days when this schedule should run (e.g. Monday to Friday).',
        },
        {
          'number': '4',
          'title': 'Instant On / Off Toggle',
          'desc': 'Toggle individual meetings on or off anytime. Alarms are updated and synchronized immediately in the background.',
        },
      ],
    },
    {
      'title': 'Quick Daily Silent',
      'icon': Icons.flash_on_rounded,
      'color': Color(0xFFD97706),
      'steps': [
        {
          'number': '1',
          'title': 'One-Tap Duration Pills',
          'desc': 'At the bottom of the Home or Meetings screen, tap any duration pill (5 Min, 10 Min, 30 Min, 1 Hour, 2 Hours).',
        },
        {
          'number': '2',
          'title': 'Immediate Silence',
          'desc': 'Your device silences instantly without having to manually open system settings.',
        },
        {
          'number': '3',
          'title': 'Auto-Restore Normal Volume',
          'desc': 'When the selected time expires, Smart Silent automatically switches your phone back to normal ringer volume.',
        },
      ],
    },
    {
      'title': 'Nearby Masjids',
      'icon': Icons.radar_rounded,
      'color': Color(0xFF8B5CF6),
      'steps': [
        {
          'number': '1',
          'title': 'Browse Masjids',
          'desc': 'Scroll horizontally on the "Nearby Masjids" row on the Home dashboard to see local mosques.',
        },
        {
          'number': '2',
          'title': 'Turn-by-Turn Navigation',
          'desc': 'Tap any mosque card or tap "Navigate" to immediately open Google Maps navigation to that mosque.',
        },
        {
          'number': '3',
          'title': 'Offline Mosque Directory',
          'desc': 'Even without an internet connection, Smart Silent provides a verified directory of masajid with walking distances.',
        },
      ],
    },
    {
      'title': 'Battery Optimization',
      'icon': Icons.battery_charging_full_rounded,
      'color': Color(0xFF10B981),
      'steps': [
        {
          'number': '1',
          'title': 'OEM App Sleeping Rules',
          'desc': 'Modern phones (Samsung, Xiaomi, Vivo, Oppo) aggressively close background apps when the screen is locked.',
        },
        {
          'number': '2',
          'title': 'Disable Battery Restrictions',
          'desc': 'Go to your phone\'s Settings > Apps > Smart Silent > Battery, and choose "Unrestricted" or "Don\'t optimize".',
        },
        {
          'number': '3',
          'title': 'Enable Autostart (Xiaomi / Vivo)',
          'desc': 'On MIUI / HyperOS and Funtouch OS, make sure "Autostart" is enabled so scheduled alarms fire on the exact minute.',
        },
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final activeGuide = _guides[_selectedCategoryIndex];
    final Color themeColor = activeGuide['color'] as Color;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
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
            'How to Use',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Top Executive Header Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
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
                      child: Icon(Icons.menu_book_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Smart Silent Guide',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Learn how to automate peaceful silent moments for prayers and daily focus.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withOpacity(0.92),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Category Chips (Horizontal Selector)
            const Text(
              'SELECT A TOPIC',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(_guides.length, (index) {
                  final item = _guides[index];
                  final isSelected = index == _selectedCategoryIndex;
                  final itemColor = item['color'] as Color;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategoryIndex = index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected ? itemColor : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? itemColor : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: itemColor.withOpacity(0.32),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : const [
                                BoxShadow(
                                  color: Color(0x06000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            size: 16,
                            color: isSelected ? Colors.white : itemColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item['title'] as String,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 20),

            // Active Guide Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(activeGuide['icon'] as IconData, color: themeColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          activeGuide['title'] as String,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 18),

                  // Steps list
                  ...((activeGuide['steps'] as List<Map<String, String>>).map((step) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: themeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: Text(
                                step['number'] ?? '1',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: themeColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step['title'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  step['desc'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList()),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick DND Settings Shortcut Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings_suggest_rounded, color: Color(0xFF0284C7), size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Need to configure Do Not Disturb permission?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await PermissionHandler.openDoNotDisturbSetting();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      backgroundColor: const Color(0xFF0284C7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Open Settings',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
}
