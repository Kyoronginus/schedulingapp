import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
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
  
  // Pick image from gallery or camera
  static Future<File?> pickImage(ImageSource source) async {
    final userId = await _getCurrentUserId();
    if (userId == null) return null;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      // Save image to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(pickedFile.path)}';
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');

      // Save path to SharedPreferences with user-specific key
      final prefs = await SharedPreferences.getInstance();
      final userSpecificKey = '${userId}_$_profileImagePathKey';
      await prefs.setString(userSpecificKey, savedImage.path);

      return savedImage;
    }

    return null;
  }
  
  // Show image picker dialog
  static Future<File?> showImagePickerDialog(BuildContext context) async {
    File? image;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Profile Picture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () async {
                Navigator.pop(context);
                image = await pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(context);
                image = await pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    return image;
  }
  
  // Delete profile image
  static Future<void> deleteProfileImage() async {
    final userId = await _getCurrentUserId();
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final userSpecificKey = '${userId}_$_profileImagePathKey';
    final imagePath = prefs.getString(userSpecificKey);

    if (imagePath != null) {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
      await prefs.remove(userSpecificKey);
    }
  }

  /// Clear all profile images for current user (for session cleanup)
  static Future<void> clearCurrentUserProfileImages() async {
    final userId = await _getCurrentUserId();
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userSpecificKey = '${userId}_$_profileImagePathKey';
      final imagePath = prefs.getString(userSpecificKey);

      // Delete the image file
      if (imagePath != null) {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Remove from preferences
      await prefs.remove(userSpecificKey);

      // Also clean up any old profile images for this user
      final appDir = await getApplicationDocumentsDirectory();
      final directory = Directory(appDir.path);
      final files = directory.listSync();

      for (final file in files) {
        if (file is File && file.path.contains('profile_${userId}_')) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error clearing user profile images: $e');
    }
  }
}
