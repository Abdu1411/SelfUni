import 'package:flutter/foundation.dart';

class ActiveResource {
  final String title;
  final String type; // 'flashcard' | 'lesson' | 'dashboard'
  final String contextText;
  final List<String> suggestedPrompts;
  final String? videoUrl;

  ActiveResource({
    required this.title,
    required this.type,
    required this.contextText,
    required this.suggestedPrompts,
    this.videoUrl,
  });
}

class ActiveViewProvider extends ChangeNotifier {
  ActiveResource? _activeResource;

  ActiveResource? get activeResource => _activeResource;

  void setActiveResource(ActiveResource? resource) {
    _activeResource = resource;
    notifyListeners();
  }
}
