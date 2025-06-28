// File: lib/schedule/invite/invite_member_dialog.dart

import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:provider/provider.dart';
import 'invite_member_service.dart';
import '../../dynamo/group_service.dart';
import '../../theme/theme_provider.dart';

class InviteMemberDialog extends StatefulWidget {
  final String groupId;
  const InviteMemberDialog({required this.groupId, super.key});

  @override
  State<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<InviteMemberDialog> {
  // DIUBAH: Menambahkan GlobalKey untuk Form
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isAdmin = false;
  bool _isInviting = false;
  final InviteMemberService _inviteMemberService = InviteMemberService();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _inviteMember() async {
    // Validasi sekarang ditangani oleh Form, jadi pengecekan email kosong dihapus dari sini.
    setState(() => _isInviting = true);

    final email = _emailController.text.trim().toLowerCase();

    try {
      final userAttributes = await Amplify.Auth.fetchUserAttributes();
      final currentUserEmail = userAttributes
          .firstWhere(
              (attr) => attr.userAttributeKey == CognitoUserAttributeKey.email)
          .value
          .toLowerCase();

      if (email == currentUserEmail) {
        throw Exception('You cannot invite yourself');
      }

      final groupMembers = await GroupService.getGroupMembers(widget.groupId);
      final emailExists =
          groupMembers.any((member) => member.email.toLowerCase() == email);

      if (emailExists) {
        throw Exception('This user is already a member');
      }

      final user = await _inviteMemberService.findUserByEmail(email);
      if (user == null) {
        throw Exception('User with this email not found');
      }

      final hasPendingInvitation = await GroupService.hasPendingInvitation(
        groupId: widget.groupId,
        userId: user.id,
      );

      if (hasPendingInvitation) {
        throw Exception('This user already has a pending invitation');
      }

      await GroupService.createGroupInvitation(
        groupId: widget.groupId,
        invitedUserId: user.id,
        isAdmin: _isAdmin,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInviting = false);
      }
    }
  }

  @override
 Widget build(BuildContext context) {
  final themeProvider = Provider.of<ThemeProvider>(context);
  final isDarkMode = themeProvider.isDarkMode;

  final primaryColor = isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF735BF2);
  final destructiveColor = const Color(0xFFEA3C54);
  final textColor = isDarkMode ? Colors.white : Colors.black87;
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
      borderRadius: BorderRadius.circular(16.0),
    ),
    backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
    title: const Text('Invite Member', textAlign: TextAlign.center),
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: isDarkMode ? Colors.white : Colors.black87,
    ),
    
    // DIUBAH: Padding konten disesuaikan
    contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
    
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Enter the email of the person you want to invite to this group.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            // DIUBAH: Jarak antara judul dan field diperbesar
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              style: TextStyle(color: textColor),
              decoration: inputDecorationTheme.copyWith(
                labelText: 'Member\'s Email',
                hintText: 'Enter member\'s email',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _isAdmin,
                  onChanged: (value) {
                    setState(() {
                      _isAdmin = value ?? false;
                    });
                  },
                  activeColor: primaryColor,
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAdmin = !_isAdmin;
                    });
                  },
                  child: const Text('Give schedule authority'),
                ),
              ],
            ),
            // DIUBAH: Jarak antara field dan tombol diperkecil
            const SizedBox(height: 16),

            // DIUBAH: Tombol dipindahkan ke sini dari 'actions'
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tombol Cancel
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isInviting ? null : () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: destructiveColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 80),
                // Tombol Invite
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _inviteMember();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                       padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isInviting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Invite'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    // DIUBAH: actions dikosongkan karena sudah dipindah ke dalam content
    actions: const [],
  );
 }
}