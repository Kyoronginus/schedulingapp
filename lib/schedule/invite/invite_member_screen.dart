import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:provider/provider.dart';
import 'invite_member_service.dart'; // Import the service
import '../../widgets/custom_app_bar.dart';
import '../../dynamo/group_service.dart';
import '../../theme/theme_provider.dart';

class InviteMemberScreen extends StatefulWidget {
  final String groupId;
  const InviteMemberScreen({required this.groupId, super.key});

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final _emailController = TextEditingController();
  bool _isAdmin = false;
  final InviteMemberService _inviteMemberService =
      InviteMemberService(); // Create an instance of the service

  void _inviteMember() async {
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter an email')),
        );
      }
      return;
    }

    try {
      // Get current user's email to prevent self-invitation
      final userAttributes = await Amplify.Auth.fetchUserAttributes();
      final currentUserEmail = userAttributes
          .firstWhere((attr) => attr.userAttributeKey == CognitoUserAttributeKey.email)
          .value
          .toLowerCase();

      // Check if user is trying to invite themselves
      if (email == currentUserEmail) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You cannot invite yourself to the group'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Get current group members to check for duplicates
      final groupMembers = await GroupService.getGroupMembers(widget.groupId);

      // Check if email already exists in the group
      final emailExists = groupMembers.any((member) =>
          member.email.toLowerCase() == email);

      if (emailExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This user is already a member of the group'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Use the service to find the user by email
      final user = await _inviteMemberService.findUserByEmail(email);
      if (user == null) {
        throw Exception('User not found');
      }

      // Check if user already has a pending invitation
      final hasPendingInvitation = await GroupService.hasPendingInvitation(
        groupId: widget.groupId,
        userId: user.id,
      );

      if (hasPendingInvitation) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This user already has a pending invitation to the group'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Create a group invitation instead of directly adding to group
      await GroupService.createGroupInvitation(
        groupId: widget.groupId,
        invitedUserId: user.id,
        isAdmin: _isAdmin,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation sent successfully! The user will receive a notification.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invitation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const CustomAppBar(
        title: Text('Invite Member'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'Email of the member',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                ),
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode ? const Color(0xFF4CAF50) : theme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _isAdmin,
                  onChanged: (value) {
                    setState(() {
                      _isAdmin = value ?? false;
                    });
                  },
                  activeColor: isDarkMode ? const Color(0xFF4CAF50) : theme.primaryColor,
                  checkColor: Colors.white,
                ),
                Text(
                  'Give schedule authority',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _inviteMember,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? const Color(0xFF4CAF50) : theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Invite'),
            ),
          ],
        ),
      ),
    );
  }
}
