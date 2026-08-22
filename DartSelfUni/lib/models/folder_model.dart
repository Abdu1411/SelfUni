class Folder {
  final String id;
  String name;
  String? color;
  final int createdAt;

  Folder({
    required this.id,
    required this.name,
    this.color,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      createdAt: json['createdAt'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'createdAt': createdAt,
    };
  }
}
