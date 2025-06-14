import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/Schedule.dart';
import '../../models/User.dart';
import '../schedule_service.dart';
import '../../models/Group.dart';
import '../../auth/auth_service.dart';
import '../../dynamo/group_service.dart';
import '../../theme/theme_provider.dart';
import '../../services/timezone_service.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class ScheduleFormOverlay extends StatefulWidget {
  final Schedule? scheduleToEdit;
  final Function onClose;
  final DateTime selectedDate;
  final Group? initialGroup;

  const ScheduleFormOverlay({
    super.key,
    this.scheduleToEdit,
    required this.onClose,
    required this.selectedDate,
    this.initialGroup,
  });

  @override
  State<ScheduleFormOverlay> createState() => _ScheduleFormOverlayState();
}

class _ScheduleFormOverlayState extends State<ScheduleFormOverlay> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSaving = false;
  Group? _selectedGroup;
  bool _isEditing = false;

  // Timer to periodically check if selected time is still valid
  Timer? _timeValidityTimer;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.scheduleToEdit != null;
    _selectedDate = widget.selectedDate;

    // If editing, populate the form with existing data
    if (_isEditing) {
      _titleController.text = widget.scheduleToEdit!.title;
      _descriptionController.text = widget.scheduleToEdit!.description ?? '';
      _locationController.text = widget.scheduleToEdit!.location ?? '';

      final startDateTime = widget.scheduleToEdit!.startTime.getDateTimeInUtc();
      final endDateTime = widget.scheduleToEdit!.endTime.getDateTimeInUtc();

      _selectedDate = DateTime(
        startDateTime.year,
        startDateTime.month,
        startDateTime.day,
      );

      _startTime = TimeOfDay(
        hour: startDateTime.hour,
        minute: startDateTime.minute,
      );

      _endTime = TimeOfDay(
        hour: endDateTime.hour,
        minute: endDateTime.minute,
      );

      _selectedGroup = widget.scheduleToEdit!.group;
    } else {
      _loadInitialData();

      // Set default times to the next hour
      final now = DateTime.now();
      // Round to the next hour
      final nextHour = (now.hour + (now.minute > 0 ? 1 : 0)) % 24;
      _startTime = TimeOfDay(hour: nextHour, minute: 0);
      // End time is 1 hour after start time
      _endTime = TimeOfDay(hour: (nextHour + 1) % 24, minute: 0);
    }

    // Start a timer to check time validity every minute
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

  // Load initial data (default group)
  Future<void> _loadInitialData() async {
    try {
      final groups = await GroupService.getUserGroups();
      if (groups.isNotEmpty) {
        setState(() {
          // Use the initialGroup if provided, otherwise use the first group
          _selectedGroup = widget.initialGroup ?? groups.first;
        });
      }
    } catch (e) {
      debugPrint('Failed to load initial data: $e');
    }
  }

  // Validate time selections
  void _validateTimeSelections() {
    if (_selectedDate == null || _startTime == null) return;

    final selectedStartDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    // If selected time is in the past (in local timezone), reset it
    if (!TimezoneService.isLocalTimeInFuture(selectedStartDateTime)) {
      setState(() {
        _startTime = null;
        _endTime = null;
      });
    }
  }

  // Convert TimeOfDay to DateTime
  DateTime _timeOfDayToDateTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  // Schedule creation/update process
  Future<void> _saveSchedule() async {
    if (_titleController.text.isEmpty ||
        _selectedDate == null ||
        _startTime == null ||
        _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    if (_selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a group')),
      );
      return;
    }

    final startDateTime = _timeOfDayToDateTime(_selectedDate!, _startTime!);
    final endDateTime = _timeOfDayToDateTime(_selectedDate!, _endTime!);

    // Validate that start time is before end time
    if (startDateTime.isAfter(endDateTime) || startDateTime.isAtSameMomentAs(endDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    // Validate that start time is not in the past
    final now = DateTime.now();
    if (startDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start time must be in the future')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        // Update existing schedule
        final updatedSchedule = widget.scheduleToEdit!.copyWith(
          title: _titleController.text,
          description: _descriptionController.text,
          location: _locationController.text,
          startTime: TimezoneService.localToUtc(startDateTime),
          endTime: TimezoneService.localToUtc(endDateTime),
          group: _selectedGroup,
        );

        await ScheduleService.updateSchedule(updatedSchedule);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schedule updated successfully!')),
          );
        }
      } else {
        // Create new schedule
        debugPrint('🔍 ScheduleForm: Starting schedule creation...');

        User currentUser;
        try {
          currentUser = await ensureUserExists();
          debugPrint('✅ ScheduleForm: Got current user: ${currentUser.id}');
        } catch (e) {
          debugPrint('❌ ScheduleForm: Failed to get current user: $e');
          throw Exception('Failed to get user information. Please try logging in again.');
        }

        if (_selectedGroup == null) {
          throw Exception('No group selected. Please select a group.');
        }

        debugPrint('🔍 ScheduleForm: Creating schedule with user: ${currentUser.id}, group: ${_selectedGroup!.id}');

        final newSchedule = Schedule(
          id: '', // Amplify will auto-generate this
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
          startTime: TimezoneService.localToUtc(startDateTime),
          endTime: TimezoneService.localToUtc(endDateTime),
          user: currentUser, // Pass the User object directly
          group: _selectedGroup!, // Explicitly set group
        );

        debugPrint('🔍 ScheduleForm: Schedule object created, calling ScheduleService...');
        await ScheduleService.createSchedule(newSchedule);
        debugPrint('✅ ScheduleForm: Schedule created successfully!');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Schedule created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      widget.onClose();
    } catch (e) {
      debugPrint('❌ ScheduleForm: Error creating/updating schedule: $e');
      if (mounted) {
        String errorMessage = e.toString();
        // Clean up the error message for better user experience
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Group selection dialog
  Future<void> _selectGroup() async {
    if (!mounted) return;

    final groups = await GroupService.getUserGroups();
    if (!mounted) return;

    final selectedGroup = await showDialog<Group>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select a Group'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: groups.length,
            itemBuilder: (ctx, index) => ListTile(
              title: Text(groups[index].name),
              onTap: () => Navigator.pop(ctx, groups[index]),
            ),
          ),
        ),
      ),
    );

    if (selectedGroup != null) {
      setState(() => _selectedGroup = selectedGroup);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final primaryColor = isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF4A80F0);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(51), // 0.2 opacity
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: const Center(
                child: Text(
                  'Add New Event',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Form content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title field
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Event title ...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date field
                  InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDate != null
                                ? DateFormat('dd / MM / yyyy').format(_selectedDate!)
                                : 'Select date',
                            style: TextStyle(
                              color: _selectedDate != null
                                  ? isDarkMode ? Colors.white : Colors.black
                                  : Colors.grey,
                            ),
                          ),
                          Icon(Icons.calendar_today, color: primaryColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time fields
                  Row(
                    children: [
                      // Start time
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _startTime != null
                                      ? _startTime!.format(context)
                                      : '${(DateTime.now().hour + (DateTime.now().minute > 0 ? 1 : 0)) % 24}:00',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                                Icon(Icons.access_time, color: primaryColor),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Arrow
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, color: primaryColor),
                      ),

                      // End time
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _endTime != null
                                      ? _endTime!.format(context)
                                      : '${((DateTime.now().hour + (DateTime.now().minute > 0 ? 1 : 0)) + 1) % 24}:00',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                                Icon(Icons.access_time, color: primaryColor),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location field
                  TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      hintText: 'Location (Link Gmaps/Zoom)',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      suffixIcon: Icon(Icons.location_on, color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description field
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      hintText: 'Description...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Group selector
                  InkWell(
                    onTap: _selectGroup,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedGroup?.name ?? 'Select group',
                            style: TextStyle(
                              color: _selectedGroup != null
                                  ? isDarkMode ? Colors.white : Colors.black
                                  : Colors.grey,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 24),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Cancel button - positioned at bottom left
                      SizedBox(
                        width: 100,
                        child: ElevatedButton(
                          onPressed: () => widget.onClose(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),

                      // Save button - positioned at bottom right
                      SizedBox(
                        width: 100,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveSchedule,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Date selection
  Future<void> _selectDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? now;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day), // Allow today
      lastDate: DateTime(2101),
    );

    if (selectedDate != null) {
      setState(() => _selectedDate = selectedDate);
    }
  }

  // Time selection
  Future<void> _selectTime(bool isStartTime) async {
    final now = DateTime.now();
    final isToday = _selectedDate?.year == now.year &&
                   _selectedDate?.month == now.month &&
                   _selectedDate?.day == now.day;

    // Get the next hour for default times
    final currentTime = DateTime.now();
    final nextHour = (currentTime.hour + (currentTime.minute > 0 ? 1 : 0)) % 24;

    final initialTime = isStartTime
        ? _startTime ?? TimeOfDay(hour: nextHour, minute: 0)
        : _endTime ?? TimeOfDay(hour: (nextHour + 1) % 24, minute: 0);

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        // Only apply time validation for today
        if (!isToday) return child!;

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: false,
          ),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      // For today, validate that time is in the future (using local timezone)
      if (isToday) {
        final selectedDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          selectedTime.hour,
          selectedTime.minute,
        );

        if (!TimezoneService.isLocalTimeInFuture(selectedDateTime)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Selected time must be in the future')),
            );
          }
          return;
        }
      }

      // For end time, validate it's after start time
      if (!isStartTime && _startTime != null) {
        final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
        final endMinutes = selectedTime.hour * 60 + selectedTime.minute;

        if (endMinutes <= startMinutes) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('End time must be after start time')),
            );
          }
          return;
        }
      }

      setState(() {
        if (isStartTime) {
          _startTime = selectedTime;

          // Always adjust end time to be 1 hour after start time
          // This ensures the end time is always updated when start time changes
          final newEndHour = (selectedTime.hour + 1) % 24;
          _endTime = TimeOfDay(hour: newEndHour, minute: selectedTime.minute);
        } else {
          _endTime = selectedTime;
        }
      });
    }
  }
}
