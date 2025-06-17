import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:convert';
import 'dart:async';

import '../widgets/custom_app_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/group_selector_sidebar.dart';
import '../dynamo/group_service.dart';
import '../models/Group.dart';
import '../models/User.dart';
import '../schedule/invite/invite_member_screen.dart';

import '../theme/theme_provider.dart';
import '../widgets/smart_back_button.dart';
import '../services/refresh_service.dart';

import 'package:provider/provider.dart';


class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> with TickerProviderStateMixin, NavigationMemoryMixin {
  final int _currentIndex = 1; // Group is the 2nd tab (index 1)
  List<Group> _groups = [];
  Group? _selectedGroup;
  bool _isLoading = true;
  String? _currentUserId;
  final Map<String, bool> _isAdminCache = {};

  // Sidebar state
  bool _isSidebarOpen = false;
  late AnimationController _sidebarAnimationController;
  late Animation<double> _sidebarAnimation;

  // Refresh service subscription
  StreamSubscription<void>? _refreshSubscription;

  @override
  void initState() {
    super.initState();
    _sidebarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _sidebarAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _sidebarAnimationController,
      curve: Curves.easeInOut,
    ));
    _getCurrentUserId();
    _loadGroups();

    // Listen for profile changes to refresh group member data
    _refreshSubscription = RefreshService().profileChanges.listen((_) {
      if (mounted) {
        setState(() {}); // Trigger rebuild to refresh member lists
      }
    });
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    _sidebarAnimationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUserId() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUserId = user.userId;
        });
      }
    } catch (e) {
      debugPrint('Error getting current user: $e');
    }
  }

  Future<bool> _isUserAdmin(String groupId) async {
    // Check cache first
    if (_isAdminCache.containsKey(groupId)) {
      return _isAdminCache[groupId]!;
    }

    if (_currentUserId == null) {
      return false;
    }

    try {
      // Query to check if the current user is an admin of the group
      final request = GraphQLRequest<String>(
        document: '''
          query GetGroupUserRole(\$userId: ID!, \$groupId: ID!) {
            listGroupUsers(filter: {
              and: {
                userId: {eq: \$userId},
                groupId: {eq: \$groupId}
              }
            }) {
              items {
                isAdmin
              }
            }
          }
        ''',
        variables: {'userId': _currentUserId, 'groupId': groupId},
      );

      final response = await Amplify.API.query(request: request).response;
      final data = jsonDecode(response.data ?? '{}');
      final items = data['listGroupUsers']?['items'] ?? [];

      bool isAdmin = false;
      if (items.isNotEmpty) {
        isAdmin = items[0]['isAdmin'] ?? false;
      }

      // Cache the result
      _isAdminCache[groupId] = isAdmin;
      return isAdmin;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await GroupService.getUserGroups();
      setState(() {
        _groups = groups;
        _selectedGroup = groups.isNotEmpty ? groups.first : null;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load groups: $e')),
        );
      }
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

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });

    if (_isSidebarOpen) {
      _sidebarAnimationController.forward();
    } else {
      _sidebarAnimationController.reverse();
    }
  }

  void _closeSidebar() {
    if (_isSidebarOpen) {
      setState(() {
        _isSidebarOpen = false;
      });
      _sidebarAnimationController.reverse();
    }
  }

  void _onGroupSelected(Group group) {
    setState(() {
      _selectedGroup = group;
    });
    _closeSidebar();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final activeColor = isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2196F3);

    return NavigationMemoryWrapper(
      currentRoute: '/addGroup',
      child: Scaffold(
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
      body: Stack(
        children: [
          // Main content
          GestureDetector(
            onTap: _closeSidebar,
            child: _isLoading
                ? Center(child: CircularProgressIndicator(
                    color: activeColor,
                  ))
                : _groups.isEmpty
                    ? _buildEmptyState()
                    : _buildGroupContent(),
          ),

          // Sidebar overlay
          if (_isSidebarOpen)
            GestureDetector(
              onTap: _closeSidebar,
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),

          // Animated sidebar
          AnimatedBuilder(
            animation: _sidebarAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_sidebarAnimation.value * 320, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GroupSelectorSidebar(
                    groups: _groups,
                    selectedGroup: _selectedGroup,
                    onGroupSelected: _onGroupSelected,
                    onCreateGroup: () {
                      _closeSidebar();
                      _navigateToCreateGroup();
                    },
                    currentUserId: _currentUserId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: _selectedGroup != null ? FloatingActionButton(
        onPressed: () => _navigateToInviteMember(_selectedGroup!.id),
        backgroundColor: activeColor,
        child: const Icon(Icons.person_add, color: Colors.white),
      ) : null,
      bottomNavigationBar: BottomNavBar(currentIndex: _currentIndex),
      ),
    );
  }

  Widget _buildGroupContent() {
    return Column(
      children: [
        // Top section with group selector
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildGroupSelector(),
        ),

        // Members list
        Expanded(
          child: _selectedGroup != null
              ? _buildMembersList(_selectedGroup!.id)
              : const Center(child: Text('Open the sidebar to select a group')),
        ),
      ],
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

  Widget _buildGroupSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: _toggleSidebar,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.1 * 255).round()),
              offset: const Offset(0, 4),
              blurRadius: 15,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group,
              size: 24,
              color: textColor,
            ),
            const SizedBox(width: 8),
            Text(
              _selectedGroup?.name ?? 'Select Group',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _isSidebarOpen ? Icons.close : Icons.menu,
              color: textColor,
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildMembersList(String groupId) {
    return FutureBuilder<List<User>>(
      future: _loadGroupMembers(groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading members: ${snapshot.error}'),
          );
        }

        final members = snapshot.data ?? [];

        if (members.isEmpty) {
          return const Center(
            child: Text('No members in this group'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {}); // Trigger rebuild to reload members
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return _buildMemberCard(member);
            },
          ),
        );
      },
    );
  }

  Widget _buildMemberCard(User member) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Profile picture with actual image or initials
            ProfileAvatar(
              userId: member.id,
              userName: member.name,
              size: 48.0,
              showBorder: false,
            ),

            const SizedBox(width: 16),

            // Member info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member.email,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Three-dot menu for admin actions (only visible to admins, but not for themselves)
            _selectedGroup != null
                ? FutureBuilder<bool>(
                    future: _isUserAdmin(_selectedGroup!.id),
                    builder: (context, snapshot) {
                      final isAdmin = snapshot.data ?? false;

                      // Hide menu for non-admins or if the member is the current user (admin themselves)
                      if (!isAdmin || member.id == _currentUserId) {
                        return const SizedBox.shrink();
                      }

                      return PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'remove') {
                            _showRemoveMemberDialog(member);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.person_remove, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Remove Member'),
                              ],
                            ),
                          ),
                        ],
                        child: const Icon(Icons.more_vert),
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  void _showRemoveMemberDialog(User member) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Member'),
          content: Text('Are you sure you want to remove ${member.name} from this group?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _removeMember(member);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeMember(User member) async {
    if (_selectedGroup == null) return;

    try {
      await GroupService.removeMemberFromGroup(
        groupId: _selectedGroup!.id,
        userId: member.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.name} removed from group')),
        );

        // Refresh the members list
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove member: $e')),
        );
      }
    }
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: !isSaving, // Prevent dismissal while saving
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final isDarkMode = themeProvider.isDarkMode;
        final primaryColor = isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2196F3);

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
              titlePadding: const EdgeInsets.all(0),
              contentPadding: const EdgeInsets.all(0),
              title: Container(
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
                    'Create New Group',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              content: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Group Name*',
                        hintText: 'e.g., Project Phoenix Team',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      maxLength: 50,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'A short description of the group\'s purpose',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      maxLines: 3,
                      maxLength: 200,
                    ),
                  ],
                ),
              ),
              actions: [
                SizedBox(
                  width: 100,
                  child: TextButton(
                    onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Group name is required')),
                              );
                              return;
                            }

                            setState(() => isSaving = true);
                            
                            final navigator = Navigator.of(context);
                            final scaffoldMessenger = ScaffoldMessenger.of(context);

                            try {
                              await GroupService.createGroup(
                                name: name,
                                description: descriptionController.text.trim(),
                              );
                              
                              if(mounted) {
                                navigator.pop();
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Group created successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                _loadGroups(); // Refresh the list of groups
                              }
                            } catch (e) {
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(content: Text('Failed to create group: ${e.toString()}')),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => isSaving = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Create'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
}
