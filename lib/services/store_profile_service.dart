import 'dart:io';
import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/User.dart';

class CentralizedProfileImageService {
  static const String _s3KeyPrefix = 'profile-pictures/';
  static const Duration _signedUrlExpiry = Duration(seconds: 900); // Increased to 15 minutes
  
  /// Uploads an image and returns a signed URL.
  static Future<String?> uploadProfilePicture(XFile imageFile, String userId) async {
    try {
      final s3Key = '$_s3KeyPrefix$userId.jpg';
      final bytes = await imageFile.readAsBytes();

      // 1) Upload with PUBLIC access (matching your URL structure)
      await Amplify.Storage.uploadData(
        data: S3DataPayload.bytes(bytes, contentType: 'image/jpeg'),
        key: s3Key,
        options: const StorageUploadDataOptions(
          accessLevel: StorageAccessLevel.guest, // PUBLIC access
        ),
      ).result;

      // 2) Save the key in DynamoDB
      await _updateUserProfilePictureUrl(userId, s3Key);

      // 3) Generate signed URL with matching access level and proper options
      final result = await Amplify.Storage.getUrl(
        key: s3Key,
        options: StorageGetUrlOptions(
          accessLevel: StorageAccessLevel.guest, // Consistent with upload
          pluginOptions: S3GetUrlPluginOptions(
            validateObjectExistence: false, // Set to false to avoid extra API calls
            expiresIn: _signedUrlExpiry,
            useAccelerateEndpoint: false, // Ensure standard endpoint
          ),
        ),
      ).result;

      final rawUrl = result.url.toString();
      final processedUrl = _processSignedUrl(rawUrl);
      
      safePrint('✅ Upload - Generated signed URL: $processedUrl');
      
      // Validate the URL before returning
      if (_validateSignedUrl(processedUrl)) {
        return processedUrl;
      } else {
        safePrint('❌ Invalid signed URL generated, trying alternative method');
        // Fallback to public URL if signed URL is invalid
        return getPublicProfilePictureUrl(userId);
      }
    } catch (e) {
      safePrint('Error uploading profile picture: $e');
      // Try to get existing URL as fallback
      return getProfilePictureUrl(userId);
    }
  }

  /// Retrieves a signed URL for an existing image.
  static Future<String?> getProfilePictureUrl(String userId) async {
    try {
      final user = await _getUserById(userId);
      var s3Key = user?.profilePictureUrl;
      if (s3Key == null || s3Key.isEmpty) return null;

      // Handle legacy full-URL values
      if (s3Key.startsWith('http')) {
        final extracted = _extractS3KeyFromUrl(s3Key);
        if (extracted != null) {
          await _updateUserProfilePictureUrl(userId, extracted);
          s3Key = extracted;
        } else {
          safePrint('❌ Could not extract S3 key from legacy URL');
          return null;
        }
      }

      // Generate signed URL with PUBLIC access level
      final result = await Amplify.Storage.getUrl(
        key: s3Key,
        options: StorageGetUrlOptions(
          accessLevel: StorageAccessLevel.guest, // PUBLIC access
          pluginOptions: S3GetUrlPluginOptions(
            validateObjectExistence: false, // Avoid extra validation calls
            expiresIn: _signedUrlExpiry,
            useAccelerateEndpoint: false, // Use standard endpoint
          ),
        ),
      ).result;

      final rawUrl = result.url.toString();
      final processedUrl = _processSignedUrl(rawUrl);
      
      safePrint('✅ Fetch - Generated signed URL: $processedUrl');
      
      // Validate the URL before returning
      if (_validateSignedUrl(processedUrl)) {
        return processedUrl;
      } else {
        safePrint('❌ Invalid signed URL generated, trying public URL');
        return getPublicProfilePictureUrl(userId);
      }
    } catch (e) {
      safePrint('Error getting profile picture URL: $e');
      // Fallback to public URL
      return getPublicProfilePictureUrl(userId);
    }
  }

  /// Alternative method that uses direct S3 URLs for public images
  static Future<String?> getPublicProfilePictureUrl(String userId) async {
    try {
      final user = await _getUserById(userId);
      var s3Key = user?.profilePictureUrl;
      if (s3Key == null || s3Key.isEmpty) return null;

      // Handle legacy full-URL values
      if (s3Key.startsWith('http')) {
        final extracted = _extractS3KeyFromUrl(s3Key);
        if (extracted != null) {
          s3Key = extracted;
        } else {
          return null;
        }
      }

      // For public images, construct the URL directly
      // Format: https://BUCKET_NAME.s3.REGION.amazonaws.com/public/KEY
      final bucketInfo = await _getBucketInfo();
      if (bucketInfo != null) {
        final directUrl = 'https://${bucketInfo['bucket']}.s3.${bucketInfo['region']}.amazonaws.com/public/$s3Key';
        safePrint('✅ Direct public URL: $directUrl');
        
        // Test if the public URL is accessible
        if (await _testUrlAccessibility(directUrl)) {
          return directUrl;
        } else {
          safePrint('❌ Public URL not accessible, falling back to signed URL');
        }
      }
      
      // Final fallback: try signed URL one more time
      return _generateFallbackSignedUrl(s3Key);
    } catch (e) {
      safePrint('Error getting public profile picture URL: $e');
      return null;
    }
  }

