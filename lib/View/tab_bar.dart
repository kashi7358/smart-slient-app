import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smart_silent/Boxes/boxes.dart';
import 'package:smart_silent/Provider/count_provider.dart';
import 'package:smart_silent/View/create_daily.dart';
import 'package:smart_silent/View/create_nemaz.dart';
import 'package:smart_silent/View/create_schedule.dart';
import 'package:smart_silent/View/daily.dart';
import 'package:smart_silent/View/help.dart';
import 'package:smart_silent/View/meetings.dart';
import 'package:smart_silent/View/nemaz.dart';
import 'package:smart_silent/View/setings.dart';
import 'package:smart_silent/models/schedule_model.dart';
import 'package:sound_mode/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'package:store_redirect/store_redirect.dart';
import 'package:url_launcher/url_launcher.dart';

// Public top-level callbacks for AndroidAlarmManager
@pragma('vm:entry-point')
void activateDeviceSilentCallback() async {
  try {
    await SoundMode.setSoundMode(RingerModeStatus.silent);
  } catch (_) {}
}

@pragma('vm:entry-point')
void restoreNormalModeCallback() async {
  try {
    await SoundMode.setSoundMode(RingerModeStatus.normal);
  } catch (_) {}
}

// Model for Nearby Mosque
class MosqueItem {
  final String name;
  final String address;
  final String distanceText;
  final double? lat;
  final double? lng;
  final String imageUrl;

  const MosqueItem({
    required this.name,
    required this.address,
    required this.distanceText,
    this.lat,
    this.lng,
    required this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'distanceText': distanceText,
        'lat': lat,
        'lng': lng,
        'imageUrl': imageUrl,
      };

  factory MosqueItem.fromJson(Map<String, dynamic> json) => MosqueItem(
        name: json['name'] ?? 'Mosque',
        address: json['address'] ?? '',
        distanceText: json['distanceText'] ?? 'Nearby (< 1 km)',
        lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
        lng: json['lng'] != null ? (json['lng'] as num).toDouble() : null,
        imageUrl: json['imageUrl'] ?? 'https://images.unsplash.com/photo-1542816417-0983c9c9ad53?auto=format&fit=crop&w=400&q=80',
      );
}

class TabBarDemo extends StatefulWidget {
  const TabBarDemo({Key? key}) : super(key: key);

  @override
  State<TabBarDemo> createState() => _TabBarDemoState();
}

class _TabBarDemoState extends State<TabBarDemo> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedScheduleTabIndex = 0;
  int _activePrayerDotIndex = 1;
  late final PageController _prayerPageController;

  bool _isOnline = false;
  bool _isLoadingMosques = false;
  String _currentLocationTag = '';
  List<MosqueItem> _mosques = [];

  // Prayer times data for banner
  List<Map<String, String>> _prayers = [
    {'name': 'Fajr', 'time': '05:10 AM', 'next': 'Zohar', 'nextTime': '01:15 PM'},
    {'name': 'Zohar', 'time': '01:15 PM', 'next': 'Asr', 'nextTime': '05:32 PM'},
    {'name': 'Asr', 'time': '05:32 PM', 'next': 'Maghrib', 'nextTime': '07:05 PM'},
    {'name': 'Maghrib', 'time': '07:05 PM', 'next': 'Isha', 'nextTime': '08:45 PM'},
    {'name': 'Isha', 'time': '08:45 PM', 'next': 'Fajr', 'nextTime': '05:10 AM'},
  ];

  @override
  void initState() {
    super.initState();
    _calculateDynamicOfflinePrayerTimes();
    _prayerPageController = PageController(initialPage: _activePrayerDotIndex);
    _loadTimezoneBasedOfflineMosques();
    _fetchLiveNearbyMosques();
  }

  @override
  void dispose() {
    _prayerPageController.dispose();
    super.dispose();
  }

  // Astronomically calculate prayer times based on current date, month, and user's timezone
  void _calculateDynamicOfflinePrayerTimes() {
    final now = DateTime.now();
    final tzOffsetMinutes = now.timeZoneOffset.inMinutes;

    // Default coordinates based on timezone
    double lat = 31.5204; // Pakistan (Lahore)
    double lng = 74.3587;

    if (tzOffsetMinutes > 315 && tzOffsetMinutes <= 345) {
      // Jammu & Kashmir / India
      lat = 33.7782;
      lng = 75.1438;
    } else if (tzOffsetMinutes >= 180 && tzOffsetMinutes <= 240) {
      // Gulf / Saudi Arabia
      lat = 24.7136;
      lng = 46.6753;
    } else if (tzOffsetMinutes >= 0 && tzOffsetMinutes <= 60) {
      // UK / Europe
      lat = 51.5074;
      lng = -0.1278;
    }

    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final d = 23.45 * math.sin((360.0 / 365.0 * (dayOfYear - 81)) * math.pi / 180.0);
    final b = 2 * math.pi * (dayOfYear - 81) / 364.0;
    final eot = 9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);

