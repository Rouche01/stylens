class ClosetItem {
  static const fallbackAspectRatio = 4 / 5;

  /// Browse section order. Empty sections are omitted by the UI.
  static const displayCategoryOrder = [
    'Tops',
    'Bottoms',
    'Outerwear',
    'Shoes',
    'Dresses',
    'Accessories',
    'Other',
  ];

  static const _displayCategories = {
    'top': 'Tops',
    'bottom': 'Bottoms',
    'outerwear': 'Outerwear',
    'footwear': 'Shoes',
    'full-body': 'Dresses',
    'accessory': 'Accessories',
  };

  final String id;
  final String label;
  final String category;
  final String subcategory;
  final String color;
  final String? isolatedImageUrl;
  final String? originalImageUrl;
  final String? imageKey;
  final String? blurHash;
  final double aspectRatio;

  const ClosetItem({
    required this.id,
    required this.label,
    required this.category,
    required this.subcategory,
    required this.color,
    this.isolatedImageUrl,
    this.originalImageUrl,
    this.imageKey,
    this.blurHash,
    this.aspectRatio = fallbackAspectRatio,
  });

  String get displayName => formatDisplayName(label);

  String get displayCategory => _displayCategories[category] ?? 'Other';

  static const _fillerWords = {'a', 'an', 'the', 'colored', 'coloured'};

  static final _wordSplit = RegExp(r'\s+');

  /// Title-cases an extraction label and drops filler words for tiles.
  /// The raw [label] is unchanged so search can still match it.
  static String formatDisplayName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;

    final words = <String>[];
    for (final token in trimmed.toLowerCase().split(_wordSplit)) {
      if (token.isEmpty || _fillerWords.contains(token)) continue;
      words.add(_titleCaseToken(token));
    }
    if (words.isEmpty) {
      return [
        for (final token in trimmed.toLowerCase().split(_wordSplit))
          if (token.isNotEmpty) _titleCaseToken(token),
      ].join(' ');
    }
    return words.join(' ');
  }

  static String _titleCaseToken(String token) {
    return token.split('-').map(_titleCaseWord).join('-');
  }

  static String _titleCaseWord(String word) {
    if (word.isEmpty) return word;
    return '${word[0].toUpperCase()}${word.substring(1)}';
  }

  /// Isolate crop for masonry tiles. Never the full outfit (`image_key`).
  String? get tileImageUrl => isolatedImageUrl;

  /// Taller tiles first (smaller width/height). The closet masonry grid then
  /// drops each next piece into the shortest column, so short crops fill holes
  /// instead of sitting in a stretched aligned-grid row.
  static List<ClosetItem> packForMasonry(List<ClosetItem> items) {
    if (items.length <= 1) return List<ClosetItem>.of(items);
    return [...items]..sort((a, b) {
      final byHeight = a.aspectRatio.compareTo(b.aspectRatio);
      if (byHeight != 0) return byHeight;
      return a.id.compareTo(b.id);
    });
  }

  factory ClosetItem.fromJson(Map<String, dynamic> json) {
    final ratio = _readPositiveDouble(json['tile_aspect_ratio']);
    return ClosetItem(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      category: json['category'] as String? ?? '',
      subcategory: json['subcategory'] as String? ?? '',
      color: json['color'] as String? ?? '',
      isolatedImageUrl: _readNonEmpty(json['isolated_image_url']),
      originalImageUrl: _readNonEmpty(json['original_image_url']),
      imageKey: _readNonEmpty(json['image_key']),
      blurHash:
          _readNonEmpty(json['blur_hash']) ?? _readNonEmpty(json['blurHash']),
      aspectRatio: ratio ?? fallbackAspectRatio,
    );
  }

  static List<ClosetItem> listFromResponse(dynamic data) {
    final raw = data is Map ? data['items'] : data;
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) ClosetItem.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  static String? _readNonEmpty(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _readPositiveDouble(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('$value');
    if (n == null || n <= 0) return null;
    return n;
  }
}
