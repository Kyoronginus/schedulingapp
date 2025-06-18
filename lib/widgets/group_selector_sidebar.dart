import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:convert';
import '../models/Group.dart';
import '../models/User.dart';
import '../theme/theme_provider.dart';
import '../widgets/profile_avatar.dart';
import '../dynamo/group_service.dart';

class GroupSelectorSidebar extends StatefulWidget {
  final List<Group> groups;
  final Group? selectedGroup;
  final bool isPersonalMode;
  final Function(Group) onGroupSelected;
  final VoidCallback? onPersonalModeSelected;
  final VoidCallback onCreateGroup;
  final VoidCallback? onGroupsChanged;
  final String? currentUserId;
  final bool showPersonalOption;

  const GroupSelectorSidebar({
    super.key,
    required this.groups,
    required this.selectedGroup,
    required this.isPersonalMode,
    required this.onGroupSelected,
    this.onPersonalModeSelected,
    required this.onCreateGroup,
    this.onGroupsChanged,
    this.currentUserId,
    this.showPersonalOption = false,
  });

  @override
  State<GroupSelectorSidebar> createState() => _GroupSelectorSidebarState();
}

class _GroupSelectorSidebarState extends State<GroupSelectorSidebar> {
  final Map<String, List<User>> _membersCache = {};
  final Map<String, bool> _isAdminCache = {};
  String? _lastUserId;

  /// Clear all caches when user changes
  void _clearCaches() {
    _membersCache.clear();
    _isAdminCache.clear();
    debugPrint('✅ GroupSelectorSidebar caches cleared');
  }

  /// Check if user has changed and clear caches if needed
  void _checkUserChange() {
    if (_lastUserId != widget.currentUserId) {
      _clearCaches();
      _lastUserId = widget.currentUserId;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user has changed and clear caches if needed
    _checkUserChange();

    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      width: 320,
      height: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            offset: const Offset(2, 0),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2E2E2E) : Colors.grey[100],
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.group,
                  color: isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2196F3),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Select Group',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),

