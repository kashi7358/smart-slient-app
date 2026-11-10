class HijriDate {
  final int year;
  final int month;
  final int day;
  final String monthName;
  final String monthNameAr;

  static const List<String> monthNames = [
    'Muharram',
    'Safar',
    'Rabi\' al-Awwal',
    'Rabi\' al-Thani',
    'Jumada al-Awwal',
    'Jumada al-Thani',
    'Rajab',
    'Sha\'ban',
    'Ramadan',
    'Shawwal',
    'Dhu al-Qadah',
    'Dhu al-Hijjah',
  ];

  static const List<String> monthNamesAr = [
    'مُحَرَّم',
    'صَفَر',
    'رَبِيع الأَوَّل',
    'رَبِيع الآخِر',
    'جُمَادَى الأُولَى',
    'جُمَادَى الآخِرَة',
    'رَجَب',
    'شَعْبَان',
    'رَمَضَان',
    'شَوَّال',
    'ذُو القَعْدَة',
    'ذُو الحِجَّة',
  ];

  const HijriDate({
    required this.year,
    required this.month,
    required this.day,
    required this.monthName,
    required this.monthNameAr,
  });

  /// Standard astronomical Julian-day conversion to Islamic (Hijri) calendar
  static HijriDate fromGregorian(DateTime date, {int dayAdjustment = 0}) {
    DateTime adjusted = date.add(Duration(days: dayAdjustment));
    int d = adjusted.day;
    int m = adjusted.month;
    int y = adjusted.year;

    if (m < 3) {
      y -= 1;
      m += 12;
    }

    final double a = (y / 100.0).floorToDouble();
    final double b = 2.0 - a + (a / 4.0).floorToDouble();
    final double jd = (365.25 * (y + 4716)).floorToDouble() +
        (30.6001 * (m + 1)).floorToDouble() +
        d +
        b -
        1524.0;

    // Julian day to Hijri conversion
    final double l = jd - 1948440.0 + 10632.0;
    final double n = ((l - 1.0) / 10631.0).floorToDouble();
    final double lPrime = l - 10631.0 * n + 354.0;
    final double j = ((10985.0 - lPrime) / 5316.0).floorToDouble() *
            ((50.0 * lPrime) / 17719.0).floorToDouble() +
        (lPrime / 5670.0).floorToDouble() * ((43.0 * lPrime) / 15238.0).floorToDouble();
    final double lDoublePrime = lPrime -
        ((30.0 - j) / 15.0).floorToDouble() * ((17719.0 * j) / 50.0).floorToDouble() -
        (j / 16.0).floorToDouble() * ((15238.0 * j) / 43.0).floorToDouble() +
        29.0;

    int hMonth = ((24.0 * lDoublePrime) / 709.0).floor();
    int hDay = (lDoublePrime - ((709.0 * hMonth) / 24.0).floor()).round();
    int hYear = (30.0 * n + j - 30.0).round();

    if (hMonth < 1) hMonth = 1;
    if (hMonth > 12) hMonth = 12;
    if (hDay < 1) hDay = 1;
    if (hDay > 30) hDay = 30;

    return HijriDate(
      year: hYear,
      month: hMonth,
      day: hDay,
      monthName: monthNames[hMonth - 1],
      monthNameAr: monthNamesAr[hMonth - 1],
    );
  }

  static String formatCurrentDate({int dayAdjustment = 0}) {
    final hijri = fromGregorian(DateTime.now(), dayAdjustment: dayAdjustment);
    return '${hijri.day} ${hijri.monthName}, ${hijri.year} AH';
  }

  static String formatFullCurrentDate({int dayAdjustment = 0}) {
    final hijri = fromGregorian(DateTime.now(), dayAdjustment: dayAdjustment);
    return '${hijri.day} ${hijri.monthName} ${hijri.year} AH';
  }

  @override
  String toString() => '$day $monthName, $year AH';
}
