import 'dart:convert';
import 'dart:math' as math;

/// Represents a real nearby mosque/masjid fetched for the user's current GPS location.
class MosqueItem {
  final String name;
  final String address;
  final String distanceText;
  final double? lat;
  final double? lng;
  final double? distanceMeters;
  final String imageUrl;
  final bool isFallbackName;

  const MosqueItem({
    required this.name,
    required this.address,
    required this.distanceText,
    this.lat,
    this.lng,
    this.distanceMeters,
    required this.imageUrl,
    this.isFallbackName = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'distanceText': distanceText,
        'lat': lat,
        'lng': lng,
        'distanceMeters': distanceMeters,
        'imageUrl': imageUrl,
      };

  factory MosqueItem.fromJson(Map<String, dynamic> json) => MosqueItem(
        name: json['name'] ?? 'Mosque',
        address: json['address'] ?? '',
        distanceText: json['distanceText'] ?? 'Nearby',
        lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
        lng: json['lng'] != null ? (json['lng'] as num).toDouble() : null,
        distanceMeters: json['distanceMeters'] != null
            ? (json['distanceMeters'] as num).toDouble()
            : null,
        imageUrl: json['imageUrl'] ?? NearbyMasjidService.mosqueImagePool.first,
      );
}

/// Pure, testable service logic for distance calculation, multi-source OSM
/// mosque parsing, smart local radius tiering, transliteration, and cache validation.
class NearbyMasjidService {
  static const double maxSearchRadiusMeters = 2500.0;
  static const double maxCacheDriftMeters = 250.0;
  static const Duration maxCacheAge = Duration(hours: 6);

  /// Bundled local mosque photographs from `assets/images/`.
  static const List<String> mosqueImagePool = [
    'assets/images/mosque_faisal.jpg',
    'assets/images/mosque_badshahi.jpg',
    'assets/images/mosque_nabawi.jpg',
    'assets/images/mosque_zayed.jpg',
    'assets/images/mosque_blue.jpg',
    'assets/images/mosque_alaqsa.jpg',
  ];

  static const Set<String> _excludedNonMosqueKeys = {
    'highway',
    'shop',
    'tourism',
    'route',
    'boundary',
    'place',
    'railway',
    'natural',
    'waterway',
    'power',
    'public_transport',
  };

  static const Set<String> _excludedAmenities = {
    'restaurant',
    'cafe',
    'fast_food',
    'bank',
    'atm',
    'pharmacy',
    'hospital',
    'clinic',
    'fuel',
    'school',
    'college',
    'university',
    'bus_station',
    'parking',
    'marketplace',
    'police',
    'post_office',
    'toilets',
  };