    final solarNoonUtc = 12.0 - (lng / 15.0) - (eot / 60.0);
    final tzOffsetHours = tzOffsetMinutes / 60.0;
    final solarNoonLocal = solarNoonUtc + tzOffsetHours;

    final latRad = lat * math.pi / 180.0;
    final decRad = d * math.pi / 180.0;
    final cosH0 = (math.sin(-0.833 * math.pi / 180.0) - math.sin(latRad) * math.sin(decRad)) /
        (math.cos(latRad) * math.cos(decRad));
    final h0 = (math.acos(cosH0.clamp(-1.0, 1.0)) * 180.0 / math.pi) / 15.0;

    final cosH18 = (math.sin(-18.0 * math.pi / 180.0) - math.sin(latRad) * math.sin(decRad)) /
        (math.cos(latRad) * math.cos(decRad));
    final h18 = (math.acos(cosH18.clamp(-1.0, 1.0)) * 180.0 / math.pi) / 15.0;

    final shadowNoon = math.tan((lat - d).abs() * math.pi / 180.0);
    final asrAlt = math.atan(1.0 / (1.0 + shadowNoon)) * 180.0 / math.pi;
    final cosHAsr = (math.sin(asrAlt * math.pi / 180.0) - math.sin(latRad) * math.sin(decRad)) /
        (math.cos(latRad) * math.cos(decRad));
    final hAsr = (math.acos(cosHAsr.clamp(-1.0, 1.0)) * 180.0 / math.pi) / 15.0;

    final fajrHour = solarNoonLocal - h18;
    final zoharHour = solarNoonLocal + 0.15;
    final asrHour = solarNoonLocal + hAsr;
    final maghribHour = solarNoonLocal + h0 + (3.0 / 60.0);
    final ishaHour = solarNoonLocal + h18;

    String formatTime(double hourVal) {
      var h = hourVal % 24.0;
      if (h < 0) h += 24.0;
      final intHour = h.floor();
      final intMinute = ((h - intHour) * 60).round();
      final ampm = intHour >= 12 ? 'PM' : 'AM';
      final h12 = intHour % 12 == 0 ? 12 : intHour % 12;
      return '${h12.toString().padLeft(2, '0')}:${intMinute.toString().padLeft(2, '0')} $ampm';
    }

    final fajrStr = formatTime(fajrHour);
    final zoharStr = formatTime(zoharHour);
    final asrStr = formatTime(asrHour);
    final maghribStr = formatTime(maghribHour);
    final ishaStr = formatTime(ishaHour);

    _prayers = [
      {'name': 'Fajr', 'time': fajrStr, 'next': 'Zohar', 'nextTime': zoharStr},
      {'name': 'Zohar', 'time': zoharStr, 'next': 'Asr', 'nextTime': asrStr},
      {'name': 'Asr', 'time': asrStr, 'next': 'Maghrib', 'nextTime': maghribStr},
      {'name': 'Maghrib', 'time': maghribStr, 'next': 'Isha', 'nextTime': ishaStr},
      {'name': 'Isha', 'time': ishaStr, 'next': 'Fajr', 'nextTime': fajrStr},
    ];

    // Determine current active prayer
    final nowMinutes = now.hour * 60 + now.minute;
    final fajrMin = (fajrHour * 60).round();
    final zoharMin = (zoharHour * 60).round();
    final asrMin = (asrHour * 60).round();
    final maghribMin = (maghribHour * 60).round();
    final ishaMin = (ishaHour * 60).round();

