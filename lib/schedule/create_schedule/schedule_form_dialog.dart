import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/Schedule.dart';
import '../../models/User.dart';
import '../schedule_service.dart';
import '../../models/Group.dart';
import '../../auth/auth_service.dart';
import '../../dynamo/group_service.dart';
import '../../theme/theme_provider.dart';
import '../../services/timezone_service.dart';
import '../../services/refresh_service.dart';
import '../../services/oauth_user_service.dart';
import '../../widgets/scrollable_time_picker.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../utils/utils_functions.dart';
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
      GlobalKey<FormState>(); // BARU: Menambahkan GlobalKey untuk validasi
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

  @override
  void initState() {
    super.initState();
    _isEditing = widget.scheduleToEdit != null;
    _selectedDate = widget.selectedDate;

    if (_isEditing) {
      // Logika untuk mengisi form saat mode edit (tidak berubah)
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
    // Logika ini tidak berubah
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

  // Jika waktu yang dipilih sudah lewat
  if (!TimezoneService.isLocalTimeInFuture(selectedStartDateTime)) {
    if (mounted) {
      setState(() {
        // DIUBAH: Jangan set ke null, tapi reset ke waktu default (jam berikutnya)
        final now = DateTime.now();
        final nextHour = (now.hour + (now.minute > 0 ? 1 : 0)) % 24;
        _startTime = TimeOfDay(hour: nextHour, minute: 0);
        _endTime = TimeOfDay(hour: (nextHour + 1) % 24, minute: 0);
      });
    }
  }
}

  DateTime _timeOfDayToDateTime(DateTime date, TimeOfDay time) {
    // Logika ini tidak berubah
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _saveSchedule() async {
    // Menggunakan form key untuk validasi
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
        // Logika update (tidak berubah)
        final updatedSchedule = widget.scheduleToEdit!.copyWith(
          title: _titleController.text,
          description: _descriptionController.text,
          location: _locationController.text,
          startTime: TimezoneService.localToUtc(startDateTime),
          endTime: TimezoneService.localToUtc(endDateTime),
          group: _selectedGroup,
        );
        await ScheduleService.updateSchedule(updatedSchedule);
      } else {
        // Logika create (tidak berubah)
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
          user: currentUser,
          group: _selectedGroup!,
        );
        await ScheduleService.createSchedule(newSchedule);
        RefreshService().notifyScheduleChange();
      }

      if (mounted) {
        Navigator.pop(context); // Tutup dialog
        widget.onFormClosed(); // Panggil callback untuk refresh
      }
    } catch (e) {
      // Error handling tidak berubah
      debugPrint('❌ ScheduleForm: Error creating/updating schedule: $e');
      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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

  Future<void> _selectGroup() async {
    // Logika ini tidak berubah
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

  // DIUBAH: Seluruh widget build diubah menjadi AlertDialog
  @override
  Widget build(BuildContext context) {
    // Definisikan warna di awal agar bisa digunakan di mana saja
    const primaryColor = Color(0xFF735BF2);
    const cancelColor = Color(0xFFF77272);
    const textColor = Colors.black87;
    const hintColor = Color(0xFF999999);
    const iconColor = Color(0xFF999999);

    // Tema dekorasi input yang akan digunakan untuk semua field
    final inputDecorationTheme = InputDecoration(
      hintStyle:
          const TextStyle(color: hintColor, fontWeight: FontWeight.normal),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: Color(0xFFEDF1F7), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      // Menambahkan border untuk error dan focus error
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );

    return AlertDialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      title: Center(
        child: Text(
          _isEditing ? 'Edit Event' : 'Add New Event',
          style: const TextStyle(
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
                  style: const TextStyle(color: textColor),
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
                            12.0), // Memberi sedikit padding agar tidak terlalu mepet
                        child: SvgPicture.asset(
                          'assets/icons/calendar_navbar-icon.svg',
                          width: 20, // Sesuaikan ukuran jika perlu
                          height: 20, // Sesuaikan ukuran jika perlu
                        ),
                      ),
                    ),
                    child: Text(
                      _selectedDate != null
                          ? DateFormat('dd / MM / yyyy').format(_selectedDate!)
                          : 'Select date',
                      style: const TextStyle(
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
                'assets/icons/clock-icon.svg', // Pastikan path ini benar
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
          ),
          child: Text(
            // DIUBAH: Hapus fallback text dan gunakan '!' karena _startTime dijamin tidak null
            _startTime!.format(context),
            // DIUBAH: Gunakan warna teks aktif, bukan warna hint
            style: const TextStyle(fontSize: 16, color: textColor),
          ),
        ),
      ),
    ),
    const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
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
                colorFilter: const ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
          ),
          child: Text(
            // DIUBAH: Hapus fallback text dan gunakan '!' karena _endTime dijamin tidak null
            _endTime!.format(context),
            // DIUBAH: Gunakan warna teks aktif, bukan warna hint
            style: const TextStyle(fontSize: 16, color: textColor),
          ),
        ),
      ),
    ),
  ],
),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  style: const TextStyle(color: textColor),
                  decoration: inputDecorationTheme.copyWith(
                    hintText: 'Location (Link Gmaps/Zoom)',
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(
                          12.0), // Memberi sedikit padding agar tidak terlalu mepet
                      child: SvgPicture.asset(
                        'assets/icons/pin_location-icon.svg',
                        width: 24, // Sesuaikan ukuran jika perlu
                        height: 24, // Sesuaikan ukuran jika perlu
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: textColor),
                  decoration: inputDecorationTheme.copyWith(
                    hintText: 'Description...',
                  ),
                  maxLines: 2,
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
                          backgroundColor:
                              const Color(0xFFEA3C54), // Warna baru
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8.0), // Radius baru
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
                          backgroundColor:
                              const Color(0xFF735BF2), // Warna baru
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8.0), // Radius baru
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

  // Metode _selectDate dan _selectTime tidak berubah secara signifikan
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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
