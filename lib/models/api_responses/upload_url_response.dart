class UploadUrlResponse {
  final String uploadUrl;
  final String downloadUrl;
  final String filename;

  UploadUrlResponse({
    required this.uploadUrl,
    required this.downloadUrl,
    required this.filename,
  });

  factory UploadUrlResponse.fromJson(Map<String, dynamic> json) {
    return UploadUrlResponse(
      uploadUrl: json['uploadUrl'] as String,
      downloadUrl: json['downloadUrl'] as String,
      filename: json['filename'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uploadUrl': uploadUrl,
      'downloadUrl': downloadUrl,
      'filename': filename,
    };
  }
}
