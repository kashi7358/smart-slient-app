

import 'package:hive/hive.dart';
import 'package:smart_silent/models/nemaz_model.dart';
import 'package:smart_silent/models/schedule_model.dart';

import '../models/repeated_model.dart';

class Boxes{
  static Box<ScheduleModel> getData() => Hive.box<ScheduleModel>('schedules');
  static Box<RepeatedModel> getDataforDaily() => Hive.box<RepeatedModel>('daily');
  static Box<NemazModel> getDataforNemaz() => Hive.box<NemazModel>('nemaz');
}