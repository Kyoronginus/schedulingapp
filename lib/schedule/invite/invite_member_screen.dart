import 'package:flutter/material.dart';
import 'invite_member_service.dart'; // Import the service
import '../../widgets/custom_app_bar.dart';
import '../../dynamo/group_service.dart';

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
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter an email')),
        );
      }
      return;
    }

    try {
      // Use the service to find the user by email
      final user = await _inviteMemberService.findUserByEmail(email);
      if (user == null) {
        throw Exception('User not found');
      }

      // Create a group invitation instead of directly adding to group
      await GroupService.createGroupInvitation(
        groupId: widget.groupId,
        invitedUserId: user.id,
        isAdmin: _isAdmin,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent successfully! The user will receive a notification.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send invitation: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Invite Member'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration:
                  const InputDecoration(labelText: 'Email of the member'),
            ),
            Row(
              children: [
                Checkbox(
                  value: _isAdmin,
                  onChanged: (value) {
                    setState(() {
                      _isAdmin = value ?? false;
                    });
                  },
                ),
                const Text('Give schedule authority'),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _inviteMember,
              child: const Text('Invite'),
            ),
          ],
        ),
      ),
    );
  }
}