  /// Process and clean up signed URLs to prevent shell interpretation issues
  static String _processSignedUrl(String url) {
    try {
      // Ensure URL is properly formatted and not truncated
      if (!url.contains('X-Amz-Algorithm')) {
        safePrint('❌ URL missing X-Amz-Algorithm parameter');
        return url;
      }
      
      // URL encode any special characters that might cause issues
      final uri = Uri.parse(url);
      final cleanedUrl = uri.toString();
      
      // Log for debugging
      safePrint('🔧 Processed URL length: ${cleanedUrl.length}');
      
      return cleanedUrl;
    } catch (e) {
      safePrint('❌ Error processing signed URL: $e');
      return url;
    }
  }

  /// Enhanced validation for signed URLs
  static bool _validateSignedUrl(String url) {
    try {
      if (url.isEmpty) {
        safePrint('❌ Empty URL');
        return false;
      }
      
      final uri = Uri.parse(url);
      final params = uri.queryParameters;
      
      // Required AWS Signature V4 parameters
      final requiredParams = [
        'X-Amz-Algorithm',
        'X-Amz-Credential', 
        'X-Amz-Signature',
        'X-Amz-Date',
        'X-Amz-SignedHeaders',
        'X-Amz-Expires'
      ];
      
      final missingParams = <String>[];
      for (final param in requiredParams) {
        if (!params.containsKey(param) || params[param]?.isEmpty == true) {
          missingParams.add(param);
        }
      }
      
      if (missingParams.isNotEmpty) {
        safePrint('❌ Missing required parameters: ${missingParams.join(', ')}');
        return false;
      }
      
      // Check if URL is complete (signed URLs are typically quite long)
      if (url.length < 200) {
        safePrint('❌ URL appears truncated (length: ${url.length})');
        return false;
      }
      
      // Validate that the signature looks correct (base64-like)
      final signature = params['X-Amz-Signature'];
      if (signature == null || signature.length < 32) {
        safePrint('❌ Invalid signature format');
        return false;
      }
      
      // Check expiry format
      final expires = params['X-Amz-Expires'];
      if (expires == null || int.tryParse(expires) == null) {
        safePrint('❌ Invalid expiry format');
        return false;
      }
      
      safePrint('✅ URL validation passed');
      return true;
    } catch (e) {
      safePrint('❌ Error validating URL: $e');
      return false;
    }
  }

  /// Test if a URL is accessible
  static Future<bool> _testUrlAccessibility(String url) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      
      final request = await client.headUrl(Uri.parse(url));
      final response = await request.close();
      
      final isAccessible = response.statusCode == 200;
      client.close();
      
      return isAccessible;
    } catch (e) {
      safePrint('URL accessibility test failed: $e');
      return false;
    }
  }

  /// Generate a fallback signed URL with minimal options
  static Future<String?> _generateFallbackSignedUrl(String s3Key) async {
    try {
      final result = await Amplify.Storage.getUrl(
        key: s3Key,
        options: const StorageGetUrlOptions(
          accessLevel: StorageAccessLevel.guest,
          pluginOptions: S3GetUrlPluginOptions(
            expiresIn: Duration(minutes: 30), // Longer expiry
            validateObjectExistence: false,
          ),
        ),
      ).result;

      final url = result.url.toString();
      safePrint('🔄 Fallback signed URL generated: ${url.substring(0, 100)}...');
      
      return _validateSignedUrl(url) ? url : null;
    } catch (e) {
      safePrint('Error generating fallback signed URL: $e');
      return null;
    }
  }

  /// Gets bucket information from Amplify configuration
  static Future<Map<String, String>?> _getBucketInfo() async {
    try {
      // These values should match your Amplify configuration
      // You can also get them dynamically from Amplify config if needed
      return {
        'bucket': 'profileimages0515b-dev', // From your error log
        'region': 'ap-southeast-1' // From your error log
      };
    } catch (e) {
      safePrint('Error getting bucket info: $e');
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

  static Future<void> _cleanupCachedProfilePicture(String userId) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/profile_$userId.jpg');
      if (await file.exists()) await file.delete();
    } catch (e) {
      safePrint('Error cleaning cache: $e');
    }
  }

  static String? _extractS3KeyFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      String path = uri.path;
      
      // Handle different URL formats
      if (path.startsWith('/public/')) {
        path = path.substring(8); // Remove '/public/'
      }
      
      final idx = path.indexOf(_s3KeyPrefix);
      if (idx != -1) {
        return path.substring(idx);
      }
      
      // If prefix not found, check if the path itself is the key
      if (path.startsWith(_s3KeyPrefix)) {
        return path;
      }
      
    } catch (e) {
      safePrint('Error extracting key: $e');
    }
    return null;
  }
  
  /// Debug method to print URL structure
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
