import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:schedulingapp/widgets/custom_app_bar.dart';
import '../../models/Schedule.dart';
import 'package:intl/intl.dart';
import '../../models/schedule_extensions.dart';
import '../schedule_service.dart';
import '../../models/User.dart';
import '../../models/Group.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../../dynamo/get_user_service.dart';
import '../../dynamo/group_service.dart';
import '../../routes/app_routes.dart';
import '../../theme/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../utils/utils_functions.dart';
import 'dart:async';

class ScheduleFormScreen extends StatefulWidget {
  final Schedule? scheduleToEdit;

  const ScheduleFormScreen({super.key, this.scheduleToEdit});

  @override
  _ScheduleFormScreenState createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isSaving = false;
  Group? _selectedGroup; // Holds the selected group

  // Timer to periodically check if selected time is still valid
  Timer? _timeValidityTimer;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.scheduleToEdit != null;

    // If editing, populate the form with existing data
    if (_isEditing) {
      _titleController.text = widget.scheduleToEdit!.title;
      _descriptionController.text = widget.scheduleToEdit!.description ?? '';
      _startTime = widget.scheduleToEdit!.startTime.getDateTimeInUtc();
      _endTime = widget.scheduleToEdit!.endTime.getDateTimeInUtc();
      _selectedGroup = widget.scheduleToEdit!.group;
    } else {
      _loadInitialData();
    }

