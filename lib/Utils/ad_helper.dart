import 'package:flutter/foundation.dart';

class AdHelper {
  /// Production AdMob Banner Ad Unit ID
  static const String _prodBannerAdUnitId =
      'ca-app-pub-9923979057032791/3153557586';

  /// Official Google AdMob Test Banner Ad Unit ID for Android
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  /// Uses Google's official Test Banner ID in debug builds so ads render
  /// reliably during development without risking invalid-traffic penalties,
  /// and automatically uses the production ID in release/profile builds.
  static String get bannerAdUnitId =>
      kDebugMode ? _testBannerAdUnitId : _prodBannerAdUnitId;
}
