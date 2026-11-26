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
import 'package:smart_silent/Utils/one_time_alarm_helper.dart';
import 'package:smart_silent/Utils/sound_control_helper.dart';
import 'package:smart_silent/View/create_schedule.dart';
import 'package:smart_silent/models/schedule_model.dart';

class OneTime extends StatefulWidget {
  const OneTime({super.key});

  @override
  State<OneTime> createState() => _OneTimeState();
}

class _OneTimeState extends State<OneTime> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _cleanupLegacyAndExpiredSchedules();
    _initBannerAd();
  }

  void _cleanupLegacyAndExpiredSchedules() {
    try {
      final box = Boxes.getData();
      final now = DateTime.now();
      final toDelete = <dynamic>[];
      for (final item in box.values) {
        // Explicitly protect active schedules: if now is within [Start, End], NEVER delete
        final bool isCurrentlyActive =
            (now.isAfter(item.Start) || now.isAtSameMomentAs(item.Start)) && now.isBefore(item.End);
        if (isCurrentlyActive) continue;

        // Never touch recurring schedules (stored separately in 'daily' box)
        // Only clean up legacy quick-silent items or one-time schedules that ended in the past
        if (item.quickTime > 0 ||
            item.name.toLowerCase().contains('quick') ||
            item.End.isBefore(now)) {
          toDelete.add(item.key);
        }
      }
      for (final key in toDelete) {
        box.delete(key);
      }
    } catch (_) {}
  }

  void _initBannerAd() {
    final String adUnitId = AdHelper.bannerAdUnitId;
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: adUnitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[SmartSilent] OneTime BannerAd failed to load: $error');
          ad.dispose();
          _bannerAd = null;
          if (mounted) setState(() => _isAdLoaded = false);
        },
      ),
      request: const AdRequest(),
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  int _getAlarmId(ScheduleModel item) {
    return OneTimeAlarmHelper.getAlarmId(item);
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (dt.year == tomorrow.year && dt.month == tomorrow.month && dt.day == tomorrow.day) {
      return 'Tomorrow';
    }
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _toggleSchedule(ScheduleModel item, bool isActivated) async {
    setState(() {
      item.isTaskActivated = isActivated;
    });
    await item.save();

    if (isActivated) {
      await OneTimeAlarmHelper.scheduleOneTime(item);
      Fluttertoast.showToast(
        msg: "Schedule activated",
        backgroundColor: AppColors.kPrimary,
        textColor: Colors.white,
      );
    } else {
      await OneTimeAlarmHelper.cancelOneTime(item);
      Fluttertoast.showToast(
        msg: "Schedule deactivated",
        backgroundColor: const Color(0xFF64748B),
        textColor: Colors.white,
      );
    }
  }

  Future<void> _deleteSchedule(ScheduleModel item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 24),
              SizedBox(width: 10),
              Text(
                'Delete Schedule?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await OneTimeAlarmHelper.cancelOneTime(item);
    await item.delete();

    if (mounted) {
      final box = Boxes.getData();
      Provider.of<CountProvider>(context, listen: false).updateHasData(box.isNotEmpty);
    }

    Fluttertoast.showToast(
      msg: "Schedule deleted",
      backgroundColor: AppColors.kPrimary,
      textColor: Colors.white,
    );
  }

  void _openCreateOrEditScreen([ScheduleModel? schedule]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateSchedule(scheduleToEdit: schedule)),
    );
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
        backgroundColor: AppColors.kbg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'One-Time Schedules',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.kPrimary, size: 26),
              tooltip: 'Add Schedule',
              onPressed: () => _openCreateOrEditScreen(),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ValueListenableBuilder<Box<ScheduleModel>>(
                valueListenable: Boxes.getData().listenable(),
                builder: (context, box, _) {
                  final now = DateTime.now();
                  // Only display active or upcoming user-created schedules
                  final schedules = box.values
                      .where((item) =>
                          item.quickTime == 0 &&
                          !item.name.toLowerCase().contains('quick') &&
                          item.End.isAfter(now))
                      .toList()
                      .cast<ScheduleModel>();

                  if (schedules.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Sort schedules by start time ascending (soonest first)
                  schedules.sort((a, b) => a.Start.compareTo(b.Start));

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: schedules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final item = schedules[index];
                      return _buildScheduleCard(item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: _isAdLoaded && _bannerAd != null
            ? SafeArea(
                child: Container(
                  alignment: Alignment.center,
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  color: Colors.white,
                  child: AdWidget(ad: _bannerAd!),
                ),
              )
            : null,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openCreateOrEditScreen(),
          backgroundColor: AppColors.kPrimary,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          label: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'New Schedule',
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.kPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.event_note_rounded,
                  color: AppColors.kPrimary,
                  size: 46,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No One-Time Schedules',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Set a one-time quiet period for a specific appointment, exam, lecture, or quiet time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 2,
              ),
              onPressed: () => _openCreateOrEditScreen(),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Create One-Time Schedule',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(ScheduleModel item) {
    final now = DateTime.now();
    final bool isExpired = item.End.isBefore(now);
    final bool isCurrentlyActive = item.isTaskActivated &&
        (now.isAfter(item.Start) || now.isAtSameMomentAs(item.Start)) &&
        now.isBefore(item.End);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentlyActive
              ? AppColors.kPrimary.withOpacity(0.6)
              : const Color(0xFFE2E8F0),
          width: isCurrentlyActive ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title, active badge & Switch
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCurrentlyActive
                        ? AppColors.kPrimary.withOpacity(0.15)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.isSilentOrVibration ? Icons.vibration_rounded : Icons.volume_off_rounded,
                    color: isCurrentlyActive ? AppColors.kPrimary : const Color(0xFF64748B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isExpired ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                          decoration: isExpired ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatDate(item.Start),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isCurrentlyActive
                                  ? AppColors.kPrimary
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          if (isCurrentlyActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ACTIVE NOW',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: item.isTaskActivated,
                  activeColor: AppColors.kPrimary,
                  onChanged: (val) => _toggleSchedule(item, val),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Middle Row: Time range + Sound Mode Pill
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 5),
                      Text(
                        '${_formatTime(item.Start)}  →  ${_formatTime(item.End)}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isSilentOrVibration
                        ? const Color(0xFFF59E0B).withOpacity(0.12)
                        : AppColors.kPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.isSilentOrVibration ? 'Vibrate' : 'Silent',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: item.isSilentOrVibration
                          ? const Color(0xFFD97706)
                          : AppColors.kPrimary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Bottom Action Row: Edit & Delete Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Edit Button
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openCreateOrEditScreen(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: const [
                        Icon(Icons.edit_outlined, size: 16, color: AppColors.kPrimary),
                        SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.kPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Delete Button
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _deleteSchedule(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: const [
                        Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                        SizedBox(width: 4),
                        Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