    // Start a timer to check time validity every minute
    _timeValidityTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _validateTimeSelections();
    });
  }

  @override
  void dispose() {
    _timeValidityTimer?.cancel();
    super.dispose();
  }

  // Validate that selected times are still in the future
  void _validateTimeSelections() {
    final now = DateTime.now();

    // If start time is in the past, clear it
    if (_startTime != null && _startTime!.isBefore(now)) {
      setState(() {
        _startTime = null;
        // If end time depends on start time, clear it too
        if (_endTime != null) {
          _endTime = null;
        }
      });

      // Only show warning if the form is visible
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected time is now in the past. Please select a new time.')),
        );
      }
    }
  }

  // Load initial data (user and group)
  Future<void> _loadInitialData() async {
    try {
      final group = await GroupService.getSelectedGroup();
      setState(() => _selectedGroup = group);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load group: $e')),
      );
    }
  }

  // Schedule creation/update process
  Future<void> _createSchedule() async {
    if (_titleController.text.isEmpty ||
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

    // Validate that start time is before end time
    if (_startTime!.isAfter(_endTime!) || _startTime!.isAtSameMomentAs(_endTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    // Validate that start time is in the future
    final now = DateTime.now();
    if (_startTime!.isBefore(now)) {
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
          startTime: TemporalDateTime(_startTime!),
          endTime: TemporalDateTime(_endTime!),
          group: _selectedGroup,
        );

        await ScheduleService.updateSchedule(updatedSchedule);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule updated successfully!')),
        );
      } else {
        // Create new schedule
        final currentUser = await AuthService.getCurrentUser();

        final newSchedule = Schedule(
          id: '', // Amplify will auto-generate this
          title: _titleController.text,
          description: _descriptionController.text,
          startTime: TemporalDateTime(_startTime!),
          endTime: TemporalDateTime(_endTime!),
          user: currentUser, // Pass the User object directly
          group: _selectedGroup, // Explicitly set groupId
        );

        await ScheduleService.createSchedule(newSchedule);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule created successfully!')),
        );
      }

      Navigator.pushReplacementNamed(context, AppRoutes.schedule);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // Date and time selection dialog
  Future<void> _selectDateTime(bool isStartTime) async {
    final DateTime now = DateTime.now();

    // Round current time to next 5 minutes
    final int currentMinute = now.minute;
    final int roundedMinute = ((currentMinute + 4) ~/ 5) * 5;
    final DateTime roundedNow = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour + (roundedMinute >= 60 ? 1 : 0),
      roundedMinute % 60
    );

    // Set initial date based on existing selection or current date
    final initialDate = isStartTime
        ? (_startTime != null ? _startTime! : roundedNow)
        : (_endTime != null ? _endTime! :
           (_startTime != null ? _startTime!.add(const Duration(hours: 1)) : roundedNow.add(const Duration(hours: 1))));

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day), // Allow today
      lastDate: DateTime(2101),
    );
    if (selectedDate == null) return;

    // Determine minimum time for today
    TimeOfDay minimumTime = TimeOfDay.fromDateTime(roundedNow);
    bool isToday = selectedDate.year == now.year &&
                   selectedDate.month == now.month &&
                   selectedDate.day == now.day;

    // Set initial time based on existing selection or current time + 1 hour (rounded to 5 minutes)
    TimeOfDay initialTimeOfDay;
    if (isStartTime) {
      initialTimeOfDay = _startTime != null
          ? TimeOfDay.fromDateTime(_startTime!)
          : TimeOfDay.fromDateTime(roundedNow.add(const Duration(minutes: 30)));
    } else {
      initialTimeOfDay = _endTime != null
          ? TimeOfDay.fromDateTime(_endTime!)
          : (_startTime != null
              ? TimeOfDay.fromDateTime(_startTime!.add(const Duration(hours: 1)))
              : TimeOfDay.fromDateTime(roundedNow.add(const Duration(hours: 1, minutes: 30))));
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTimeOfDay,
      builder: (BuildContext context, Widget? child) {
        // Only apply time validation for today
        if (!isToday) return child!;

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: false,
          ),
          child: TimePickerDialog(
            initialTime: initialTimeOfDay,
            cancelText: 'CANCEL',
            confirmText: 'OK',
            // This validator ensures time is in the future for today
            errorInvalidText: 'Time must be in the future',
            initialEntryMode: TimePickerEntryMode.dial,
          ),
        );
      },
    );
    if (selectedTime == null) return;

    final selectedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // Ensure selected time is in the future
    if (selectedDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected time must be in the future')),
      );
      return;
    }

    // For end time, ensure it's after start time
    if (!isStartTime && _startTime != null && selectedDateTime.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    setState(() {
      if (isStartTime) {
        _startTime = selectedDateTime;
        // If end time exists but is now before start time, clear it
        if (_endTime != null && _endTime!.isBefore(selectedDateTime)) {
          _endTime = null;
        }
      } else {
        _endTime = selectedDateTime;
      }
    });
  }

  // Group selection dialog
  Future<void> _selectGroup() async {
    final groups = await GroupService.getUserGroups();
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

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(
            context); // Ensure it navigates back to the previous screen
        return false; // Prevent default back button behavior
      },
      child: Scaffold(
        appBar: CustomAppBar(
          title: Text(
            _isEditing ? "Edit Schedule" : "Create Schedule",
            style: TextStyle(
              color: isDarkMode ? const Color(0xFF4CAF50) : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : null,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title*',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _buildTimeSelection(
                    'Start Time*', _startTime, () => _selectDateTime(true)),
                const SizedBox(height: 16),
                _buildTimeSelection(
                    'End Time*', _endTime, () => _selectDateTime(false)),
                const SizedBox(height: 16),
                _buildGroupSelector(),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _createSchedule,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator()
                      : const Text('Save', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Time selection widget
  Widget _buildTimeSelection(
      String label, DateTime? time, VoidCallback onPressed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.centerLeft,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time != null
                    ? DateFormat('yyyy/MM/dd HH:mm').format(time)
                    : 'Please select',
                style: TextStyle(
                  color: time != null
                      ? (Provider.of<ThemeProvider>(context).isDarkMode ? Colors.white : Colors.black)
                      : Colors.grey,
                ),
              ),
              const Icon(Icons.calendar_today, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  // Group selection widget
  Widget _buildGroupSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Group*', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _selectGroup,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.centerLeft,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedGroup?.name ?? 'Please select',
                style: TextStyle(
                  color: _selectedGroup != null
                      ? (Provider.of<ThemeProvider>(context).isDarkMode ? Colors.white : Colors.black)
                      : Colors.grey,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 24),
            ],
          ),
        ),
      ],
    );
  }
}
