import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Privacy Policy',
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
            // Header Banner
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
                      child: Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Privacy Matters',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Smart Silent operates 100% offline. We do not collect or track your personal data.',
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

            const SizedBox(height: 22),

            // Policy Sections
            _buildSectionCard(
              icon: Icons.storage_rounded,
              iconColor: const Color(0xFF0284C7),
              title: '1. Local Offline Storage',
              content:
                  'All your prayer schedules, meeting preferences, and time configurations are stored strictly on your local device storage using Hive database. No schedule data is ever sent to or stored on external cloud servers.',
            ),

            _buildSectionCard(
              icon: Icons.do_not_disturb_on_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: '2. Do Not Disturb (DND) Access',
              content:
                  'Smart Silent requires Android Do Not Disturb (Notification Policy) access exclusively to automate switching your ringer volume between Normal, Silent, and Vibrate modes. The app cannot read your messages, screen notifications, or call logs.',
            ),

            _buildSectionCard(
              icon: Icons.alarm_rounded,
              iconColor: const Color(0xFFD97706),
              title: '3. Exact Alarm Permissions',
              content:
                  'The exact alarm permission is used strictly to trigger your silent window at precise prayer and meeting minutes, and to restore normal sound mode immediately when your quiet interval ends.',
            ),

            _buildSectionCard(
              icon: Icons.person_off_rounded,
              iconColor: const Color(0xFF10B981),
              title: '4. Zero Personal Data Collection',
              content:
                  'We do not collect names, phone numbers, email addresses, device location history, audio, or contacts. You can use Smart Silent completely anonymously without creating an account.',
            ),

            _buildSectionCard(
              icon: Icons.ads_click_rounded,
              iconColor: const Color(0xFFEC4899),
              title: '5. Advertising & Third-Party SDKs',
              content:
                  'To keep this application free, Smart Silent uses Google AdMob to display banner advertisements. Google AdMob may use anonymized device identifiers in compliance with Google Play Developer Policies and privacy standards.',
            ),

            _buildSectionCard(
              icon: Icons.delete_forever_rounded,
              iconColor: const Color(0xFFEF4444),
              title: '6. Complete User Data Control',
              content:
                  'You have full control over your data. You can delete individual schedules at any time or use "Reset App Data" in Settings to instantly wipe all saved schedules and alarms from your phone.',
            ),

            const SizedBox(height: 20),

            // Footer Timestamp
            Center(
              child: Column(
                children: const [
                  Text(
                    'Last Updated: November 2026',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Smart Silent • Offline Mobile Utility',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFFCBD5E1),
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

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
