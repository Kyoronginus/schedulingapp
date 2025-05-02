import 'package:flutter/material.dart';
import 'package:schedulingapp/widgets/custom_button.dart';
import '../routes/app_routes.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../dynamo/group_service.dart'; // Import your group service
import '../../models/Group.dart';
import '../../models/User.dart'; // Import User model
import 'invite/invite_member_screen.dart';
import '../../models/Schedule.dart'; // Import Schedule model
import '../../schedule/schedule_service.dart'; // Import ScheduleService

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int _currentIndex = 0;
  List<Group> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await GroupService.getUserGroups();
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load groups: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<List<User>> _loadGroupMembers(String groupId) async {
    try {
      return await GroupService.getGroupMembers(groupId); // Fetch group members
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load members: $e')),
      );
      return [];
    }
  }

  Future<List<Schedule>> _loadGroupSchedules(String groupId) async {
    try {
      return await ScheduleService.getGroupSchedules(
          groupId); // Fetch group schedules
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load schedules: $e')),
      );
      return [];
    }
  }

  void _navigateToInviteMember(String groupId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InviteMemberScreen(groupId: groupId),
      ),
    );
  }

  void _navigateToScheduleForm() {
    Navigator.pushReplacementNamed(context, '/scheduleForm');
  }

  void _navigateToAddGroup() {
    Navigator.pushNamed(context, '/addGroup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: const Text("Schedule Screen")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _buildGroupList()),
                const SizedBox(height: 20),
                _buildActionButtons(),
              ],
            ),
      bottomNavigationBar: BottomNavBar(currentIndex: _currentIndex),
    );
  }

  Widget _buildGroupList() {
    return ListView.builder(
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        return ExpansionTile(
          title: Text(group.name),
          subtitle: Text('Group ID: ${group.id}'),
          trailing: ElevatedButton(
            onPressed: () => _navigateToInviteMember(group.id),
            child: const Text('Invite Members'),
          ),
          children: [
            _buildGroupMembers(group.id),
            _buildGroupSchedules(group.id),
          ],
        );
      },
    );
  }

  Widget _buildGroupMembers(String groupId) {
    return FutureBuilder<List<User>>(
      future: _loadGroupMembers(groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return ListTile(title: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const ListTile(title: Text('No members found'));
        } else {
          final members = snapshot.data!;
          return Column(
            children: members.map((member) {
              return ListTile(
                title: Text(member.name),
                subtitle: Text(member.email),
              );
            }).toList(),
          );
        }
      },
    );
  }

  Widget _buildGroupSchedules(String groupId) {
    return FutureBuilder<List<Schedule>>(
      future: _loadGroupSchedules(groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return ListTile(title: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          print('📭 [$groupId] No schedules found');
          return const ListTile(title: Text('No schedules found'));
        } else {
          final schedules = snapshot.data!;
          print('📦 [$groupId] Loaded ${schedules.length} schedules');
          for (var s in schedules) {
            print(
                '📝 ${s.title}: ${s.startTime.format()} - ${s.endTime.format()}');
          }

          return Column(
            children: schedules.map((schedule) {
              return ListTile(
                title: Text(schedule.title),
                subtitle: Text(
                    '${schedule.startTime.format()} - ${schedule.endTime.format()}'),
              );
            }).toList(),
          );
        }
      },
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        CustomButton(
          onPressed: _navigateToScheduleForm,
          label: 'Create Schedule',
        ),
        const SizedBox(height: 20),
        CustomButton(
          onPressed: _navigateToAddGroup,
          label: 'Create Group',
        ),
      ],
    );
  }
}
