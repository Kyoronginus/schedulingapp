// File: lib/widgets/group_selector_sidebar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:convert';
import '../models/Group.dart';
import '../models/User.dart';
import '../theme/theme_provider.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/custom_menu_button.dart';
import '../dynamo/group_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  final bool showCreateGroupButton;

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
    this.showCreateGroupButton = true,
  });

  @override
  State<GroupSelectorSidebar> createState() => _GroupSelectorSidebarState();
}

class _GroupSelectorSidebarState extends State<GroupSelectorSidebar> {
  final Map<String, List<User>> _membersCache = {};
  final Map<String, bool> _isAdminCache = {};
  String? _lastUserId;

  void _clearCaches() {
    _membersCache.clear();
    _isAdminCache.clear();
    debugPrint('✅ GroupSelectorSidebar caches cleared');
  }

  void _checkUserChange() {
    if (_lastUserId != widget.currentUserId) {
      _clearCaches();
      _lastUserId = widget.currentUserId;
    }
  }

  @override
 Widget build(BuildContext context) {
  _checkUserChange();

  const sidebarBackgroundColor = Color(0xFFF2F2F2);
  const textColor = Colors.black;
  const headerIconColor = Color(0xFF2196F3);

  return Container(
    width: 320,
    height: double.infinity,
    decoration: BoxDecoration(
      color: sidebarBackgroundColor,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          offset: const Offset(2, 0),
          blurRadius: 10,
        ),
      ],
    ),
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 50, 20, 16),
          child: Row(
            children: [
              SizedBox(width: 12),
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
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Divider(
            color: Colors.grey[400]!,
            height: 1,
          ),
        ),

        Expanded(
          child: widget.groups.isEmpty && !widget.showPersonalOption
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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

        if (widget.showCreateGroupButton)
  Container(
    // DIUBAH: Padding disesuaikan untuk menaikkan posisi tombol
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: widget.onCreateGroup,
        icon: SvgPicture.asset(
          'assets/icons/group_add-icon.svg',
          // DIUBAH: Ukuran ikon diperbesar
          height: 24, 
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        label: const Text(
          'Create New Group',
          // DIUBAH: Ukuran teks diperbesar
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF735BF2),
          foregroundColor: Colors.white,
          // Padding tombol juga sedikit diperbesar untuk menampung ikon & teks baru
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
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
    final isSelected = widget.isPersonalMode;

    // Warna-warna untuk gaya baru
    const primaryColor = Color(0xFF735BF2);
    // ... di dalam _buildPersonalOption ...

  // DIUBAH: Warna ikon dibuat statis (tidak berubah)
  const iconColor = primaryColor; // Warna biru, sama seperti header

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white, // Kartu berwarna putih
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          // Border hanya berwarna saat dipilih
          color: isSelected ? primaryColor : Colors.transparent,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                SvgPicture.asset(
                  'assets/icons/profile-icon.svg',
                  width: 32,
                  height: 32,
                  colorFilter: ColorFilter.mode(
                    iconColor,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Personal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View all your schedules and notifications',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No Groups Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first group to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupBox(Group group) {
    final isSelected = widget.selectedGroup?.id == group.id;
    final primaryColor = const Color(0xFF735BF2);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white, // Kartu berwarna putih
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? primaryColor : Colors.transparent, // Border hanya berwarna saat dipilih
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onGroupSelected(group),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    _buildAdminOptions(group),
                  ],
                ),
                if (group.description != null && group.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    group.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
  const double avatarSize = 40.0;
  const double overlap = 22.0;

  return FutureBuilder<List<User>>(
    future: _getGroupMembers(group.id),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox(
          height: avatarSize,
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
      if (members.isEmpty) {
        return const Text('No members yet', style: TextStyle(fontSize: 12, color: Colors.grey));
      }
      
      final displayMembers = members.take(4).toList();
      final remainingCount = members.length - displayMembers.length;

      final stackWidth = (displayMembers.length * overlap) + (avatarSize - overlap);

      return Row(
        children: [
          SizedBox(
            width: stackWidth,
            height: avatarSize,
            child: Stack(
              children: [
                ...displayMembers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final member = entry.value;
                  return Positioned(
                    left: index * overlap,
                    child: ProfileAvatar(
                      userId: member.id,
                      userName: member.name,
                      size: avatarSize,
                      showBorder: true,
                    ),
                  );
                }),

                if (remainingCount > 0)
                  Positioned(
                    left: displayMembers.length * overlap,
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
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
                  ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          Text(
            '${members.length} member${members.length != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
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
    if (_isAdminCache.containsKey(groupId)) {
      return _isAdminCache[groupId]!;
    }

    if (widget.currentUserId == null) {
      return false;
    }

    try {
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

        return CustomMenuButton(
          onSelected: (value) {
            if (!mounted) return;
            if (value == 'edit') {
              _showEditGroupDialog(group);
            } else if (value == 'delete') {
              _showDeleteGroupDialog(group);
            }
          },
          items: const [
            CustomMenuItem(
              value: 'edit',
              text: 'Edit Group',
              icon: Icons.edit,
              iconColor: Colors.black87,
              textColor: Colors.black87,
            ),
            CustomMenuItem(
              value: 'delete',
              text: 'Delete Group',
              icon: Icons.delete,
              iconColor: Colors.red,
              textColor: Colors.red,
            ),
          ],
          backgroundColor: Colors.white,
          child: Icon(
            Icons.more_vert,
            size: 20,
            color: Colors.grey[600],
          ),
        );
      },
    );
  }

  void _showEditGroupDialog(Group group) {
  final nameController = TextEditingController(text: group.name);
  final descriptionController =
      TextEditingController(text: group.description ?? '');
  bool isSaving = false;

  showDialog(
    context: context,
    barrierDismissible: !isSaving,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final themeProvider = Provider.of<ThemeProvider>(context);
          final isDarkMode = themeProvider.isDarkMode;

          final primaryColor = const Color(0xFF735BF2);
          final destructiveColor = const Color(0xFFEA3C54);
          final hintColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
          final borderColor = isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;

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
              borderSide: const BorderSide(color: Colors.red, width: 2.0),
            ),
            fillColor: isDarkMode ? const Color(0xFF3A3A3A) : Colors.white,
            filled: true,
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
            titlePadding: const EdgeInsets.all(0),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            
            title: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: inputDecorationTheme.copyWith(
                      labelText: 'Group Name',
                    ),
                    maxLength: 50,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: inputDecorationTheme.copyWith(
                      labelText: 'Description (Optional)',
                    ),
                    maxLines: 3,
                    maxLength: 200,
                  ),
                ],
              ),
            ),
            
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: destructiveColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Group name cannot be empty')),
                            );
                            return;
                          }
                          
                          setState(() => isSaving = true);
                          
                          final success = await GroupService.updateGroup(
                            group.id,
                            name,
                            descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                          );

                          if(mounted){
                             Navigator.of(dialogContext).pop();
                             if (success) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Group updated!"), backgroundColor: Colors.green,));
                               // DIHAPUS: Baris Provider.of<GroupSelectionProvider>... telah dihapus
                             } else {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update group."), backgroundColor: Colors.red,));
                             }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                     shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Update'),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

  void _showDeleteGroupDialog(Group group) {
  final theme = Theme.of(context);
  final isDarkMode = theme.brightness == Brightness.dark;

  // Mendefinisikan warna yang akan digunakan
  final primaryPurpleColor = const Color(0xFF735BF2);
  final destructiveColor = const Color(0xFFEA3C54);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
      elevation: 10.0,
      title: const Text('Delete Group'),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
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
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      
      // DIUBAH: Menambahkan alignment untuk meratakan tombol
      actionsAlignment: MainAxisAlignment.spaceBetween,

      actions: [
        // ==== GAYA TOMBOL DIUBAH MENJADI SEPANJANG DIALOG ====

        // Tombol Batal (di sisi kiri)
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: destructiveColor, // Warna merah
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: const Text('Cancel',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),


        // Tombol Delete (di sisi kanan)
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              navigator.pop();
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Row(children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 16),
                    Text('Deleting group...'),
                  ]),
                  duration: Duration(seconds: 30),
                ),
              );
              final success = await GroupService.deleteGroup(group.id);
              if (mounted) {
                scaffoldMessenger.hideCurrentSnackBar();
                if (success) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Group deleted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
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
              backgroundColor: primaryPurpleColor, // Warna ungu
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: const Text('Delete',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );
}
}