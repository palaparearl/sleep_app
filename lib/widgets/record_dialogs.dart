import 'package:flutter/material.dart';

import '../models/models.dart';

Future<void> showAddSleepDialog({
  required BuildContext context,
  required DateTime selectedDay,
  required void Function(DateTime, TimeOfDay, DateTime, TimeOfDay) onSave,
}) async {
  DateTime? sleepDate = selectedDay;
  TimeOfDay? sleepTime;
  DateTime? wakeDate = selectedDay;
  TimeOfDay? wakeTime;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Sleep Record'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Sleep Date'),
                    subtitle: Text(
                      sleepDate != null
                          ? '${sleepDate!.year}-${sleepDate!.month.toString().padLeft(2, '0')}-${sleepDate!.day.toString().padLeft(2, '0')}'
                          : 'Select date',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: sleepDate ?? DateTime.now(),
                        firstDate: DateTime(2020, 1, 1),
                        lastDate: DateTime(2030, 12, 31),
                      );
                      if (date != null) setState(() => sleepDate = date);
                    },
                  ),
                  ListTile(
                    title: const Text('Sleep Time'),
                    subtitle: Text(sleepTime?.format(context) ?? 'Select time'),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime:
                            sleepTime ?? const TimeOfDay(hour: 22, minute: 0),
                      );
                      if (time != null) setState(() => sleepTime = time);
                    },
                  ),
                  ListTile(
                    title: const Text('Wake Date'),
                    subtitle: Text(
                      wakeDate != null
                          ? '${wakeDate!.year}-${wakeDate!.month.toString().padLeft(2, '0')}-${wakeDate!.day.toString().padLeft(2, '0')}'
                          : 'Select date',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: wakeDate ?? DateTime.now(),
                        firstDate: DateTime(2020, 1, 1),
                        lastDate: DateTime(2030, 12, 31),
                      );
                      if (date != null) setState(() => wakeDate = date);
                    },
                  ),
                  ListTile(
                    title: const Text('Wake Time'),
                    subtitle: Text(wakeTime?.format(context) ?? 'Select time'),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime:
                            wakeTime ?? const TimeOfDay(hour: 7, minute: 0),
                      );
                      if (time != null) setState(() => wakeTime = time);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (sleepDate != null &&
                      sleepTime != null &&
                      wakeDate != null &&
                      wakeTime != null) {
                    final sleepDateTime = DateTime(
                      sleepDate!.year,
                      sleepDate!.month,
                      sleepDate!.day,
                      sleepTime!.hour,
                      sleepTime!.minute,
                    );
                    final wakeDateTime = DateTime(
                      wakeDate!.year,
                      wakeDate!.month,
                      wakeDate!.day,
                      wakeTime!.hour,
                      wakeTime!.minute,
                    );
                    if (wakeDateTime.isBefore(sleepDateTime)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Wake time must be after sleep time'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    onSave(sleepDate!, sleepTime!, wakeDate!, wakeTime!);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showEditSleepDialog({
  required BuildContext context,
  required SleepRecord record,
  required void Function(SleepRecord oldRecord, SleepRecord newRecord) onSave,
}) async {
  DateTime? sleepDate = record.sleepDate;
  TimeOfDay? sleepTime = record.sleepTime;
  DateTime? wakeDate = record.wakeDate;
  TimeOfDay? wakeTime = record.wakeTime;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Sleep Record'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Sleep Date'),
                    subtitle: Text(
                      '${sleepDate!.year}-${sleepDate!.month.toString().padLeft(2, '0')}-${sleepDate!.day.toString().padLeft(2, '0')}',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: sleepDate!,
                        firstDate: DateTime(2020, 1, 1),
                        lastDate: DateTime(2030, 12, 31),
                      );
                      if (date != null) setState(() => sleepDate = date);
                    },
                  ),
                  ListTile(
                    title: const Text('Sleep Time'),
                    subtitle: Text(sleepTime!.format(context)),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: sleepTime!,
                      );
                      if (time != null) setState(() => sleepTime = time);
                    },
                  ),
                  ListTile(
                    title: const Text('Wake Date'),
                    subtitle: Text(
                      '${wakeDate!.year}-${wakeDate!.month.toString().padLeft(2, '0')}-${wakeDate!.day.toString().padLeft(2, '0')}',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: wakeDate!,
                        firstDate: DateTime(2020, 1, 1),
                        lastDate: DateTime(2030, 12, 31),
                      );
                      if (date != null) setState(() => wakeDate = date);
                    },
                  ),
                  ListTile(
                    title: const Text('Wake Time'),
                    subtitle: Text(wakeTime!.format(context)),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: wakeTime!,
                      );
                      if (time != null) setState(() => wakeTime = time);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final sleepDateTime = DateTime(
                    sleepDate!.year,
                    sleepDate!.month,
                    sleepDate!.day,
                    sleepTime!.hour,
                    sleepTime!.minute,
                  );
                  final wakeDateTime = DateTime(
                    wakeDate!.year,
                    wakeDate!.month,
                    wakeDate!.day,
                    wakeTime!.hour,
                    wakeTime!.minute,
                  );
                  if (wakeDateTime.isBefore(sleepDateTime)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Wake time must be after sleep time'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  final newRecord = SleepRecord(
                    sleepDate: sleepDate!,
                    sleepTime: sleepTime!,
                    wakeDate: wakeDate!,
                    wakeTime: wakeTime!,
                  );
                  onSave(record, newRecord);
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showAddActivityDialog({
  required BuildContext context,
  required String title,
  required DateTime selectedDay,
  required void Function(DateTime, TimeOfDay, DateTime, TimeOfDay) onSave,
}) async {
  DateTime? startDate = selectedDay;
  TimeOfDay? startTime;
  DateTime? endDate = selectedDay;
  TimeOfDay? endTime;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add $title'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Start Date'),
                    subtitle: Text(
                      startDate != null
                          ? '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}'
                          : 'Select date',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? selectedDay,
                        firstDate: DateTime.utc(2020, 1, 1),
                        lastDate: DateTime.utc(2030, 12, 31),
                      );
                      if (date != null) setState(() => startDate = date);
                    },
                  ),
                  ListTile(
                    title: const Text('Start Time'),
                    subtitle: Text(startTime?.format(context) ?? 'Select time'),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime:
                            startTime ?? const TimeOfDay(hour: 8, minute: 0),
                      );
                      if (time != null) setState(() => startTime = time);
                    },
                  ),
                  ListTile(
                    title: const Text('End Date'),
                    subtitle: Text(
                      endDate != null
                          ? '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}'
                          : 'Select date',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? selectedDay,
                        firstDate: DateTime.utc(2020, 1, 1),
                        lastDate: DateTime.utc(2030, 12, 31),
                      );
                      if (date != null) setState(() => endDate = date);
                    },
                  ),
                  ListTile(
                    title: const Text('End Time'),
                    subtitle: Text(endTime?.format(context) ?? 'Select time'),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime:
                            endTime ?? const TimeOfDay(hour: 10, minute: 0),
                      );
                      if (time != null) setState(() => endTime = time);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (startDate != null &&
                      startTime != null &&
                      endDate != null &&
                      endTime != null) {
                    onSave(startDate!, startTime!, endDate!, endTime!);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showEditActivityDialog({
  required BuildContext context,
  required String title,
  required DateTime startDateInit,
  required TimeOfDay startTimeInit,
  required DateTime endDateInit,
  required TimeOfDay endTimeInit,
  required void Function(DateTime, TimeOfDay, DateTime, TimeOfDay) onSave,
}) async {
  DateTime? startDate = startDateInit;
  TimeOfDay? startTime = startTimeInit;
  DateTime? endDate = endDateInit;
  TimeOfDay? endTime = endTimeInit;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Edit $title'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Start Date'),
                    subtitle: Text(
                      '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate!,
                        firstDate: DateTime.utc(2020, 1, 1),
                        lastDate: DateTime.utc(2030, 12, 31),
                      );
                      if (date != null) setState(() => startDate = date);
                    },
                  ),
                  ListTile(
                    title: const Text('Start Time'),
                    subtitle: Text(startTime!.format(context)),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: startTime!,
                      );
                      if (time != null) setState(() => startTime = time);
                    },
                  ),
                  ListTile(
                    title: const Text('End Date'),
                    subtitle: Text(
                      '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: endDate!,
                        firstDate: DateTime.utc(2020, 1, 1),
                        lastDate: DateTime.utc(2030, 12, 31),
                      );
                      if (date != null) setState(() => endDate = date);
                    },
                  ),
                  ListTile(
                    title: const Text('End Time'),
                    subtitle: Text(endTime!.format(context)),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: endTime!,
                      );
                      if (time != null) setState(() => endTime = time);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  onSave(startDate!, startTime!, endDate!, endTime!);
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}
