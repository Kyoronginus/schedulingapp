import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// A scrollable time picker widget with separate wheels for hours and minutes
class ScrollableTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final Function(TimeOfDay) onTimeChanged;
  final bool use24HourFormat;

  const ScrollableTimePicker({
    super.key,
    required this.initialTime,
    required this.onTimeChanged,
    this.use24HourFormat = false,
  });

  @override
  State<ScrollableTimePicker> createState() => _ScrollableTimePickerState();
}

class _ScrollableTimePickerState extends State<ScrollableTimePicker> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _periodController;
  
  late int _selectedHour;
  late int _selectedMinute;
  late int _selectedPeriod; // 0 for AM, 1 for PM

  @override
  void initState() {
    super.initState();
    
    if (widget.use24HourFormat) {
      _selectedHour = widget.initialTime.hour;
    } else {
      _selectedHour = widget.initialTime.hourOfPeriod == 0 ? 12 : widget.initialTime.hourOfPeriod;
      _selectedPeriod = widget.initialTime.period == DayPeriod.am ? 0 : 1;
    }
    
    _selectedMinute = widget.initialTime.minute;
    
    _hourController = FixedExtentScrollController(initialItem: widget.use24HourFormat ? _selectedHour : _selectedHour - 1);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinute);
    _periodController = FixedExtentScrollController(initialItem: _selectedPeriod);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  void _updateTime() {
    int hour;
    if (widget.use24HourFormat) {
      hour = _selectedHour;
    } else {
      if (_selectedHour == 12) {
        hour = _selectedPeriod == 0 ? 0 : 12; // 12 AM = 0, 12 PM = 12
      } else {
        hour = _selectedPeriod == 0 ? _selectedHour : _selectedHour + 12;
      }
    }
    
    final newTime = TimeOfDay(hour: hour, minute: _selectedMinute);
    widget.onTimeChanged(newTime);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Hour picker
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Hour',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _hourController,
                    itemExtent: 40,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedHour = widget.use24HourFormat ? index : index + 1;
                      });
                      _updateTime();
                    },
                    children: List.generate(
                      widget.use24HourFormat ? 24 : 12,
                      (index) {
                        final hour = widget.use24HourFormat ? index : index + 1;
                        return Center(
                          child: Text(
                            hour.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Separator
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              ':',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Minute picker
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Minute',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _minuteController,
                    itemExtent: 40,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedMinute = index;
                      });
                      _updateTime();
                    },
                    children: List.generate(
                      60,
                      (index) => Center(
                        child: Text(
                          index.toString().padLeft(2, '0'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // AM/PM picker (only for 12-hour format)
          if (!widget.use24HourFormat) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'Period',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _periodController,
                      itemExtent: 40,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _selectedPeriod = index;
                        });
                        _updateTime();
                      },
                      children: const [
                        Center(
                          child: Text(
                            'AM',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            'PM',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A dialog that shows the scrollable time picker
class ScrollableTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final bool use24HourFormat;

  const ScrollableTimePickerDialog({
    super.key,
    required this.initialTime,
    this.use24HourFormat = false,
  });

  @override
  State<ScrollableTimePickerDialog> createState() => _ScrollableTimePickerDialogState();
}

class _ScrollableTimePickerDialogState extends State<ScrollableTimePickerDialog> {
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Time'),
      content: SizedBox(
        width: double.maxFinite,
        child: ScrollableTimePicker(
          initialTime: widget.initialTime,
          use24HourFormat: widget.use24HourFormat,
          onTimeChanged: (time) {
            _selectedTime = time;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selectedTime),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Helper function to show the scrollable time picker dialog
Future<TimeOfDay?> showScrollableTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  bool use24HourFormat = false,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    builder: (context) => ScrollableTimePickerDialog(
      initialTime: initialTime,
      use24HourFormat: use24HourFormat,
    ),
  );
}
