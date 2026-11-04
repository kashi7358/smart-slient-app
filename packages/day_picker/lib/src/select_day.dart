import 'package:flutter/material.dart';
import 'day_in_week.dart';

/// A widget that allows the user to select days of the week.
class SelectWeekDays extends StatefulWidget {
  final List<DayInWeek> days;
  final void Function(List<String>) onSelect;
  final Color? daysFillColor;
  final Color? selectedDayTextColor;
  final Color? unSelectedDayTextColor;
  final FontWeight? fontWeight;
  final bool border;
  final BoxDecoration? boxDecoration;
  final double fontSize;

  const SelectWeekDays({
    Key? key,
    required this.days,
    required this.onSelect,
    this.daysFillColor,
    this.selectedDayTextColor,
    this.unSelectedDayTextColor,
    this.fontWeight,
    this.border = true,
    this.boxDecoration,
    this.fontSize = 14.0,
  }) : super(key: key);

  @override
  State<SelectWeekDays> createState() => _SelectWeekDaysState();
}

class _SelectWeekDaysState extends State<SelectWeekDays> {
  late List<DayInWeek> _days;

  @override
  void initState() {
    super.initState();
    _days = List.from(widget.days);
  }

  void _onDaySelected(int index) {
    setState(() {
      _days[index].isSelected = !_days[index].isSelected;
    });
    final selectedKeys = _days
        .where((d) => d.isSelected)
        .map((d) => d.dayKey ?? d.dayName)
        .toList();
    widget.onSelect(selectedKeys);
  }

  @override
  Widget build(BuildContext context) {
    // Use Theme.of(context).colorScheme.primary instead of deprecated accentColor
    final Color fillColor =
        widget.daysFillColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      decoration: widget.boxDecoration ??
          BoxDecoration(
            border: widget.border
                ? Border.all(color: fillColor, width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(30),
          ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_days.length, (index) {
          final day = _days[index];
          final isSelected = day.isSelected;
          return GestureDetector(
            onTap: () => _onDaySelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? fillColor : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: Text(
                day.dayName,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: widget.fontWeight ?? FontWeight.w500,
                  color: isSelected
                      ? (widget.selectedDayTextColor ?? Colors.white)
                      : (widget.unSelectedDayTextColor ?? Colors.black87),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