  static const Map<String, String> _urduWordMap = {
    'ایبٹ آباد': 'Abbottabad',
    'اسلام آباد': 'Islamabad',
    'راولپنڈی': 'Rawalpindi',
    'فیصل آباد': 'Faisalabad',
    'گوجرانوالہ': 'Gujranwala',
    'جناح آباد': 'Jinnahabad',
    'نواں شہر': 'Nawan Shehr',
    'بلوچستان': 'Balochistan',
    'اہلحدیث': 'Ahle Hadith',
    'اہلسنت': 'Ahle Sunnat',
    'نقشبندیہ': 'Naqshbandia',
    'یونیورسٹی': 'University',
    'سوسائٹی': 'Society',
    'انکلیو': 'Enclave',
    'کمپلیکس': 'Complex',
    'اسٹریٹ': 'Street',
    'سٹریٹ': 'Street',
    'شاہراہ': 'Shahrah',
    'کالونی': 'Colony',
    'ہاؤسنگ': 'Housing',
    'مارکیٹ': 'Market',
    'پاکستان': 'Pakistan',
    'سیالکوٹ': 'Sialkot',
    'پشاور': 'Peshawar',
    'کراچی': 'Karachi',
    'ملتان': 'Multan',
    'کوئٹہ': 'Quetta',
    'لاہور': 'Lahore',
    'مانسہرہ': 'Mansehra',
    'حویلیاں': 'Havelian',
    'منڈیاں': 'Mandian',
    'سپلائی': 'Supply',
    'میرپور': 'Mirpur',
    'کاکول': 'Kakul',
    'اسپتال': 'Hospital',
    'ہسپتال': 'Hospital',
    'پنجاب': 'Punjab',
    'سندھ': 'Sindh',
    'تحصیل': 'Tehsil',
    'ضلع': 'District',
    'گاؤں': 'Village',
    'محلہ': 'Mohallah',
    'بازار': 'Bazaar',
    'سیکٹر': 'Sector',
    'ٹاؤن': 'Town',
    'بلاک': 'Block',
    'بلاگ': 'Block',
    'چوک': 'Chowk',
    'موڑ': 'More',
    'روڈ': 'Road',
    'شہر': 'City',
    'پارک': 'Park',
    'گیٹ': 'Gate',
    'نگر': 'Nagar',
    'آباد': 'Abad',
    'والا': 'Wala',
    'والی': 'Wali',
    'گلی': 'Street',
    'فیز': 'Phase',
    'چک': 'Chak',
    'پور': 'Pur',
    'نمبر': 'No.',
    'قریب': 'Near',
    'ابوبکر': 'Abu Bakr',
    'عثمانیہ': 'Usmania',
    'فاروقیہ': 'Farooqia',
    'صدیقیہ': 'Siddiqia',
    'قادریہ': 'Qadria',
    'چشتیہ': 'Chishtia',
    'رضویہ': 'Rizvia',
    'حنفیہ': 'Hanfia',
    'محمدی': 'Muhammadi',
    'اسلامیہ': 'Islamia',
    'عیدگاہ': 'Eidgah',
    'مدرسہ': 'Madrasa',
    'مرکزی': 'Markazi',
    'مرکز': 'Markaz',
    'توحید': 'Tauheed',
    'غوثیہ': 'Ghausia',
    'فیضان': 'Faizan',
    'مصطفی': 'Mustafa',
    'مدینہ': 'Madina',
    'مدنیہ': 'Madania',
    'مدنی': 'Madani',
    'رحمان': 'Rehman',
    'رحیم': 'Rahim',
    'کریم': 'Karim',
    'محمد': 'Muhammad',
    'فاروق': 'Farooq',
    'عثمان': 'Usman',
    'صدیق': 'Siddiq',
    'شہید': 'Shaheed',
    'حسین': 'Hussain',
    'خالد': 'Khalid',
    'اقصیٰ': 'Al-Aqsa',
    'اقصی': 'Al-Aqsa',
    'الہی': 'Ilahi',
    'سعد بن ابی وقاص': 'Saad Bin Abi Waqas',
    'طیبہ': 'Tayyaba',
    'نوری': 'Noori',
    'نور': 'Noor',
    'جامعہ': 'Jamia',
    'جامع': 'Jamia',
    'مسجد': 'Masjid',
    'مکہ': 'Makkah',
    'بلال': 'Bilal',
    'عمر': 'Umar',
    'علی': 'Ali',
    'حرم': 'Haram',
    'قباء': 'Quba',
    'شاہی': 'Shahi',
    'غازی': 'Ghazi',
    'حسن': 'Hassan',
    'بیت': 'Bait',
    'کالج': 'College',
  };

