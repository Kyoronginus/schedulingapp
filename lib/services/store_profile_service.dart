import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:image_picker/image_picker.dart';
import '../models/User.dart';

class CentralizedProfileImageService {
  static const String _s3KeyPrefix = 'profile-pictures/';
  static const Duration _signedUrlExpiry = Duration(seconds: 900);

  // Global cache for profile picture URLs to avoid redundant fetches
  static final Map<String, String?> _profilePictureCache = <String, String?>{};
  static final Map<String, DateTime> _cacheTimestamps = <String, DateTime>{};
  static const Duration _cacheExpiry = Duration(minutes: 30);
  
  static Future<String?> uploadProfilePicture(XFile imageFile, String userId) async {
    try {
      final s3Key = '$_s3KeyPrefix$userId.jpg';
      final bytes = await imageFile.readAsBytes();

      await Amplify.Storage.uploadData(
        data: S3DataPayload.bytes(bytes, contentType: 'image/jpeg'),
        key: s3Key,
        options: const StorageUploadDataOptions(
          accessLevel: StorageAccessLevel.guest,
        ),
      ).result;

      await _updateUserProfilePictureUrl(userId, s3Key);

      // Clear cache for this user since we're uploading a new picture
      clearCacheForUser(userId);

      final result = await Amplify.Storage.getUrl(
        key: s3Key,
        options: const StorageGetUrlOptions(
          accessLevel: StorageAccessLevel.guest,
          pluginOptions: S3GetUrlPluginOptions(
            validateObjectExistence: false,
            expiresIn: _signedUrlExpiry,
            useAccelerateEndpoint: false,
          ),
        ),
      ).result;

      final url = result.url.toString();
      _setCachedUrl(userId, url);
      return url;
    } catch (e) {
      safePrint('Error uploading profile picture: $e');
      // Try to get existing URL as fallback
      return getProfilePictureUrl(userId);
    }
  }

  // Cache management methods
  static String? _getCachedUrl(String userId) {
    final cachedUrl = _profilePictureCache[userId];
    final timestamp = _cacheTimestamps[userId];

    if (cachedUrl != null && timestamp != null) {
      if (DateTime.now().difference(timestamp) < _cacheExpiry) {
        return cachedUrl;
      } else {
        // Cache expired, remove it
        _profilePictureCache.remove(userId);
        _cacheTimestamps.remove(userId);
      }
    }
    return null;
  }

  static void _setCachedUrl(String userId, String? url) {
    _profilePictureCache[userId] = url;
    _cacheTimestamps[userId] = DateTime.now();
  }

  static void clearCacheForUser(String userId) {
    _profilePictureCache.remove(userId);
    _cacheTimestamps.remove(userId);
  }

  static Future<String?> getProfilePictureUrl(String userId) async {
    // Check cache first
    final cachedUrl = _getCachedUrl(userId);
    if (cachedUrl != null) {
      return cachedUrl;
    }

    try {
      safePrint('🔍 Fetching profile picture from network for user: $userId');
      final user = await _getUserById(userId);
      var s3Key = user?.profilePictureUrl;
      if (s3Key == null || s3Key.isEmpty) {
        _setCachedUrl(userId, null);
        return null;
      }

      // Handle legacy full-URL values
      if (s3Key.startsWith('http')) {
        final extracted = _extractS3KeyFromUrl(s3Key);
        if (extracted != null) {
          await _updateUserProfilePictureUrl(userId, extracted);
          s3Key = extracted;
        } else {
          safePrint('❌ Could not extract S3 key from legacy URL');
          _setCachedUrl(userId, null);
          return null;
        }
      }

      final result = await Amplify.Storage.getUrl(
        key: s3Key,
        options: const StorageGetUrlOptions(
          accessLevel: StorageAccessLevel.guest,
          pluginOptions: S3GetUrlPluginOptions(
            validateObjectExistence: false,
            expiresIn: _signedUrlExpiry,
            useAccelerateEndpoint: false,
          ),
        ),
      ).result;

      final url = result.url.toString();
      _setCachedUrl(userId, url);
      safePrint('✅ Profile picture URL cached for user: $userId');
      return url;
    } catch (e) {
      safePrint('Error getting profile picture URL: $e');
      _setCachedUrl(userId, null);
      return null;
    }
  }

  static String getUserInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final words = name.trim().split(' ');
    if (words.length == 1) return words[0][0].toUpperCase();
    return (words.first[0] + words.last[0]).toUpperCase();
  }

  static Future<User?> _getUserById(String userId) async {
    try {
      final req = ModelQueries.get(User.classType, UserModelIdentifier(id: userId));
      final resp = await Amplify.API.query(request: req).response;
      return resp.data;
    } catch (e) {
      safePrint('Error querying user: $e');
      return null;
    }
  }

  static Future<void> _updateUserProfilePictureUrl(String userId, String? url) async {
    try {
      final user = await _getUserById(userId);
      if (user != null) {
        final updated = user.copyWith(profilePictureUrl: url);
        final response = await Amplify.API.mutate(request: ModelMutations.update(updated)).response;
        if (response.hasErrors) {
          safePrint('Error updating user: ${response.errors}');
        }
      }
    } catch (e) {
      safePrint('Error updating user record: $e');
    }
  }



  static String? _extractS3KeyFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      String path = uri.path;
      
      if (path.startsWith('/public/')) {
        path = path.substring(8);
      }
      
      final idx = path.indexOf(_s3KeyPrefix);
      if (idx != -1) {
        return path.substring(idx);
      }
      
      if (path.startsWith(_s3KeyPrefix)) {
        return path;
      }
      
    } catch (e) {
      safePrint('Error extracting key: $e');
    }
    return null;
  }
  
  static void debugUrl(String url) {
    try {
      final uri = Uri.parse(url);
      safePrint('🔍 URL Debug:');
      safePrint('  Host: ${uri.host}');
      safePrint('  Path: ${uri.path}');
      safePrint('  Query params count: ${uri.queryParameters.length}');
      uri.queryParameters.forEach((key, value) {
        final truncatedValue = value.length > 50 ? '${value.substring(0, 50)}...' : value;
        safePrint('    $key: $truncatedValue');
      });
    } catch (e) {
      safePrint('❌ Error debugging URL: $e');
    }
  }
}
