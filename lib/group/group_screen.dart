import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:convert';
import 'dart:async';
import '../utils/utils_functions.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/group_selector_sidebar.dart';
import '../widgets/custom_menu_button.dart';
import '../dynamo/group_service.dart';
import '../models/User.dart';
// DIUBAH: Import screen diganti dengan import dialog
import '../schedule/invite/invite_member_dialog.dart';

import '../theme/theme_provider.dart';
import '../providers/group_selection_provider.dart';
import '../widgets/smart_back_button.dart';
import '../services/refresh_service.dart';

import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen>
    with TickerProviderStateMixin, NavigationMemoryMixin {
  final int _currentIndex = 1; // Group is the 2nd tab (index 1)
  final Map<String, bool> _isAdminCache = {};

  // Sidebar state
  bool _isSidebarOpen = false;
  late AnimationController _sidebarAnimationController;
  late Animation<double> _sidebarAnimation;
  late AnimationController _navbarAnimationController;
  late Animation<double> _navbarAnimation;

  // Refresh service subscriptions
  StreamSubscription<void>? _profileRefreshSubscription;
  StreamSubscription<void>? _groupRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _sidebarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _sidebarAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _sidebarAnimationController,
      curve: Curves.easeInOut,
    ));

    _navbarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _navbarAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _navbarAnimationController,
      curve: Curves.easeInOut,
    ));

    _profileRefreshSubscription = RefreshService().profileChanges.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    _groupRefreshSubscription = RefreshService().groupChanges.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _profileRefreshSubscription?.cancel();
    _groupRefreshSubscription?.cancel();
    _sidebarAnimationController.dispose();
    _navbarAnimationController.dispose();
    super.dispose();
  }

  Future<bool> _isUserAdmin(String groupId) async {
    if (_isAdminCache.containsKey(groupId)) {
      return _isAdminCache[groupId]!;
    }

    final groupProvider =
        Provider.of<GroupSelectionProvider>(context, listen: false);
    final currentUserId = groupProvider.currentUserId;

    if (currentUserId == null) {
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
        variables: {'userId': currentUserId, 'groupId': groupId},
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

  Future<List<User>> _loadGroupMembers(String groupId) async {
    try {
      return await GroupService.getGroupMembers(groupId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load members: $e')),
        );
      }
      return [];
    }
  }

  // DIUBAH: Fungsi ini sekarang menampilkan dialog, bukan screen baru
  void _showInviteMemberDialog(String groupId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return InviteMemberDialog(groupId: groupId);
      },
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
      _navbarAnimationController.forward();
    } else {
      _sidebarAnimationController.reverse();
      _navbarAnimationController.reverse();
    }
  }

  void _closeSidebar() {
    if (_isSidebarOpen) {
      setState(() {
        _isSidebarOpen = false;
      });
      _sidebarAnimationController.reverse();
      _navbarAnimationController.reverse();
    }
  }

  @override
