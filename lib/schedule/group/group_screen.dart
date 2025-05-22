import 'package:flutter/material.dart';

import '../../widgets/custom_app_bar.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../dynamo/group_service.dart';
import '../../models/Group.dart';
import '../../models/User.dart';
import '../invite/invite_member_screen.dart';
import '../../models/Schedule.dart';
import '../../schedule/schedule_service.dart';
import '../../theme/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../utils/utils_functions.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  _GroupScreenState createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  int _currentIndex = 1; // Group is the 2nd tab (index 1)
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
      return await GroupService.getGroupMembers(groupId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load members: $e')),
      );
      return [];
    }
  }

  Future<List<Schedule>> _loadGroupSchedules(String groupId) async {
    try {
      return await ScheduleService.getGroupSchedules(groupId);
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

  void _navigateToCreateGroup() {
    _showCreateGroupDialog();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final activeColor = isDarkMode ? const Color(0xFF4CAF50) : primaryColor;

    return Scaffold(
      appBar: CustomAppBar(
        title: Text(
          "Groups",
          style: TextStyle(
            color: isDarkMode ? const Color(0xFF4CAF50) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : null,
        showBackButton: false,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(
              color: activeColor,
            ))
          : _groups.isEmpty
              ? _buildEmptyState()
              : _buildGroupList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateGroup,
        backgroundColor: activeColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: _currentIndex),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Groups Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a group to start collaborating',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToCreateGroup,
            icon: const Icon(Icons.add),
            label: const Text('Create Group'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return ListView.builder(
      itemCount: _groups.length,
      padding: const EdgeInsets.all(16.0),
      itemBuilder: (context, index) {
        final group = _groups[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            title: Text(
              group.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor,
              ),
            ),
            subtitle: group.description != null && group.description!.isNotEmpty
                ? Text(
                    group.description!,
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _navigateToInviteMember(group.id),
            ),
            children: [
              _buildGroupMembers(group.id),
              _buildGroupSchedules(group.id),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupMembers(String groupId) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return FutureBuilder<List<User>>(
      future: _loadGroupMembers(groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasError) {
          return ListTile(title: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const ListTile(title: Text('No members found'));
        } else {
          final members = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Members',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                ...members.map((member) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      child: Text(
                        member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    title: Text(member.name),
                    subtitle: Text(member.email),
                    dense: true,
                  );
                }).toList(),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildGroupSchedules(String groupId) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final activeColor = isDarkMode ? const Color(0xFF4CAF50) : primaryColor;

    return FutureBuilder<List<Schedule>>(
      future: _loadGroupSchedules(groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasError) {
          return ListTile(title: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No schedules found for this group'),
          );
        } else {
          final schedules = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Upcoming Schedules',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                ...schedules.map((schedule) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(schedule.title),
                      subtitle: Text(
                        '${schedule.startTime.format()} - ${schedule.endTime.format()}',
                        style: TextStyle(
                          color: activeColor,
                          fontSize: 12,
                        ),
                      ),
                      dense: true,
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        }
      },
    );
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create a New Group'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Group Name*',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Group name is required')),
                          );
                          return;
                        }

                        setState(() => isSaving = true);

                        try {
                          await GroupService.createGroup(
                            name: name,
                            description: descriptionController.text.trim(),
                          );

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Group created successfully!')),
                          );

                          // Reload groups
                          _loadGroups();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Failed to create group: ${e.toString()}')),
                          );
                        } finally {
                          setState(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }
}
