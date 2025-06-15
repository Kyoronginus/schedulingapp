import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/User.dart';

class CentralizedProfileImageService {
  static const String _s3KeyPrefix = 'profile-pictures/';

  /// Upload a profile picture to S3 and update the user's profile
  static Future<String?> uploadProfilePicture(XFile imageFile, String userId) async {
    try {
      // Generate S3 key for the user's profile picture
      final s3Key = '$_s3KeyPrefix$userId.jpg';

      // Read image file
      final imageBytes = await imageFile.readAsBytes();

      // Upload to S3 with public access level for group sharing
      await Amplify.Storage.uploadData(
        data: S3DataPayload.bytes(
          imageBytes,
          contentType: 'image/jpeg',
        ),
        key: s3Key,
        options: const StorageUploadDataOptions(
          accessLevel: StorageAccessLevel.guest,
        ),
      ).result;

      // Store the S3 key (not the signed URL) in the user's profile
      await _updateUserProfilePictureUrl(userId, s3Key);

      // Generate and return a fresh URL for immediate use
      final urlResult = await Amplify.Storage.getUrl(
        key: s3Key,
        options: const StorageGetUrlOptions(
          accessLevel: StorageAccessLevel.guest,
        ),
      ).result;

      return urlResult.url.toString();
    } catch (e) {
      safePrint('Error uploading profile picture: $e');
      return null;
    }
  }

  /// Get profile picture URL for a user (with caching)
  static Future<String?> getProfilePictureUrl(String userId) async {
    try {
      // Get S3 key from user's profile
      final user = await _getUserById(userId);
      String? s3Key = user?.profilePictureUrl;

      // If we have an S3 key, generate a fresh signed URL
      if (s3Key != null && s3Key.isNotEmpty) {
        // Check if the stored value is already a full URL (legacy data)
        if (s3Key.startsWith('http')) {
          // This is a legacy signed URL, extract the S3 key and update the user record
          final extractedKey = _extractS3KeyFromUrl(s3Key);
          if (extractedKey != null) {
            await _updateUserProfilePictureUrl(userId, extractedKey);
            s3Key = extractedKey;
          } else {
            // Can't extract key from URL, return null
            return null;
          }
        }

        // Generate fresh URL from S3 key
        final urlResult = await Amplify.Storage.getUrl(
          key: s3Key,
          options: const StorageGetUrlOptions(
            accessLevel: StorageAccessLevel.guest,
          ),
        ).result;

        return urlResult.url.toString();
      }

      return null;
    } catch (e) {
      safePrint('Error getting profile picture URL: $e');
      return null;
    }
  }

  /// Download and cache profile picture locally for offline access
  static Future<File?> getCachedProfilePicture(String userId) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cachedFile = File('${cacheDir.path}/profile_$userId.jpg');

      // Return cached file if it exists and is recent (less than 1 hour old)
      if (await cachedFile.exists()) {
        final lastModified = await cachedFile.lastModified();
        final now = DateTime.now();
        if (now.difference(lastModified).inHours < 1) {
          return cachedFile;
        }
      }

      // Download from S3
      final s3Key = '$_s3KeyPrefix$userId.jpg';
      final downloadResult = await Amplify.Storage.downloadData(
        key: s3Key,
        options: const StorageDownloadDataOptions(
          accessLevel: StorageAccessLevel.guest,
        ),
      ).result;

      // Save to cache
      await cachedFile.writeAsBytes(downloadResult.bytes);
      return cachedFile;
    } catch (e) {
      safePrint('Error downloading profile picture: $e');
      return null;
    }
  }

  /// Delete profile picture from S3 and update user profile
  static Future<bool> deleteProfilePicture(String userId) async {
    try {
      final s3Key = '$_s3KeyPrefix$userId.jpg';
      
      // Delete from S3
      await Amplify.Storage.remove(
        key: s3Key,
        options: const StorageRemoveOptions(
          accessLevel: StorageAccessLevel.guest,
        ),
      ).result;

      // Update user profile to remove URL
      await _updateUserProfilePictureUrl(userId, null);

      // Clean up local cache
      await _cleanupCachedProfilePicture(userId);

      return true;
    } catch (e) {
      safePrint('Error deleting profile picture: $e');
      return false;
    }
  }

  /// Check if user has a profile picture
  static Future<bool> hasProfilePicture(String userId) async {
    final url = await getProfilePictureUrl(userId);
    return url != null && url.isNotEmpty;
  }

  /// Get user initials for fallback display
  static String getUserInitials(String name) {
    if (name.isEmpty) return '?';
    
    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    } else {
      return '${words[0][0]}${words[words.length - 1][0]}'.toUpperCase();
    }
  }

  // Private helper methods

  static Future<User?> _getUserById(String userId) async {
    try {
      final request = ModelQueries.get(User.classType, UserModelIdentifier(id: userId));
      final response = await Amplify.API.query(request: request).response;
      return response.data;
    } catch (e) {
      safePrint('Error getting user by ID: $e');
      return null;
    }
  }

  static Future<void> _updateUserProfilePictureUrl(String userId, String? profilePictureUrl) async {
    try {
      final user = await _getUserById(userId);
      if (user != null) {
        final updatedUser = user.copyWith(profilePictureUrl: profilePictureUrl);
        final request = ModelMutations.update(updatedUser);
        await Amplify.API.mutate(request: request).response;
      }
    } catch (e) {
      safePrint('Error updating user profile picture URL: $e');
    }
  }



  static Future<void> _cleanupCachedProfilePicture(String userId) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cachedFile = File('${cacheDir.path}/profile_$userId.jpg');
      if (await cachedFile.exists()) {
        await cachedFile.delete();
      }
    } catch (e) {
      safePrint('Error cleaning up cached profile picture: $e');
    }
  }

  /// Extract S3 key from a legacy signed URL
  static String? _extractS3KeyFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;

      // Look for the profile-pictures pattern in the path
      final profilePicturesIndex = path.indexOf('profile-pictures/');
      if (profilePicturesIndex != -1) {
        // Extract everything from 'profile-pictures/' onwards
        return path.substring(profilePicturesIndex);
      }

      return null;
    } catch (e) {
      safePrint('Error extracting S3 key from URL: $e');
      return null;
    }
  }
}