Widget build(BuildContext context) {
  final themeProvider = Provider.of<ThemeProvider>(context);
  final groupProvider = Provider.of<GroupSelectionProvider>(context);
  final isDarkMode = themeProvider.isDarkMode;
  final primaryColor =
      isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF735BF2);

  return NavigationMemoryWrapper(
    currentRoute: '/addGroup',
    child: Scaffold(
      extendBody: true,
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF1F1F1),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 50.0, 8, 0),
            child: GestureDetector(
              onTap: _closeSidebar,
              child: groupProvider.isLoading
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(
                          color: primaryColor,
                        ),
                      ),
                    )
                  : groupProvider.groups.isEmpty
                      ? _buildEmptyState(
                          textColor: isDarkMode
                              ? Colors.white
                              : const Color(0xFF000000),
                          subTextColor: isDarkMode
                              ? Colors.grey.shade400
                              : const Color(0xFF000000),
                        )
                      : _buildGroupContent(),
            ),
          ),
          if (_isSidebarOpen)
            GestureDetector(
              onTap: _closeSidebar,
              child: Container(
                color: Colors.black.withOpacity(0.6),
              ),
            ),
          AnimatedBuilder(
            animation: _sidebarAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_sidebarAnimation.value * 320, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GroupSelectorSidebar(
                    groups: groupProvider.groups,
                    selectedGroup: groupProvider.selectedGroup,
                    isPersonalMode: false,
                    onGroupSelected: (group) {
                      groupProvider.selectGroup(group);
                      _closeSidebar();
                    },
                    onCreateGroup: () {
                      _closeSidebar();
                      _navigateToCreateGroup();
                    },
                    currentUserId: groupProvider.currentUserId,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      // ==== PERUBAHAN PADA FLOATING ACTION BUTTON DIMULAI DI SINI ====
      floatingActionButton: groupProvider.selectedGroup != null
          ? AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: _isSidebarOpen ? 0.0 : 1.0,
              child: IgnorePointer(
                ignoring: _isSidebarOpen,
                child: FloatingActionButton(
                  onPressed: () =>
                      _showInviteMemberDialog(groupProvider.selectedGroup!.id),
                  backgroundColor:
                      isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/add_person-icon.svg',
                    width: 28,
                    height: 28,
                    colorFilter:
                        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
              ),
            )
          : null,
      // ==== AKHIR DARI PERUBAHAN ====
      
      bottomNavigationBar: AnimatedBottomNavBar(
        currentIndex: _currentIndex,
        navbarAnimation: _navbarAnimation,
      ),
    ),
  );
}

  Widget _buildGroupContent() {
    final groupProvider =
        Provider.of<GroupSelectionProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildGroupSelector(),
        ),
        SizedBox(
          height: 650,
          child: groupProvider.selectedGroup != null
              ? _buildMembersList(groupProvider.selectedGroup!.id)
              : const Center(child: Text('Open the sidebar to select a group')),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
      {required Color textColor, required Color subTextColor}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.groups_3_outlined,
            size: 72,
            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'You don\'t have a group yet',
            style: TextStyle(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new group or accept an invitation to start collaborating on schedules.',
            style: TextStyle(
              color: subTextColor,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final groupProvider =
        Provider.of<GroupSelectionProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF222B45);

    return SizedBox(
      width: 148.0,
      height: 50.0,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 4),
              blurRadius: 6,
            ),
          ],
        ),
        child: InkWell(
          onTap: _toggleSidebar,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17.0),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/calendar_selector-icon.svg',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    groupProvider.selectedGroup?.name ?? 'Select Group',
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        fontFamily: 'Arial'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMembersList(String groupId) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final cardBackgroundColor =
        isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: FutureBuilder<List<User>>(
          future: _loadGroupMembers(groupId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ));
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading members: ${snapshot.error}'),
                ),
              );
            }

            final members = snapshot.data ?? [];

            if (members.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No members in this group'),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 125.0),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  return _buildMemberCard(member);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMemberCard(User member) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final groupProvider =
        Provider.of<GroupSelectionProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    final Color secondaryColor = isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(
          color: secondaryColor,
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            ProfileAvatar(
              userId: member.id,
              userName: member.name,
              size: 48.0,
              showBorder: false,
            ),
            const SizedBox(width: 16),
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
            if (groupProvider.selectedGroup != null)
              FutureBuilder<bool>(
                future: _isUserAdmin(groupProvider.selectedGroup!.id),
                builder: (context, snapshot) {
                  final isAdmin = snapshot.data ?? false;

                  if (!isAdmin || member.id == groupProvider.currentUserId) {
                    return const SizedBox.shrink();
                  }

                  return CustomMenuButton(
                    onSelected: (value) {
                      if (!mounted) return;
                      if (value == 'remove') {
                        _showRemoveMemberDialog(member);
                      }
                    },
                    items: const [
                      CustomMenuItem(
                        value: 'remove',
                        text: 'Remove',
                        iconColor: Colors.red,
                        textColor: Colors.red,
                        svgPath: 'assets/icons/person_remove-icon.svg',
                      ),
                    ],
                    backgroundColor:
                        isDarkMode ? Colors.grey[800] : Colors.white,
                    child: const Icon(Icons.more_vert),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showRemoveMemberDialog(User member) {
  final theme = Theme.of(context);
  final isDarkMode = theme.brightness == Brightness.dark;

  // Mendefinisikan warna yang akan digunakan
  const primaryPurpleColor = Color(0xFF735BF2);
  const destructiveColor = Color(0xFFEA3C54); // Warna merah untuk tombol batal

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
        elevation: 10.0,
        title: const Text('Remove Member'),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        content: Text(
          'Are you sure you want to remove ${member.name} from this group?',
        ),
        contentTextStyle: TextStyle(
          fontSize: 16,
          color: isDarkMode
              ? Colors.white.withOpacity(0.8)
              : Colors.black.withOpacity(0.6),
          height: 1.5,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          // ==== GAYA TOMBOL DIUBAH SESUAI PERMINTAAN ====

          // Tombol Batal
          SizedBox(
            width: 106,
            height: 41,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: destructiveColor, // Warna merah
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                elevation: 0,
              ),
              child: const Text('Cancel',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),

          // Tombol Remove
          SizedBox(
            width: 106,
            height: 41,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _removeMember(member);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurpleColor, // Warna ungu primer
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                elevation: 0,
              ),
              child: const Text('Remove',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    },
  );
}

  Future<void> _removeMember(User member) async {
    final groupProvider =
        Provider.of<GroupSelectionProvider>(context, listen: false);
    if (groupProvider.selectedGroup == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final groupId = groupProvider.selectedGroup!.id;

    try {
      await GroupService.removeMemberFromGroup(
        groupId: groupId,
        userId: member.id,
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('${member.name} removed from group')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
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
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final themeProvider = Provider.of<ThemeProvider>(context);
            final isDarkMode = themeProvider.isDarkMode;
            final primaryColor =
                isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2196F3);

            return AlertDialog(
              contentPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              elevation: 0,
              content: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        color: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        width: double.infinity,
                        child: const Text(
                          'Create New Group',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      Container(
                        color:
                            isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Group Name*',
                                hintText: 'e.g., Project Phoenix Team',
                                border: OutlineInputBorder(),
                              ),
                              maxLength: 50,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description (Optional)',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                              maxLength: 200,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: isSaving
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                          final name =
                                              nameController.text.trim();
                                          if (name.isEmpty) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'Group name is required')),
                                            );
                                            return;
                                          }

                                          setState(() => isSaving = true);

                                          final navigator =
                                              Navigator.of(dialogContext);
                                          final scaffoldMessenger =
                                              ScaffoldMessenger.of(context);
                                          final groupProvider = Provider.of<
                                                  GroupSelectionProvider>(
                                              context,
                                              listen: false);

                                          try {
                                            await GroupService.createGroup(
                                              name: name,
                                              description:
                                                  descriptionController.text
                                                      .trim(),
                                            );

                                            if (mounted) {
                                              await groupProvider
                                                  .refreshGroups();
                                              navigator.pop();
                                              scaffoldMessenger.showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Group created successfully!'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              scaffoldMessenger.showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Failed to create group: ${e.toString()}')),
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
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Text('Create'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}