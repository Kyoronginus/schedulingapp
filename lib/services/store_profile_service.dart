import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/User.dart';

class CentralizedProfileImageService {
  static const String _s3KeyPrefix = 'profile-pictures/';
  static Future<String?> uploadProfilePicture(XFile imageFile, String userId) async {
    try {
      final s3Key = '$_s3KeyPrefix$userId.jpg';
      final imageBytes = await imageFile.readAsBytes();

      // Upload to S3 with GUEST access level for public profile picture access.
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

      await _updateUserProfilePictureUrl(userId, s3Key);

      final urlResult = await Amplify.Storage.getUrl(
        key: s3Key,
        options: const StorageGetUrlOptions(
          accessLevel: StorageAccessLevel.protected,
        ),
      ).result;

      return urlResult.url.toString();
    } catch (e) {
      safePrint('Error uploading profile picture: $e');
      return null;
    }
  }

  /// Get a signed profile picture URL for a user.
  /// Generates a temporary, secure URL for a file stored with 'protected' access.
  static Future<String?> getProfilePictureUrl(String userId) async {
    try {
      safePrint('🔍 Getting profile picture URL for user: $userId');

      // Get the S3 key from the user's profile in DynamoDB.
      final user = await _getUserById(userId);
      String? s3Key = user?.profilePictureUrl;

      safePrint('📄 User profile picture URL from DB: $s3Key');

      if (s3Key != null && s3Key.isNotEmpty) {
        if (s3Key.startsWith('http')) {
          safePrint('🔄 Found legacy URL, extracting S3 key...');
          final extractedKey = _extractS3KeyFromUrl(s3Key);
          if (extractedKey != null) {
            safePrint('✅ Extracted S3 key: $extractedKey');
            await _updateUserProfilePictureUrl(userId, extractedKey);
            s3Key = extractedKey;
          } else {
            safePrint('❌ Could not extract S3 key from URL');
            return null;
          }
        }

        safePrint('🔗 Generating signed URL for S3 key: $s3Key');

        // Generate fresh URL from the S3 key with the correct access level.
        final urlResult = await Amplify.Storage.getUrl(
          key: s3Key,
          options: const StorageGetUrlOptions(
            accessLevel: StorageAccessLevel.protected,
          ),
        ).result;

        final finalUrl = urlResult.url.toString();
        safePrint('✅ Generated protected signed URL: $finalUrl');
        return finalUrl;
      }

      safePrint('⚠️ No profile picture URL found for user');
      return null;
    } catch (e) {
      safePrint('❌ Error getting profile picture URL: $e');
      return null;
    }
  }

  /// Download and cache profile picture locally for offline access.
  static Future<File?> getCachedProfilePicture(String userId) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cachedFile = File('${cacheDir.path}/profile_$userId.jpg');

      if (await cachedFile.exists()) {
        final lastModified = await cachedFile.lastModified();
        if (DateTime.now().difference(lastModified).inHours < 1) {
          return cachedFile;
        }
      }

      // Download from S3 using the correct key and access level.
      final s3Key = '$_s3KeyPrefix$userId.jpg';
      final downloadResult = await Amplify.Storage.downloadData(
        key: s3Key,
        options: const StorageDownloadDataOptions(
          // CORRECTED: Use 'protected' for consistency.
          accessLevel: StorageAccessLevel.protected,
        ),
      ).result;

      // Save the downloaded bytes to the local cache file.
      await cachedFile.writeAsBytes(downloadResult.bytes);
      return cachedFile;
    } catch (e) {
      safePrint('Error downloading/caching profile picture: $e');
      return null;
    }
  }

  /// Delete profile picture from S3 and update the user profile.
  static Future<bool> deleteProfilePicture(String userId) async {
    try {
      final s3Key = '$_s3KeyPrefix$userId.jpg';
      
      // Delete the object from S3.
      await Amplify.Storage.remove(
        key: s3Key,
        options: const StorageRemoveOptions(
          accessLevel: StorageAccessLevel.protected,
        ),
      ).result;

      await _updateUserProfilePictureUrl(userId, null);
      await _cleanupCachedProfilePicture(userId);

      return true;
    } catch (e) {
      safePrint('Error deleting profile picture: $e');
      return false;
    }
  }

  /// Check if a user has a profile picture by attempting to get its URL.
  static Future<bool> hasProfilePicture(String userId) async {
    final url = await getProfilePictureUrl(userId);
    return url != null && url.isNotEmpty;
  }

  /// Get user initials for fallback display when no image is available.
  static String getUserInitials(String name) {
    if (name.isEmpty) return '?';
    
    final words = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    } else {
      return '${words[0][0]}${words[words.length - 1][0]}'.toUpperCase();
    }
  }


  /// Fetches a user record from DynamoDB by its ID.
  static Future<User?> _getUserById(String userId) async {
    try {
      safePrint('🔍 Querying user by ID: $userId');
      final request = ModelQueries.get(User.classType, UserModelIdentifier(id: userId));
      final response = await Amplify.API.query(request: request).response;
      final user = response.data;

      if (user != null) {
        safePrint('✅ Found user: ${user.name}, profilePictureUrl: ${user.profilePictureUrl}');
      } else {
        safePrint('❌ No user found for ID: $userId');
      }

      return user;
    } catch (e) {
      safePrint('❌ Error getting user by ID: $e');
      return null;
    }
  }

  /// Updates the 'profilePictureUrl' field for a user in DynamoDB.
  static Future<void> _updateUserProfilePictureUrl(String userId, String? profilePictureUrl) async {
    try {
      final user = await _getUserById(userId);
      if (user != null) {
        final updatedUser = user.copyWith(profilePictureUrl: profilePictureUrl);
        final request = ModelMutations.update(updatedUser);
        await Amplify.API.mutate(request: request).response;
        safePrint('✅ Updated user profile with S3 key: $profilePictureUrl');
      }
    } catch (e) {
      safePrint('Error updating user profile picture URL: $e');
    }
  }

  /// Removes the cached profile picture file from the local device storage.
  static Future<void> _cleanupCachedProfilePicture(String userId) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cachedFile = File('${cacheDir.path}/profile_$userId.jpg');
      if (await cachedFile.exists()) {
        await cachedFile.delete();
        safePrint('🧹 Cleaned up cached picture for user $userId');
      }
    } catch (e) {
      safePrint('Error cleaning up cached profile picture: $e');
    }
  }

  /// Extracts the S3 key from a legacy signed URL.
  static String? _extractS3KeyFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;

      final profilePicturesIndex = path.indexOf('profile-pictures/');
      if (profilePicturesIndex != -1) {
        final keyStartIndex = path.indexOf(_s3KeyPrefix);
        if (keyStartIndex != -1) {
          return path.substring(keyStartIndex);
        }
      }
      return null;
    } catch (e) {
      safePrint('Error extracting S3 key from URL: $e');
      return null;
    }
  }
}