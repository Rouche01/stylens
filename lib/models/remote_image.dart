class RemoteImage {
  final String url;
  final String key;
  final String? blurHash;

  RemoteImage({required this.url, required this.key, this.blurHash});

  factory RemoteImage.fromJson(Map<String, dynamic> json) {
    final hash =
        json['blurHash'] ?? json['blur_hash'] ?? json['image_blur_hash'];
    return RemoteImage(
      url: json['image_url'] ?? json['url'] as String? ?? '',
      key: json['image_key'] ?? json['key'] as String? ?? '',
      blurHash: hash is String && hash.isNotEmpty ? hash : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'key': key,
      if (blurHash != null) 'blurHash': blurHash,
    };
  }

  RemoteImage copyWith({String? url, String? key, String? blurHash}) {
    return RemoteImage(
      url: url ?? this.url,
      key: key ?? this.key,
      blurHash: blurHash ?? this.blurHash,
    );
  }
}
