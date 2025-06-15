import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

class ProfileImageService {
  static const String _profileImagePathKey = 'profile_image_path';

  /// Get current user ID for user-specific storage
  static Future<String?> _getCurrentUserId() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      return user.userId;
    } catch (e) {
      return null;
    }
  }

  
  // Get profile image if it exists
  static Future<ImageProvider?> getProfileImage() async {
    final userId = await _getCurrentUserId();
    if (userId == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final userSpecificKey = '${userId}_$_profileImagePathKey';
    final imagePath = prefs.getString(userSpecificKey);

    if (imagePath != null) {
      final file = File(imagePath);
      if (await file.exists()) {
        return FileImage(file);
      }
    }

    return null;
  }

  // Save profile image path to SharedPreferences with user-specific key
  static Future<void> saveProfileImagePath(String imagePath) async {
    final userId = await _getCurrentUserId();
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final userSpecificKey = '${userId}_$_profileImagePathKey';
    await prefs.setString(userSpecificKey, imagePath);
  }

  // Clear profile image path from SharedPreferences for current user
  static Future<void> clearProfileImagePath() async {
    final userId = await _getCurrentUserId();
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final userSpecificKey = '${userId}_$_profileImagePathKey';
    await prefs.remove(userSpecificKey);
  }

  // Pick image from gallery or camera
  static Future<XFile?> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    return await picker.pickImage(source: source);
  }

  // Clear all profile images for current user (used on logout)
  static Future<void> clearCurrentUserProfileImages() async {
    await clearProfileImagePath();
  }

  // Get user initials for fallback display
  static String getUserInitials(String name) {
    if (name.isEmpty) return '?';

    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    } else {
      return '${words[0][0]}${words[words.length - 1][0]}'.toUpperCase();
    }
  }
}
