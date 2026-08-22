class CourseItem {
  final String id;
  final String title;
  final String type; // 'video' | 'pdf' | 'html' | 'resource' | 'unknown'
  final String? fileKey;
  final String? path;
  final String? description;
  bool? isCompleted;
  final String? transcript;

  CourseItem({
    required this.id,
    required this.title,
    required this.type,
    this.fileKey,
    this.path,
    this.description,
    this.isCompleted,
    this.transcript,
  });

  CourseItem copyWith({
    String? id,
    String? title,
    String? type,
    String? fileKey,
    String? path,
    String? description,
    bool? isCompleted,
    String? transcript,
  }) {
    return CourseItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      fileKey: fileKey ?? this.fileKey,
      path: path ?? this.path,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      transcript: transcript ?? this.transcript,
    );
  }

  factory CourseItem.fromJson(Map<String, dynamic> json) {
    return CourseItem(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      fileKey: json['fileKey'] as String?,
      path: json['path'] as String?,
      description: json['description'] as String?,
      isCompleted: json['isCompleted'] as bool?,
      transcript: json['transcript'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'fileKey': fileKey,
      'path': path,
      'description': description,
      'isCompleted': isCompleted,
      'transcript': transcript,
    };
  }
}

class CourseModule {
  final String id;
  final String title;
  final List<CourseItem> items;

  CourseModule({
    required this.id,
    required this.title,
    required this.items,
  });

  factory CourseModule.fromJson(Map<String, dynamic> json) {
    return CourseModule(
      id: json['id'] as String,
      title: json['title'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => CourseItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}

class Course {
  final String id;
  final String title;
  final String description;
  final List<String> instructors;
  final String? coverImageUrl;
  final List<CourseModule> modules;
  final int createdAt;
  final int? lastAccessed;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.instructors,
    this.coverImageUrl,
    required this.modules,
    int? createdAt,
    this.lastAccessed,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      instructors: (json['instructors'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      coverImageUrl: json['coverImageUrl'] as String?,
      modules: (json['modules'] as List<dynamic>?)
              ?.map((e) => CourseModule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] as int?,
      lastAccessed: json['lastAccessed'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'instructors': instructors,
      'coverImageUrl': coverImageUrl,
      'modules': modules.map((m) => m.toJson()).toList(),
      'createdAt': createdAt,
      'lastAccessed': lastAccessed,
    };
  }
}
