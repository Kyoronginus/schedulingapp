import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:schedulingapp/widgets/custom_app_bar.dart';
import '../models/Schedule.dart';
import 'package:intl/intl.dart';
import '../models/Schedule_extensions.dart';
import 'schedule_service.dart';
import '../models/User.dart';
import '../models/Group.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../dynamo/get_user_service.dart';
import '../dynamo/group_service.dart';

class ScheduleFormScreen extends StatefulWidget {
  const ScheduleFormScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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

  // Schedule creation process
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

    setState(() => _isSaving = true);

    try {
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
      Navigator.pop(context);
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
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (selectedDate == null) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now()),
    );
    if (selectedTime == null) return;

    final selectedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    setState(() {
      if (isStartTime) {
        _startTime = selectedDateTime;
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
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(
            context); // Ensure it navigates back to the previous screen
        return false; // Prevent default back button behavior
      },
      child: Scaffold(
        appBar: CustomAppBar(title: Text('Ini schedule form screen')),
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
                  color: time != null ? Colors.black : Colors.grey,
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
                  color: _selectedGroup != null ? Colors.black : Colors.grey,
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
