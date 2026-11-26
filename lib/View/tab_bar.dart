import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:smart_silent/Utils/ad_helper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smart_silent/constants.dart';
import 'package:smart_silent/Boxes/boxes.dart';
import 'package:smart_silent/Provider/count_provider.dart';
import 'package:smart_silent/Utils/device_compatibility_helper.dart';
import 'package:smart_silent/Utils/hijri_helper.dart';
import 'package:smart_silent/Utils/meeting_alarm_helper.dart';
import 'package:smart_silent/Utils/nearby_masjid_service.dart';
import 'package:smart_silent/Utils/one_time_alarm_helper.dart';
import 'package:smart_silent/Utils/prayer_alarm_helper.dart';
import 'package:smart_silent/Utils/sound_control_helper.dart';
import 'package:smart_silent/View/create_daily.dart';
import 'package:smart_silent/View/create_nemaz.dart';
import 'package:smart_silent/View/create_schedule.dart';
import 'package:smart_silent/View/daily.dart';
import 'package:smart_silent/View/help.dart';
import 'package:smart_silent/View/meetings.dart';
import 'package:smart_silent/View/privacy_policy.dart';
import 'package:smart_silent/View/nemaz.dart';
import 'package:smart_silent/View/setings.dart';
import 'package:smart_silent/models/schedule_model.dart';
import 'package:sound_mode/permission_handler.dart';
import 'package:store_redirect/store_redirect.dart';
import 'package:url_launcher/url_launcher.dart';

// Public top-level callbacks for AndroidAlarmManager
@pragma('vm:entry-point')
void activateDeviceSilentCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[SmartSilent] activateDeviceSilentCallback fired');
  await SoundControlHelper.ensureHiveInitialized();
  try {
    await SoundControlHelper.applySilentOrVibrate(vibrate: true);
  } catch (_) {}
}

@pragma('vm:entry-point')
void restoreNormalModeCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[SmartSilent] restoreNormalModeCallback fired');
  await SoundControlHelper.ensureHiveInitialized();
  await SoundControlHelper.leaveSilentWindow(sourceId: 'quick_silent');
}

class TabBarDemo extends StatefulWidget {
  const TabBarDemo({Key? key}) : super(key: key);

  @override
  State<TabBarDemo> createState() => _TabBarDemoState();
}

