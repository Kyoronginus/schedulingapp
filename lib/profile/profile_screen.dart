import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:provider/provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../utils/utils_functions.dart';
import '../auth/logout.dart';
import '../auth/password/change_password_dialog.dart';
import '../theme/theme_provider.dart';
import '../services/store_profile_service.dart';
import '../services/refresh_service.dart';
import '../widgets/profile_avatar.dart';
import '../auth/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import '../services/secure_storage_service.dart';
import '../services/auth_method_service.dart';

class ProfileScreen extends StatefulWidget {
  final String email;

  const ProfileScreen({super.key, required this.email});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;
  String? _storedPassword; // The actual password from secure storage

  String? _userName;
  String? _userEmail;
  String? _authProvider;
  String? _userId;
  final int _currentIndex = 3;

  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }
  void _showChangePasswordDialog() async {
    // `showDialog` adalah fungsi bawaan Flutter untuk menampilkan modal
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User harus menekan tombol untuk menutup
      builder: (BuildContext context) {
        // Panggil widget ChangePasswordScreen yang sudah kita ubah
        return const ChangePasswordDialog(); 
      },
    );

    // Kode ini akan berjalan SETELAH dialog ditutup
    if (result == true) {
      // Jika password berhasil diubah, kita refresh data password di halaman profil
      debugPrint('🔄 Password changed successfully, refreshing stored password...');
      await _refreshStoredPassword();
    }
  }
  Future<void> _fetchUserProfile() async {
    setState(() => _isLoading = true);
    try {
      // Get current user
      final user = await Amplify.Auth.getCurrentUser();
      _userId = user.userId;

      // Fetch user attributes
      final attributes = await Amplify.Auth.fetchUserAttributes();
      final emailAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey == CognitoUserAttributeKey.email,
        orElse: () => AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.email,
          value: widget.email,
        ),
      );

      // Initialize auth provider to default
      _authProvider = 'Email';

      // Fetch user data from API using AuthService
      try {
        final userData = await ensureUserExists();
        debugPrint('✅ ProfileScreen: Got user data: ${userData.name}');

        // Get authentication method from user data
        final authMethodDisplayName = AuthMethodService.getAuthMethodDisplayName(userData.primaryAuthMethod);

        // Check if widget is still mounted before calling setState
        if (!mounted) return;
        setState(() {
          _userName = userData.name;
          _userEmail = userData.email;
          _authProvider = authMethodDisplayName;
          _nameController.text = _userName ?? '';
        });
      } catch (e) {
        debugPrint('⚠️ ProfileScreen: Could not get/create user data: $e');
        // Use email from Cognito if user not found in database
        // Try to detect auth method as fallback
        try {
          final currentAuthMethod = await AuthMethodService.detectCurrentAuthMethod();
          final authMethodDisplayName = AuthMethodService.getAuthMethodDisplayName(currentAuthMethod);

          // Check if widget is still mounted before calling setState
          if (!mounted) return;
          setState(() {
            _userEmail = emailAttr.value;
            _authProvider = authMethodDisplayName;
            _nameController.text = '';
          });
        } catch (authError) {
          debugPrint('⚠️ ProfileScreen: Could not detect auth method: $authError');
          // Check if widget is still mounted before calling setState
          if (!mounted) return;
          setState(() {
            _userEmail = emailAttr.value;
            _authProvider = 'Email'; // Default fallback
            _nameController.text = '';
          });
        }
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
    if (_userId == null) return;

    try {
      setState(() {
        _isUploadingImage = true;
      });

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 80,
      );

      if (image != null) {
        final url = await CentralizedProfileImageService.uploadProfilePicture(image, _userId!);

        if (url != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Trigger a rebuild to refresh the avatar
          setState(() {});

          // Notify other screens to refresh
          RefreshService().notifyProfileChange();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload profile picture'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(
            color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
          ))
        : SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchUserProfile,
              color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                    const SizedBox(height: 56),
                    // Profile header with avatar and info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white, // Menggunakan warna kartu dari tema (putih di light mode)
                        borderRadius: BorderRadius.circular(16), // Membuat sudut melengkung
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha:0.1), // Bayangan yang sangat lembut
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 4), // Posisi bayangan (sedikit ke bawah)
                          ),
                        ],
                                
                        ),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          // Profile avatar with upload functionality
                          Stack(
                            children: [
                              if (_userId != null)
                                ProfileAvatar(
                                  userId: _userId!,
                                  userName: _userName ?? "User",
                                  size: 100.0,
                                  showBorder: true,
                                  borderColor: theme.cardTheme.color ?? Colors.white,
                                )
                              else
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDarkMode ? const Color(0xFF4CAF50) : primaryColor,
                                    border: Border.all(color: theme.cardTheme.color ?? Colors.white, width: 2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _getInitials(),
                                      style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              // Add photo button with loading state
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: _isUploadingImage ? null : _changeProfilePicture,
                                  child: Container(
                                    height: 30,
                                    width: 30,
                                    decoration: BoxDecoration(
                                      color: _isUploadingImage
                                        ? Colors.grey
                                        : (isDarkMode ? const Color(0xFF4CAF50) : primaryColor),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: theme.cardTheme.color ?? Colors.white, width: 2),
                                    ),
                                    child: _isUploadingImage
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
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
                          const SizedBox(height:8),
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

                          // Password field (show for all accounts but with different content)
                          _buildSettingItemNew(
                            icon: Icons.lock_outline,
                            iconColor: isDarkMode ? const Color(0xFF4CAF50) : Colors.grey,
                            title: "Password",
                            trailing: SizedBox(
                              width: 100, // Fixed width for the trailing widget
                              child: _authProvider == 'Email'
                                ? Row(
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
                                  )
                                : Text(
                                    "N/A",
                                    style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                            ),
                            showDivider: true,
                          ),

                          // Change password option (show for all but disable for OAuth)
                          _buildSettingItemNew(
                            icon: Icons.info_outline,
                            iconColor: _authProvider == 'Email'
                              ? (isDarkMode ? const Color(0xFF4CAF50) : Colors.grey)
                              : Colors.grey.withValues(alpha: 0.5),
                            title: "Change Password",
                            titleColor: _authProvider == 'Email'
                              ? (theme.textTheme.bodyLarge?.color ?? Colors.black87)
                              : Colors.grey.withValues(alpha: 0.5),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: _authProvider == 'Email'
                                ? (isDarkMode ? const Color(0xFF4CAF50) : Colors.grey)
                                : Colors.grey.withValues(alpha: 0.5),
                              size: 24, // Explicit size for consistency
                            ),
                            onTap: _authProvider == 'Email' ? _showChangePasswordDialog : null, // Disable for OAuth users
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
