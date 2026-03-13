import 'package:flutter/material.dart';

class FilterChipsWidget extends StatelessWidget {
  final bool showSleep;
  final bool showCoffee;
  final bool showMedicine;
  final bool showAlcohol;
  final bool showNotes;
  final ValueChanged<bool> onSleepChanged;
  final ValueChanged<bool> onCoffeeChanged;
  final ValueChanged<bool> onMedicineChanged;
  final ValueChanged<bool> onAlcoholChanged;
  final ValueChanged<bool> onNotesChanged;

  const FilterChipsWidget({
    super.key,
    required this.showSleep,
    required this.showCoffee,
    required this.showMedicine,
    required this.showAlcohol,
    required this.showNotes,
    required this.onSleepChanged,
    required this.onCoffeeChanged,
    required this.onMedicineChanged,
    required this.onAlcoholChanged,
    required this.onNotesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Wrap(
        spacing: 8,
        children: [
          FilterChip(
            label: Text(
              'Sleep',
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
            avatar: Icon(
              Icons.bedtime,
              size: 18,
              color: isDark ? Colors.indigo[200] : null,
            ),
            selected: showSleep,
            selectedColor: isDark ? Colors.indigo[700] : Colors.indigo[100],
            checkmarkColor: isDark ? Colors.white : null,
            onSelected: onSleepChanged,
          ),
          FilterChip(
            label: Text(
              'Coffee/Cola/Tea',
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
            avatar: Icon(
              Icons.coffee,
              size: 18,
              color: isDark ? Colors.brown[200] : null,
            ),
            selected: showCoffee,
            selectedColor: isDark ? Colors.brown[700] : Colors.brown[100],
            checkmarkColor: isDark ? Colors.white : null,
            onSelected: onCoffeeChanged,
          ),
          FilterChip(
            label: Text(
              'Medicine',
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
            avatar: Icon(
              Icons.medication,
              size: 18,
              color: isDark ? Colors.green[200] : null,
            ),
            selected: showMedicine,
            selectedColor: isDark ? Colors.green[700] : Colors.green[100],
            checkmarkColor: isDark ? Colors.white : null,
            onSelected: onMedicineChanged,
          ),
          FilterChip(
            label: Text(
              'Alcohol',
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
            avatar: Icon(
              Icons.local_bar,
              size: 18,
              color: isDark ? Colors.red[200] : null,
            ),
            selected: showAlcohol,
            selectedColor: isDark ? Colors.red[700] : Colors.red[100],
            checkmarkColor: isDark ? Colors.white : null,
            onSelected: onAlcoholChanged,
          ),
          FilterChip(
            label: Text(
              'Notes',
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
            avatar: Icon(
              Icons.note,
              size: 18,
              color: isDark ? Colors.amber[200] : null,
            ),
            selected: showNotes,
            selectedColor: isDark ? Colors.amber[700] : Colors.amber[100],
            checkmarkColor: isDark ? Colors.white : null,
            onSelected: onNotesChanged,
          ),
        ],
      ),
    );
  }
}
