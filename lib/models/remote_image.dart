class RemoteImage {
  final String url;
  final String key;

  RemoteImage({required this.url, required this.key});

  factory RemoteImage.fromJson(Map<String, dynamic> json) {
    return RemoteImage(
      url: json['image_url'] as String,
      key: json['image_key'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'image_url': url, 'image_key': key};
}
