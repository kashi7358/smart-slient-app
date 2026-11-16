import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_silent/Utils/nearby_masjid_service.dart';

void main() {
  // Approximate coordinates inside Mandian, Abbottabad
  const double mandianLat = 34.1872;
  const double mandianLon = 73.2414;

  group('NearbyMasjidService distance, formatting, and local asset images', () {
    test('returns infinity when target coordinates are null', () {
      expect(
        NearbyMasjidService.calcDistanceMeters(mandianLat, mandianLon, null, 73.24),
        double.infinity,
      );
      expect(
        NearbyMasjidService.calcDistanceMeters(mandianLat, mandianLon, 34.18, null),
        double.infinity,
      );
    });

    test('formats meter and km distances and walk time cleanly', () {
      expect(NearbyMasjidService.formatDistanceText(240.4), '240 m');
      expect(NearbyMasjidService.formatDistanceText(1240.0), '1.2 km');
      expect(NearbyMasjidService.formatWalkTime(240.0), '~3 min walk');
    });

    test('uses bundled local assets/images/ mosque photos instead of network URLs', () {
      for (final path in NearbyMasjidService.mosqueImagePool) {
        expect(path.startsWith('assets/images/mosque_'), isTrue);
      }
    });
  });

  group('Overpass and Photon parsing & smart local tiering', () {
    test('includes Mandian mosques, catches named mosque buildings, excludes far & non-mosque items', () {
      final elements = [
        // ~410m north inside Mandian
        {
          'type': 'node',
          'lat': 34.1909,
          'lon': 73.2414,
          'tags': {
            'amenity': 'place_of_worship',
            'religion': 'muslim',
            'name': 'Bilal Masjid',
            'addr:suburb': 'Mandian',
          },
        },
        // ~110m south inside Mandian
        {
          'type': 'way',
          'center': {'lat': 34.1862, 'lon': 73.2414},
          'tags': {
            'amenity': 'place_of_worship',
            'religion': 'muslim',
            'name': 'جامع مسجد نوری',
            'addr:street': 'Mansehra Road',
            'addr:suburb': 'Mandian',
          },
        },
        // Named mosque building without amenity tag (~780m away in Mandian)
        {
          'type': 'way',
          'center': {'lat': 34.1942, 'lon': 73.2414},
          'tags': {
            'building': 'yes',
            'name': 'Jamia Masjid Al-Mustafa',
          },
        },
        // Highway named Masjid Road (~120m) - MUST be excluded
        {
          'type': 'way',
          'center': {'lat': 34.1883, 'lon': 73.2414},
          'tags': {
            'highway': 'residential',
            'name': 'Masjid Road',
          },
        },
        // ~4.5 km away (outside local radius) - MUST be excluded
        {
          'type': 'node',
          'lat': 34.1460,
          'lon': 73.2414,
          'tags': {
            'amenity': 'place_of_worship',
            'religion': 'muslim',
            'name': 'Far Away Masjid City',
          },
        },
        // Non-Muslim place of worship within 200m - MUST be excluded
        {
          'type': 'node',
          'lat': 34.1880,
          'lon': 73.2414,
          'tags': {
            'amenity': 'place_of_worship',
            'religion': 'christian',
            'name': 'St. Church',
          },
        },
      ];

      final mosques = NearbyMasjidService.parseOverpassElements(
        elements: elements,
        userLat: mandianLat,
        userLon: mandianLon,
        fallbackArea: 'Mandian',
      );

      expect(mosques.length, 3);
      expect(mosques[0].name, 'Jamia Masjid Noori');
      expect(mosques[0].imageUrl.startsWith('assets/images/'), isTrue);
      expect(mosques[1].name, 'Bilal Masjid');
      expect(mosques[2].name, 'Jamia Masjid Al-Mustafa');
    });

    test('parses Komoot Photon features and merges without duplicating Overpass items', () {
      final initial = [
        MosqueItem(
          name: 'Jamia Masjid Noori',
          address: 'Mandian',
          distanceText: '111 m',
          lat: 34.1862,
          lng: 73.2414,
          distanceMeters: 111.0,
          imageUrl: NearbyMasjidService.mosqueImagePool[0],
        ),
      ];

      final features = [
        // Duplicate within 25m of Jamia Masjid Noori -> ignored
        {
          'geometry': {
            'coordinates': [73.24141, 34.18622],
          },
          'properties': {
            'osm_key': 'amenity',
            'osm_value': 'place_of_worship',
            'name': 'Noori Masjid',
          },
        },
        // New mosque ~650m away in Mandian -> added
        {
          'geometry': {
            'coordinates': [73.2414, 34.1930],
          },
          'properties': {
            'osm_key': 'amenity',
            'osm_value': 'place_of_worship',
            'name': 'Masjid Usman',
            'district': 'Mandian',
          },
        },
        // Road in Photon -> rejected
        {
          'geometry': {
            'coordinates': [73.2415, 34.1875],
          },
          'properties': {
            'osm_key': 'highway',
            'osm_value': 'residential',
            'name': 'Masjid Gali',
          },
        },
      ];

      final merged = NearbyMasjidService.parsePhotonFeatures(
        features: features,
        userLat: mandianLat,
        userLon: mandianLon,
        fallbackArea: 'Mandian',
        existingResults: initial,
      );

      expect(merged.length, 2);
      expect(merged[1].name, 'Masjid Usman');
      expect(merged[1].address, 'Mandian');
    });

    test('selectNearestLocalMosques keeps <=650m when >=2 exist, else tiers smoothly up to 2km', () {
      final dense = [
        MosqueItem(name: 'M1', address: 'A', distanceText: '100 m', distanceMeters: 100, imageUrl: NearbyMasjidService.mosqueImagePool[0]),
        MosqueItem(name: 'M2', address: 'A', distanceText: '350 m', distanceMeters: 350, imageUrl: NearbyMasjidService.mosqueImagePool[1]),
        MosqueItem(name: 'M3', address: 'A', distanceText: '900 m', distanceMeters: 900, imageUrl: NearbyMasjidService.mosqueImagePool[2]),
        MosqueItem(name: 'M4', address: 'A', distanceText: '1.4 km', distanceMeters: 1400, imageUrl: NearbyMasjidService.mosqueImagePool[3]),
      ];
      final denseResult = NearbyMasjidService.selectNearestLocalMosques(dense);
      expect(denseResult.map((e) => e.name).toList(), ['M1', 'M2']);

      final sparse = [
        MosqueItem(name: 'M1', address: 'A', distanceText: '750 m', distanceMeters: 750, imageUrl: NearbyMasjidService.mosqueImagePool[0]),
        MosqueItem(name: 'M2', address: 'A', distanceText: '950 m', distanceMeters: 950, imageUrl: NearbyMasjidService.mosqueImagePool[1]),
        MosqueItem(name: 'M3', address: 'A', distanceText: '1.8 km', distanceMeters: 1800, imageUrl: NearbyMasjidService.mosqueImagePool[2]),
      ];
      final sparseResult = NearbyMasjidService.selectNearestLocalMosques(sparse);
      expect(sparseResult.map((e) => e.name).toList(), ['M1', 'M2']);
    });

    test('deduplicates colocated node and building polygon (< 25m) preferring named entry', () {
      final elements = [
        {
          'type': 'way',
          'center': {'lat': 34.1875, 'lon': 73.2415},
          'tags': {'building': 'mosque'},
        },
        {
          'type': 'node',
          'lat': 34.18755,
          'lon': 73.24152,
          'tags': {
            'amenity': 'place_of_worship',
            'religion': 'muslim',
            'name': 'Madina Masjid Mandian',
          },
        },
      ];

      final mosques = NearbyMasjidService.parseOverpassElements(
        elements: elements,
        userLat: mandianLat,
        userLon: mandianLon,
        fallbackArea: 'Mandian',
      );

      expect(mosques.length, 1);
      expect(mosques.first.name, 'Madina Masjid Mandian');
    });

    test('keeps two distinct mosques > 150m apart even if both share the name Jamia Masjid', () {
      final elements = [
        {
          'type': 'node',
          'lat': 34.1882,
          'lon': 73.2414,
          'tags': {'amenity': 'place_of_worship', 'religion': 'muslim', 'name': 'Jamia Masjid'},
        },
        {
          'type': 'node',
          'lat': 34.1848,
          'lon': 73.2414,
          'tags': {'amenity': 'place_of_worship', 'religion': 'muslim', 'name': 'Jamia Masjid'},
        },
      ];

      final mosques = NearbyMasjidService.parseOverpassElements(
        elements: elements,
        userLat: mandianLat,
        userLon: mandianLon,
      );

      expect(mosques.length, 2);
    });
  });

  group('Nominatim strict feature filtering', () {
    test('rejects Masjid Road and shops while accepting real mosque features', () {
      final items = [
        {
          'class': 'highway',
          'type': 'residential',
          'lat': '34.1878',
          'lon': '73.2414',
          'name': 'Masjid Road',
          'display_name': 'Masjid Road, Mandian, Abbottabad',
        },
        {
          'class': 'shop',
          'type': 'convenience',
          'lat': '34.1876',
          'lon': '73.2415',
          'name': 'Masjid Bakery',
          'display_name': 'Masjid Bakery, Mandian',
        },
        {
          'class': 'amenity',
          'type': 'place_of_worship',
          'lat': '34.1890',
          'lon': '73.2414',
          'name': 'Masjid Al-Quba',
          'extratags': {'religion': 'muslim'},
          'address': {'road': 'College Road', 'suburb': 'Mandian'},
        },
        // 4.5km away -> reject
        {
          'class': 'amenity',
          'type': 'place_of_worship',
          'lat': '34.1460',
          'lon': '73.2414',
          'name': 'City Central Masjid',
          'extratags': {'religion': 'muslim'},
        },
      ];

      final mosques = NearbyMasjidService.parseNominatimItems(
        items: items,
        userLat: mandianLat,
        userLon: mandianLon,
        fallbackArea: 'Mandian',
      );

      expect(mosques.length, 1);
      expect(mosques.first.name, 'Masjid Al-Quba');
      expect(mosques.first.address, 'College Road, Mandian');
    });
  });

  group('Cache location validation', () {
    test('invalidates cache when user moves > 250m (e.g. from city center to Mandian)', () {
      final now = DateTime(2026, 11, 12, 10, 30);
      final validSameSpot = NearbyMasjidService.isCacheValidForCoordinates(
        cachedLat: mandianLat,
        cachedLng: mandianLon,
        cachedTimestampMs: now.subtract(const Duration(minutes: 15)).millisecondsSinceEpoch,
        currentLat: mandianLat + 0.0005,
        currentLng: mandianLon,
        now: now,
      );
      expect(validSameSpot, isTrue);

      final invalidMoved = NearbyMasjidService.isCacheValidForCoordinates(
        cachedLat: 34.1495,
        cachedLng: 73.2194,
        cachedTimestampMs: now.subtract(const Duration(minutes: 15)).millisecondsSinceEpoch,
        currentLat: mandianLat,
        currentLng: mandianLon,
        now: now,
      );
      expect(invalidMoved, isFalse);
    });

    test('decodeAndValidateCachedMosques migrates legacy http images to local assets and strips out-of-range items', () {
      final rawJson = jsonEncode([
        MosqueItem(
          name: 'Masjid A',
          address: 'Mandian',
          distanceText: '120 m',
          lat: 34.1882,
          lng: 73.2414,
          imageUrl: 'https://images.unsplash.com/photo-old.jpg',
        ).toJson(),
        MosqueItem(
          name: 'Masjid Too Far',
          address: 'Supply',
          distanceText: '200 m',
          lat: 34.1400,
          lng: 73.2414,
          imageUrl: 'assets/images/mosque_faisal.jpg',
        ).toJson(),
      ]);

      final validated = NearbyMasjidService.decodeAndValidateCachedMosques(
        rawJson: rawJson,
        currentLat: mandianLat,
        currentLng: mandianLon,
      );

      expect(validated.length, 1);
      expect(validated.first.name, 'Masjid A');
      expect(validated.first.imageUrl, 'assets/images/mosque_faisal.jpg');
    });
  });

  group('Urdu transliteration and area tag extraction', () {
    test('transliterates Urdu mosque and Mandian area names accurately', () {
      expect(
        NearbyMasjidService.urduToEnglish('جامع مسجد نوری منڈیاں'),
        'Jamia Masjid Noori Mandian',
      );
      expect(
        NearbyMasjidService.urduToEnglish('الہی مسجد'),
        'Ilahi Masjid',
      );
    });

    test('buildOverpassQuery uses fast indexed tags without unindexed name regex', () {
      final query = NearbyMasjidService.buildOverpassQuery(mandianLat, mandianLon);
      expect(query, contains('["amenity"="place_of_worship"]'));
      expect(query, contains('["building"="mosque"]'));
      expect(query, contains('["amenity"="mosque"]'));
      expect(query.contains('["name"~'), isFalse);
    });

    test('parseOverpassElements skips non-Muslim place_of_worship even when religion tag is omitted', () {
      final parsed = NearbyMasjidService.parseOverpassElements(
        elements: [
          {
            'type': 'node',
            'lat': 34.1862,
            'lon': 73.2414,
            'tags': {
              'amenity': 'place_of_worship',
              'name': 'St. Luke Church',
            },
          },
          {
            'type': 'node',
            'lat': 34.1865,
            'lon': 73.2414,
            'tags': {
              'amenity': 'place_of_worship',
              'name': 'Jamia Masjid Mandian',
            },
          },
        ],
        userLat: mandianLat,
        userLon: mandianLon,
      );

      expect(parsed.length, 1);
      expect(parsed.first.name, 'Jamia Masjid Mandian');
    });

    test('extracts Mandian from Nominatim reverse address', () {
      final tag = NearbyMasjidService.extractLocalAreaTag({
        'suburb': 'Mandian',
        'city': 'Abbottabad',
        'country': 'Pakistan',
      });
      expect(tag, 'Mandian');
    });
  });
}
