enum StylistOpenerTag {
  withImage('with_image'),
  withoutImage('without_image');

  final String value;
  const StylistOpenerTag(this.value);

  static StylistOpenerTag? tryParse(String value) {
    for (final tag in StylistOpenerTag.values) {
      if (tag.value == value) return tag;
    }
    return null;
  }
}

class StylistOpenerMessage {
  const StylistOpenerMessage({
    required this.id,
    required this.text,
    required this.tags,
  });

  final String id;
  final String text;
  final List<StylistOpenerTag> tags;

  bool hasTag(StylistOpenerTag tag) => tags.contains(tag);

  factory StylistOpenerMessage.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final tags = <StylistOpenerTag>[];
    if (rawTags is List) {
      for (final raw in rawTags) {
        if (raw is! String) continue;
        final tag = StylistOpenerTag.tryParse(raw);
        if (tag != null && !tags.contains(tag)) {
          tags.add(tag);
        }
      }
    }

    return StylistOpenerMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      tags: tags,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'tags': tags.map((t) => t.value).toList(),
  };
}

class StylistOpenersPool {
  const StylistOpenersPool({
    required this.version,
    required this.messages,
  });

  final int version;
  final List<StylistOpenerMessage> messages;

  factory StylistOpenersPool.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final messages = <StylistOpenerMessage>[];
    if (rawMessages is List) {
      for (final raw in rawMessages) {
        if (raw is Map<String, dynamic>) {
          messages.add(StylistOpenerMessage.fromJson(raw));
        } else if (raw is Map) {
          messages.add(
            StylistOpenerMessage.fromJson(Map<String, dynamic>.from(raw)),
          );
        }
      }
    }

    return StylistOpenersPool(
      version: (json['version'] as num?)?.toInt() ?? 0,
      messages: messages,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'messages': messages.map((m) => m.toJson()).toList(),
  };
}
