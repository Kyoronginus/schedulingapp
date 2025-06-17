import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../services/store_profile_service.dart';
import '../services/refresh_service.dart';

class ProfileAvatar extends StatefulWidget {
  final String userId;
  final String userName;
  final double size;
  final bool showBorder;
  final Color? borderColor;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    required this.userId,
    required this.userName,
    this.size = 50.0,
    this.showBorder = false,
    this.borderColor,
    this.onTap,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  String? _profilePictureUrl;
  bool _isLoading = true;
  StreamSubscription<void>? _profileChangeSubscription;

  @override
  void initState() {
    super.initState();
    _loadProfilePicture();

    // Listen for profile changes to refresh the avatar
    _profileChangeSubscription = RefreshService().profileChanges.listen((_) {
      if (mounted) {
        _loadProfilePicture();
      }
    });
  }

  @override
  void dispose() {
    _profileChangeSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadProfilePicture();
    }
  }

  Future<void> _loadProfilePicture() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🖼️ ProfileAvatar: Loading profile picture for user ${widget.userId} (${widget.userName})');
      final url = await CentralizedProfileImageService.getProfilePictureUrl(widget.userId);

      if (mounted) {
        // Clear cached image for this user to force refresh
        if (_profilePictureUrl != null) {
          await CachedNetworkImage.evictFromCache(_profilePictureUrl!);
        }

        setState(() {
          // Add timestamp to URL to bust cache when refreshing
          _profilePictureUrl = url != null ? '$url?t=${DateTime.now().millisecondsSinceEpoch}' : null;
          _isLoading = false;
        });

        if (_profilePictureUrl != null) {
          debugPrint('✅ ProfileAvatar: Successfully loaded profile picture URL');
        } else {
          debugPrint('⚠️ ProfileAvatar: No profile picture URL found, will show initials');
        }
      }
    } catch (e) {
      debugPrint('❌ ProfileAvatar: Error loading profile picture: $e');
      if (mounted) {
        setState(() {
          _profilePictureUrl = null;
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildInitialsAvatar() {
    final initials = CentralizedProfileImageService.getUserInitials(widget.userName);
    
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getInitialsBackgroundColor(widget.userName),
        border: widget.showBorder
            ? Border.all(
                color: widget.borderColor ?? Colors.white,
                width: 2.0,
              )
            : null,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: widget.size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: widget.showBorder
            ? Border.all(
                color: widget.borderColor ?? Colors.white,
                width: 2.0,
              )
            : null,
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: _profilePictureUrl!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: widget.size,
            height: widget.size,
            color: Colors.grey[300],
            child: Center(
              child: SizedBox(
                width: widget.size * 0.3,
                height: widget.size * 0.3,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.grey[600]!,
                  ),
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) {
            debugPrint('❌ CachedNetworkImage error for URL $url: $error');
            return _buildInitialsAvatar();
          },
        ),
      ),
    );
  }

  Widget _buildLoadingAvatar() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
        border: widget.showBorder
            ? Border.all(
                color: widget.borderColor ?? Colors.white,
                width: 2.0,
              )
            : null,
      ),
      child: Center(
        child: SizedBox(
          width: widget.size * 0.3,
          height: widget.size * 0.3,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.grey[600]!,
            ),
          ),
        ),
      ),
    );
  }

  Color _getInitialsBackgroundColor(String name) {
    // Generate a consistent color based on the user's name
    final colors = [
      Colors.blue[600]!,
      Colors.green[600]!,
      Colors.orange[600]!,
      Colors.purple[600]!,
      Colors.red[600]!,
      Colors.teal[600]!,
      Colors.indigo[600]!,
      Colors.pink[600]!,
    ];

    final hash = name.hashCode;
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar;

    if (_isLoading) {
      avatar = _buildLoadingAvatar();
    } else if (_profilePictureUrl != null && _profilePictureUrl!.isNotEmpty) {
      avatar = _buildProfileImage();
    } else {
      avatar = _buildInitialsAvatar();
    }

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}

// Specialized avatar for the current user with upload functionality
class CurrentUserProfileAvatar extends StatefulWidget {
  final String userId;
  final String userName;
  final double size;
  final bool showBorder;
  final Color? borderColor;
  final VoidCallback? onImageChanged;

  const CurrentUserProfileAvatar({
    super.key,
    required this.userId,
    required this.userName,
    this.size = 50.0,
    this.showBorder = false,
    this.borderColor,
    this.onImageChanged,
  });

  @override
  State<CurrentUserProfileAvatar> createState() => _CurrentUserProfileAvatarState();
}

class _CurrentUserProfileAvatarState extends State<CurrentUserProfileAvatar> {
  bool _isUploading = false;

  Future<void> _handleImageUpload() async {
    try {
      setState(() {
        _isUploading = true;
      });

      // This would typically open an image picker
      // For now, we'll just show a placeholder implementation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image upload functionality will be implemented in the profile screen'),
        ),
      );

      if (widget.onImageChanged != null) {
        widget.onImageChanged!();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ProfileAvatar(
          userId: widget.userId,
          userName: widget.userName,
          size: widget.size,
          showBorder: widget.showBorder,
          borderColor: widget.borderColor,
          onTap: _handleImageUpload,
        ),
        if (_isUploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.5),
              ),
              child: Center(
                child: SizedBox(
                  width: widget.size * 0.3,
                  height: widget.size * 0.3,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: widget.size * 0.3,
            height: widget.size * 0.3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Icon(
              Icons.camera_alt,
              size: widget.size * 0.15,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
