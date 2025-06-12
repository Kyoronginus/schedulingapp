import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import '../utils/utils_functions.dart';
import '../auth/logout.dart';

import '../theme/theme_provider.dart';
import '../services/profile_image_service.dart';
import '../auth/auth_service.dart';
import '../routes/app_routes.dart';
import '../services/secure_storage_service.dart';

class ProfileScreen extends StatefulWidget {
  final String email;

  const ProfileScreen({Key? key, required this.email}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;
  String? _storedPassword; // The actual password from secure storage

  String? _userName;
  String? _userEmail;
  String? _authProvider;
  int _currentIndex = 3; // Updated to reflect new navigation order

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
      // Check if widget is still mounted before calling setState
      if (!mounted) return;
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
          options: FetchAuthSessionOptions(),
        ) as CognitoAuthSession;

        final identityIdResult = session.identityIdResult;
        final id = identityIdResult.value;
        if (id.contains('google')) {
          _authProvider = 'Google';
        } else if (id.contains('facebook')) {
          _authProvider = 'Facebook';
        } else {
          _authProvider = 'Email';
        }
      } catch (e) {
        debugPrint('Error determining auth provider: $e');
        _authProvider = 'Email';
      }

      // Fetch user data from API using AuthService
      try {
        final userData = await ensureUserExists();
        debugPrint('✅ ProfileScreen: Got user data: ${userData.name}');

        // Check if widget is still mounted before calling setState
        if (!mounted) return;
        setState(() {
          _userName = userData.name;
          _userEmail = userData.email;
          _nameController.text = _userName ?? '';
        });
      } catch (e) {
        debugPrint('⚠️ ProfileScreen: Could not get/create user data: $e');
        // Use email from Cognito if user not found in database

        // Check if widget is still mounted before calling setState
        if (!mounted) return;
        setState(() {
          _userEmail = emailAttr.value;
          _nameController.text = '';
        });
      }

      // Fetch stored password after auth provider is determined
      await _fetchStoredPassword();
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }

    // Check if widget is still mounted before calling setState
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    // Check if widget is still mounted before calling setState
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = await Amplify.Auth.getCurrentUser();
      final newName = _nameController.text.trim();

      if (newName.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter your name')),
          );
        }
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
        // Check if widget is still mounted before calling setState
        if (!mounted) return;
        setState(() => _userName = newName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }

    // Check if widget is still mounted before calling setState
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStoredPassword() async {
    if (_authProvider == 'Email') {
      try {
        final storedPassword = await SecureStorageService.getPassword();
        debugPrint('🔍 Initial password fetch: ${storedPassword != null ? "Found password" : "No password found"}');
        setState(() {
          _storedPassword = storedPassword; // Store the actual password (can be null)
        });
      } catch (e) {
        debugPrint('❌ Error retrieving password: $e');
        setState(() {
          _storedPassword = null; // No password available
        });
      }
    } else {
      debugPrint('🔍 Not an email account, skipping password fetch');
      setState(() {
        _storedPassword = null; // No password for social logins
      });
    }
  }

  Future<void> _refreshStoredPassword() async {
    debugPrint('� Refreshing stored password...');
    await _fetchStoredPassword();
  }

  Future<void> _changeProfilePicture() async {
    final file = await ProfileImageService.showImagePickerDialog(context);
    if (file != null) {
      // Check if widget is still mounted before calling setState
      if (!mounted) return;
      setState(() {
        _profileImage = FileImage(file);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
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
                            color: Colors.black.withValues(alpha:0.05),
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
                            color: Colors.black.withValues(alpha:0.05),
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
                                    Expanded(
                                      child: Text(
                                        _showPassword
                                          ? (_storedPassword ?? "Password not available")
                                          : "••••••••",
                                        style: TextStyle(
                                          color: theme.textTheme.bodyMedium?.color,
                                          letterSpacing: _showPassword ? 0 : 2,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 24, // Fixed width to match chevron_right icon
                                      height: 24, // Fixed height to match chevron_right icon
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _showPassword = !_showPassword;
                                          });
                                        },
                                        child: Icon(
                                          _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          color: isDarkMode ? const Color(0xFF4CAF50) : Colors.grey,
                                          size: 24, // Match the size of chevron_right
                                        ),
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
                                size: 24, // Explicit size for consistency
                              ),
                              onTap: () async {
                                // Navigate to change password screen and refresh password if changed
                                final result = await Navigator.pushNamed(context, AppRoutes.changePassword);
                                debugPrint('🔍 Change password result: $result');
                                if (result == true) {
                                  // Password was changed successfully, refresh the stored password
                                  debugPrint('🔄 Refreshing stored password...');
                                  await _refreshStoredPassword();
                                } else {
                                  debugPrint('⚠️ Password change was cancelled or failed');
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
