import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:provider/provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../utils/utils_functions.dart';
import '../../auth/logout.dart';
import '../../routes/app_routes.dart';
import '../../theme/theme_provider.dart';
import '../../services/profile_image_service.dart';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  final String email;

  const ProfileScreen({Key? key, required this.email}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showChangePassword = false;
  bool _showPassword = false;
  String? _password;

  String? _userName;
  String? _userEmail;
  String? _authProvider;
  int _currentIndex = 2; // Updated to match new navigation index

  ImageProvider? _profileImage;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final image = await ProfileImageService.getProfileImage();
    if (image != null) {
      setState(() {
        _profileImage = image;
      });
    }
  }

  Future<void> _fetchUserProfile() async {
    setState(() => _isLoading = true);
    try {
      // Get current user
      final user = await Amplify.Auth.getCurrentUser();

      // Fetch user attributes
      final attributes = await Amplify.Auth.fetchUserAttributes();
      final emailAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey == CognitoUserAttributeKey.email,
        orElse: () => AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.email,
          value: widget.email,
        ),
      );

      // Try to determine auth provider
      try {
        final session = await Amplify.Auth.fetchAuthSession(
          options: CognitoSessionOptions(getAWSCredentials: true),
        ) as CognitoAuthSession;

        final identityId = session.identityId;
        if (identityId != null) {
          if (identityId.contains('google')) {
            _authProvider = 'Google';
          } else if (identityId.contains('facebook')) {
            _authProvider = 'Facebook';
          } else {
            _authProvider = 'Email';
          }
        } else {
          _authProvider = 'Email';
        }
      } catch (e) {
        print('Error determining auth provider: $e');
        _authProvider = 'Email';
      }

      // Fetch user data from API
      final request = GraphQLRequest<String>(
        document: '''
          query GetUser(\$id: ID!) {
            getUser(id: \$id) {
              id
              name
              email
            }
          }
        ''',
        variables: {
          'id': user.userId,
        },
      );

      final response = await Amplify.API.query(request: request).response;
      final userData = response.data != null
          ? jsonDecode(response.data!)
          : null;

      if (userData != null && userData['getUser'] != null) {
        setState(() {
          _userName = userData['getUser']['name'];
          _userEmail = emailAttr.value;
          _nameController.text = _userName ?? '';
        });
      }

      // If using email authentication, try to get the password
      if (_authProvider == 'Email') {
        try {
          // For security reasons, we can't actually retrieve the real password
          // from Cognito. Instead, we'll use a placeholder that can be toggled
          // for demonstration purposes
          setState(() {
            _password = "Password123"; // This is just a placeholder
          });
        } catch (e) {
          print('Error retrieving password: $e');
        }
      }
    } catch (e) {
      print('Error fetching profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = await Amplify.Auth.getCurrentUser();
      final newName = _nameController.text.trim();

      if (newName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your name')),
        );
        return;
      }

      final request = GraphQLRequest<String>(
        document: '''
          mutation UpdateUser(\$input: UpdateUserInput!) {
            updateUser(input: \$input) {
              id
              name
              email
            }
          }
        ''',
        variables: {
          'input': {
            'id': user.userId,
            'name': newName,
          }
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      if (response.data != null) {
        setState(() => _userName = newName);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all password fields')),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Amplify.Auth.updatePassword(
        oldPassword: _passwordController.text,
        newPassword: _newPasswordController.text,
      );

      // Update the stored password
      setState(() {
        _password = _newPasswordController.text;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _showChangePassword = false;
        _passwordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changeProfilePicture() async {
    final file = await ProfileImageService.showImagePickerDialog(context);
    if (file != null) {
      setState(() {
        _profileImage = FileImage(file);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: Text(
          "Profile",
          style: TextStyle(
            color: isDarkMode ? const Color(0xFF4CAF50) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : null,
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(
            color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
          ))
        : SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // Profile header with avatar and info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Profile avatar with initials
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                                backgroundImage: _profileImage,
                                child: _profileImage == null ? Text(
                                  _getInitials(),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ) : null,
                              ),
                              // Add photo button
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: _changeProfilePicture,
                                  child: Container(
                                    height: 30,
                                    width: 30,
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: theme.cardTheme.color ?? Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // User name
                          Text(
                            _userName ?? "User",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // User email
                          Text(
                            _userEmail ?? widget.email,
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Settings container
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Account platform
                          _buildSettingItemNew(
                            icon: Icons.account_circle_outlined,
                            iconColor: isDarkMode ? const Color(0xFF4CAF50) : Colors.grey,
                            title: "Account Platform",
                            trailing: SizedBox(
                              width: 80, // Fixed width for the trailing widget
                              child: Text(
                                _authProvider ?? "Email",
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            showDivider: true,
                          ),

                          // Password field (only for email accounts)
                          if (_authProvider == 'Email')
                            _buildSettingItemNew(
                              icon: Icons.lock_outline,
                              iconColor: isDarkMode ? const Color(0xFF4CAF50) : Colors.grey,
                              title: "Password",
                              trailing: SizedBox(
                                width: 100, // Fixed width for the trailing widget
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _showPassword ? (_password ?? "Password") : "••••••••",
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color,
                                        letterSpacing: _showPassword ? 0 : 2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _showPassword = !_showPassword;
                                        });
                                      },
                                      child: Icon(
                                        _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: isDarkMode ? const Color(0xFF4CAF50) : Colors.grey,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              showDivider: true,
                            ),

                          // Change password option (only for email accounts)
                          if (_authProvider == 'Email')
                            _buildSettingItemNew(
                              icon: Icons.info_outline,
                              iconColor: isDarkMode ? const Color(0xFF4CAF50) : Colors.grey,
                              title: "Change Password",
                              trailing: Icon(
                                Icons.chevron_right,
                                color: isDarkMode ? const Color(0xFF4CAF50) : Colors.grey,
                              ),
                              onTap: () {
                                setState(() {
                                  _showChangePassword = !_showChangePassword;
                                });

                                if (_showChangePassword) {
                                  // Show change password dialog
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Change Password'),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: _passwordController,
                                              obscureText: _obscurePassword,
                                              decoration: const InputDecoration(
                                                labelText: "Current Password",
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            TextField(
                                              controller: _newPasswordController,
                                              obscureText: _obscurePassword,
                                              decoration: const InputDecoration(
                                                labelText: "New Password",
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            TextField(
                                              controller: _confirmPasswordController,
                                              obscureText: _obscurePassword,
                                              decoration: const InputDecoration(
                                                labelText: "Confirm New Password",
                                                border: OutlineInputBorder(),
                                              ),
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
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _changePassword();
                                          },
                                          child: const Text('Change Password'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              showDivider: true,
                            ),

                          // Dark mode toggle
                          _buildSettingItemNew(
                            icon: Icons.dark_mode_outlined,
                            iconColor: isDarkMode ? const Color(0xFF4CAF50) : Colors.grey,
                            title: "Dark Mode",
                            trailing: Switch(
                              value: isDarkMode,
                              onChanged: (value) {
                                themeProvider.toggleTheme();
                              },
                              activeColor: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                            ),
                            showDivider: true,
                          ),

                          // Sign out button
                          _buildSettingItemNew(
                            icon: Icons.logout,
                            iconColor: Colors.redAccent,
                            title: "Sign Out",
                            titleColor: Colors.redAccent,
                            trailing: const SizedBox.shrink(),
                            onTap: () => logout(context),
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
      bottomNavigationBar: BottomNavBar(currentIndex: _currentIndex),
    );
  }

  // Helper method to get user initials
  String _getInitials() {
    if (_userName == null || _userName!.isEmpty) {
      return "MS"; // Default initials
    }

    final nameParts = _userName!.split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}';
    } else {
      return nameParts[0].length > 1 ? nameParts[0].substring(0, 2) : nameParts[0];
    }
  }

  // New setting item builder for the updated design
  Widget _buildSettingItemNew({
    required IconData icon,
    required Color iconColor,
    required String title,
    Color titleColor = Colors.black87,
    required Widget trailing,
    VoidCallback? onTap,
    required bool showDivider,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: iconColor),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: titleColor,
            ),
          ),
          trailing: trailing,
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 20, endIndent: 20),
      ],
    );
  }
}