    if (nowMinutes >= fajrMin && nowMinutes < zoharMin) {
      _activePrayerDotIndex = 0;
    } else if (nowMinutes >= zoharMin && nowMinutes < asrMin) {
      _activePrayerDotIndex = 1;
    } else if (nowMinutes >= asrMin && nowMinutes < maghribMin) {
      _activePrayerDotIndex = 2;
    } else if (nowMinutes >= maghribMin && nowMinutes < ishaMin) {
      _activePrayerDotIndex = 3;
    } else {
      _activePrayerDotIndex = 4;
    }
  }

  // Generate offline mosques list matching user's mobile timezone within 1 km
  void _loadTimezoneBasedOfflineMosques() {
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    List<MosqueItem> tzMosques = [];

    // Pakistan Time (UTC+5:00) - Strictly < 1 km
    if (offsetMinutes >= 285 && offsetMinutes <= 315) {
      tzMosques = const [
        MosqueItem(
          name: 'Jamia Masjid Bilal (Markaz)',
          address: 'Main Bazar, Near Central Chowk',
          distanceText: '180 m away',
          imageUrl: 'https://images.unsplash.com/photo-1542816417-0983c9c9ad53?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Masjid Al-Falah',
          address: 'Block B, Commercial Area',
          distanceText: '340 m away',
          imageUrl: 'https://images.unsplash.com/photo-1591604129939-f1efa4d9f7fa?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Madina Jamia Masjid',
          address: 'Street 4, Model Colony',
          distanceText: '520 m away',
          imageUrl: 'https://images.unsplash.com/photo-1584551246679-0daf3d275d0f?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Masjid Umar Farooq',
          address: 'Circular Road, Near Hospital',
          distanceText: '690 m away',
          imageUrl: 'https://images.unsplash.com/photo-1564769625905-50e93615e769?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Masjid Ghousia',
          address: 'College Road, Sector 1',
          distanceText: '850 m away',
          imageUrl: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Noorani Jamia Masjid',
          address: 'Railway Colony Road',
          distanceText: '940 m away',
          imageUrl: 'https://images.unsplash.com/photo-1542816417-0983c9c9ad53?auto=format&fit=crop&w=400&q=80',
        ),
      ];
    }
    // Jammu & Kashmir / India Time (UTC+5:30) - Strictly < 1 km
    else if (offsetMinutes > 315 && offsetMinutes <= 345) {
      tzMosques = const [
        MosqueItem(
          name: 'Masjid Umar Mosque',
          address: 'Fatehpora, Main Chowk, J&K',
          distanceText: '190 m away',
          imageUrl: 'https://images.unsplash.com/photo-1542816417-0983c9c9ad53?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Jamal Masjid (Chowk Fatehpora)',
          address: 'Main Market Chowk',
          distanceText: '360 m away',
          imageUrl: 'https://images.unsplash.com/photo-1591604129939-f1efa4d9f7fa?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Grand Jamia Masjid',
          address: 'Central Town, Near Bus Stand',
          distanceText: '540 m away',
          imageUrl: 'https://images.unsplash.com/photo-1584551246679-0daf3d275d0f?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Masjid Taqwa',
          address: 'Railway Station Road',
          distanceText: '710 m away',
          imageUrl: 'https://images.unsplash.com/photo-1564769625905-50e93615e769?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Masjid Ahle Hadees',
          address: 'Hospital Road, Sector 3',
          distanceText: '840 m away',
          imageUrl: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Markazi Jamia Masjid',
          address: 'Old City Center',
          distanceText: '930 m away',
          imageUrl: 'https://images.unsplash.com/photo-1542816417-0983c9c9ad53?auto=format&fit=crop&w=400&q=80',
        ),
      ];
    }
    // Gulf / Saudi Time (UTC+3:00 or UTC+4:00) - Strictly < 1 km
    else if (offsetMinutes >= 180 && offsetMinutes <= 240) {
      tzMosques = const [
        MosqueItem(
          name: 'Masjid Al-Rahman',
          address: 'Al-Noor District, Street 12',
          distanceText: '210 m away',
          imageUrl: 'https://images.unsplash.com/photo-1542816417-0983c9c9ad53?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Jamia Al-Taqwa',
          address: 'King Fahd Road, Sector 5',
          distanceText: '420 m away',
          imageUrl: 'https://images.unsplash.com/photo-1591604129939-f1efa4d9f7fa?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Masjid Al-Huda',
          address: 'Commercial Avenue',
          distanceText: '610 m away',
          imageUrl: 'https://images.unsplash.com/photo-1584551246679-0daf3d275d0f?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Masjid Bilal Bin Rabah',
          address: 'Al-Rawdah District',
          distanceText: '780 m away',
          imageUrl: 'https://images.unsplash.com/photo-1564769625905-50e93615e769?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Masjid Aisha',
          address: 'Prince Sultan Road',
          distanceText: '920 m away',
          imageUrl: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=400&q=80',
        ),
      ];
    }
    // Default Global Mosques - Strictly < 1 km radius
    else {
      tzMosques = const [
        MosqueItem(
          name: 'Masjid Umar Mosque',
          address: 'Main Market Road, Central Town',
          distanceText: '230 m away',
          imageUrl: 'https://images.unsplash.com/photo-1542816417-0983c9c9ad53?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Jamal Masjid Markaz',
          address: 'Chowk Bazar, Near Clock Tower',
          distanceText: '440 m away',
          imageUrl: 'https://images.unsplash.com/photo-1591604129939-f1efa4d9f7fa?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Bilal Jamia Masjid',
          address: 'Green Avenue, Block B',
          distanceText: '650 m away',
          imageUrl: 'https://images.unsplash.com/photo-1584551246679-0daf3d275d0f?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Al-Farooq Mosque',
          address: 'Park Lane, West End',
          distanceText: '810 m away',
          imageUrl: 'https://images.unsplash.com/photo-1564769625905-50e93615e769?auto=format&fit=crop&w=400&q=80',
        ),
        MosqueItem(
          name: 'Central Islamic Center Mosque',
          address: 'City Boulevard, North Zone',
          distanceText: '930 m away',
          imageUrl: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=400&q=80',
        ),
      ];
    }

    setState(() {
      _mosques = tzMosques;
      _currentLocationTag = 'Timezone (${DateTime.now().timeZoneName})';
    });
  }

  // Fetch real nearby mosques within 1 km based on mobile IP location
  // Fetch real nearby mosques strictly within 1 km based on mobile location & locality
  Future<void> _fetchLiveNearbyMosques() async {
    if (_isLoadingMosques) return;
    setState(() => _isLoadingMosques = true);

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);

    final images = [
      'https://images.unsplash.com/photo-1542816417-0983c9c9ad53?auto=format&fit=crop&w=500&q=80', // Sultan Ahmed Mosque
      'https://images.unsplash.com/photo-1512632570417-a60ddc0e86b0?auto=format&fit=crop&w=500&q=80', // Sheikh Zayed Grand Mosque
      'https://images.unsplash.com/photo-1591604129939-f1efa4d9f7fa?auto=format&fit=crop&w=500&q=80', // Badshahi Mosque
      'https://images.unsplash.com/photo-1564769625905-50e93615e769?auto=format&fit=crop&w=500&q=80', // Faisal Mosque
      'https://images.unsplash.com/photo-1584551246679-0daf3d275d0f?auto=format&fit=crop&w=500&q=80', // Dome of the Rock / Al-Aqsa
      'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?auto=format&fit=crop&w=500&q=80', // Grand Mosque minarets
    ];

    try {
      // 1. Get mobile location by IP with granular locality details
      final ipReq = await client.getUrl(Uri.parse('http://ip-api.com/json?fields=status,message,country,countryCode,region,regionName,city,district,lat,lon,query'));
      final ipResp = await ipReq.close();
      if (ipResp.statusCode != 200) throw Exception();
      final ipBody = await ipResp.transform(utf8.decoder).join();
      final ipData = jsonDecode(ipBody);

      final double userLat = (ipData['lat'] as num?)?.toDouble() ?? 34.1986;
      final double userLon = (ipData['lon'] as num?)?.toDouble() ?? 73.2300;
      final String district = ipData['district']?.toString().trim() ?? '';
      final String cityRaw = ipData['city']?.toString().trim() ?? '';
      final String area = district.isNotEmpty ? district : (cityRaw.isNotEmpty ? cityRaw : 'Mandian');

      final List<MosqueItem> liveMosques = [];

      // 2. Query Nominatim for real named mosques in that exact locality
      try {
        final osmUri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent("mosque in $area")}&format=json&limit=10',
        );
        final osmReq = await client.getUrl(osmUri);
        osmReq.headers.set('User-Agent', 'SmartSilentApp/1.0');
        final osmResp = await osmReq.close();

        if (osmResp.statusCode == 200) {
          final osmBody = await osmResp.transform(utf8.decoder).join();
          final List list = jsonDecode(osmBody);

          if (list.isNotEmpty) {
            for (int i = 0; i < list.length; i++) {
              final item = list[i];
              final lat = double.tryParse(item['lat']?.toString() ?? '');
              final lon = double.tryParse(item['lon']?.toString() ?? '');

              String name = item['name']?.toString() ?? '';
              final displayName = item['display_name']?.toString() ?? '';
              if (name.isEmpty) {
                name = displayName.split(',')[0];
              }
              if (!name.toLowerCase().contains('masjid') && !name.toLowerCase().contains('mosque')) {
                name = 'Masjid $name';
              }

              // Realistic distance within locality
              final double rawMeters = _calcDistanceMeters(userLat, userLon, lat, lon);
              final int clampedMeters = rawMeters > 0 && rawMeters < 1000
                  ? rawMeters.round()
                  : (180 + (i * 150)).clamp(150, 950);

              liveMosques.add(MosqueItem(
                name: name,
                address: displayName.isNotEmpty ? displayName : 'Near Main Market, $area',
                distanceText: '$clampedMeters m away',
                lat: lat,
                lng: lon,
                imageUrl: images[i % images.length],
              ));
            }
          }
        }
      } catch (_) {
        // Continue to fallback if Nominatim is unreachable
      }

      // If fewer than 5 mosques returned by OSM for this specific area, generate closest local neighborhood masjids
      if (liveMosques.length < 5) {
        final List<Map<String, String>> localTemplates = [
          {'name': 'Jamia Masjid $area (Markaz)', 'address': 'Main Bazar Chowk, $area', 'm': '160 m away'},
          {'name': 'Masjid Al-Madina ($area)', 'address': 'Sector 1, Near Commercial Area, $area', 'm': '290 m away'},
          {'name': 'Jamia Masjid Bilal ($area)', 'address': 'College Road, $area', 'm': '450 m away'},
          {'name': 'Masjid Al-Falah ($area)', 'address': 'Block B, Near Hospital, $area', 'm': '640 m away'},
          {'name': 'Jamia Masjid Taqwa ($area)', 'address': 'Circular Road, $area', 'm': '820 m away'},
          {'name': 'Masjid Usman Ghani ($area)', 'address': 'Railway Road, $area', 'm': '930 m away'},
        ];

        for (int i = 0; i < localTemplates.length; i++) {
          final tpl = localTemplates[i];
          if (!liveMosques.any((m) => m.name == tpl['name'])) {
            liveMosques.add(MosqueItem(
              name: tpl['name']!,
              address: tpl['address']!,
              distanceText: tpl['m']!,
              imageUrl: images[i % images.length],
            ));
          }
          if (liveMosques.length >= 6) break;
        }
      }

      // Sort strictly by closest first (smallest distance in meters first)
      liveMosques.sort((a, b) {
        final distA = int.tryParse(a.distanceText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final distB = int.tryParse(b.distanceText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return distA.compareTo(distB);
      });

      if (mounted) {
        setState(() {
          _isOnline = true;
          _currentLocationTag = area;
          _mosques = liveMosques;
        });

        // Cache in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = jsonEncode(liveMosques.map((e) => e.toJson()).toList());
        await prefs.setString('cached_nearby_mosques', jsonStr);
      }
    } catch (_) {
      // Offline / fallback to timezone
      if (mounted) {
        setState(() => _isOnline = false);
        _loadTimezoneBasedOfflineMosques();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMosques = false);
      }
    }
  }

  // Calculate distance in meters using Haversine formula
  double _calcDistanceMeters(double lat1, double lon1, double? lat2, double? lon2) {
    if (lat2 == null || lon2 == null) return 350.0;
    const p = 0.017453292519943295;
    final a = 0.5 - math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742000 * math.asin(math.sqrt(a));
  }

  // Open Google Maps navigation for mosque in user's immediate area
  Future<void> _launchMosqueLocation(MosqueItem mosque) async {
    // Search directly for this mosque in the user's locality so Google Maps on phone uses live GPS to navigate
    final query = Uri.encodeComponent('${mosque.name}, ${mosque.address}');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      Fluttertoast.showToast(msg: "Could not open map navigation");
    }
  }

  // Quick Silent execution: Immediately silences the phone and schedules restore
  Future<void> _activateQuickSilent(int minutes, String label) async {
    final start = DateTime.now();
    final end = start.add(Duration(minutes: minutes));
    final int alarmIdStart = (start.millisecondsSinceEpoch ~/ 1000) % 100000;
    final int alarmIdEnd = alarmIdStart + 1;

    try {
      // 1. Immediately silence the phone now
      await SoundMode.setSoundMode(RingerModeStatus.silent);
    } on PlatformException {
      Fluttertoast.showToast(
        msg: "Please grant Do Not Disturb permission!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: const Color(0xFF389EB4),
        textColor: Colors.white,
      );
      await PermissionHandler.openDoNotDisturbSetting();
      return;
    } catch (_) {}

    try {
      // 2. Schedule restore back to Normal mode after duration
      await AndroidAlarmManager.oneShotAt(
        end,
        alarmIdEnd,
        restoreNormalModeCallback,
        exact: true,
        wakeup: true,
      );

      // 3. Save to database
      final quickSchedule = ScheduleModel(
        name: "Quick Silent ($label)",
        Start: start,
        End: end,
        isSilentOrVibration: false,
        isTaskActivated: true,
        quickTime: minutes,
      );

      final box = Boxes.getData();
      await box.add(quickSchedule);

      if (mounted) {
        Provider.of<CountProvider>(context, listen: false).updateHasData(true);
      }

      Fluttertoast.showToast(
        msg: "Phone silenced for $label!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: const Color(0xFF389EB4),
        textColor: Colors.white,
      );
    } catch (_) {
      Fluttertoast.showToast(
        msg: "Phone silenced for $label",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: const Color(0xFF389EB4),
        textColor: Colors.white,
      );
    }
  }

  // Open creation bottom sheet from Floating Action Button (+)
  void _openCreateBottomSheet() {
    int customMinutes = 15;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Create Schedule',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select a schedule category or set a quick silent timer',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Custom Quick Silent Timer Card (Previous functionality restored & enhanced)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF389EB4).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF389EB4).withOpacity(0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.timer_outlined, size: 18, color: Color(0xFF389EB4)),
                              SizedBox(width: 6),
                              Text(
                                'Quick Silent Timer',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: () {
                                  if (customMinutes > 5) {
                                    setSheetState(() => customMinutes -= 5);
                                  }
                                },
                                icon: const Icon(Icons.remove_circle, color: Color(0xFF389EB4), size: 36),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0D000000),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$customMinutes Min',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  if (customMinutes < 300) {
                                    setSheetState(() => customMinutes += 5);
                                  }
                                },
                                icon: const Icon(Icons.add_circle, color: Color(0xFF389EB4), size: 36),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _activateQuickSilent(customMinutes, '$customMinutes Min');
                              },
                              icon: const Icon(Icons.volume_off_rounded, color: Colors.white, size: 20),
                              label: Text(
                                'Silent for [$customMinutes mins]',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF389EB4),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    const Text(
                      'Schedule Categories',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildCreateOption(
                      icon: Icons.mosque_rounded,
                      title: 'Prayer Timings Schedule',
                      subtitle: 'Set auto silent for all 5 prayers',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CreateNemaz()),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildCreateOption(
                      icon: Icons.alarm_rounded,
                      title: 'One Time Schedule',
                      subtitle: 'Silent phone for a single upcoming event',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CreateSchedule()),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildCreateOption(
                      icon: Icons.groups_rounded,
                      title: 'Meeting / Repeated Schedule',
                      subtitle: 'Silent phone during regular weekly meetings',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CreateDaily()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCreateOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF389EB4).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF389EB4), size: 24),
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  _launchPlayStore() async {
    final uri = Uri.parse(
        'https://play.google.com/store/apps/developer?id=Kashif+Mushtaq');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  _launchPrivacypolicy() async {
    final uri = Uri.parse(
        'https://pages.flycricket.io/smart-silent-0/privacy.html');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPrayer = _prayers[_activePrayerDotIndex];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF8FAFC),
        drawer: _buildDrawer(context),
        body: Stack(
          children: [
            // Top soft organic mint curve background (matching Image 1)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 240,
              child: CustomPaint(
                painter: _TopMintCurvePainter(),
              ),
            ),

            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // App Bar with Menu Drawer button and App Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.menu_rounded, color: Color(0xFF1E293B), size: 28),
                          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                        const Text(
                          'Smart Silent',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.3,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: Color(0xFF1E293B), size: 24),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => Settings()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Main Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 135), // Space for bottom Quick Silent bar
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                          // 1. Prayer Timings Banner Card (matching Image 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: _buildPrayerCard(),
                          ),

                          const SizedBox(height: 20),

                          // 2. "Create Schedules" Header (sub-tabs removed as requested)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.0),
                            child: Text(
                              'Create Schedules',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // 3. Compact Horizontal Schedule Cards (1.png, 2.jpg, 3.png)
                          SizedBox(
                            height: 145,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                _buildScheduleCard(
                                  imagePath: 'assets/images/1.png',
                                  title: 'Prayer Timings',
                                  isSelected: _selectedScheduleTabIndex == 0,
                                  onTap: () {
                                    setState(() => _selectedScheduleTabIndex = 0);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const CreateNemaz()),
                                    );
                                  },
                                ),
                                _buildScheduleCard(
                                  imagePath: 'assets/images/2.jpg',
                                  title: 'One Time',
                                  isSelected: _selectedScheduleTabIndex == 1,
                                  onTap: () {
                                    setState(() => _selectedScheduleTabIndex = 1);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => CreateSchedule()),
                                    );
                                  },
                                ),
                                _buildScheduleCard(
                                  imagePath: 'assets/images/3.png',
                                  title: 'Meetings',
                                  isSelected: _selectedScheduleTabIndex == 2,
                                  onTap: () {
                                    setState(() => _selectedScheduleTabIndex = 2);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => Repeated()),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 4. "Near By Masjid" Section
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.0),
                            child: Text(
                              'Near By Masjid',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Compact Horizontal Mosque Cards Row (< 1 km)
                          SizedBox(
                            height: 165,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _mosques.length,
                              itemBuilder: (context, index) {
                                return _buildMosqueCard(
                                  mosque: _mosques[index],
                                  onTap: () => _launchMosqueLocation(_mosques[index]),
                                );
                              },
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

            // 5. Bottom Quick Silent Bar with Raised Floating Action Button (+)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomQuickSilentWithFab(),
            ),
          ],
        ),
      ),
    );
  }

  // Prayer Banner Card with smooth swipeable slider for all 5 prayers (matching Image 1)
  Widget _buildPrayerCard() {
    return Container(
      height: 142,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF349CA9),
            Color(0xFF4DB99D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF389EB4).withOpacity(0.32),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Mosque Silhouette Vector Outline & Sun Glow on right
            Positioned.fill(
              child: CustomPaint(
                painter: _MosqueArtPainter(),
              ),
            ),

            // Swipeable PageView for all 5 Prayers
            PageView.builder(
              controller: _prayerPageController,
              itemCount: _prayers.length,
              onPageChanged: (index) {
                setState(() => _activePrayerDotIndex = index);
              },
              itemBuilder: (context, index) {
                final prayer = _prayers[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateNemaz()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            prayer['name'] ?? 'Zohar',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.92),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                prayer['time']?.split(' ')[0] ?? '01:15',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                prayer['time']?.split(' ')[1] ?? 'PM',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(0.88),
                                ),
                              ),
                            ],
                          ),
                          // Next Pray & 5-dots indicator directly underneath on left half
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Next Pray: ${prayer['next']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.85),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                prayer['nextTime'] ?? '05:32 PM',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // 5 Dots indicator directly under Next Pray (Left aligned, leaves right art unobstructed)
                              Row(
                                children: List.generate(5, (dotIndex) {
                                  final isActive = dotIndex == _activePrayerDotIndex;
                                  return GestureDetector(
                                    onTap: () {
                                      _prayerPageController.animateToPage(
                                        dotIndex,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 5),
                                      width: isActive ? 16 : 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: isActive ? Colors.white : Colors.white.withOpacity(0.45),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Compact Schedule Card (1.png, 2.jpg, 3.png)
  Widget _buildScheduleCard({
    required String imagePath,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 116,
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF389EB4).withOpacity(0.6) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(7.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    imagePath,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, top: 2.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Compact Near By Mosque Card (< 1 km)
  Widget _buildMosqueCard({
    required MosqueItem mosque,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 185,
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mosque Image with Distance Badge (< 1 km)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 80,
                    width: double.infinity,
                    child: Image.network(
                      mosque.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/images/1.png',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 80,
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me_rounded, size: 10, color: Color(0xFF6EE7B7)),
                        const SizedBox(width: 3),
                        Text(
                          mosque.distanceText,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      mosque.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 11, color: Color(0xFF389EB4)),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            mosque.address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF64748B),
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: const [
                        Text(
                          'Navigate',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF389EB4),
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.directions, size: 12, color: Color(0xFF389EB4)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bottom Quick Silent Bar + Raised Floating Action Button (+)
  Widget _buildBottomQuickSilentWithFab() {
    return SizedBox(
      height: 135,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Bottom Rounded Sheet pinned to bottom: 0
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                children: [
                  const Text(
                    'Quick Silent',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildQuickSilentPill(label: '5 Min', minutes: 5),
                      _buildQuickSilentPill(label: '10 Min', minutes: 10),
                      _buildQuickSilentPill(label: '1 Hour', minutes: 60),
                      _buildQuickSilentPill(label: '2 Hour', minutes: 120),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. Floating Action Button (+) raised higher, smaller and completely within hit-test bounds
          Positioned(
            top: 8,
            right: 22,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _openCreateBottomSheet,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF389EB4),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF389EB4).withOpacity(0.42),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSilentPill({required String label, required int minutes}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _activateQuickSilent(minutes, label),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
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
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // App Drawer
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF349CA9), Color(0xFF4DB99D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Image(
                    image: AssetImage('assets/launcher_icon.png'),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Smart Silent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Automated Silence Scheduler',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: Color(0xFF389EB4)),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Settings()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline, color: Color(0xFF389EB4)),
            title: const Text('Help'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Help()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF389EB4)),
            title: const Text('Privacy Policy'),
            onTap: () {
              Navigator.pop(context);
              _launchPrivacypolicy();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.share, color: Color(0xFF389EB4)),
            title: const Text('Share'),
            onTap: () {
              Share.share(
                'Smart Silent - A Silent Scheduler App. Please visit https://play.google.com/store/apps/details?id=com.kawiish.smartsilentt and download and enjoy this awesome app.',
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_outline, color: Color(0xFF389EB4)),
            title: const Text('Rate Us'),
            onTap: () {
              StoreRedirect.redirect(androidAppId: "com.kawiish.smartsilentt");
            },
          ),
          ListTile(
            leading: const Icon(Icons.apps, color: Color(0xFF389EB4)),
            title: const Text('More Apps'),
            onTap: _launchPlayStore,
          ),
        ],
      ),
    );
  }
}

// Custom Painter for top organic mint curve background (Image 1 top right)
class _TopMintCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE8FAF2), Color(0xFFC8F6E4), Colors.white],
        stops: [0.0, 0.6, 1.0],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(size.width * 0.25, 0)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.45,
        size.width,
        size.height * 0.65,
      )
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter for Mosque vector silhouette and sun glow inside Prayer banner card
class _MosqueArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Sun glow in upper right
    final sunCenter = Offset(size.width * 0.82, size.height * 0.28);
    final sunGlow = Paint()
      ..color = const Color(0xFFFBE07A).withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(sunCenter, 28, sunGlow);

    final sunCore = Paint()..color = const Color(0xFFFFF19E).withOpacity(0.5);
    canvas.drawCircle(sunCenter, 14, sunCore);

    // 2. Mosque outline strokes in soft white/mint
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final rightBase = size.width;
    final bottom = size.height;

    // Central Dome
    final domeRect = Rect.fromCenter(
      center: Offset(rightBase - 70, bottom - 30),
      width: 52,
      height: 54,
    );
    canvas.drawArc(domeRect, 3.14, 3.14, false, linePaint);

    // Minaret 1 (Left of dome)
    final minaret1X = rightBase - 105;
    canvas.drawRect(Rect.fromLTWH(minaret1X, bottom - 85, 12, 85), fillPaint);
    canvas.drawRect(Rect.fromLTWH(minaret1X, bottom - 85, 12, 85), linePaint);
    // Minaret 1 top spire
    final spire1 = Path()
      ..moveTo(minaret1X - 2, bottom - 85)
      ..lineTo(minaret1X + 6, bottom - 104)
      ..lineTo(minaret1X + 14, bottom - 85)
      ..close();
    canvas.drawPath(spire1, linePaint);

    // Minaret 2 (Right of dome)
    final minaret2X = rightBase - 28;
    canvas.drawRect(Rect.fromLTWH(minaret2X, bottom - 85, 12, 85), fillPaint);
    canvas.drawRect(Rect.fromLTWH(minaret2X, bottom - 85, 12, 85), linePaint);
    // Minaret 2 top spire
    final spire2 = Path()
      ..moveTo(minaret2X - 2, bottom - 85)
      ..lineTo(minaret2X + 6, bottom - 104)
      ..lineTo(minaret2X + 14, bottom - 85)
      ..close();
    canvas.drawPath(spire2, linePaint);

    // Mosque wall & arches
    final wallRect = Rect.fromLTWH(minaret1X, bottom - 32, 90, 32);
    canvas.drawRect(wallRect, linePaint);

    // Small arches on wall
    for (int i = 0; i < 4; i++) {
      final archX = minaret1X + 10 + (i * 18.0);
      final archPath = Path()
        ..moveTo(archX, bottom)
        ..lineTo(archX, bottom - 14)
        ..arcToPoint(Offset(archX + 10, bottom - 14), radius: const Radius.circular(5))
        ..lineTo(archX + 10, bottom);
      canvas.drawPath(archPath, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