  static final List<MapEntry<String, String>> _sortedUrduWords =
      _urduWordMap.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length));

  static const Map<String, String> _urduCharMap = {
    'ا': 'a', 'آ': 'Aa', 'أ': 'a', 'إ': 'i', 'ٱ': 'a',
    'ب': 'b', 'پ': 'p', 'ت': 't', 'ٹ': 't', 'ث': 's',
    'ج': 'j', 'چ': 'ch', 'ح': 'h', 'خ': 'kh',
    'د': 'd', 'ڈ': 'd', 'ذ': 'z',
    'ر': 'r', 'ڑ': 'r', 'ز': 'z', 'ژ': 'zh',
    'س': 's', 'ش': 'sh', 'ص': 's', 'ض': 'z',
    'ط': 't', 'ظ': 'z', 'ع': 'a', 'غ': 'gh',
    'ف': 'f', 'ڤ': 'v', 'ق': 'q', 'ک': 'k', 'ك': 'k', 'گ': 'g',
    'ل': 'l', 'م': 'm', 'ن': 'n', 'ں': 'n',
    'و': 'o', 'ؤ': 'o',
    'ہ': 'h', 'ه': 'h', 'ۂ': 'h', 'ۃ': 'h', 'ة': 'h', 'ھ': 'h',
    'ء': '', 'ی': 'i', 'ي': 'i', 'ى': 'a', 'ئ': 'i', 'ے': 'e',
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
    '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    '،': ',', '۔': '.',
  };

  /// Transliterates Urdu/Arabic text into clean English/Roman text.
  static String urduToEnglish(String input) {
    if (input.isEmpty) return input;
    String result = input.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

    for (final entry in _sortedUrduWords) {
      result = result.replaceAll(entry.key, ' ${entry.value} ');
    }

    final buffer = StringBuffer();
    for (int i = 0; i < result.length; i++) {
      final ch = result[i];
      buffer.write(_urduCharMap[ch] ?? ch);
    }

    String cleaned = buffer
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*,\s*'), ', ')
        .replaceAll(RegExp(r',\s*,+'), ',')
        .trim();

    if (cleaned.isNotEmpty) {
      cleaned = cleaned.split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : '');
      }).join(' ');
    }
    return cleaned;
  }

  /// Calculates Haversine distance in meters. Returns [double.infinity] when
  /// target coordinates are missing so unlocated items cannot pass radius checks.
  static double calcDistanceMeters(
    double lat1,
    double lon1,
    double? lat2,
    double? lon2,
  ) {
    if (lat2 == null || lon2 == null) return double.infinity;
    const double p = 0.017453292519943295;
    final double a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742000.0 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  }

  static double parseDistanceInMeters(String text) {
    if (text.toLowerCase().contains('km')) {
      final val =
          double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 9999.0;
      return val * 1000.0;
    }
    return double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 9999.0;
  }

  static String formatDistanceText(double distMeters) {
    if (distMeters >= 1000.0) {
      final double km = distMeters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
    final int meters = distMeters.round().clamp(1, 999);
    return '$meters m';
  }

  static String formatWalkTime(double? distMeters) {
    final int mins = ((distMeters ?? 250.0) / 80.0).ceil().clamp(1, 60);
    return '~$mins min walk';
  }

  /// Extracts the most specific local neighborhood/area name (e.g. "Mandian")
  /// from an OSM Nominatim reverse-geocode `address` object.
  static String extractLocalAreaTag(Map<String, dynamic>? addr) {
    if (addr == null) return '';
    const keys = [
      'neighbourhood:en',
      'neighbourhood',
      'quarter:en',
      'quarter',
      'suburb:en',
      'suburb',
      'residential:en',
      'residential',
      'locality:en',
      'locality',
      'village:en',
      'village',
      'city_district:en',
      'city_district',
      'town:en',
      'town',
      'city:en',
      'city',
      'county',
    ];
    for (final k in keys) {
      final raw = addr[k]?.toString().trim() ?? '';
      if (raw.isNotEmpty) {
        return urduToEnglish(raw);
      }
    }
    return '';
  }

  static String extractEnglishAddress(
    Map<String, dynamic>? addr,
    String displayName,
    String fallbackArea,
  ) {
    if (addr != null) {
      final road = addr['road:en'] ?? addr['road'] ?? addr['street'] ?? '';
      final suburb = addr['neighbourhood:en'] ??
          addr['neighbourhood'] ??
          addr['quarter:en'] ??
          addr['quarter'] ??
          addr['suburb:en'] ??
          addr['suburb'] ??
          addr['residential'] ??
          '';
      final city = addr['city:en'] ??
          addr['city'] ??
          addr['town:en'] ??
          addr['town'] ??
          addr['county'] ??
          fallbackArea;

      final parts = <String>[];
      if (road.toString().trim().isNotEmpty) {
        parts.add(urduToEnglish(road.toString().trim()));
      }
      if (suburb.toString().trim().isNotEmpty) {
        parts.add(urduToEnglish(suburb.toString().trim()));
      }
      if (city.toString().trim().isNotEmpty) {
        parts.add(urduToEnglish(city.toString().trim()));
      }

      if (parts.isNotEmpty) {
        return parts.toSet().take(2).join(', ');
      }
    }

    if (displayName.isNotEmpty) {
      final segments = displayName
          .split(',')
          .map((s) => urduToEnglish(s.trim()))
          .where((s) => s.isNotEmpty)
          .toList();
      if (segments.length > 1) {
        return '${segments[1]}, ${segments.length > 2 ? segments[2] : segments[0]}';
      }
      if (segments.isNotEmpty) return segments.first;
    }

    return fallbackArea.isNotEmpty ? urduToEnglish(fallbackArea) : 'Nearby';
  }

  /// Queries mosques using indexed Overpass tags within [radiusMeters] so the
  /// server responds quickly (avoiding slow unindexed name regex full-scans).
  static String buildOverpassQuery(
    double lat,
    double lon, {
    double radiusMeters = maxSearchRadiusMeters,
  }) {
    final int r = radiusMeters.round();
    return '[out:json][timeout:12];('
        'nwr["amenity"="place_of_worship"](around:$r,$lat,$lon);'
        'nwr["building"="mosque"](around:$r,$lat,$lon);'
        'nwr["amenity"="mosque"](around:$r,$lat,$lon);'
        ');out center;';
  }

  static bool _isExcludedReligion(String? religion) {
    if (religion == null) return false;
    final r = religion.trim().toLowerCase();
    if (r.isEmpty || r == 'muslim' || r == 'islam') return false;
    return true;
  }

  static bool _isNonMuslimPlaceName(String name) {
    final lower = name.toLowerCase();
    return lower.contains('church') ||
        lower.contains('cathedral') ||
        lower.contains('chapel') ||
        lower.contains('temple') ||
        lower.contains('mandir') ||
        lower.contains('gurdwara') ||
        lower.contains('synagogue') ||
        lower.contains('shrine') && !lower.contains('masjid');
  }

  static bool _looksLikeMosqueName(String name) {
    final lower = name.toLowerCase();
    return lower.contains('masjid') ||
        lower.contains('mosque') ||
        lower.contains('jamia') ||
        lower.contains('jamiah') ||
        lower.contains('eidgah') ||
        lower.contains('musalla') ||
        lower.contains('مسجد') ||
        lower.contains('جامع');
  }

  static String _normalizeMosqueTitle(String rawName) {
    String clean = urduToEnglish(rawName).trim();
    if (clean.isEmpty) return '';
    final lower = clean.toLowerCase();
    if (!lower.contains('masjid') &&
        !lower.contains('mosque') &&
        !lower.contains('jamia') &&
        !lower.contains('eidgah') &&
        !lower.contains('musalla') &&
        !lower.contains('imambargah')) {
      clean = 'Masjid $clean';
    }
    return clean;
  }

  static String _resolveLocalAssetImage(String? candidate, int index) {
    if (candidate != null && mosqueImagePool.contains(candidate)) {
      return candidate;
    }
    return mosqueImagePool[index % mosqueImagePool.length];
  }

  static void _insertCandidate({
    required List<MosqueItem> target,
    required double userLat,
    required double userLon,
    required double radiusMeters,
    required String rawName,
    required double mLat,
    required double mLon,
    required String address,
    bool isFallbackName = false,
  }) {
    final double distMeters = calcDistanceMeters(userLat, userLon, mLat, mLon);
    if (!distMeters.isFinite || distMeters > radiusMeters) return;

    final String cleanName = _normalizeMosqueTitle(rawName);
    if (cleanName.isEmpty) return;

    final String cleanAddress = urduToEnglish(address);

    // 1. Check if virtually identical coordinates (< 25m): e.g. node + building polygon
    final int existingCoordIdx = target.indexWhere((existing) {
      if (existing.lat == null || existing.lng == null) return false;
      return calcDistanceMeters(existing.lat!, existing.lng!, mLat, mLon) < 25.0;
    });
    if (existingCoordIdx != -1) {
      final existing = target[existingCoordIdx];
      final bool existingGeneric = existing.isFallbackName ||
          existing.name == 'Local Masjid' ||
          existing.name == 'Nearby Masjid';
      final bool candidateGeneric = isFallbackName ||
          cleanName == 'Local Masjid' ||
          cleanName == 'Nearby Masjid';
      if (existingGeneric && !candidateGeneric) {
        target[existingCoordIdx] = MosqueItem(
          name: cleanName,
          address: cleanAddress.isNotEmpty ? cleanAddress : existing.address,
          distanceText: formatDistanceText(distMeters),
          lat: mLat,
          lng: mLon,
          distanceMeters: distMeters,
          imageUrl: existing.imageUrl,
          isFallbackName: false,
        );
      }
      return;
    }

    // 2. Deduplicate identical name within 150m (e.g., entrance node vs hall node)
    final lowerName = cleanName.toLowerCase();
    final bool duplicateNearbyName = target.any((existing) {
      if (existing.name.toLowerCase() != lowerName) return false;
      if (existing.lat == null || existing.lng == null) return true;
      return calcDistanceMeters(existing.lat!, existing.lng!, mLat, mLon) < 150.0;
    });
    if (duplicateNearbyName) return;

    target.add(MosqueItem(
      name: cleanName,
      address: cleanAddress,
      distanceText: formatDistanceText(distMeters),
      lat: mLat,
      lng: mLon,
      distanceMeters: distMeters,
      imageUrl: _resolveLocalAssetImage(null, target.length),
      isFallbackName: isFallbackName,
    ));
  }

  /// Parses Overpass API JSON elements into deduplicated, sorted [MosqueItem]s
  /// strictly within [radiusMeters] of the user's coordinates.
  static List<MosqueItem> parseOverpassElements({
    required List<dynamic> elements,
    required double userLat,
    required double userLon,
    double radiusMeters = maxSearchRadiusMeters,
    String fallbackArea = '',
    List<MosqueItem>? existingResults,
  }) {
    final List<MosqueItem> results = List<MosqueItem>.from(existingResults ?? []);

    for (final el in elements) {
      if (el is! Map) continue;
      final tags =
          (el['tags'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

      if (_isExcludedReligion(tags['religion']?.toString())) continue;
      if (_excludedNonMosqueKeys.any((k) => tags.containsKey(k))) continue;

      final amenity = tags['amenity']?.toString().toLowerCase() ?? '';
      if (amenity.isNotEmpty && _excludedAmenities.contains(amenity)) {
        continue;
      }

      final double? mLat = (el['lat'] as num?)?.toDouble() ??
          ((el['center'] is Map)
              ? (el['center']['lat'] as num?)?.toDouble()
              : null);
      final double? mLon = (el['lon'] as num?)?.toDouble() ??
          ((el['center'] is Map)
              ? (el['center']['lon'] as num?)?.toDouble()
              : null);
      if (mLat == null || mLon == null) continue;

      final street =
          (tags['addr:street'] ?? tags['addr:place'] ?? '').toString().trim();
      final area = (tags['addr:suburb'] ??
              tags['addr:neighbourhood'] ??
              tags['addr:city'] ??
              fallbackArea)
          .toString()
          .trim();

      String rawName = (tags['name:en'] ??
              tags['int_name'] ??
              tags['name'] ??
              tags['official_name'] ??
              tags['alt_name'] ??
              '')
          .toString()
          .trim();

      if (rawName.isNotEmpty &&
          (tags['religion']?.toString().trim().toLowerCase() ?? '') !=
              'muslim' &&
          _isNonMuslimPlaceName(rawName)) {
        continue;
      }

      final bool isFallbackName = rawName.isEmpty;
      if (isFallbackName) {
        if (street.isNotEmpty) {
          rawName = 'Masjid (${urduToEnglish(street)})';
        } else if (area.isNotEmpty) {
          rawName = 'Masjid (${urduToEnglish(area)})';
        } else {
          rawName = 'Local Masjid';
        }
      }

      final parts = <String>[];
      if (street.isNotEmpty) parts.add(urduToEnglish(street));
      if (area.isNotEmpty) parts.add(urduToEnglish(area));
      final address = parts.isNotEmpty
          ? parts.toSet().join(', ')
          : (fallbackArea.isNotEmpty ? urduToEnglish(fallbackArea) : 'Nearby');

      _insertCandidate(
        target: results,
        userLat: userLat,
        userLon: userLon,
        radiusMeters: radiusMeters,
        rawName: rawName,
        mLat: mLat,
        mLon: mLon,
        address: address,
        isFallbackName: isFallbackName,
      );
    }

    sortByDistance(results);
    return results;
  }

  /// Parses Komoot Photon GeoJSON features, accepting only actual mosque /
  /// place_of_worship features within [radiusMeters].
  static List<MosqueItem> parsePhotonFeatures({
    required List<dynamic> features,
    required double userLat,
    required double userLon,
    double radiusMeters = maxSearchRadiusMeters,
    String fallbackArea = '',
    List<MosqueItem>? existingResults,
  }) {
    final List<MosqueItem> results = List<MosqueItem>.from(existingResults ?? []);

    for (final feature in features) {
      if (feature is! Map) continue;
      final geometry = feature['geometry'];
      final props = (feature['properties'] as Map?)?.cast<String, dynamic>();
      if (geometry is! Map || props == null) continue;

      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final double? mLon = (coords[0] as num?)?.toDouble();
      final double? mLat = (coords[1] as num?)?.toDouble();
      if (mLat == null || mLon == null) continue;

      final osmKey = (props['osm_key'] ?? '').toString().toLowerCase();
      final osmValue = (props['osm_value'] ?? '').toString().toLowerCase();
      final rawName = (props['name'] ?? '').toString().trim();

      if (_excludedNonMosqueKeys.contains(osmKey)) continue;
      if (osmKey == 'amenity' && _excludedAmenities.contains(osmValue)) continue;

      final bool isTaggedMosque =
          (osmKey == 'amenity' &&
              (osmValue == 'place_of_worship' || osmValue == 'mosque')) ||
          (osmKey == 'building' && osmValue == 'mosque');
      final bool isNamedMosqueBuilding =
          (osmKey == 'building' || osmKey == 'landuse' || osmKey.isEmpty) &&
              _looksLikeMosqueName(rawName);
      if (!isTaggedMosque && !isNamedMosqueBuilding) continue;
      if (rawName.isEmpty) continue;

      final street = (props['street'] ?? '').toString().trim();
      final area = (props['district'] ??
              props['locality'] ??
              props['city'] ??
              fallbackArea)
          .toString()
          .trim();
      final parts = <String>[];
      if (street.isNotEmpty) parts.add(urduToEnglish(street));
      if (area.isNotEmpty) parts.add(urduToEnglish(area));
      final address = parts.isNotEmpty
          ? parts.toSet().join(', ')
          : (fallbackArea.isNotEmpty ? urduToEnglish(fallbackArea) : 'Nearby');

      _insertCandidate(
        target: results,
        userLat: userLat,
        userLon: userLon,
        radiusMeters: radiusMeters,
        rawName: rawName,
        mLat: mLat,
        mLon: mLon,
        address: address,
      );
    }

    sortByDistance(results);
    return results;
  }

  /// Parses Nominatim search JSON results, strictly accepting only actual mosque
  /// / place_of_worship features (rejecting streets, shops, colonies, etc.).
  static List<MosqueItem> parseNominatimItems({
    required List<dynamic> items,
    required double userLat,
    required double userLon,
    double radiusMeters = maxSearchRadiusMeters,
    String fallbackArea = '',
    List<MosqueItem>? existingResults,
  }) {
    final List<MosqueItem> results = List<MosqueItem>.from(existingResults ?? []);

    for (final item in items) {
      if (item is! Map) continue;
      final osmClass = (item['class'] ?? '').toString().toLowerCase();
      final osmType = (item['type'] ?? '').toString().toLowerCase();
      if (_excludedNonMosqueKeys.contains(osmClass)) continue;

      final namedetails =
          (item['namedetails'] as Map?)?.cast<String, dynamic>();
      String name =
          (namedetails?['name:en'] ?? item['name'] ?? '').toString().trim();
      final displayName = (item['display_name'] ?? '').toString().trim();
      if (name.isEmpty && displayName.isNotEmpty) {
        name = displayName.split(',')[0].trim();
      }

      final bool isTaggedMosque =
          (osmClass == 'amenity' &&
              (osmType == 'place_of_worship' || osmType == 'mosque')) ||
          (osmClass == 'building' && osmType == 'mosque');
      final bool isNamedMosqueBuilding =
          osmClass == 'building' && _looksLikeMosqueName(name);
      if (!isTaggedMosque && !isNamedMosqueBuilding) continue;

      final extratags =
          (item['extratags'] as Map?)?.cast<String, dynamic>();
      if (_isExcludedReligion(extratags?['religion']?.toString())) continue;

      final mLat = double.tryParse(item['lat']?.toString() ?? '');
      final mLon = double.tryParse(item['lon']?.toString() ?? '');
      if (mLat == null || mLon == null) continue;
      if (name.isEmpty) continue;

      final addr = (item['address'] as Map?)?.cast<String, dynamic>();
      final address = extractEnglishAddress(addr, displayName, fallbackArea);

      _insertCandidate(
        target: results,
        userLat: userLat,
        userLon: userLon,
        radiusMeters: radiusMeters,
        rawName: name,
        mLat: mLat,
        mLon: mLon,
        address: address,
      );
    }

    sortByDistance(results);
    return results;
  }

  /// Smart local radius tiering: always prioritizes the closest masjids right
  /// around the user's current GPS spot (<= 650m when >= 2 exist, else 1km -> 1.5km -> 2km).
  static List<MosqueItem> selectNearestLocalMosques(
    List<MosqueItem> sortedMosques, {
    int maxCount = 8,
  }) {
    if (sortedMosques.isEmpty) return [];
    final within650 = sortedMosques
        .where((m) => (m.distanceMeters ?? 99999.0) <= 650.0)
        .toList();
    if (within650.length >= 2) {
      return within650.take(maxCount).toList();
    }
    final within1000 = sortedMosques
        .where((m) => (m.distanceMeters ?? 99999.0) <= 1000.0)
        .toList();
    if (within1000.length >= 2) {
      return within1000.take(maxCount).toList();
    }
    final within1500 = sortedMosques
        .where((m) => (m.distanceMeters ?? 99999.0) <= 1500.0)
        .toList();
    if (within1500.isNotEmpty) {
      return within1500.take(maxCount).toList();
    }
    return sortedMosques
        .where((m) => (m.distanceMeters ?? 99999.0) <= maxSearchRadiusMeters)
        .take(maxCount)
        .toList();
  }

  static void sortByDistance(List<MosqueItem> mosques) {
    mosques.sort((a, b) {
      final dA = a.distanceMeters ?? parseDistanceInMeters(a.distanceText);
      final dB = b.distanceMeters ?? parseDistanceInMeters(b.distanceText);
      return dA.compareTo(dB);
    });
  }

  /// Validates whether cached mosques belong to the user's current location
  /// (within [maxDriftMeters]) and are not expired.
  static bool isCacheValidForCoordinates({
    required double? cachedLat,
    required double? cachedLng,
    required int? cachedTimestampMs,
    required double currentLat,
    required double currentLng,
    double maxDriftMeters = maxCacheDriftMeters,
    Duration maxAge = const Duration(hours: 24),
    DateTime? now,
  }) {
    if (cachedLat == null || cachedLng == null || cachedTimestampMs == null) {
      return false;
    }
    final currentTime = now ?? DateTime.now();
    final ageMs = currentTime.millisecondsSinceEpoch - cachedTimestampMs;
    if (ageMs < 0 || ageMs > maxAge.inMilliseconds) {
      return false;
    }
    final drift = calcDistanceMeters(cachedLat, cachedLng, currentLat, currentLng);
    return drift.isFinite && drift <= maxDriftMeters;
  }

  /// Recomputes live distances from the current GPS fix for validated cached
  /// mosques and ensures local asset image paths.
  static List<MosqueItem> decodeAndValidateCachedMosques({
    required String? rawJson,
    required double currentLat,
    required double currentLng,
    double radiusMeters = maxSearchRadiusMeters,
  }) {
    if (rawJson == null || rawJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return [];
      final List<MosqueItem> validated = [];
      for (int i = 0; i < decoded.length; i++) {
        final raw = decoded[i];
        if (raw is! Map) continue;
        final item = MosqueItem.fromJson(raw.cast<String, dynamic>());
        if (item.lat == null || item.lng == null) continue;
        final dist = calcDistanceMeters(currentLat, currentLng, item.lat, item.lng);
        if (!dist.isFinite || dist > radiusMeters) continue;
        validated.add(MosqueItem(
          name: urduToEnglish(item.name),
          address: urduToEnglish(item.address),
          distanceText: formatDistanceText(dist),
          lat: item.lat,
          lng: item.lng,
          distanceMeters: dist,
          imageUrl: _resolveLocalAssetImage(item.imageUrl, validated.length),
        ));
      }
      sortByDistance(validated);
      return selectNearestLocalMosques(validated);
    } catch (_) {
      return [];
    }
  }
}
