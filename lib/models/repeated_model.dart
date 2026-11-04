
import 'package:day_picker/day_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
part 'repeated_model.g.dart';
@HiveType(typeId: 1)
class RepeatedModel  extends HiveObject{
  @HiveField(0)
  String name;

  @HiveField(1)
  DateTime Start;

  @HiveField(2)
  DateTime End;

  @HiveField(3)
  bool isSilentOrVibration;

  @HiveField(4)
  bool isTaskActivated;

  @HiveField(5)
  int? quickTime;

  @HiveField(6)
  List? dayInWeek ;

  RepeatedModel({required this.name, required this.Start,required this.End ,required this.isSilentOrVibration,required this.isTaskActivated,  this.quickTime,this.dayInWeek});

}