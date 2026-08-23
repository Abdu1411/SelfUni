class MediaItem {
  final String id;
  final String type; // 'image' | 'audio' | 'pdf' | 'video' | 'other'
  final String url;
  final String? caption;

  MediaItem({
    required this.id,
    required this.type,
    required this.url,
    this.caption,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      type: json['type'] as String,
      url: json['url'] as String,
      caption: json['caption'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'url': url,
      'caption': caption,
    };
  }
}

class Lesson {
  final String id;
  String title;
  String topic;
  String? sourceUrl;
  List<String>? sources;
  String content;
  String? folderId;
  final int createdAt;
  String? videoUrl;
  String? pdfUrl;
  String? pdfFilename;
  int? pdfPages;
  double? lastWatchedTime;
  List<MediaItem>? multimedia;
  String? imageUrl;
  bool isNote;

  Lesson({
    required this.id,
    required this.title,
    required this.topic,
    this.sourceUrl,
    this.sources,
    required this.content,
    this.folderId,
    int? createdAt,
    this.videoUrl,
    this.pdfUrl,
    this.pdfFilename,
    this.pdfPages,
    this.lastWatchedTime,
    this.multimedia,
    this.imageUrl,
    this.isNote = true,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String? ?? 'lesson_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Untitled Note',
      topic: json['topic'] as String? ?? 'General',
      sourceUrl: json['sourceUrl'] as String?,
      sources: (json['sources'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      content: json['content'] as String? ?? '',
      folderId: json['folderId'] as String?,
      createdAt: json['createdAt'] as int?,
      videoUrl: json['videoUrl'] as String?,
      pdfUrl: json['pdfUrl'] as String?,
      pdfFilename: json['pdfFilename'] as String?,
      pdfPages: json['pdfPages'] as int?,
      lastWatchedTime: (json['lastWatchedTime'] as num?)?.toDouble(),
      multimedia: (json['multimedia'] as List<dynamic>?)
          ?.map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      imageUrl: json['imageUrl'] as String?,
      isNote: json['isNote'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'topic': topic,
      'sourceUrl': sourceUrl,
      'sources': sources,
      'content': content,
      'folderId': folderId,
      'createdAt': createdAt,
      'videoUrl': videoUrl,
      'pdfUrl': pdfUrl,
      'pdfFilename': pdfFilename,
      'pdfPages': pdfPages,
      'lastWatchedTime': lastWatchedTime,
      'multimedia': multimedia?.map((m) => m.toJson()).toList(),
      'imageUrl': imageUrl,
      'isNote': isNote,
    };
  }
}
