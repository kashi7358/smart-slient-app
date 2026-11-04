import 'package:hive/hive.dart';
part 'nemaz_model.g.dart';

@HiveType(typeId: 2)
class NemazModel extends HiveObject {
  @HiveField(0)
  DateTime FajarStart;
  @HiveField(1)
  DateTime FajarEnd;

  @HiveField(2)
  DateTime ZoharStart;
  @HiveField(3)
  DateTime ZoharEnd;

  @HiveField(4)
  DateTime AsarStart;
  @HiveField(5)
  DateTime AsarEnd;

  @HiveField(6)
  DateTime MagribStart;
  @HiveField(7)
  DateTime MagribEnd;
  @HiveField(8)
  DateTime IshaStart;
  @HiveField(9)
  DateTime IshaEnd;

  @HiveField(10)
  bool isSilentOrVibration;

  @HiveField(11)
  bool isFajarTaskActivated;
  @HiveField(12)
  bool isZoharTaskActivated;
  @HiveField(13)
  bool isAsarTaskActivated;
  @HiveField(14)
  bool isMagribTaskActivated;
  @HiveField(15)
  bool isIshaTaskActivated;

  @HiveField(16)
  String forWhichMasjid;

  NemazModel(
      {required this.FajarStart,
      required this.FajarEnd,
      required this.ZoharStart,
      required this.ZoharEnd,
      required this.AsarStart,
      required this.AsarEnd,
      required this.MagribStart,
      required this.MagribEnd,
      required this.IshaStart,
      required this.IshaEnd,
      required this.isSilentOrVibration,
      required this.isFajarTaskActivated,
      required this.isZoharTaskActivated,
      required this.isAsarTaskActivated,
      required this.isMagribTaskActivated,
      required this.isIshaTaskActivated,
      required this.forWhichMasjid});
}
