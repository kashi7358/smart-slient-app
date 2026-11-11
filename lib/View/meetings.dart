import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:smart_silent/Boxes/boxes.dart';
import 'package:smart_silent/Provider/count_provider.dart';
import 'package:smart_silent/Utils/meeting_alarm_helper.dart';
import 'package:smart_silent/View/create_daily.dart';
import 'package:smart_silent/models/repeated_model.dart';
import 'package:sound_mode/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

class Repeated extends StatefulWidget {
  const Repeated({super.key});

  @override
  State<Repeated> createState() => _RepeatedState();
}

class _RepeatedState extends State<Repeated> {
  final nameController = TextEditingController();
  DateTime startDateTime = DateTime.now();
  DateTime endDateTime = DateTime.now().add(const Duration(hours: 1));
  bool isSilentOrVibration = false;

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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CountProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                  padding: const EdgeInsets.only(top: 10, bottom: 180),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    final days = item.dayInWeek ?? [0, 1, 2, 3, 4, 5, 6];

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: item.isTaskActivated
                              ? const Color(0xFF389EB4).withOpacity(0.25)
                              : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: item.isTaskActivated
                                ? const Color(0xFF389EB4).withOpacity(0.08)
                                : const Color(0x080F172A),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
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
                                        ? const Color(0xFF389EB4).withOpacity(0.12)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.business_center_rounded,
                                      color: item.isTaskActivated
                                          ? const Color(0xFF389EB4)
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
                                  activeTrackColor: const Color(0xFF389EB4).withOpacity(0.4),
                                  activeColor: const Color(0xFF389EB4),
                                ),
                                PopupMenuButton<int>(
                                  onSelected: (val) {
                                    if (val == 1) {
                                      _deleteSchedule(item);
                                    } else if (val == 2) {
                                      _showEditDialog(item);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 2,
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18, color: Color(0xFF389EB4)),
                                          SizedBox(width: 8),
                                          Text("Edit", style: TextStyle(color: Color(0xFF389EB4), fontWeight: FontWeight.bold)),
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

                            // Middle Row: Time pill + Vibrate/Silent badge
                            Row(
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
                                      const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF389EB4)),
                                      const SizedBox(width: 5),
                                      Text(
                                        "${item.Start.hour.toString().padLeft(2, '0')}:${item.Start.minute.toString().padLeft(2, '0')} - ${item.End.hour.toString().padLeft(2, '0')}:${item.End.minute.toString().padLeft(2, '0')}",
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
                                const SizedBox(width: 8),
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

                            // Bottom Row: Days pills aligned nicely across
                            Row(
                              children: List.generate(7, (dayIdx) {
                                final dayNames = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                                final isSelected = days.contains(dayIdx);
                                return Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF389EB4) : const Color(0xFFF1F5F9),
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
                            color: const Color(0xFF389EB4).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            size: 40,
                            color: Color(0xFF389EB4),
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
                            backgroundColor: const Color(0xFF389EB4),
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
    final double bannerHeight = isAdLoaded ? _bannerAd.size.height.toDouble() : 0.0;
    final double sheetHeight = 94.0 + (isAdLoaded ? bannerHeight + 10.0 : 0.0);
    final double totalHeight = sheetHeight + 25.0;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
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

          // Raised FAB (+) aligned comfortably right above Quick Daily card (matching Home screen)
          Positioned(
            bottom: sheetHeight - 25.0,
            right: 22,
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
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF389EB4),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF389EB4).withOpacity(0.42),
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
        ],
      ),
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
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF389EB4),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF389EB4).withOpacity(0.28),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  void _activateQuickDailySilent(int minutes, String label, CountProvider provider) async {
    final startTime = DateTime.now();
    final endTime = startTime.add(Duration(minutes: minutes));

    final data = RepeatedModel(
      name: 'Quick $label daily',
      Start: startTime,
      End: endTime,
      isSilentOrVibration: false,
      isTaskActivated: true,
      quickTime: minutes,
      dayInWeek: [0, 1, 2, 3, 4, 5, 6],
    );

    final box = Boxes.getDataforDaily();
    await box.add(data);
    provider.updateHasData(box.isNotEmpty);

    await MeetingAlarmHelper.syncAllMeetings();

    // Immediately trigger silent mode
    try {
      await SoundMode.setSoundMode(RingerModeStatus.silent);
    } catch (_) {
      try {
        await SoundMode.setSoundMode(RingerModeStatus.vibrate);
      } catch (_) {}
    }

    Fluttertoast.showToast(
      msg: 'Quick $label Daily Silent activated!',
      toastLength: Toast.LENGTH_SHORT,
      backgroundColor: const Color(0xFF389EB4),
      textColor: Colors.white,
    );
  }

  void _deleteSchedule(RepeatedModel item) async {
    await item.delete();
    await MeetingAlarmHelper.syncAllMeetings();
    Fluttertoast.showToast(msg: "Schedule deleted");
  }

  void _showEditDialog(RepeatedModel item) {
    nameController.text = item.name;
    startDateTime = item.Start;
    endDateTime = item.End;
    isSilentOrVibration = item.isSilentOrVibration;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Edit Schedule", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: "Schedule Title",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Start Time"),
                      trailing: Text(
                        "${startDateTime.hour.toString().padLeft(2, '0')}:${startDateTime.minute.toString().padLeft(2, '0')}",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF389EB4)),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: startDateTime.hour, minute: startDateTime.minute),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            startDateTime = DateTime(startDateTime.year, startDateTime.month, startDateTime.day, picked.hour, picked.minute);
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("End Time"),
                      trailing: Text(
                        "${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF389EB4)),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: endDateTime.hour, minute: endDateTime.minute),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            endDateTime = DateTime(endDateTime.year, endDateTime.month, endDateTime.day, picked.hour, picked.minute);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF389EB4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    item.name = nameController.text.trim().isEmpty ? "Meeting" : nameController.text.trim();
                    item.Start = startDateTime;
                    item.End = endDateTime;
                    item.isSilentOrVibration = isSilentOrVibration;
                    await item.save();
                    await MeetingAlarmHelper.syncAllMeetings();
                    Navigator.pop(context);
                  },
                  child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