class _TabBarDemoState extends State<TabBarDemo> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedScheduleTabIndex = 0;
  int _activePrayerDotIndex = 0;
  late final PageController _prayerPageController;
  Timer? _prayerTimer;

  // AdMob Banner Ad configuration
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  bool _isLoadingMosques = false;
  int _mosqueFetchGeneration = 0;
  String _locationStatusMessage = '';
  String _locationErrorType = '';
  double? _lastUserLat;
  double? _lastUserLon;
  List<MosqueItem> _mosques = [];

  // Prayer times data for banner
  List<Map<String, String>> _prayers = [
    {'name': 'Fajr', 'time': '05:10 AM', 'next': 'Zohar', 'nextTime': '01:15 PM'},
    {'name': 'Zohar', 'time': '01:15 PM', 'next': 'Asr', 'nextTime': '05:32 PM'},
    {'name': 'Asr', 'time': '05:32 PM', 'next': 'Maghrib', 'nextTime': '07:05 PM'},
    {'name': 'Maghrib', 'time': '07:05 PM', 'next': 'Isha', 'nextTime': '08:45 PM'},
    {'name': 'Isha', 'time': '08:45 PM', 'next': 'Fajr', 'nextTime': '05:10 AM'},
  ];

  // Dynamic Background Gradients matching each prayer's time-of-day (Zohar uses brand purple instead of green)
  static const List<List<Color>> _prayerGradients = [
    // 0: Fajr (Dawn / Subh Sadiq)
    [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
    // 1: Zohar (Midday / Brand Royal Purple)
    [AppColors.kPrimaryDark, AppColors.kPrimary, AppColors.kPrimaryLight],
    // 2: Asr (Late Afternoon / Golden Hour)
    [Color(0xFFB45309), Color(0xFFD97706), Color(0xFFF59E0B)],
    // 3: Maghrib (Sunset Dusk / Twilight Crimson-Purple)
    [Color(0xFF581C87), Color(0xFF7E22CE), Color(0xFFBE185D)],
    // 4: Isha (Midnight Celestial Night Sky)
    [Color(0xFF0B132B), Color(0xFF1C2541), Color(0xFF3A506B)],
  ];

  static const List<Color> _prayerGradientsGlow = [
    Color(0xFF2C5364),
    AppColors.kPrimary,
    Color(0xFFD97706),
    Color(0xFF7E22CE),
    Color(0xFF1C2541),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initBannerAd();
    _calculateDynamicOfflinePrayerTimes();
    _prayerPageController = PageController(initialPage: _activePrayerDotIndex);
    _fetchLiveNearbyMosques();
    SoundControlHelper.syncManualOverrideState();
    try {
      PrayerAlarmHelper.verifyAlarmsOnAppLaunch();
      MeetingAlarmHelper.verifyAlarmsOnAppLaunch();
      OneTimeAlarmHelper.verifyAlarmsOnAppLaunch();
    } catch (_) {}

    // Dynamically update nearest prayer slider every minute
    _prayerTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateNearestPrayerOnTimer();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _prayerTimer?.cancel();
    _prayerPageController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _initBannerAd() {
    final String adUnitId = AdHelper.bannerAdUnitId;
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[SmartSilent] Home Tab BannerAd loaded successfully.');
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[SmartSilent] Home Tab BannerAd failed to load: $error');
          ad.dispose();
          _bannerAd = null;
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
            });
          }
        },
      ),
    );
    _bannerAd?.load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SoundControlHelper.syncManualOverrideState();
      try {
        PrayerAlarmHelper.verifyAlarmsOnAppLaunch();
        MeetingAlarmHelper.verifyAlarmsOnAppLaunch();
        OneTimeAlarmHelper.verifyAlarmsOnAppLaunch();
      } catch (_) {}
      // Auto-retry when returning from Location / App Permission settings
      if (_mosques.isEmpty &&
          (_locationErrorType == 'location_disabled' ||
              _locationErrorType == 'permission_denied' ||
              _locationErrorType == 'approximate_only')) {
        _fetchLiveNearbyMosques(forceFresh: true);
      }
    }
  }

  // Smoothly animate the PageView slider to the nearest prayer
  void _animateToNearestPrayer() {
    if (_prayerPageController.hasClients) {
      _prayerPageController.animateToPage(
        _activePrayerDotIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _updateNearestPrayerOnTimer() {
    if (!mounted) return;
    final int previousIndex = _activePrayerDotIndex;
    _calculateDynamicOfflinePrayerTimes();
    if (previousIndex != _activePrayerDotIndex) {
      setState(() {});
      _animateToNearestPrayer();
    }
  }

  void _refreshPrayerTimesAndSlider() {
    if (!mounted) return;
    setState(() {
      _calculateDynamicOfflinePrayerTimes();
    });
    _animateToNearestPrayer();
  }

  // Calculate dynamic prayer times: checks user's saved Hive timings first, falls back to astronomical
  void _calculateDynamicOfflinePrayerTimes() {
    final now = DateTime.now();
    double fajrHour = 5.31;
    double zoharHour = 13.25;
    double asrHour = 16.5;
    double maghribHour = 18.2;
    double ishaHour = 19.75;

    // 1. Check if user has saved custom prayer timings in Hive
    final nemazBox = Boxes.getDataforNemaz();
    if (nemazBox.isNotEmpty) {
      final saved = nemazBox.values.last;
      fajrHour = saved.FajarStart.hour + (saved.FajarStart.minute / 60.0);
      zoharHour = saved.ZoharStart.hour + (saved.ZoharStart.minute / 60.0);
      asrHour = saved.AsarStart.hour + (saved.AsarStart.minute / 60.0);
      maghribHour = saved.MagribStart.hour + (saved.MagribStart.minute / 60.0);
      ishaHour = saved.IshaStart.hour + (saved.IshaStart.minute / 60.0);
    } else {
      // 2. Astronomical fallback based on user's timezone
      final tzOffsetMinutes = now.timeZoneOffset.inMinutes;
      double lat = 31.5204;
      double lng = 74.3587;

      if (tzOffsetMinutes > 315 && tzOffsetMinutes <= 345) {
        lat = 33.7782;
        lng = 75.1438;
      } else if (tzOffsetMinutes >= 180 && tzOffsetMinutes <= 240) {
        lat = 24.7136;
        lng = 46.6753;
      } else if (tzOffsetMinutes >= 0 && tzOffsetMinutes <= 60) {
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

      fajrHour = solarNoonLocal - h18;
      zoharHour = solarNoonLocal + 0.15;
      asrHour = solarNoonLocal + hAsr;
      maghribHour = solarNoonLocal + h0 + (3.0 / 60.0);
      ishaHour = solarNoonLocal + h18;
    }

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

    // 3. Find the prayer whose time is NEAREST to the current clock time (circular 24h distance)
    final nowMinutes = now.hour * 60 + now.minute;
    final fajrMin = (fajrHour * 60).round() % 1440;
    final zoharMin = (zoharHour * 60).round() % 1440;
    final asrMin = (asrHour * 60).round() % 1440;
    final maghribMin = (maghribHour * 60).round() % 1440;
    final ishaMin = (ishaHour * 60).round() % 1440;

    final prayerTimes = [fajrMin, zoharMin, asrMin, maghribMin, ishaMin];
    _activePrayerDotIndex = _findNearestPrayerIndex(prayerTimes, nowMinutes);
  }

  // 24-hour circular nearest prayer calculation
  int _findNearestPrayerIndex(List<int> prayerMinutes, int nowMinutes) {
    int bestIndex = 0;
    int minDiff = 999999;
    for (int i = 0; i < prayerMinutes.length; i++) {
      int diff = (nowMinutes - prayerMinutes[i]).abs();
      if (diff > 720) {
        diff = 1440 - diff;
      }
      if (diff < minDiff) {
        minDiff = diff;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  static const MethodChannel _platformChannel =
      MethodChannel('com.kawiish.smartsilent/device_compatibility');

  static const String _cacheMosquesKey = 'saved_real_nearby_mosques_v4';
  static const String _cacheLatKey = 'saved_mosques_center_lat';
  static const String _cacheLngKey = 'saved_mosques_center_lng';
  static const String _cacheTimeKey = 'cached_mosques_timestamp';
  static const String _cacheTagKey = 'cached_location_tag';

  /// Opens Google Maps searching for nearby masjids around current coordinates.
  Future<void> _openGoogleMapsMasjidSearch() async {
    final Uri uri = (_lastUserLat != null && _lastUserLon != null)
        ? Uri.parse('geo:$_lastUserLat,$_lastUserLon?q=masjid')
        : Uri.parse('geo:0,0?q=masjid+near+me');
    final Uri webUri = (_lastUserLat != null && _lastUserLon != null)
        ? Uri.parse(
            'https://www.google.com/maps/search/masjid/@$_lastUserLat,$_lastUserLon,16z')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=masjid');
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!launched) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  /// Handles tap on the empty/error Nearby Masjids card based on the failure reason.
  Future<void> _handleMosqueEmptyCardTap() async {
    if (_locationErrorType == 'location_disabled') {
      try {
        await _platformChannel.invokeMethod('openLocationSettings');
      } catch (_) {}
      return;
    }
    if (_locationErrorType == 'permission_denied' ||
        _locationErrorType == 'approximate_only') {
      try {
        final dynamic granted = await _platformChannel.invokeMethod(
          'requestLocationPermission',
          {'upgradePrecise': _locationErrorType == 'approximate_only'},
        );
        if (granted != true) {
          await _platformChannel.invokeMethod('openAppSettings');
          return;
        }
      } catch (_) {}
    }
    await _fetchLiveNearbyMosques(forceFresh: true);
  }

  /// Fetch 100% REAL nearby mosques using verified device GPS/Fused coordinates
  /// and smart local tiering (650m -> 1km -> 1.5km -> 2.5km max) across Overpass,
  /// Komoot Photon, and Nominatim, showing cached/early results immediately.
  Future<void> _fetchLiveNearbyMosques({bool forceFresh = false}) async {
    final int generation = ++_mosqueFetchGeneration;

    final prefs = await SharedPreferences.getInstance();
    if (generation != _mosqueFetchGeneration || !mounted) return;

    // 0. Show fresh local cache immediately BEFORE waiting for GPS when not forcing refresh
    if (!forceFresh && _mosques.isEmpty) {
      final int? cachedTs = prefs.getInt(_cacheTimeKey);
      final double? cLat = prefs.getDouble(_cacheLatKey);
      final double? cLng = prefs.getDouble(_cacheLngKey);
      if (cachedTs != null &&
          cLat != null &&
          cLng != null &&
          DateTime.now()
                  .difference(DateTime.fromMillisecondsSinceEpoch(cachedTs)) <=
              NearbyMasjidService.maxCacheAge) {
        final quickCache = NearbyMasjidService.decodeAndValidateCachedMosques(
          rawJson: prefs.getString(_cacheMosquesKey),
          currentLat: cLat,
          currentLng: cLng,
        );
        if (quickCache.isNotEmpty) {
          setState(() {
            _mosques = quickCache;
            _lastUserLat = cLat;
            _lastUserLon = cLng;
            _isLoadingMosques = false;
            _locationStatusMessage = '';
            _locationErrorType = '';
          });
        }
      }
    }

    if (mounted && (_mosques.isEmpty || forceFresh)) {
      setState(() {
        _isLoadingMosques = true;
        _locationStatusMessage = '';
        _locationErrorType = '';
      });
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);

    try {
      // 1. Ensure runtime location permission only if missing
      try {
        final dynamic hasPerm =
            await _platformChannel.invokeMethod('hasLocationPermission');
        if (hasPerm != true) {
          await _platformChannel.invokeMethod('requestLocationPermission');
        }
      } catch (_) {}

      // 2. Get verified GPS/Fused coordinates from Android
      double? userLat;
      double? userLon;
      String? locationError;

      try {
        final dynamic raw = await _platformChannel.invokeMethod(
          'getDeviceLocation',
          {'forceFresh': forceFresh},
        );
        if (raw is Map) {
          locationError = raw['error']?.toString();
          final lat = (raw['latitude'] as num?)?.toDouble();
          final lng = (raw['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            userLat = lat;
            userLon = lng;
          }
        }
      } catch (_) {
        locationError = 'timeout';
      }

      if (generation != _mosqueFetchGeneration || !mounted) return;

      // Never fall back to IP geolocation or stale mosques from another area
      if (userLat == null || userLon == null) {
        final String errType = locationError ?? 'timeout';
        String msg;
        switch (errType) {
          case 'permission_denied':
            msg = 'Allow location permission & tap here to see masjids in your area.';
            break;
          case 'approximate_only':
            msg = 'Enable Precise Location (not Approximate) & tap here for accurate masjids.';
            break;
          case 'location_disabled':
            msg = 'Device GPS/Location is turned off. Tap here to enable Location.';
            break;
          case 'low_accuracy':
            msg = 'GPS signal is weak indoors. Move near a window & tap to retry.';
            break;
          default:
            msg = 'Could not get a fresh GPS fix. Turn on GPS & tap to retry.';
        }
        if (mounted) {
          setState(() {
            _mosques = [];
            _locationErrorType = errType;
            _locationStatusMessage = msg;
            _isLoadingMosques = false;
          });
        }
        return;
      }

      final double resolvedLat = userLat;
      final double resolvedLon = userLon;
      _lastUserLat = resolvedLat;
      _lastUserLon = resolvedLon;

      // 3. Validate cached mosques ONLY against verified current coordinates
      for (final legacyKey in const [
        'saved_real_nearby_mosques',
        'saved_real_nearby_mosques_v2',
        'saved_real_nearby_mosques_v3',
      ]) {
        if (prefs.containsKey(legacyKey)) {
          await prefs.remove(legacyKey);
        }
      }

      List<MosqueItem> verifiedCache = [];
      final bool cacheMatchesSpot = NearbyMasjidService.isCacheValidForCoordinates(
        cachedLat: prefs.getDouble(_cacheLatKey),
        cachedLng: prefs.getDouble(_cacheLngKey),
        cachedTimestampMs: prefs.getInt(_cacheTimeKey),
        currentLat: resolvedLat,
        currentLng: resolvedLon,
      );

      if (cacheMatchesSpot) {
        verifiedCache = NearbyMasjidService.decodeAndValidateCachedMosques(
          rawJson: prefs.getString(_cacheMosquesKey),
          currentLat: resolvedLat,
          currentLng: resolvedLon,
        );
        if (verifiedCache.isNotEmpty && mounted) {
          setState(() {
            _mosques = verifiedCache;
            _isLoadingMosques = false;
          });
        }
      } else {
        if (mounted && _mosques.isNotEmpty) {
          setState(() {
            _mosques = [];
            _isLoadingMosques = true;
          });
        }
        await prefs.remove(_cacheMosquesKey);
        await prefs.remove(_cacheLatKey);
        await prefs.remove(_cacheLngKey);
        await prefs.remove(_cacheTimeKey);
        await prefs.remove(_cacheTagKey);
      }

      // 4. Race Overpass mirrors + Photon in parallel and display as soon as first source answers
      List<dynamic> overpassElements = [];
      final List<dynamic> photonFeatures = [];
      bool anyOsmSuccess = false;

      void publishMergedSnapshot() {
        if (generation != _mosqueFetchGeneration || !mounted) return;
        List<MosqueItem> snapshot = NearbyMasjidService.parseOverpassElements(
          elements: overpassElements,
          userLat: resolvedLat,
          userLon: resolvedLon,
        );
        snapshot = NearbyMasjidService.parsePhotonFeatures(
          features: photonFeatures,
          userLat: resolvedLat,
          userLon: resolvedLon,
          existingResults: snapshot,
        );
        final List<MosqueItem> selected =
            NearbyMasjidService.selectNearestLocalMosques(snapshot);
        if (selected.isNotEmpty) {
          setState(() {
            _locationStatusMessage = '';
            _locationErrorType = '';
            _mosques = selected;
            _isLoadingMosques = false;
          });
        }
      }

      Future<void> runOverpassParallel() async {
        final String overpassQuery = NearbyMasjidService.buildOverpassQuery(
          resolvedLat,
          resolvedLon,
        );
        final String encoded = Uri.encodeComponent(overpassQuery);
        final List<String> endpoints = [
          'https://overpass-api.de/api/interpreter?data=$encoded',
          'https://maps.mail.ru/osm/tools/overpass/api/interpreter?data=$encoded',
          'https://overpass.kumi.systems/api/interpreter?data=$encoded',
        ];
        final completer = Completer<void>();
        int remaining = endpoints.length;

        for (final ep in endpoints) {
          () async {
            try {
              final req = await client
                  .getUrl(Uri.parse(ep))
                  .timeout(const Duration(seconds: 6));
              req.headers.set(
                  'User-Agent', 'SmartSilentApp/1.0 (contact: support@kawiish.com)');
              final resp =
                  await req.close().timeout(const Duration(seconds: 7));
              if (resp.statusCode == 200) {
                final body = await resp
                    .transform(utf8.decoder)
                    .join()
                    .timeout(const Duration(seconds: 7));
                final decoded = jsonDecode(body);
                if (decoded is Map && decoded['elements'] is List) {
                  if (!completer.isCompleted) {
                    anyOsmSuccess = true;
                    overpassElements = decoded['elements'] as List;
                    completer.complete();
                    publishMergedSnapshot();
                  }
                  return;
                }
              }
            } catch (_) {} finally {
              remaining--;
              if (remaining <= 0 && !completer.isCompleted) {
                completer.complete();
              }
            }
          }();
        }
        await completer.future;
      }

      Future<void> runPhotonParallel() async {
        final double minLon = resolvedLon - 0.025;
        final double maxLon = resolvedLon + 0.025;
        final double minLat = resolvedLat - 0.025;
        final double maxLat = resolvedLat + 0.025;
        await Future.wait(['masjid', 'mosque'].map((q) async {
          if (generation != _mosqueFetchGeneration) return;
          try {
            final uri = Uri.parse(
              'https://photon.komoot.io/api/?q=$q&lat=$resolvedLat&lon=$resolvedLon&bbox=$minLon,$minLat,$maxLon,$maxLat&limit=20',
            );
            final req =
                await client.getUrl(uri).timeout(const Duration(seconds: 4));
            req.headers.set(
                'User-Agent', 'SmartSilentApp/1.0 (contact: support@kawiish.com)');
            final resp = await req.close().timeout(const Duration(seconds: 4));
            if (resp.statusCode == 200) {
              final body = await resp
                  .transform(utf8.decoder)
                  .join()
                  .timeout(const Duration(seconds: 4));
              final decoded = jsonDecode(body);
              if (decoded is Map && decoded['features'] is List) {
                anyOsmSuccess = true;
                photonFeatures.addAll(decoded['features'] as List);
              }
            }
          } catch (_) {}
        }));
        publishMergedSnapshot();
      }

      await Future.wait([
        runOverpassParallel(),
        runPhotonParallel(),
      ]);

      if (generation != _mosqueFetchGeneration || !mounted) return;

      // Merge Overpass + Photon results strictly around GPS coordinates
      List<MosqueItem> allCandidates = NearbyMasjidService.parseOverpassElements(
        elements: overpassElements,
        userLat: resolvedLat,
        userLon: resolvedLon,
      );
      allCandidates = NearbyMasjidService.parsePhotonFeatures(
        features: photonFeatures,
        userLat: resolvedLat,
        userLon: resolvedLon,
        existingResults: allCandidates,
      );

      // 5. Fallback Nominatim search if Overpass + Photon yielded < 2 results
      if (allCandidates.length < 2) {
        const double delta =
            (NearbyMasjidService.maxSearchRadiusMeters / 111000.0) * 1.15;
        const List<String> nominatimQueries = ['masjid', 'mosque'];
        for (int idx = 0; idx < nominatimQueries.length; idx++) {
          if (generation != _mosqueFetchGeneration) return;
          if (idx > 0) {
            await Future.delayed(const Duration(milliseconds: 1100));
          }
          try {
            final q = Uri.encodeQueryComponent(nominatimQueries[idx]);
            final osmUri = Uri.parse(
              'https://nominatim.openstreetmap.org/search?format=json&q=$q&bounded=1&viewbox=${resolvedLon - delta},${resolvedLat + delta},${resolvedLon + delta},${resolvedLat - delta}&limit=15&addressdetails=1&namedetails=1&extratags=1&accept-language=en',
            );
            final osmReq =
                await client.getUrl(osmUri).timeout(const Duration(seconds: 5));
            osmReq.headers
                .set('User-Agent', 'SmartSilentApp/1.0 (contact: support@kawiish.com)');
            osmReq.headers.set('Accept-Language', 'en-US,en;q=0.9');
            final osmResp =
                await osmReq.close().timeout(const Duration(seconds: 5));
            if (osmResp.statusCode == 200) {
              final osmBody = await osmResp
                  .transform(utf8.decoder)
                  .join()
                  .timeout(const Duration(seconds: 5));
              final decoded = jsonDecode(osmBody);
              if (decoded is List) {
                anyOsmSuccess = true;
                allCandidates = NearbyMasjidService.parseNominatimItems(
                  items: decoded,
                  userLat: resolvedLat,
                  userLon: resolvedLon,
                  existingResults: allCandidates,
                );
              }
            }
          } catch (_) {}
          if (allCandidates.length >= 4) break;
        }
      }

      if (generation != _mosqueFetchGeneration || !mounted) return;

      final List<MosqueItem> selectedMosques =
          NearbyMasjidService.selectNearestLocalMosques(allCandidates);

      if (selectedMosques.isNotEmpty) {
        setState(() {
          _locationStatusMessage = '';
          _locationErrorType = '';
          _mosques = selectedMosques;
        });

        final jsonStr =
            jsonEncode(selectedMosques.map((e) => e.toJson()).toList());
        await prefs.setString(_cacheMosquesKey, jsonStr);
        await prefs.setDouble(_cacheLatKey, resolvedLat);
        await prefs.setDouble(_cacheLngKey, resolvedLon);
        await prefs.setInt(
            _cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
      } else if (anyOsmSuccess) {
        await prefs.remove(_cacheMosquesKey);
        await prefs.remove(_cacheLatKey);
        await prefs.remove(_cacheLngKey);
        await prefs.remove(_cacheTimeKey);
        setState(() {
          _mosques = [];
          _locationErrorType = 'no_results';
          _locationStatusMessage =
              'No OpenStreetMap masjids mapped near your GPS location. Tap below to view on Google Maps.';
        });
      } else if (verifiedCache.isNotEmpty) {
        setState(() {
          _mosques = verifiedCache;
          _locationErrorType = '';
          _locationStatusMessage = '';
        });
      } else {
        setState(() {
          _mosques = [];
          _locationErrorType = 'network_error';
          _locationStatusMessage =
              'Unable to load nearby masjids. Check internet & pull down to retry.';
        });
      }
    } catch (_) {
      if (generation == _mosqueFetchGeneration && mounted && _mosques.isEmpty) {
        setState(() {
          _locationErrorType = 'network_error';
          _locationStatusMessage =
              'Unable to load nearby masjids. Tap here to try again.';
        });
      }
    } finally {
      client.close(force: true);
      if (generation == _mosqueFetchGeneration && mounted) {
        setState(() => _isLoadingMosques = false);
      }
    }
  }

  // Open Google Maps navigation for mosque with exact pin coordinates
  Future<void> _launchMosqueLocation(MosqueItem mosque) async {
    Uri geoUri;
    Uri googleMapsAppUri;
    Uri webUri;

    if (mosque.lat != null && mosque.lng != null) {
      final label = Uri.encodeComponent(mosque.name);
      geoUri = Uri.parse('geo:${mosque.lat},${mosque.lng}?q=${mosque.lat},${mosque.lng}($label)');
      googleMapsAppUri = Uri.parse('google.navigation:q=${mosque.lat},${mosque.lng}&mode=w');
      webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${mosque.lat},${mosque.lng}');
    } else {
      final query = Uri.encodeComponent('${mosque.name}, ${mosque.address}');
      geoUri = Uri.parse('geo:0,0?q=$query');
      googleMapsAppUri = Uri.parse('google.navigation:q=$query');
      webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }

    bool launched = false;
    try {
      launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    if (!launched) {
      try {
        launched = await launchUrl(googleMapsAppUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    if (!launched) {
      try {
        launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    if (!launched) {
      try {
        await launchUrl(webUri, mode: LaunchMode.platformDefault);
      } catch (_) {
        Fluttertoast.showToast(msg: "Could not open map navigation");
      }
    }
  }

  // Quick Silent execution: Immediately silences the phone and schedules restore
  Future<void> _activateQuickSilent(int minutes, String label) async {
    final start = DateTime.now();
    final end = start.add(Duration(minutes: minutes));
    final int epochSeconds = start.millisecondsSinceEpoch ~/ 1000;
    final int alarmIdStart = 40000 + (epochSeconds % 9000);
    final int alarmIdEnd = alarmIdStart + 1000;

    try {
      // 1. Immediately silence the phone now & track active quick window
      await SoundControlHelper.enterSilentWindow(
        sourceId: 'quick_silent',
        endTime: end,
        vibrate: false,
        endAlarmId: alarmIdEnd,
      );
    } catch (_) {}

    try {
      // 2. Schedule restore back to Normal mode after duration
      try {
        await AndroidAlarmManager.oneShotAt(
          end,
          alarmIdEnd,
          restoreNormalModeCallback,
          exact: true,
          wakeup: true,
          allowWhileIdle: true,
          rescheduleOnReboot: true,
        );
      } catch (_) {
        await AndroidAlarmManager.oneShotAt(
          end,
          alarmIdEnd,
          restoreNormalModeCallback,
          exact: false,
          wakeup: true,
          allowWhileIdle: true,
          rescheduleOnReboot: true,
        );
      }

      Fluttertoast.showToast(
        msg: "Phone silenced for $label!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppColors.kPrimary,
        textColor: Colors.white,
      );
    } catch (_) {
      Fluttertoast.showToast(
        msg: "Phone silenced for $label",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: AppColors.kPrimary,
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
                        color: AppColors.kSecondary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.kPrimary.withOpacity(0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.timer_outlined, size: 18, color: AppColors.kPrimary),
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
                                icon: const Icon(Icons.remove_circle, color: AppColors.kPrimary, size: 36),
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
                                icon: const Icon(Icons.add_circle, color: AppColors.kPrimary, size: 36),
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
                                backgroundColor: AppColors.kPrimary,
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
                      onTap: () async {
                        Navigator.pop(context);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CreateNemaz()),
                        );
                        _refreshPrayerTimesAndSlider();
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
                color: AppColors.kSecondary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.kPrimary, size: 24),
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
        backgroundColor: AppColors.kbg,
        drawer: _buildDrawer(context),
        body: Stack(
          children: [
            // Top soft organic curve background dynamically matching active prayer ambiance
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 240,
              child: CustomPaint(
                painter: _TopMintCurvePainter(prayerIndex: _activePrayerDotIndex),
              ),
            ),

            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // App Bar with elevated Menu Drawer button, Title with Hijri Date, and modern Settings button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Elevated Left Menu Drawer Button
                        Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () => _scaffoldKey.currentState?.openDrawer(),
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1E293B).withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.menu_rounded, color: Color(0xFF1E293B), size: 24),
                              ),
                            ),
                          ),
                        ),

                        // Center Title with Islamic Calendar Date Badge
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Smart Silent',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.kSecondary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_month_rounded, size: 11, color: AppColors.kPrimary),
                                  const SizedBox(width: 4),
                                  Text(
                                    HijriDate.formatCurrentDate(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.kPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Elevated Right Settings Button (Matching Image: circular gear button)
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
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1E293B).withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.settings_rounded, color: Color(0xFF1E293B), size: 22),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main Scrollable Body (Pull down to refresh nearby masjids)
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.kPrimary,
                      onRefresh: () => _fetchLiveNearbyMosques(forceFresh: true),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.only(bottom: 28), // Clean breathing room above bottomNavigationBar & FAB
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

                          // 3. Non-scrolling Row of 3 Schedule Cards (1.png, 2.jpg, 3.png)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: SizedBox(
                              height: 136,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildScheduleCard(
                                      imagePath: 'assets/images/1.png',
                                      title: 'Prayer Timings',
                                      isSelected: _selectedScheduleTabIndex == 0,
                                      onTap: () async {
                                        setState(() => _selectedScheduleTabIndex = 0);
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const CreateNemaz()),
                                        );
                                        _refreshPrayerTimesAndSlider();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildScheduleCard(
                                      imagePath: 'assets/images/2.jpg',
                                      title: 'One Time',
                                      isSelected: _selectedScheduleTabIndex == 1,
                                      onTap: () async {
                                        setState(() => _selectedScheduleTabIndex = 1);
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const OneTime()),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildScheduleCard(
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
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 4. "Near By Masjids" Section (Clean header, no location pill, 500 badge, or refresh icon)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.0),
                            child: Text(
                              'Nearby Masjids',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Compact Horizontal Mosque Cards Row
                          if (_isLoadingMosques && _mosques.isEmpty)
                            _buildMosqueLoadingRow()
                          else if (_mosques.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: _handleMosqueEmptyCardTap,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x0A000000),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.kSecondary,
                                              AppColors.kPrimary.withOpacity(0.12),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _locationErrorType == 'location_disabled'
                                              ? Icons.location_off_rounded
                                              : Icons.mosque_rounded,
                                          color: AppColors.kPrimary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _locationErrorType == 'location_disabled'
                                                  ? 'Turn On Device GPS'
                                                  : _locationErrorType == 'approximate_only'
                                                      ? 'Enable Precise Location'
                                                      : 'Find Nearby Masjids',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _locationStatusMessage.isNotEmpty
                                                  ? _locationStatusMessage
                                                  : 'Tap to load masjids near your current location.',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: Color(0xFF64748B),
                                                height: 1.35,
                                              ),
                                            ),
                                            if (_locationErrorType == 'no_results') ...[
                                              const SizedBox(height: 8),
                                              GestureDetector(
                                                onTap: _openGoogleMapsMasjidSearch,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.kSecondary,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Text(
                                                    'Open in Google Maps',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.kPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 192,
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
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _buildHomeFab(),
        bottomNavigationBar: _buildBottomQuickSilentBar(),
      ),
    );
  }

  // Prayer Banner Card with smooth swipeable slider and dynamic background per prayer
  Widget _buildPrayerCard() {
    final int safeIndex = _activePrayerDotIndex.clamp(0, 4);
    final String currentPrayerName = _prayers[safeIndex]['name'] ?? 'Fajr';

    // Prayer mood subtitle tag
    final List<String> prayerTags = [
      'Dawn Prayer',
      'Noon Prayer',
      'Afternoon Prayer',
      'Sunset Prayer',
      'Night Prayer',
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      height: 146,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: _prayerGradients[safeIndex],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _prayerGradientsGlow[safeIndex].withOpacity(0.38),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: PageView.builder(
          controller: _prayerPageController,
          itemCount: _prayers.length,
          onPageChanged: (index) {
            setState(() => _activePrayerDotIndex = index);
          },
          itemBuilder: (context, index) {
            final prayer = _prayers[index];
            final tag = prayerTags[index % prayerTags.length];
            return Stack(
              children: [
                // Distinct architectural Mosque & Celestial artwork per prayer slide
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MosqueArtPainter(prayerIndex: index),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateNemaz()),
                      );
                      _refreshPrayerTimesAndSlider();
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                prayer['name'] ?? 'Zohar',
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.95),
                                  ),
                                ),
                              ),
                            ],
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
                                      width: isActive ? 18 : 5,
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
                ),
              ],
            );
          },
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
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.kPrimary : Colors.transparent,
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
                padding: const EdgeInsets.all(6.0),
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
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMosqueFallbackTile() {
    return Container(
      height: 82,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.22),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mosque_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildMosqueLoadingRow() {
    return SizedBox(
      height: 192,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 210,
            margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 94,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: index == 0
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.kPrimary,
                            ),
                          ),
                        )
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 130,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 95,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Polished Near By Mosque Card using bundled local mosque photos
  Widget _buildMosqueCard({
    required MosqueItem mosque,
    required VoidCallback onTap,
  }) {
    final String walkTime = NearbyMasjidService.formatWalkTime(mosque.distanceMeters);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 210,
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0).withOpacity(0.8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bundled Local Mosque Photo with Subtle Gradient & Distance Pill
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                  child: SizedBox(
                    height: 94,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        mosque.imageUrl.startsWith('http')
                            ? Image.asset(
                                NearbyMasjidService.mosqueImagePool.first,
                                fit: BoxFit.cover,
                                cacheWidth: 480,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildMosqueFallbackTile(),
                              )
                            : Image.asset(
                                mosque.imageUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 480,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildMosqueFallbackTile(),
                              ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.38),
                              ],
                              stops: const [0.45, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 0.6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me_rounded, size: 10, color: Color(0xFF6EE7B7)),
                        const SizedBox(width: 3),
                        Text(
                          mosque.distanceText,
                          style: const TextStyle(
                            fontSize: 10,
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
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mosque.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on_rounded, size: 12, color: AppColors.kPrimary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                mosque.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_walk_rounded, size: 12, color: Color(0xFF64748B)),
                            const SizedBox(width: 2),
                            Text(
                              walkTime,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.kSecondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'Navigate',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0E7490),
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(Icons.directions_rounded, size: 12, color: Color(0xFF0E7490)),
                            ],
                          ),
                        ),
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

  // Raised Floating Action Button (+) positioned cleanly above bottomNavigationBar
  Widget _buildHomeFab() {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: _openCreateBottomSheet,
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
            child: Icon(
              Icons.add,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  // Bottom Quick Silent Bar + Banner Ad pinned safely above mobile navigation buttons
  Widget _buildBottomQuickSilentBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.kPrimary.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Quick Silent',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1B2E),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildQuickSilentPill(label: '5 Min', minutes: 5),
                  const SizedBox(width: 8),
                  _buildQuickSilentPill(label: '10 Min', minutes: 10),
                  const SizedBox(width: 8),
                  _buildQuickSilentPill(label: '1 Hour', minutes: 60),
                  const SizedBox(width: 8),
                  _buildQuickSilentPill(label: '2 Hour', minutes: 120),
                ],
              ),
              // AdMob Banner Ad (ca-app-pub-9923979057032791/3153557586)
              if (_isAdLoaded && _bannerAd != null) ...[
                const SizedBox(height: 8),
                Container(
                  alignment: Alignment.center,
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSilentPill({required String label, required int minutes}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _activateQuickSilent(minutes, label),
        child: Container(
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
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
        ),
      ),
    );
  }

  // Human-Crafted Executive App Drawer
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Executive Drawer Header with Islamic Identity & Live Hijri Date
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.kPrimary, AppColors.kPrimaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(topRight: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Elevated Circular App Icon
                    Container(
                      width: 58,
                      height: 58,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/launcher_icon.png', fit: BoxFit.cover),
                      ),
                    ),

                    // Version Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'v1.0.7',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Smart Silent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Automated Silence & Prayer Assistant',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 10),

                // Live Hijri Date Pill in Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 12),
                      const SizedBox(width: 5),
                      Text(
                        HijriDate.formatCurrentDate(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Drawer Menu Items
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 6, 20, 6),
                  child: Text(
                    'MAIN NAVIGATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),

                // Prayer Timings
                _buildDrawerItem(
                  icon: Icons.mosque_rounded,
                  iconColor: AppColors.kPrimary,
                  iconBgColor: AppColors.kSecondary,
                  title: 'Prayer Timings',
                  subtitle: 'Set auto-silent times for prayers',
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateNemaz()),
                    );
                    _refreshPrayerTimesAndSlider();
                  },
                ),

                // Meeting Schedules
                _buildDrawerItem(
                  icon: Icons.business_center_rounded,
                  iconColor: AppColors.kPrimaryLight,
                  iconBgColor: AppColors.kSecondary,
                  title: 'Meeting Schedules',
                  subtitle: 'Daily & repeated silent tasks',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Repeated()),
                    );
                  },
                ),

                // Settings
                _buildDrawerItem(
                  icon: Icons.settings_rounded,
                  iconColor: AppColors.kPrimary,
                  iconBgColor: AppColors.kSecondary,
                  title: 'Settings',
                  subtitle: 'DND permissions & app data',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Settings()),
                    );
                  },
                ),

                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Text(
                    'SUPPORT & COMMUNITY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),

                // Help & FAQ
                _buildDrawerItem(
                  icon: Icons.help_outline_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBgColor: const Color(0xFFEDE9FE),
                  title: 'Help & FAQ',
                  subtitle: 'Usage guides & troubleshooting',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Help()),
                    );
                  },
                ),

                // Share App
                _buildDrawerItem(
                  icon: Icons.share_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBgColor: const Color(0xFFD1FAE5),
                  title: 'Share with Friends',
                  subtitle: 'Recommend Smart Silent',
                  onTap: () {
                    Share.share(
                      'Smart Silent - Automatically silent your phone during prayers and meetings! Download now: https://play.google.com/store/apps/details?id=com.kawiish.smartsilentt',
                    );
                  },
                ),

                // Rate Us
                _buildDrawerItem(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  iconBgColor: const Color(0xFFFEF3C7),
                  title: 'Rate Us 5 Stars',
                  subtitle: 'Support development on Play Store',
                  trailing: const Icon(Icons.open_in_new_rounded, size: 15, color: Color(0xFFCBD5E1)),
                  onTap: () {
                    StoreRedirect.redirect(androidAppId: "com.kawiish.smartsilentt");
                  },
                ),

                // Privacy Policy
                _buildDrawerItem(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: const Color(0xFF059669),
                  iconBgColor: const Color(0xFFD1FAE5),
                  title: 'Privacy Policy',
                  subtitle: 'Your privacy is respected offline',
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          // Drawer Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.favorite_rounded, color: Color(0xFFEF4444), size: 14),
                SizedBox(width: 6),
                Text(
                  'Crafted for Peaceful Worship',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing
                else
                  const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Painter for top organic curve background dynamically matching active prayer ambiance
class _TopMintCurvePainter extends CustomPainter {
  final int prayerIndex;
  _TopMintCurvePainter({this.prayerIndex = 1});

  static const List<List<Color>> _curveGradients = [
    [Color(0xFFE2E8F0), Color(0xFFCBD5E1), Colors.white], // Fajr
    [Color(0xFFEDE7F6), Color(0xFFD1C4E9), Colors.white], // Zohar (Brand Purple tint)
    [Color(0xFFFEF3C7), Color(0xFFFDE68A), Colors.white], // Asr
    [Color(0xFFF3E8FF), Color(0xFFE9D5FF), Colors.white], // Maghrib
    [Color(0xFFE0E7FF), Color(0xFFC7D2FE), Colors.white], // Isha
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final colors = _curveGradients[prayerIndex.clamp(0, 4)];
    final paint = Paint()
      ..shader = LinearGradient(
        colors: colors,
        stops: const [0.0, 0.6, 1.0],
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
  bool shouldRepaint(covariant _TopMintCurvePainter oldDelegate) =>
      oldDelegate.prayerIndex != prayerIndex;
}

// Professional Multi-Architecture Mosque Painter (Distinct Masjid Design & Celestial Sky per Prayer)
class _MosqueArtPainter extends CustomPainter {
  final int prayerIndex;
  _MosqueArtPainter({this.prayerIndex = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final rightBase = size.width;
    final bottom = size.height;

    final fillSoft = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.fill;

    final fillMid = Paint()
      ..color = Colors.white.withOpacity(0.16)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final archCut = Paint()
      ..color = AppColors.kPrimaryDark.withOpacity(0.45)
      ..style = PaintingStyle.fill;

    // 1. Celestial Sky + Distinct Mosque Architecture per Prayer
    switch (prayerIndex % 5) {
      case 0:
        // FAJR: Dawn crescent + morning star + Twin-Minaret Nabawi-inspired Masjid
        _drawCrescentMoon(canvas, Offset(rightBase - 96, 28), 9.5, Colors.white.withOpacity(0.85));
        _drawTwinklingStar(canvas, Offset(rightBase - 46, 24), 5.5, Colors.white.withOpacity(0.9));
        _drawTwinklingStar(canvas, Offset(rightBase - 68, 40), 3.0, Colors.white.withOpacity(0.6));

        // Flanking low domes
        _drawDome(canvas, rightBase - 116, bottom - 26, 30, 28, fillSoft, linePaint);
        _drawDome(canvas, rightBase - 32, bottom - 26, 30, 28, fillSoft, linePaint);

        // Grand central dome + finial
        _drawDome(canvas, rightBase - 74, bottom - 30, 56, 52, fillMid, linePaint, withFinial: true);

        // Twin tiered minarets
        _drawTieredMinaret(canvas, rightBase - 120, bottom, 10, 88, fillMid, linePaint);
        _drawTieredMinaret(canvas, rightBase - 38, bottom, 10, 88, fillMid, linePaint);

        // Base arcade & 5 arches
        _drawArcadeWall(canvas, rightBase - 124, bottom, 104, 30, 5, fillMid, linePaint, archCut);
        break;

      case 1:
        // ZOHAR: High radiant sun + Modern Faisal-Mosque inspired geometric canopy & 4 pencil minarets
        final sunCenter = Offset(rightBase - 72, 30);
        canvas.drawCircle(
          sunCenter,
          26,
          Paint()
            ..color = Colors.white.withOpacity(0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );
        canvas.drawCircle(sunCenter, 11, Paint()..color = Colors.white.withOpacity(0.75));

        // 4 sleek pencil minarets
        _drawPencilMinaret(canvas, rightBase - 126, bottom, 6.5, 96, fillMid, linePaint);
        _drawPencilMinaret(canvas, rightBase - 104, bottom, 6.5, 82, fillSoft, linePaint);
        _drawPencilMinaret(canvas, rightBase - 40, bottom, 6.5, 82, fillSoft, linePaint);
        _drawPencilMinaret(canvas, rightBase - 20, bottom, 6.5, 96, fillMid, linePaint);

        // Iconic triangular tent sanctuary
        final tent = Path()
          ..moveTo(rightBase - 114, bottom - 18)
          ..lineTo(rightBase - 70, bottom - 76)
          ..lineTo(rightBase - 26, bottom - 18)
          ..close();
        canvas.drawPath(tent, fillMid);
        canvas.drawPath(tent, linePaint);

        // Inner geometric ridge lines
        canvas.drawLine(Offset(rightBase - 70, bottom - 76), Offset(rightBase - 70, bottom - 18), linePaint);
        canvas.drawLine(Offset(rightBase - 70, bottom - 76), Offset(rightBase - 90, bottom - 18), linePaint);
        canvas.drawLine(Offset(rightBase - 70, bottom - 76), Offset(rightBase - 50, bottom - 18), linePaint);

        // Stepped courtyard plinth
        canvas.drawRect(Rect.fromLTWH(rightBase - 130, bottom - 18, 120, 18), fillMid);
        canvas.drawRect(Rect.fromLTWH(rightBase - 130, bottom - 18, 120, 18), linePaint);
        break;

      case 2:
        // ASR: Descending sun + Ottoman cascading multi-dome Blue-Mosque style
        final asrSun = Offset(rightBase - 42, 40);
        canvas.drawCircle(
          asrSun,
          24,
          Paint()
            ..color = Colors.white.withOpacity(0.16)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );
        canvas.drawCircle(asrSun, 10, Paint()..color = Colors.white.withOpacity(0.68));

        // 4 classic Ottoman minarets
        _drawPencilMinaret(canvas, rightBase - 128, bottom, 7, 94, fillSoft, linePaint);
        _drawPencilMinaret(canvas, rightBase - 108, bottom, 8, 104, fillMid, linePaint);
        _drawPencilMinaret(canvas, rightBase - 42, bottom, 8, 104, fillMid, linePaint);
        _drawPencilMinaret(canvas, rightBase - 20, bottom, 7, 94, fillSoft, linePaint);

        // Stepped semi-domes + grand central dome
        _drawDome(canvas, rightBase - 96, bottom - 26, 36, 36, fillSoft, linePaint);
        _drawDome(canvas, rightBase - 48, bottom - 26, 36, 36, fillSoft, linePaint);
        _drawDome(canvas, rightBase - 72, bottom - 34, 54, 54, fillMid, linePaint, withFinial: true);

        _drawArcadeWall(canvas, rightBase - 122, bottom, 102, 28, 5, fillMid, linePaint, archCut);
        break;

      case 3:
        // MAGHRIB: Sunset glow + evening stars + Mughal 3-dome Badshahi style
        final sunsetGlow = Paint()
          ..shader = LinearGradient(
            colors: [AppColors.kPrimaryGlow.withOpacity(0.28), Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ).createShader(Rect.fromLTWH(0, bottom - 65, size.width, 65));
        canvas.drawRect(Rect.fromLTWH(0, bottom - 65, size.width, 65), sunsetGlow);

        _drawTwinklingStar(canvas, Offset(rightBase - 48, 24), 5.5, Colors.white.withOpacity(0.85));
        _drawTwinklingStar(canvas, Offset(rightBase - 96, 36), 3.8, Colors.white.withOpacity(0.65));

        // Twin Mughal corner minarets with cupolas
        _drawTieredMinaret(canvas, rightBase - 124, bottom, 10, 92, fillMid, linePaint);
        _drawTieredMinaret(canvas, rightBase - 28, bottom, 10, 92, fillMid, linePaint);

        // Side onion domes + grand central onion dome
        _drawOnionDome(canvas, rightBase - 98, bottom - 30, 28, 34, fillSoft, linePaint);
        _drawOnionDome(canvas, rightBase - 46, bottom - 30, 28, 34, fillSoft, linePaint);
        _drawOnionDome(canvas, rightBase - 72, bottom - 32, 46, 54, fillMid, linePaint, withFinial: true);

        // Mughal facade with grand center pishtaq arch
        _drawArcadeWall(canvas, rightBase - 122, bottom, 102, 32, 3, fillMid, linePaint, archCut);
        break;

      default:
        // ISHA: Celestial night moon & stars + Grand multi-dome Sheikh Zayed style
        _drawCrescentMoon(canvas, Offset(rightBase - 54, 28), 11.5, Colors.white.withOpacity(0.92));
        _drawTwinklingStar(canvas, Offset(rightBase - 92, 22), 4.5, Colors.white.withOpacity(0.85));
        _drawTwinklingStar(canvas, Offset(rightBase - 26, 46), 3.8, Colors.white.withOpacity(0.75));
        _drawTwinklingStar(canvas, Offset(rightBase - 114, 42), 3.2, Colors.white.withOpacity(0.65));

        // Outer small domes
        _drawDome(canvas, rightBase - 122, bottom - 26, 26, 26, fillSoft, linePaint);
        _drawDome(canvas, rightBase - 22, bottom - 26, 26, 26, fillSoft, linePaint);

        // Inner medium domes
        _drawDome(canvas, rightBase - 98, bottom - 28, 34, 34, fillSoft, linePaint);
        _drawDome(canvas, rightBase - 46, bottom - 28, 34, 34, fillSoft, linePaint);

        // Grand central dome
        _drawDome(canvas, rightBase - 72, bottom - 30, 54, 52, fillMid, linePaint, withFinial: true);

        // Ornate flanking minarets
        _drawTieredMinaret(canvas, rightBase - 118, bottom, 9.5, 92, fillMid, linePaint);
        _drawTieredMinaret(canvas, rightBase - 34, bottom, 9.5, 92, fillMid, linePaint);

        _drawArcadeWall(canvas, rightBase - 128, bottom, 114, 28, 6, fillMid, linePaint, archCut);
        break;
    }
  }

  void _drawDome(
    Canvas canvas,
    double cx,
    double baseY,
    double w,
    double h,
    Paint fill,
    Paint stroke, {
    bool withFinial = false,
  }) {
    final rect = Rect.fromCenter(center: Offset(cx, baseY), width: w, height: h);
    canvas.drawArc(rect, math.pi, math.pi, true, fill);
    canvas.drawArc(rect, math.pi, math.pi, false, stroke);
    if (withFinial) {
      final topY = baseY - (h / 2);
      canvas.drawLine(Offset(cx, topY), Offset(cx, topY - 12), stroke);
      canvas.drawCircle(Offset(cx, topY - 14), 2.2, Paint()..color = Colors.white.withOpacity(0.8));
    }
  }

  void _drawOnionDome(
    Canvas canvas,
    double cx,
    double baseY,
    double w,
    double h,
    Paint fill,
    Paint stroke, {
    bool withFinial = false,
  }) {
    final r = w / 2;
    final path = Path()
      ..moveTo(cx - r * 0.78, baseY)
      ..cubicTo(cx - r * 1.15, baseY - h * 0.35, cx - r * 0.9, baseY - h * 0.72, cx, baseY - h)
      ..cubicTo(cx + r * 0.9, baseY - h * 0.72, cx + r * 1.15, baseY - h * 0.35, cx + r * 0.78, baseY)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    if (withFinial) {
      final topY = baseY - h;
      canvas.drawLine(Offset(cx, topY), Offset(cx, topY - 11), stroke);
      canvas.drawCircle(Offset(cx, topY - 13), 2.2, Paint()..color = Colors.white.withOpacity(0.8));
    }
  }

  void _drawTieredMinaret(
    Canvas canvas,
    double x,
    double bottom,
    double w,
    double totalH,
    Paint fill,
    Paint stroke,
  ) {
    final spireH = 18.0;
    final shaftH = totalH - spireH;
    final shaftRect = Rect.fromLTWH(x, bottom - shaftH, w, shaftH);
    canvas.drawRect(shaftRect, fill);
    canvas.drawRect(shaftRect, stroke);

    // Dual balconies
    for (final ratio in [0.68, 0.96]) {
      final balRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 2.5, bottom - shaftH * ratio, w + 5, 3.5),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(balRect, fill);
      canvas.drawRRect(balRect, stroke);
    }

    // Pointed spire + finial
    final spire = Path()
      ..moveTo(x - 1, bottom - shaftH)
      ..lineTo(x + w / 2, bottom - totalH)
      ..lineTo(x + w + 1, bottom - shaftH)
      ..close();
    canvas.drawPath(spire, fill);
    canvas.drawPath(spire, stroke);
    canvas.drawCircle(Offset(x + w / 2, bottom - totalH - 2), 1.8, Paint()..color = Colors.white.withOpacity(0.8));
  }

  void _drawPencilMinaret(
    Canvas canvas,
    double x,
    double bottom,
    double w,
    double totalH,
    Paint fill,
    Paint stroke,
  ) {
    final spireH = 20.0;
    final shaftH = totalH - spireH;
    final shaftRect = Rect.fromLTWH(x, bottom - shaftH, w, shaftH);
    canvas.drawRect(shaftRect, fill);
    canvas.drawRect(shaftRect, stroke);

    final balRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - 2, bottom - shaftH, w + 4, 3),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(balRect, fill);
    canvas.drawRRect(balRect, stroke);

    final spire = Path()
      ..moveTo(x, bottom - shaftH)
      ..lineTo(x + w / 2, bottom - totalH)
      ..lineTo(x + w, bottom - shaftH)
      ..close();
    canvas.drawPath(spire, fill);
    canvas.drawPath(spire, stroke);
  }

  void _drawArcadeWall(
    Canvas canvas,
    double startX,
    double bottom,
    double width,
    double height,
    int archCount,
    Paint fill,
    Paint stroke,
    Paint archCut,
  ) {
    final wallRect = Rect.fromLTWH(startX, bottom - height, width, height);
    canvas.drawRect(wallRect, fill);
    canvas.drawRect(wallRect, stroke);

    final step = width / archCount;
    final archW = math.min(11.0, step * 0.52);
    for (int i = 0; i < archCount; i++) {
      final archX = startX + (step * i) + (step - archW) / 2;
      final archPath = Path()
        ..moveTo(archX, bottom)
        ..lineTo(archX, bottom - height * 0.45)
        ..arcToPoint(Offset(archX + archW, bottom - height * 0.45), radius: Radius.circular(archW / 2))
        ..lineTo(archX + archW, bottom)
        ..close();
      canvas.drawPath(archPath, archCut);
      canvas.drawPath(archPath, stroke);
    }
  }

  void _drawCrescentMoon(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..addArc(Rect.fromCircle(center: center, radius: radius), -math.pi * 0.5, math.pi * 1.5)
      ..arcToPoint(
        Offset(center.dx, center.dy - radius),
        radius: Radius.circular(radius * 0.78),
        clockwise: false,
      );
    canvas.drawPath(path, paint);
  }

  void _drawTwinklingStar(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MosqueArtPainter oldDelegate) =>
      oldDelegate.prayerIndex != prayerIndex;
}
