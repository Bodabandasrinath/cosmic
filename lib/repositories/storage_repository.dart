import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../core/errors/app_exception.dart';

class StorageRepository {
  // Canonical Firebase Storage bucket for Cosmic
  static const String storageBucketName = 'cosmic-ed916.firebasestorage.app';

  final FirebaseStorage _storage = FirebaseStorage.instanceFor(bucket: storageBucketName);
  final Uuid _uuid = const Uuid();

  // Max size constants (matching storage.rules)
  static const int maxProfilePhotoBytes = 10 * 1024 * 1024; // 10MB
  static const int maxChatMediaBytes = 50 * 1024 * 1024;    // 50MB

  /// Upload or Update User Profile Photo
  /// Organized at: users/{userId}/profile/{fileName}
  Future<String> uploadProfilePhoto({
    required String userId,
    File? imageFile,
    Uint8List? imageBytes,
    String? fileExtension,
  }) async {
    try {
      Uint8List? data = imageBytes;
      if (data == null && imageFile != null) {
        data = await imageFile.readAsBytes();
      }

      if (data == null || data.isEmpty) {
        throw StorageException('No image data provided for profile upload.');
      }

      // 1. File size validation
      if (data.lengthInBytes > maxProfilePhotoBytes) {
        final mb = (data.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
        throw StorageException('Image size ($mb MB) exceeds maximum allowed 10 MB.');
      }

      final ext = (fileExtension ?? 'jpg').toLowerCase().replaceAll('.', '');
      final contentType = ext == 'png'
          ? 'image/png'
          : (ext == 'webp' ? 'image/webp' : 'image/jpeg');

      // 2. MIME type validation
      if (!contentType.startsWith('image/')) {
        throw StorageException('Invalid MIME type for profile photo: $contentType');
      }

      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = _storage.ref().child('users/$userId/profile/$fileName');

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedBy': userId,
          'purpose': 'profile_photo',
        },
      );

      UploadTask uploadTask;
      if (kIsWeb || imageFile == null) {
        uploadTask = ref.putData(data, metadata);
      } else {
        uploadTask = ref.putFile(imageFile, metadata);
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (kDebugMode) print('uploadProfilePhoto FirebaseException: ${e.code} - ${e.message}');
      throw StorageException('Failed to upload profile photo: ${e.message ?? e.code}');
    } catch (e) {
      if (kDebugMode) print('uploadProfilePhoto Error: $e');
      throw StorageException('Failed to upload profile photo: $e');
    }
  }

  /// Upload Chat Media (Photo, Video, or Audio Voice Message)
  /// Organized at: chats/{chatId}/{fileName}
  Future<String> uploadChatMedia({
    required String chatId,
    required String mediaType, // 'image', 'video', 'audio'
    File? file,
    Uint8List? bytes,
    String? fileName,
    Function(double progress)? onProgress,
  }) async {
    try {
      Uint8List? data = bytes;
      if (data == null && file != null) {
        data = await file.readAsBytes();
      }

      if (data == null || data.isEmpty) {
        throw StorageException('No media data provided for chat upload.');
      }

      // 1. Size validation
      if (data.lengthInBytes > maxChatMediaBytes) {
        final mb = (data.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
        throw StorageException('$mediaType file size ($mb MB) exceeds 50 MB limit.');
      }

      final ext = _getExtension(mediaType, fileName ?? (file?.path ?? ''));
      final contentType = _getContentType(mediaType, ext);
      final finalFileName = fileName ?? '${mediaType}_${_uuid.v4()}.$ext';
      final ref = _storage.ref().child('chats/$chatId/$finalFileName');

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'chatId': chatId,
          'mediaType': mediaType,
        },
      );

      UploadTask uploadTask;
      if (kIsWeb || file == null) {
        uploadTask = ref.putData(data, metadata);
      } else {
        uploadTask = ref.putFile(file, metadata);
      }

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress?.call(progress);
        }
      });

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (kDebugMode) print('uploadChatMedia FirebaseException: ${e.code} - ${e.message}');
      throw StorageException('Failed to upload $mediaType: ${e.message ?? e.code}');
    } catch (e) {
      if (kDebugMode) print('uploadChatMedia Error: $e');
      throw StorageException('Failed to upload $mediaType: $e');
    }
  }

  String _getExtension(String mediaType, String filePath) {
    if (filePath.contains('.')) {
      return filePath.split('.').last.toLowerCase().split('?').first;
    }
    switch (mediaType) {
      case 'image':
        return 'jpg';
      case 'video':
        return 'mp4';
      case 'audio':
        return 'm4a';
      default:
        return 'bin';
    }
  }

  String _getContentType(String mediaType, String ext) {
    switch (mediaType) {
      case 'image':
        if (ext == 'png') return 'image/png';
        if (ext == 'webp') return 'image/webp';
        if (ext == 'gif') return 'image/gif';
        return 'image/jpeg';
      case 'video':
        if (ext == 'webm') return 'video/webm';
        if (ext == 'mov') return 'video/quicktime';
        return 'video/mp4';
      case 'audio':
        if (ext == 'aac') return 'audio/aac';
        if (ext == 'mp3') return 'audio/mpeg';
        if (ext == 'wav') return 'audio/wav';
        if (ext == 'ogg') return 'audio/ogg';
        return 'audio/m4a';
      default:
        return 'application/octet-stream';
    }
  }
}
