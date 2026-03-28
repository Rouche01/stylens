class RemoteImage {
  final String url;
  final String key;

  RemoteImage({required this.url, required this.key});

  factory RemoteImage.fromJson(Map<String, dynamic> json) {
    return RemoteImage(
      url: json['image_url'] ?? json['url'] as String,
      key: json['image_key'] ?? json['key'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'url': url, 'key': key};
}
