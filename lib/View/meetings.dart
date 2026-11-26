import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:smart_silent/Utils/ad_helper.dart';
import 'package:smart_silent/constants.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:smart_silent/Boxes/boxes.dart';
import 'package:smart_silent/Provider/count_provider.dart';
import 'package:smart_silent/Utils/meeting_alarm_helper.dart';
import 'package:smart_silent/Utils/sound_control_helper.dart';
import 'package:smart_silent/View/create_daily.dart';
import 'package:smart_silent/View/tab_bar.dart';
import 'package:smart_silent/models/repeated_model.dart';
import 'package:smart_silent/models/schedule_model.dart';
import 'package:sound_mode/permission_handler.dart';

class Repeated extends StatefulWidget {
  const Repeated({super.key});

  @override
  State<Repeated> createState() => _RepeatedState();
}

class _RepeatedState extends State<Repeated> {
  late BannerAd _bannerAd;
  bool isAdLoaded = false;

  void initBannerAd() {
    final adsId = AdHelper.bannerAdUnitId;
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: adsId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[SmartSilent] Meetings BannerAd failed to load: $error');
        },
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
    try {
      if (isAdLoaded) {
        _bannerAd.dispose();
      }
    } catch (_) {}
    super.dispose();
  }

  String _formatTime12h(DateTime dt) {
    final int h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final String m = dt.minute.toString().padLeft(2, '0');
    final String period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  Future<void> _openEditSchedule(RepeatedModel item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateDaily(existingSchedule: item),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CountProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.kbg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Meeting Schedules',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ValueListenableBuilder<Box<RepeatedModel>>(
            valueListenable: Boxes.getDataforDaily().listenable(),
            builder: (context, box, _) {
              if (box.isNotEmpty) {
                final data = box.values.toList().cast<RepeatedModel>();

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 10, bottom: 240),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    final days = (item.dayInWeek != null && item.dayInWeek!.isNotEmpty)
                        ? item.dayInWeek!
                        : [0, 1, 2, 3, 4, 5, 6];

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: item.isTaskActivated
                              ? AppColors.kPrimary.withOpacity(0.25)
                              : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: item.isTaskActivated
                                ? AppColors.kPrimary.withOpacity(0.08)
                                : const Color(0x080F172A),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _openEditSchedule(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            // Top Row: Icon + Title + Status Badge + Switch + Popup Menu
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: item.isTaskActivated
                                        ? AppColors.kPrimary.withOpacity(0.12)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.business_center_rounded,
                                      color: item.isTaskActivated
                                          ? AppColors.kPrimary
                                          : const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: item.isTaskActivated
                                              ? const Color(0xFF0F172A)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: item.isTaskActivated
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF94A3B8),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            item.isTaskActivated ? 'Active' : 'Disabled',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: item.isTaskActivated
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: item.isTaskActivated,
                                  onChanged: (value) async {
                                    setState(() => item.isTaskActivated = value);
                                    await item.save();
                                    await MeetingAlarmHelper.syncAllMeetings();
                                  },
                                  activeTrackColor: AppColors.kPrimary.withOpacity(0.4),
                                  activeColor: AppColors.kPrimary,
                                ),
                                PopupMenuButton<int>(
                                  onSelected: (val) {
                                    if (val == 1) {
                                      _deleteSchedule(item);
                                    } else if (val == 2) {
                                      _openEditSchedule(item);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 2,
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18, color: AppColors.kPrimary),
                                          SizedBox(width: 8),
                                          Text("Edit", style: TextStyle(color: AppColors.kPrimary, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 1,
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                          SizedBox(width: 8),
                                          Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                              ],
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                            ),

                            // Middle Row: Time pill + Vibrate/Silent badge (Wrap prevents any screen width overflow)
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 13, color: AppColors.kPrimary),
                                      const SizedBox(width: 5),
                                      Text(
                                        "${_formatTime12h(item.Start)} - ${_formatTime12h(item.End)}",
                                        style: const TextStyle(
                                          color: Color(0xFF334155),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: item.isSilentOrVibration
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFCCFBF1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        item.isSilentOrVibration ? Icons.vibration_rounded : Icons.volume_off_rounded,
                                        size: 12,
                                        color: item.isSilentOrVibration ? const Color(0xFFD97706) : const Color(0xFF0D9488),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        item.isSilentOrVibration ? "Vibrate" : "Silent",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: item.isSilentOrVibration ? const Color(0xFFD97706) : const Color(0xFF0D9488),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Bottom Row: Days pills wrapped nicely to prevent overflow
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: List.generate(7, (dayIdx) {
                                final dayNames = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                                final isSelected = days.contains(dayIdx);
                                return Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.kPrimary : const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      dayNames[dayIdx],
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                        ),
                      ),
                    );
                  },
                );
              } else {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.kPrimary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            size: 40,
                            color: AppColors.kPrimary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'No Meeting Schedules Yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Set up repeating silent schedules for your work meetings, university classes, or appointments.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF64748B),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CreateDaily()),
                            );
                          },
                          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                          label: const Text(
                            'Add Meeting Schedule',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.kPrimary,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),

          // Bottom Quick Daily Silent with Raised Floating Action Button (+) matching Home UI
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomQuickDailySilentWithFab(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomQuickDailySilentWithFab(CountProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Raised FAB (+) positioned cleanly above Quick Daily Silent sheet
        Padding(
          padding: const EdgeInsets.only(right: 22, bottom: 14),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateDaily()),
                );
              },
              customBorder: const CircleBorder(),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.kPrimary, AppColors.kPrimaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.kPrimary.withOpacity(0.38),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 18,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'Quick Daily Silent',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildQuickDailyPill(label: '5 Min', minutes: 5, provider: provider),
                      _buildQuickDailyPill(label: '10 Min', minutes: 10, provider: provider),
                      _buildQuickDailyPill(label: '30 Min', minutes: 30, provider: provider),
                      _buildQuickDailyPill(label: '1 Hour', minutes: 60, provider: provider),
                      _buildQuickDailyPill(label: '2 Hour', minutes: 120, provider: provider),
                      _buildQuickDailyPill(label: '3 Hour', minutes: 180, provider: provider),
                    ],
                  ),
                ),
                if (isAdLoaded) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: SizedBox(
                      height: _bannerAd.size.height.toDouble(),
                      width: _bannerAd.size.width.toDouble(),
                      child: AdWidget(ad: _bannerAd),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickDailyPill({
    required String label,
    required int minutes,
    required CountProvider provider,
  }) {
    return GestureDetector(
      onTap: () => _activateQuickDailySilent(minutes, label, provider),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        height: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.kPrimary, AppColors.kPrimaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.kPrimary.withOpacity(0.28),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _activateQuickDailySilent(int minutes, String label, CountProvider provider) async {
    final startTime = DateTime.now();
    final endTime = startTime.add(Duration(minutes: minutes));
    final int epochSeconds = startTime.millisecondsSinceEpoch ~/ 1000;
    final int alarmIdStart = 40000 + (epochSeconds % 9000);
    final int alarmIdEnd = alarmIdStart + 1000;

    try {
      await SoundControlHelper.enterSilentWindow(
        sourceId: 'quick_silent',
        endTime: endTime,
        vibrate: false,
        endAlarmId: alarmIdEnd,
      );
    } catch (_) {}

    try {
      await AndroidAlarmManager.oneShotAt(
        endTime,
        alarmIdEnd,
        restoreNormalModeCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: true,
      );
    } catch (_) {
      try {
        await AndroidAlarmManager.oneShotAt(
          endTime,
          alarmIdEnd,
          restoreNormalModeCallback,
          exact: false,
          wakeup: true,
          allowWhileIdle: true,
          rescheduleOnReboot: true,
        );
      } catch (_) {}
    }

    Fluttertoast.showToast(
      msg: 'Phone silenced for $label!',
      toastLength: Toast.LENGTH_SHORT,
      backgroundColor: AppColors.kPrimary,
      textColor: Colors.white,
    );
  }

  void _deleteSchedule(RepeatedModel item) async {
    await item.delete();
    await MeetingAlarmHelper.syncAllMeetings();
    Fluttertoast.showToast(msg: "Schedule deleted");
  }
}