          // Groups list
          Expanded(
            child: widget.groups.isEmpty && !widget.showPersonalOption
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _getItemCount(),
                    itemBuilder: (context, index) {
                      if (widget.showPersonalOption && index == 0) {
                        return _buildPersonalOption();
                      }
                      final groupIndex = widget.showPersonalOption ? index - 1 : index;
                      final group = widget.groups[groupIndex];
                      return _buildGroupBox(group);
                    },
                  ),
          ),

          // Add group button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onCreateGroup,
                icon: const Icon(Icons.add),
                label: const Text('Create New Group'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _getItemCount() {
    return widget.groups.length + (widget.showPersonalOption ? 1 : 0);
  }

  Widget _buildPersonalOption() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final isSelected = widget.isPersonalMode;
    final backgroundColor = isSelected
        ? (isDarkMode ? const Color(0xFF4CAF50).withValues(alpha: 0.2) : const Color(0xFF2196F3).withValues(alpha: 0.1))
        : (isDarkMode ? const Color(0xFF2E2E2E) : Colors.white);
    final borderColor = isSelected
        ? (isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2196F3))
        : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPersonalModeSelected,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  color: isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2196F3),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View all your schedules and notifications',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Groups Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first group to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupBox(Group group) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final isSelected = widget.selectedGroup?.id == group.id;
    final backgroundColor = isSelected
        ? (isDarkMode ? const Color(0xFF4CAF50).withValues(alpha: 0.2) : const Color(0xFF2196F3).withValues(alpha: 0.1))
        : (isDarkMode ? const Color(0xFF2E2E2E) : Colors.white);
    final borderColor = isSelected
        ? (isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2196F3))
        : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onGroupSelected(group),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with group name and admin options
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    // Admin options
                    _buildAdminOptions(group),
                  ],
                ),

                // Description
                if (group.description != null && group.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    group.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Member previews
                const SizedBox(height: 12),
                _buildMemberPreviews(group),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberPreviews(Group group) {
    return FutureBuilder<List<User>>(
      future: _getGroupMembers(group.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 32,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final members = snapshot.data ?? [];
        final displayMembers = members.take(4).toList();
        final remainingCount = members.length - displayMembers.length;

        return Row(
          children: [
            // Profile pictures
            ...displayMembers.asMap().entries.map((entry) {
              final index = entry.key;
              final member = entry.value;
              return Container(
                margin: EdgeInsets.only(left: index > 0 ? 4 : 0),
                child: ProfileAvatar(
                  userId: member.id,
                  userName: member.name,
                  size: 32,
                  showBorder: true,
                ),
              );
            }),

            // Remaining count indicator
            if (remainingCount > 0) ...[
              Container(
                margin: const EdgeInsets.only(left: 4),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$remainingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],

            // Member count text
            const SizedBox(width: 8),
            Text(
              '${members.length} member${members.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<User>> _getGroupMembers(String groupId) async {
    if (_membersCache.containsKey(groupId)) {
      return _membersCache[groupId]!;
    }

    try {
      final members = await GroupService.getGroupMembers(groupId);
      _membersCache[groupId] = members;
      return members;
    } catch (e) {
      debugPrint('Error loading group members: $e');
      return [];
    }
  }

  Future<bool> _isUserAdmin(String groupId) async {
    // Check cache first
    if (_isAdminCache.containsKey(groupId)) {
      return _isAdminCache[groupId]!;
    }

    if (widget.currentUserId == null) {
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
        variables: {'userId': widget.currentUserId, 'groupId': groupId},
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

  Widget _buildAdminOptions(Group group) {
    if (widget.currentUserId == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<bool>(
      future: _isUserAdmin(group.id),
      builder: (context, snapshot) {
        final isAdmin = snapshot.data ?? false;

        if (!isAdmin) {
          return const SizedBox.shrink();
        }

        final themeProvider = Provider.of<ThemeProvider>(context);
        final isDarkMode = themeProvider.isDarkMode;

        return PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditGroupDialog(group);
            } else if (value == 'delete') {
              _showDeleteGroupDialog(group);
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Edit Group'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('Delete Group', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          child: Icon(
            Icons.more_vert,
            size: 20,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        );
      },
    );
  }

  void _showEditGroupDialog(Group group) {
    final nameController = TextEditingController(text: group.name);
    final descriptionController = TextEditingController(text: group.description ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: !isSaving, // Prevent dismissal while saving
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final isDarkMode = themeProvider.isDarkMode;
        final primaryColor = isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF4A80F0);

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
                    'Edit Group',
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
                        labelText: 'Group Name',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      maxLength: 50,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'What is this group about?',
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
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final description = descriptionController.text.trim();

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Group name cannot be empty')),
                            );
                            return;
                          }

                          setState(() => isSaving = true);

                          final navigator = Navigator.of(context);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);

                          // Update the group
                          final success = await GroupService.updateGroup(
                            group.id,
                            name,
                            description.isEmpty ? null : description,
                          );

                          if (mounted) {
                            navigator.pop(); // Close the dialog first

                            if (success) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Group updated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              if (widget.onGroupsChanged != null) {
                                widget.onGroupsChanged!();
                              }
                            } else {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to update group. Please try again.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
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
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteGroupDialog(Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${group.name}"?'),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone. All schedules and data associated with this group will be permanently deleted.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              navigator.pop();

              // Show loading indicator
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 16),
                      Text('Deleting group...'),
                    ],
                  ),
                  duration: Duration(seconds: 30),
                ),
              );

              // Delete the group
              final success = await GroupService.deleteGroup(group.id);

              // Hide loading indicator and show result
              if (mounted) {
                scaffoldMessenger.hideCurrentSnackBar();

                if (success) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Group deleted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Refresh the groups list
                  if (widget.onGroupsChanged != null) {
                    widget.onGroupsChanged!();
                  }
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete group. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
