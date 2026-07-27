/// storage_service.dart — File storage service (Cloudinary via backend)
///
/// File uploads are now handled server-side by the Node.js backend
/// using multer-storage-cloudinary. This service is retained as a thin
/// facade so no screens that import it need to be modified.
///
/// The actual upload is delegated to [FirestoreService.uploadMaterial].

class StorageService {
  /// No-op in production mode — kept for API compatibility.
  /// Screens that need to upload should call [FirestoreService.uploadMaterial]
  /// directly, passing the [filePath].
  ///
  /// Returns the dummy placeholder URL so any legacy callers don't break,
  /// but the real URL will come from the API response.
  Future<String?> uploadMaterialFile({
    required String filePath,
    required String fileName,
  }) async {
    // This method is now intentionally unused.
    // The upload happens inside FirestoreService.uploadMaterial via ApiClient.postMultipart.
    return null;
  }
}
