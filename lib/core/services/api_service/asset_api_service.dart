import 'package:http/http.dart' as http;
import 'package:gostylens/core/services/api_service/base_api_service.dart';
import 'package:gostylens/models/api_responses/upload_url_response.dart';

class AssetApiService extends BaseApiService {
  AssetApiService() : super(resourcePath: 'assets');

  /// Gets the presigned upload URL and download URL mapping for a given filename
  Future<UploadUrlResponse> getUploadUrl(String filename) async {
    final response = await get<UploadUrlResponse>(
      'upload-url?filename=$filename',
      fromJson: (json) => UploadUrlResponse.fromJson(json),
      defaultErrorMessage: 'Failed to get upload URL',
    );

    if (response.isSuccess && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.error ?? 'Failed to get upload URL');
    }
  }

  /// Uploads binary file data to a direct presigned URL
  Future<int> uploadImage(String uploadUrl, List<int> fileBytes) async {
    final uploadImageResp = await http.put(
      Uri.parse(uploadUrl),
      body: fileBytes,
    );
    return uploadImageResp.statusCode;
  }

  /// Refetches a non-expired download URL for an asset
  Future<String> getDownloadUrl(String filename) async {
    try {
      final reqHeaders = await headers;
      final presignedUrlRes = await http.get(
        Uri.parse(buildUrl('download-url?filename=$filename')),
        headers: reqHeaders,
      );

      if (presignedUrlRes.statusCode != 200) {
        throw Exception('Failed to get download URL: ${presignedUrlRes.body}');
      }

      return presignedUrlRes.body;
    } catch (e) {
      print('Error getting download URL: $e');
      return '';
    }
  }
}
