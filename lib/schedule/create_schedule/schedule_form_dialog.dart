import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/Schedule.dart';
import '../schedule_service.dart';
import '../../models/Group.dart';
import '../../dynamo/group_service.dart';
import '../../services/timezone_service.dart';
import '../../services/refresh_service.dart';
import '../../services/oauth_user_service.dart';
import '../../widgets/scrollable_time_picker.dart';
import '../../theme/theme_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

// DIUBAH: Nama kelas diubah agar lebih deskriptif
class ScheduleFormDialog extends StatefulWidget {
  final Schedule? scheduleToEdit;
  final Function onFormClosed; // DIUBAH: Nama callback diubah agar lebih jelas
  final DateTime selectedDate;
  final Group? initialGroup;

  const ScheduleFormDialog({
    super.key,
    this.scheduleToEdit,
    required this.onFormClosed,
    required this.selectedDate,
    this.initialGroup,
  });

  @override
  State<ScheduleFormDialog> createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends State<ScheduleFormDialog> {
  final _formKey =
      GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSaving = false;
  Group? _selectedGroup;
  bool _isEditing = false;
  Timer? _timeValidityTimer;
  Color _selectedColor = const Color(0xFF735BF2); // Default purple color

  final List<Color> _colorOptions = [
    const Color(0xFF735BF2), // Purple (default)
    const Color(0xFF4CAF50), // Green
    const Color(0xFF2196F3), // Blue
    const Color(0xFFFF9800), // Orange
    const Color(0xFFE91E63), // Pink
    const Color(0xFF9C27B0), // Purple variant
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFF607D8B), // Blue Grey
    const Color(0xFF795548), // Brown
    const Color(0xFFFFC107), // Amber
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.scheduleToEdit != null;
    _selectedDate = widget.selectedDate;

    if (_isEditing) {
      _titleController.text = widget.scheduleToEdit!.title;
      _descriptionController.text = widget.scheduleToEdit!.description ?? '';
      _locationController.text = widget.scheduleToEdit!.location ?? '';
      final startDateTime = widget.scheduleToEdit!.startTime.getDateTimeInUtc();
      final endDateTime = widget.scheduleToEdit!.endTime.getDateTimeInUtc();
      _selectedDate =
          DateTime(startDateTime.year, startDateTime.month, startDateTime.day);
      _startTime =
          TimeOfDay(hour: startDateTime.hour, minute: startDateTime.minute);
      _endTime = TimeOfDay(hour: endDateTime.hour, minute: endDateTime.minute);
      _selectedGroup = widget.scheduleToEdit!.group;

      // Initialize color from existing schedule
      if (widget.scheduleToEdit!.color != null && widget.scheduleToEdit!.color!.isNotEmpty) {
        try {
          _selectedColor = Color(int.parse(widget.scheduleToEdit!.color!));
        } catch (e) {
          _selectedColor = const Color(0xFF735BF2); // Default if parsing fails
        }
      } else {
        _selectedColor = const Color(0xFF735BF2); // Default if no color set
      }
    } else {
      _loadInitialData();
      final now = DateTime.now();
      final nextHour = (now.hour + (now.minute > 0 ? 1 : 0)) % 24;
      _startTime = TimeOfDay(hour: nextHour, minute: 0);
      _endTime = TimeOfDay(hour: (nextHour + 1) % 24, minute: 0);
    }

    _timeValidityTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _validateTimeSelections();
    });
  }

  @override
  void dispose() {
    _timeValidityTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final groups = await GroupService.getUserGroups();
      if (groups.isNotEmpty && mounted) {
        setState(() {
          _selectedGroup = widget.initialGroup ?? groups.first;
        });
      }
    } catch (e) {
      debugPrint('Failed to load initial data: $e');
    }
  }

  void _validateTimeSelections() {
  if (_selectedDate == null || _startTime == null) return;
  final selectedStartDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _startTime!.hour,
      _startTime!.minute);

  if (!TimezoneService.isLocalTimeInFuture(selectedStartDateTime)) {
    if (mounted) {
      setState(() {

        final now = DateTime.now();
        final nextHour = (now.hour + (now.minute > 0 ? 1 : 0)) % 24;
        _startTime = TimeOfDay(hour: nextHour, minute: 0);
        _endTime = TimeOfDay(hour: (nextHour + 1) % 24, minute: 0);
      });
    }
  }
}

  DateTime _timeOfDayToDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all time fields')));
      return;
    }

    if (_selectedGroup == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a group')));
      return;
    }

    final startDateTime = _timeOfDayToDateTime(_selectedDate!, _startTime!);
    final endDateTime = _timeOfDayToDateTime(_selectedDate!, _endTime!);

    if (startDateTime.isAfter(endDateTime) ||
        startDateTime.isAtSameMomentAs(endDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time')));
      return;
    }

    final now = DateTime.now();
    if (startDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Start time must be in the future')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        final updatedSchedule = widget.scheduleToEdit!.copyWith(
          title: _titleController.text,
          description: _descriptionController.text,
          location: _locationController.text,
          startTime: TimezoneService.localToUtc(startDateTime),
          endTime: TimezoneService.localToUtc(endDateTime),
          color: _selectedColor.toARGB32().toString(),
          group: _selectedGroup,
        );
        await ScheduleService.updateSchedule(updatedSchedule);
      } else {
        final currentUser = await OAuthUserService.createUserObject();
        final newSchedule = Schedule(
          id: '',
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          startTime: TimezoneService.localToUtc(startDateTime),
          endTime: TimezoneService.localToUtc(endDateTime),
          color: _selectedColor.toARGB32().toString(),
          user: currentUser,
          group: _selectedGroup!,
        );
        await ScheduleService.createSchedule(newSchedule);
        RefreshService().notifyScheduleChange();
      }

      if (mounted) {
        final navigator = Navigator.of(context);
        navigator.pop();
        widget.onFormClosed();
      }
    } catch (e) {
      debugPrint('❌ ScheduleForm: Error creating/updating schedule: $e');
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text('Error: $errorMessage'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final primaryColor = isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF735BF2);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final hintColor = isDarkMode ? Colors.grey.shade400 : const Color(0xFF999999);
    final iconColor = isDarkMode ? Colors.grey.shade400 : const Color(0xFF999999);
    final backgroundColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDarkMode ? Colors.grey.shade600 : const Color(0xFFEDF1F7);

    final inputDecorationTheme = InputDecoration(
      hintStyle: TextStyle(color: hintColor, fontWeight: FontWeight.normal),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      fillColor: isDarkMode ? const Color(0xFF3A3A3A) : Colors.white,
      filled: true,
    );

    return AlertDialog(
      backgroundColor: backgroundColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      title: Center(
        child: Text(
          _isEditing ? 'Edit Event' : 'Add New Event',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 24.0),
      actions: null,
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // DIUBAH: Menerapkan tema ke semua field
                TextFormField(
                  controller: _titleController,
                  style: TextStyle(color: textColor),
                  decoration: inputDecorationTheme.copyWith(
                    hintText: 'Event title ...',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: inputDecorationTheme.copyWith(
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(
                            12.0),
                        child: SvgPicture.asset(
                          'assets/icons/calendar_navbar-icon.svg',
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ),
                    child: Text(
                      _selectedDate != null
                          ? DateFormat('dd / MM / yyyy').format(_selectedDate!)
                          : 'Select date',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
  children: [
    Expanded(
      child: InkWell(
        onTap: () => _selectTime(true),
        child: InputDecorator(
          decoration: inputDecorationTheme.copyWith(
            suffixIcon: Padding(
              padding: const EdgeInsets.all(12.0),
              child: SvgPicture.asset(
                'assets/icons/clock-icon.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
          ),
          child: Text(
            _startTime!.format(context),
            style: TextStyle(fontSize: 16, color: textColor),
          ),
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Icon(Icons.arrow_forward, color: hintColor),
    ),
    Expanded(
      child: InkWell(
        onTap: () => _selectTime(false),
        child: InputDecorator(
          decoration: inputDecorationTheme.copyWith(
            suffixIcon: Padding(
              padding: const EdgeInsets.all(12.0),
              child: SvgPicture.asset(
                'assets/icons/clock-icon.svg', // Pastikan path ini benar
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
          ),
          child: Text(
            _endTime!.format(context),
            style: TextStyle(fontSize: 16, color: textColor),
          ),
        ),
      ),
    ),
  ],
),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  style: TextStyle(color: textColor),
                  decoration: inputDecorationTheme.copyWith(
                    hintText: 'Location (Link Gmaps/Zoom)',
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(
                          12.0),
                      child: SvgPicture.asset(
                        'assets/icons/pin_location-icon.svg',
                        width: 24,
                        height: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  style: TextStyle(color: textColor),
                  decoration: inputDecorationTheme.copyWith(
                    hintText: 'Description...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Event Color',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: inputDecorationTheme.copyWith(
                        contentPadding: const EdgeInsets.all(12.0),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.start,
                        spacing: 12,
                        runSpacing: 12,
                        children: _colorOptions.map((color) {
                          final isSelected = color == _selectedColor;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: isDarkMode ? Colors.white : Colors.black,
                                        width: 3
                                      )
                                    : Border.all(
                                        color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
                                        width: 1
                                      ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 106,
                      height: 41,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA3C54),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 106,
                      height: 41,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSchedule,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('Save',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? now;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2101),
    );
    if (selectedDate != null) {
      setState(() => _selectedDate = selectedDate);
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    final now = DateTime.now();
    final isToday = _selectedDate?.year == now.year &&
        _selectedDate?.month == now.month &&
        _selectedDate?.day == now.day;
    final currentTime = DateTime.now();
    final nextHour = (currentTime.hour + (currentTime.minute > 0 ? 1 : 0)) % 24;
    final initialTime = isStartTime
        ? _startTime ?? TimeOfDay(hour: nextHour, minute: 0)
        : _endTime ?? TimeOfDay(hour: (nextHour + 1) % 24, minute: 0);

    final selectedTime = await showScrollableTimePicker(
      context: context,
      initialTime: initialTime,
      use24HourFormat: false,
    );
    if (selectedTime != null) {
      // Validasi waktu
      if (isToday) {
        final selectedDateTime = DateTime(now.year, now.month, now.day,
            selectedTime.hour, selectedTime.minute);
        if (!TimezoneService.isLocalTimeInFuture(selectedDateTime)) {
          if (mounted) {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            scaffoldMessenger.showSnackBar(const SnackBar(
                content: Text('Selected time must be in the future')));
          }
          return;
        }
      }
      if (!isStartTime && _startTime != null) {
        final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
        final endMinutes = selectedTime.hour * 60 + selectedTime.minute;
        if (endMinutes <= startMinutes) {
          if (mounted) {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            scaffoldMessenger.showSnackBar(const SnackBar(
                content: Text('End time must be after start time')));
          }
          return;
        }
      }
      setState(() {
        if (isStartTime) {
          _startTime = selectedTime;
          final newEndHour = (selectedTime.hour + 1) % 24;
          _endTime = TimeOfDay(hour: newEndHour, minute: selectedTime.minute);
        } else {
          _endTime = selectedTime;
        }
      });
    }
  }
}