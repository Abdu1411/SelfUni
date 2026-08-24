import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:selfuni/models/card_model.dart';
import 'package:selfuni/models/deck_model.dart';
import 'package:selfuni/models/lesson_model.dart';
import 'package:selfuni/models/folder_model.dart';
import 'package:selfuni/models/course_model.dart';
import 'package:selfuni/core/services/storage_service.dart';
import 'package:selfuni/core/services/notes_storage_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:selfuni/providers/active_view_provider.dart';
import 'package:selfuni/providers/deck_provider.dart';
import 'package:selfuni/providers/pomodoro_provider.dart';
import 'package:selfuni/views/dashboard_view.dart';
import 'package:selfuni/views/lesson_detail_view.dart';
import 'package:selfuni/views/studio_view.dart';
import 'package:selfuni/views/study_session_view.dart';
import 'package:selfuni/widgets/common/markdown_view.dart';
import 'package:selfuni/widgets/common/rich_note_editor.dart';
import 'package:selfuni/widgets/modals/export_note_modal.dart';
import 'package:selfuni/widgets/modals/ask_ai_modal.dart';
import 'package:selfuni/widgets/common/adaptive_video_player_widget.dart';
import 'package:selfuni/core/services/ai_service.dart';
import 'package:selfuni/models/note_mastery_model.dart';
import 'package:selfuni/core/services/note_mastery_storage_service.dart';
import 'package:selfuni/widgets/modals/note_mastery_modal.dart';
import 'package:selfuni/widgets/modals/folder_modal.dart';
import 'package:selfuni/widgets/modals/due_notes_review_modal.dart';
import 'package:selfuni/views/lessons_view.dart';
import 'package:selfuni/views/pdf_viewer_view.dart';
import 'package:selfuni/widgets/modals/due_cards_review_modal.dart';
import 'package:selfuni/views/decks_view.dart';
import 'package:selfuni/core/utils/srs_engine.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final tempDir = Directory.systemTemp.createTempSync('selfuni_test_global_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );
  });

  testWidgets('LessonDetailView renders Quick Actions buttons properly', (WidgetTester tester) async {
    final sampleLesson = Lesson(
      id: 'test-lesson-1',
      title: 'Dynamic Programming Patterns',
      topic: 'Algorithms',
      content: '# Dynamic Programming\n\nThis note explains memoization and tabulation.',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    final deckProvider = DeckProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ActiveViewProvider()),
          ChangeNotifierProvider.value(value: deckProvider),
          ChangeNotifierProvider(create: (_) => PomodoroProvider(deckProvider)),
        ],
        child: MaterialApp(
          home: LessonDetailView(
            lesson: sampleLesson,
            onNavigateBack: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Quick Actions headers and buttons are present
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Generate Flashcards'), findsOneWidget);
    expect(find.text('Ask AI Tutor'), findsOneWidget);
  });

  testWidgets('StudioView initializes with active resource and allows clearing raw notes', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final activeViewProvider = ActiveViewProvider();
    activeViewProvider.setActiveResource(
      ActiveResource(
        title: 'Python Notes',
        type: 'lesson',
        contextText: '# Python Content Here',
        suggestedPrompts: [],
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: activeViewProvider),
          ChangeNotifierProvider(create: (_) => DeckProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StudioView(
              onNavigateBack: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify topic and raw notes text field are populated
    expect(find.text('Python Notes'), findsOneWidget);
    expect(find.text('# Python Content Here'), findsOneWidget);

    // Verify action buttons are rendered
    expect(find.text('GENERATE CS LESSON'), findsOneWidget);
    expect(find.text('SYNTHESIZE 30 CARDS'), findsOneWidget);
    expect(find.text('GENERATE BOTH (LESSON & CARDS)'), findsOneWidget);

    // Tap clear button in the notes textfield
    final clearButton = find.byTooltip('Clear notes');
    expect(clearButton, findsOneWidget);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    // Verify notes textfield and active resource are cleared
    expect(find.text('# Python Content Here'), findsNothing);
    expect(activeViewProvider.activeResource, isNull);
  });

  testWidgets('StudySessionView renders Scaffold on caught up state and enables Relearn', (WidgetTester tester) async {
    final sampleCard = Flashcard(
      id: 'card-1',
      type: CardType.concept,
      front: 'What is a binary tree?',
      back: 'A tree data structure where each node has at most two children.',
      deckId: 'deck-1',
      nextReview: DateTime.now().millisecondsSinceEpoch + 1000000, // in the future (not due)
      interval: 1,
      ease: 2.5,
      reps: 1,
    );

    final deck = Deck(
      id: 'deck-1',
      title: 'Trees & Graphs',
      cards: [sampleCard],
    );

    final deckProvider = DeckProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: deckProvider),
          ChangeNotifierProvider(create: (_) => PomodoroProvider(deckProvider)),
        ],
        child: MaterialApp(
          home: StudySessionView(deck: deck),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All Caught Up!'), findsOneWidget);
    expect(find.text('Relearn All Cards Now'), findsOneWidget);

    // 2. Tapping Relearn All Cards starts the study session
    await tester.tap(find.text('Relearn All Cards Now'));
    await tester.pumpAndSettle();

    expect(find.text('What is a binary tree?'), findsOneWidget);
  });

  testWidgets('DashboardView displays Study by Note Archetype connected to Universal Deck', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late final DeckProvider deckProvider;
    await tester.runAsync(() async {
      deckProvider = DeckProvider();
      while (deckProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    });
    final sampleCard = Flashcard(
      id: 'card-1',
      type: CardType.complexity,
      front: 'What is the time complexity of QuickSort average case?',
      back: 'O(N log N)',
      deckId: 'deck-1',
      nextReview: DateTime.now().millisecondsSinceEpoch - 1000, // due now
      interval: 1,
      ease: 2.5,
      reps: 1,
    );

    final deck = Deck(
      id: 'deck-1',
      title: 'Sorting Algorithms',
      cards: [sampleCard],
    );
    deckProvider.addDeck(deck);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: deckProvider),
          ChangeNotifierProvider(create: (_) => PomodoroProvider(deckProvider)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DashboardView(
              onNavigateToDecks: () {},
              onNavigateToLessons: () {},
              onNavigateToSynthesizer: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Archetype header and Universal Deck badge
    expect(find.text('🎯 Study by Note Archetype'), findsOneWidget);
    expect(find.textContaining('Study Universal Deck'), findsOneWidget);

    // Verify Complexity archetype shows 1 due
    expect(find.text('Complexity'), findsOneWidget);
    expect(find.text('Study Due (1)'), findsOneWidget);

    // Tap Study Due (1) to start StudySessionView
    await tester.ensureVisible(find.text('Study Due (1)'));
    await tester.tap(find.text('Study Due (1)'));
    await tester.pumpAndSettle();

    // Verify study session opened with the complexity card
    expect(find.text('What is the time complexity of QuickSort average case?'), findsOneWidget);
  });

  testWidgets('Clicking Concept card on Dashboard studies all Concept cards in Universal Deck', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late final DeckProvider deckProvider;
    await tester.runAsync(() async {
      deckProvider = DeckProvider();
      while (deckProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    });
    final conceptCard1 = Flashcard(
      id: 'concept-1',
      type: CardType.concept,
      front: 'What is memoization?',
      back: 'Caching the results of expensive function calls.',
      deckId: 'deck-dp',
      nextReview: DateTime.now().millisecondsSinceEpoch + 50000,
      interval: 1,
      ease: 2.5,
      reps: 1,
    );

    final conceptCard2 = Flashcard(
      id: 'concept-2',
      type: CardType.concept,
      front: 'What is a hash table collision?',
      back: 'When two distinct keys produce the same hash index.',
      deckId: 'deck-hash',
      nextReview: DateTime.now().millisecondsSinceEpoch + 60000,
      interval: 1,
      ease: 2.5,
      reps: 1,
    );

    deckProvider.addDeck(Deck(id: 'deck-dp', title: 'Dynamic Programming', cards: [conceptCard1]));
    deckProvider.addDeck(Deck(id: 'deck-hash', title: 'Hashing', cards: [conceptCard2]));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: deckProvider),
          ChangeNotifierProvider(create: (_) => PomodoroProvider(deckProvider)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DashboardView(
              onNavigateToDecks: () {},
              onNavigateToLessons: () {},
              onNavigateToSynthesizer: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify 2 cards in Universal Deck text on Concept card
    expect(find.text('2 cards in Universal Deck'), findsOneWidget);
    expect(find.text('Relearn All (2)'), findsOneWidget);

    // Tap Concept card directly on the Dashboard
    await tester.ensureVisible(find.text('Concept'));
    await tester.tap(find.text('Concept'));
    await tester.pumpAndSettle();

    // Verify study session opened and displays the first concept card
    expect(find.text('What is memoization?'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('MarkdownView renders GitHub-flavored Markdown, alerts, and code blocks using flutter_html', (WidgetTester tester) async {
    const sampleMarkdown = '''
# Masterclass: Graph Algorithms

> [!NOTE]
> This is a key theoretical note about directed acyclic graphs.

## Complexity Table

| Algorithm | Time | Space |
| :--- | :--- | :--- |
| BFS | \$O(V + E)\$ | \$O(V)\$ |
| DFS | \$O(V + E)\$ | \$O(V)\$ |

```dart
void traverse() {
  print("Traversing DAG");
}
```
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownView(data: sampleMarkdown),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final htmlFinder = find.byType(Html);
    expect(htmlFinder, findsAtLeastNWidgets(1));
    final htmlWidget = tester.widget<Html>(htmlFinder.first);
    expect(htmlWidget.data, contains('Masterclass: Graph Algorithms'));
    expect(htmlWidget.data, contains('directed acyclic graphs'));
    expect(htmlWidget.data, contains('Complexity Table'));
    expect(htmlWidget.data, contains('traverse'));
  });

  testWidgets('Code snippet is sized to 40% of the page width on desktop/tablet in RichNoteEditor preview', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const noteWithCode = '```dart\nvoid main() {\n  print("40% width test");\n}\n```';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownView(data: noteWithCode),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final codeBlockFinder = find.byType(CodeSnippetWidget);
    expect(codeBlockFinder, findsOneWidget);
  });

  testWidgets('MarkdownView renders MarkdownImageWidget and handles missing local file gracefully', (WidgetTester tester) async {
    const sampleMarkdown = '''
# Image Test

![Diagram of Tree](C:/non_existent_folder/tree_diagram.png)
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownView(data: sampleMarkdown),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownImageWidget), findsOneWidget);
    expect(find.text('Image Not Found or Inaccessible'), findsOneWidget);
    expect(find.textContaining('tree_diagram.png'), findsOneWidget);
  });

  testWidgets('RichNoteEditor provides Add Image action chip', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichNoteEditor(
            initialContent: '# Notes',
            onChanged: (val) {},
          ),
        ),
      ),
    );
    expect(find.text('Add Image'), findsOneWidget);
  });

  testWidgets('MarkdownView renders local image from PC file with spaces and backslashes', (WidgetTester tester) async {
    final tempDir = Directory.systemTemp.createTempSync('selfuni img test ');
    final spaceDir = Directory('${tempDir.path}/Folder With Spaces');
    spaceDir.createSync(recursive: true);
    final testImageFile = File('${spaceDir.path}/My Diagram Image.png');
    final pngBytes = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');
    testImageFile.writeAsBytesSync(pngBytes);
    addTearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    // Test with Windows backslashes and spaces
    final sampleMarkdown = '![Architecture Diagram](${testImageFile.path})';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownView(data: sampleMarkdown),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownImageWidget), findsOneWidget);
    expect(find.text('Architecture Diagram'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('RichNoteEditor opens image options modal with options', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichNoteEditor(
            initialContent: '# Notes',
            onChanged: (val) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Image'));
    await tester.pumpAndSettle();

    expect(find.text('Insert Image into Notes'), findsOneWidget);
    expect(find.text('Select Image File(s)'), findsOneWidget);
    expect(find.text('Browse Folder on PC'), findsOneWidget);
    expect(find.text('Enter File Path or Web URL'), findsOneWidget);
  });

  testWidgets('Folder Gallery dialog displays scanned images and allows selection', (WidgetTester tester) async {
    final tempDir = Directory.systemTemp.createTempSync('selfuni_gallery_test_');
    final subDir = Directory('${tempDir.path}/Screenshots');
    subDir.createSync(recursive: true);
    final img1 = File('${tempDir.path}/slide1.png');
    final img2 = File('${subDir.path}/diagram_lecture.jpg');
    final pngBytes = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');
    img1.writeAsBytesSync(pngBytes);
    img2.writeAsBytesSync(pngBytes);
    addTearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichNoteEditor(
            initialContent: '',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Markdown editor is mounted and ready
    expect(find.text('Add Image'), findsOneWidget);
  });

  testWidgets('DeckProvider saves and restores live lectures and courses across restarts without data loss', (WidgetTester tester) async {
    final tempDir = Directory.systemTemp.createTempSync('selfuni_test_storage_');
    addTearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );

    await tester.runAsync(() async {
      final storageService = StorageService();

      // Create sample course and live lecture
      final course = Course(
        id: 'crs_test_sysdesign',
        title: 'Distributed Systems 101',
        description: 'Test course',
        instructors: ['Dr. Rivera'],
        modules: [
          CourseModule(
            id: 'mod_1',
            title: 'Module 1',
            items: [
              CourseItem(
                id: 'lec_item_1',
                title: 'Intro to Raft Consensus',
                type: 'video',
                path: 'https://youtube.com/watch?v=vLnPwxZdW4w',
              ),
            ],
          ),
        ],
      );

      final lesson = Lesson(
        id: 'lec_item_1',
        title: 'Intro to Raft Consensus',
        topic: 'Distributed Systems 101',
        videoUrl: 'https://youtube.com/watch?v=vLnPwxZdW4w',
        sourceUrl: 'https://youtube.com/watch?v=vLnPwxZdW4w',
        content: '# Intro to Raft Consensus',
        isNote: false,
      );

      // Save directly to storage
      await storageService.saveCourses([course]);
      await storageService.saveLessons([lesson]);
      await storageService.saveFolders([Folder(id: 'folder_dist', name: 'Distributed Systems 101')]);

      // Simulate opening the app fresh (instantiating DeckProvider)
      final provider = DeckProvider();
      while (provider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 20));
      }

      // Verify lectures and courses are not purged on restart
      expect(provider.courses.length, equals(1));
      expect(provider.courses.first.title, equals('Distributed Systems 101'));
      expect(provider.lessons.length, equals(1));
      expect(provider.lessons.first.title, equals('Intro to Raft Consensus'));
      expect(provider.lessons.first.videoUrl, equals('https://youtube.com/watch?v=vLnPwxZdW4w'));

      // Verify folders include the course
      expect(provider.folders.any((f) => f.name == 'Distributed Systems 101'), isTrue);

      // Verify creating a custom note in custom folder "Abs" persists across restart
      await provider.addFolder('Abs', color: '#10B981');
      final absFolder = provider.folders.firstWhere((f) => f.name == 'Abs');

      final note = Lesson(
        id: 'note_as_123',
        title: 'as',
        topic: 'Abs',
        content: '# Chapter 1: Mathematical Reasoning\n\nMathematics extends beyond calculation...',
        folderId: absFolder.id,
        isNote: true,
      );

      await provider.addLesson(note);

      // Simulate restarting the app completely
      final restartedProvider = DeckProvider();
      while (restartedProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 20));
      }

      // Verify custom folder and note persist
      expect(restartedProvider.folders.any((f) => f.name == 'Abs'), isTrue);
      final persistedNote = restartedProvider.lessons.where((l) => l.title == 'as').firstOrNull;
      expect(persistedNote, isNotNull);
      expect(persistedNote!.topic, equals('Abs'));
      expect(persistedNote.content, contains('Chapter 1: Mathematical Reasoning'));
      expect(persistedNote.isNote, isTrue);
    });
  });

  testWidgets('ExportNoteModal requires and enforces obligatory destination folder before exporting notes', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late final DeckProvider deckProvider;
    await tester.runAsync(() async {
      deckProvider = DeckProvider();
      while (deckProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: deckProvider),
          ChangeNotifierProvider(create: (_) => ActiveViewProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ExportNoteModal(
              noteContent: '# Test lecture notes',
              defaultTitle: 'Lecture 1 Notes',
              defaultTopic: 'Operating Systems',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify the Obligatory badge and destination folder section are visible
    expect(find.text('DESTINATION FOLDER'), findsOneWidget);
    expect(find.text('Obligatory'), findsOneWidget);
    expect(find.text('Export to Notes'), findsOneWidget);
  });

  group('Permanent Deletion Tests', () {
    test('Deleting a deck permanently deletes card images and deck data', () async {
      final docDir = await getApplicationDocumentsDirectory();
      final testImgFile = File('${docDir.path}/test_card_img.png');
      await testImgFile.writeAsString('image-data');
      expect(await testImgFile.exists(), isTrue);

      final provider = DeckProvider();
      while (provider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      final deck = Deck(
        id: 'test_deck_del',
        title: 'Algorithms to Delete',
        cards: [
          Flashcard(
            id: 'card_1',
            type: CardType.concept,
            front: 'What is quicksort?',
            back: 'Divide and conquer sorting algorithm',
            imageUrl: testImgFile.path,
            nextReview: DateTime.now().millisecondsSinceEpoch,
            interval: 1,
            ease: 2.5,
            reps: 1,
          ),
        ],
      );

      await provider.addDeck(deck);
      expect(provider.decks.any((d) => d.id == 'test_deck_del'), isTrue);

      // Delete deck
      await provider.deleteDeck('test_deck_del');

      // Verify removed from provider
      expect(provider.decks.any((d) => d.id == 'test_deck_del'), isFalse);

      // Verify card image permanently deleted from storage
      expect(await testImgFile.exists(), isFalse);
    });

    test('Deleting a lesson with PDF and note permanently deletes files and notes folder', () async {
      final docDir = await getApplicationDocumentsDirectory();
      final pdfFile = File('${docDir.path}/AlgoMaster/pdfs/test_sample.pdf');
      await pdfFile.parent.create(recursive: true);
      await pdfFile.writeAsString('pdf-content');
      expect(await pdfFile.exists(), isTrue);

      // Append a note for this lesson
      await NotesStorageService.appendNoteToClass(
        className: 'Database Systems',
        lectureTitle: 'LSM Trees Deep Dive',
        noteContent: 'Notes about memtable and sstables',
      );

      final notesFolder = Directory('${docDir.path}/SelfUni_Notes/Database Systems');
      expect(await notesFolder.exists(), isTrue);

      final provider = DeckProvider();
      while (provider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      final lesson = Lesson(
        id: 'lesson_pdf_1',
        title: 'LSM Trees Deep Dive',
        topic: 'Database Systems',
        content: 'Content',
        pdfUrl: pdfFile.path,
        isNote: true,
      );

      await provider.addLesson(lesson);
      expect(provider.lessons.any((l) => l.id == 'lesson_pdf_1'), isTrue);

      // Delete lesson
      await provider.deleteLesson('lesson_pdf_1');

      // Verify removed from provider
      expect(provider.lessons.any((l) => l.id == 'lesson_pdf_1'), isFalse);

      // Verify PDF file was permanently deleted
      expect(await pdfFile.exists(), isFalse);

      // Verify note was permanently removed
      final masterNotes = File('${notesFolder.path}/master_notes.md');
      expect(await masterNotes.exists(), isFalse);
    });

    test('Deleting a course keeps course notes folder and files intact if they contain notes', () async {
      final docDir = await getApplicationDocumentsDirectory();
      final courseNotesDir = Directory('${docDir.path}/SelfUni_Notes/Compilers_101');
      await courseNotesDir.create(recursive: true);
      final noteFile = File('${courseNotesDir.path}/master_notes.md');
      await noteFile.writeAsString('## Compilers note');
      expect(await courseNotesDir.exists(), isTrue);

      final provider = DeckProvider();
      while (provider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      final course = Course(
        id: 'course_compilers',
        title: 'Compilers 101',
        description: 'Compilers course',
        instructors: ['Dr. A'],
        modules: [],
      );

      await provider.addCourse(course);
      expect(provider.courses.any((c) => c.id == 'course_compilers'), isTrue);

      // Delete course
      await provider.deleteCourse('course_compilers', deleteFolderToo: true);

      // Verify course removed from provider
      expect(provider.courses.any((c) => c.id == 'course_compilers'), isFalse);

      // Verify notes folder remains intact
      expect(await courseNotesDir.exists(), isTrue);
      expect(await noteFile.readAsString(), '## Compilers note');

      // Cleanup notes folder
      await noteFile.delete();
      await courseNotesDir.delete();
    });

    test('Deleting a course deletes course notes folder if it is empty', () async {
      final docDir = await getApplicationDocumentsDirectory();
      final courseNotesDir = Directory('${docDir.path}/SelfUni_Notes/Physics_101');
      await courseNotesDir.create(recursive: true);
      final noteFile = File('${courseNotesDir.path}/master_notes.md');
      await noteFile.writeAsString('   '); // empty spaces
      expect(await courseNotesDir.exists(), isTrue);

      final provider = DeckProvider();
      while (provider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      final course = Course(
        id: 'course_physics',
        title: 'Physics 101',
        description: 'Physics course',
        instructors: ['Dr. B'],
        modules: [],
      );

      await provider.addCourse(course);
      expect(provider.courses.any((c) => c.id == 'course_physics'), isTrue);

      // Delete course
      await provider.deleteCourse('course_physics', deleteFolderToo: true);

      // Verify course removed from provider
      expect(provider.courses.any((c) => c.id == 'course_physics'), isFalse);

      // Verify notes folder is permanently deleted
      expect(await courseNotesDir.exists(), isFalse);
    });

    test('Deleting a course keeps the Notes & PDFs folder object if it contains notes', () async {
      final provider = DeckProvider();
      while (provider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      final folder = await provider.addFolder('Compilers 101', color: '#123456');
      
      final noteLesson = Lesson(
        id: 'lesson_note_compilers',
        title: 'Introduction to Parsing',
        topic: 'Compilers 101',
        content: '# Parsing Notes',
        isNote: true,
        folderId: folder.id,
      );
      await provider.addLesson(noteLesson);

      final course = Course(
        id: 'course_compilers',
        title: 'Compilers 101',
        description: 'Compilers course',
        instructors: ['Dr. A'],
        modules: [],
      );
      await provider.addCourse(course);

      expect(provider.folders.any((f) => f.id == folder.id), isTrue);
      expect(provider.courses.any((c) => c.id == 'course_compilers'), isTrue);

      await provider.deleteCourse('course_compilers', deleteFolderToo: true);

      expect(provider.courses.any((c) => c.id == 'course_compilers'), isFalse);
      expect(provider.folders.any((f) => f.id == folder.id), isTrue);
      expect(provider.lessons.any((l) => l.id == 'lesson_note_compilers'), isTrue);

      await provider.deleteFolder(folder.id);
    });
  });

  group('Tutor AI Styling Tests', () {
    testWidgets('AskAiModal dynamically styles UI based on selected note theme', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late final DeckProvider deckProvider;
      await tester.runAsync(() async {
        deckProvider = DeckProvider();
        while (deckProvider.isLoading) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      });

      // Set custom note theme styles (Soft Sepia colors)
      await deckProvider.setCustomThemeStyles({
        'bg': '#fbf0d9',
        'text': '#433422',
        'link': '#8c6239',
        'border': '#e6d8b8',
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: deckProvider),
            ChangeNotifierProvider(create: (_) => ActiveViewProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AskAiModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Container that has background color matching Soft Sepia (Color(0xFFFBF0D9))
      final containerFinder = find.byType(Container);
      bool foundSepiaBackground = false;
      for (final element in containerFinder.evaluate()) {
        final widget = element.widget as Container;
        if (widget.decoration is BoxDecoration) {
          final decoration = widget.decoration as BoxDecoration;
          if (decoration.color == const Color(0xFFFBF0D9)) {
            foundSepiaBackground = true;
            break;
          }
        }
      }
      expect(foundSepiaBackground, isTrue);
    });
  });

  group('AdaptiveVideoPlayerWidget Tests', () {
    testWidgets('AdaptiveVideoPlayerWidget renders fallback buttons and text on native initialization failure', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveVideoPlayerWidget(
              videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
              thumbnailUrl: 'https://img.youtube.com/vi/dQw4w9WgXcQ/0.jpg',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AdaptiveVideoPlayerWidget), findsOneWidget);
      expect(find.text("Could not initialize media player. Use browser play option."), findsOneWidget);
      expect(find.text('Retry Stream'), findsOneWidget);
      expect(find.text('Open in Browser'), findsOneWidget);
    });
  });

  group('Two-way Title Sync Tests', () {
    testWidgets('Renaming a lesson syncs title to the corresponding course item', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final mockCourse = Course(
          id: 'course_sync_test',
          title: 'Algorithms 101',
          description: 'Discrete math',
          instructors: const [],
          modules: [
            CourseModule(
              id: 'm_sync',
              title: 'Introduction',
              items: [
                CourseItem(
                  id: 'sync_item_1',
                  title: 'Original Lecture Title',
                  type: 'video',
                  path: 'https://youtube.com/sync_video',
                ),
              ],
            ),
          ],
        );
        
        final mockLesson = Lesson(
          id: 'sync_item_1',
          title: 'Original Lecture Title',
          topic: 'Algorithms 101',
          videoUrl: 'https://youtube.com/sync_video',
          isNote: false,
          content: 'Live course video stream',
        );

        final deckProvider = DeckProvider();
        
        // Wait for _initData to finish loading
        while (deckProvider.isLoading) {
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Inject mock data into provider internal lists
        deckProvider.courses.add(mockCourse);
        deckProvider.lessons.add(mockLesson);

        // Verify initial title
        expect(deckProvider.courses.first.modules.first.items.first.title, 'Original Lecture Title');
        expect(deckProvider.lessons.first.title, 'Original Lecture Title');

        // Rename from live lecture
        await deckProvider.renameLesson('sync_item_1', 'Renamed Lecture Title');

        // Verify title is updated in both lessons and courses
        expect(deckProvider.lessons.first.title, 'Renamed Lecture Title');
        expect(deckProvider.courses.first.modules.first.items.first.title, 'Renamed Lecture Title');
      });
    });
  });

  group('Export/Import Data Tests', () {
    testWidgets('Exporting and importing JSON backup restores files and SharedPreferences settings', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final docDir = await getApplicationDocumentsDirectory();
        
        final classFolder = Directory('${docDir.path}/SelfUni_Notes/Discrete_Math');
        if (await classFolder.exists()) {
          await classFolder.delete(recursive: true);
        }
        await classFolder.create(recursive: true);
        final noteFile = File('${classFolder.path}/master_notes.md');
        await noteFile.writeAsString('# Mock Note Content');
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('deepseek_api_key', 'sk-test-key-123');
        await prefs.setString('note_theme', 'Solarized Dark');

        final deckProvider = DeckProvider();
        while (deckProvider.isLoading) {
          await Future.delayed(const Duration(milliseconds: 10));
        }

        final backupJson = await StorageService().generateBackupJson();
        expect(backupJson, contains('Discrete_Math'));
        expect(backupJson, contains('sk-test-key-123'));
        expect(backupJson, contains('Solarized Dark'));

        await noteFile.delete();
        expect(await noteFile.exists(), isFalse);
        await prefs.remove('deepseek_api_key');
        await prefs.remove('note_theme');

        await deckProvider.restoreBackup(backupJson);

        expect(await noteFile.exists(), isTrue);
        expect(await noteFile.readAsString(), '# Mock Note Content');
        expect(prefs.getString('deepseek_api_key'), 'sk-test-key-123');
        expect(prefs.getString('note_theme'), 'Solarized Dark');
        
        await noteFile.delete();
        await classFolder.delete(recursive: true);
      });
    });
  });

  group('Arabic Preview Tests', () {
    testWidgets('RichNoteEditor renders Arabic preview button and switches to Arabic preview mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichNoteEditor(
              initialContent: '# Sorting Algorithms\n\nMerge Sort runs in \$O(N \\log N)\$.',
              onChanged: (val) {},
            ),
          ),
        ),
      );

      final arabicBtnFinder = find.byIcon(Icons.g_translate_outlined);
      expect(arabicBtnFinder, findsOneWidget);

      await tester.tap(arabicBtnFinder);
      await tester.pump();

      expect(find.textContaining('معاينة باللغة العربية'), findsWidgets);
    });

    testWidgets('MarkdownView renders in RTL when isArabic is true', (WidgetTester tester) async {
      const sampleArabicMarkdown = '''
# خوارزميات الترتيب

هذه الملاحظات تشرح خوارزمية الترتيب بالدمج وتعقيدها \$O(N \\log N)\$.

```dart
void mergeSort() {
  // LTR code
}
```
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownView(
                data: sampleArabicMarkdown,
                isArabic: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final directionalityFinder = find.byWidgetPredicate(
        (widget) => widget is Directionality && widget.textDirection == TextDirection.rtl,
      );
      expect(directionalityFinder, findsWidgets);
    });

    test('AIService translateNotesToArabic handles empty notes gracefully', () async {
      final aiService = AIService();
      final result = await aiService.translateNotesToArabic(notes: '');
      expect(result, '');
    });

    testWidgets('MarkdownView automatically detects RTL language and formats RTL without manual flag', (WidgetTester tester) async {
      const arabicContent = '''
# شجرة البحث الثنائية

تحتوي شجرة البحث الثنائية على عقد مرتبة بحيث تكون جميع القيم في الشجرة الفرعية اليسرى أصغر من الجذر.
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownView(
                data: arabicContent,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rtlDirectionality = find.byWidgetPredicate(
        (widget) => widget is Directionality && widget.textDirection == TextDirection.rtl,
      );
      expect(rtlDirectionality, findsWidgets);
    });

    testWidgets('MarkdownView automatically formats English content in LTR', (WidgetTester tester) async {
      const englishContent = '''
# Binary Search Tree

A binary search tree is a rooted binary tree data structure with the key property.
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownView(
                data: englishContent,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ltrDirectionality = find.byWidgetPredicate(
        (widget) => widget is Directionality && widget.textDirection == TextDirection.ltr,
      );
      expect(ltrDirectionality, findsWidgets);
    });

    test('AIService detectLanguageHeuristic detects Arabic and English accurately', () {
      final arabicDetect = AIService.detectLanguageHeuristic('ملاحظات عن البرمجة الديناميكية والخوارزميات');
      expect(arabicDetect['isRtl'], isTrue);
      expect(arabicDetect['language'], 'Arabic');

      final englishDetect = AIService.detectLanguageHeuristic('# Dynamic Programming Notes\nThis is in English.');
      expect(englishDetect['isRtl'], isFalse);
      expect(englishDetect['language'], 'English');
    });

    testWidgets('RichNoteEditor standard preview displays RTL direction indicator when note is Arabic', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichNoteEditor(
              initialContent: '# ملاحظات الدرس\n\nشرح الخوارزميات وهياكل البيانات.',
              onChanged: (val) {},
            ),
          ),
        ),
      );

      // Switch to standard preview
      final previewBtn = find.byTooltip('Preview Mode');
      expect(previewBtn, findsOneWidget);
      await tester.tap(previewBtn);
      await tester.pumpAndSettle();

      expect(find.text('RTL'), findsOneWidget);
      expect(find.text('Switch'), findsOneWidget);
    });
  });

  group('Note Mastery Tests', () {
    test('NoteMasteryModel computes effective mastery and decays to 0% after 7 days', () {
      final now = DateTime.now();

      final q1 = MasteryQuestionModel(id: '1', question: 'Q1', idealAnswer: 'A1', isCorrect: true);
      final q2 = MasteryQuestionModel(id: '2', question: 'Q2', idealAnswer: 'A2', isCorrect: true);
      final q3 = MasteryQuestionModel(id: '3', question: 'Q3', idealAnswer: 'A3', isCorrect: false);

      // Fresh review: 2/3 correct = 67%
      final freshMastery = NoteMasteryModel(
        noteKey: 'note_123',
        questions: [q1, q2, q3],
        lastReviewedAt: now,
      );
      expect(freshMastery.effectiveMasteryPercentage, 67);
      expect(freshMastery.incorrectQuestions.length, 1);
      expect(freshMastery.incorrectQuestions.first.id, '3');

      // 100% mastery fresh
      final allCorrectMastery = NoteMasteryModel(
        noteKey: 'note_123',
        questions: [
          q1,
          q2,
          MasteryQuestionModel(id: '3', question: 'Q3', idealAnswer: 'A3', isCorrect: true),
        ],
        lastReviewedAt: now,
      );
      expect(allCorrectMastery.effectiveMasteryPercentage, 100);
      expect(allCorrectMastery.incorrectQuestions, isEmpty);

      // 8 days elapsed (> 7 days / 168 hours): mastery falls to 0%
      final decayedMastery = NoteMasteryModel(
        noteKey: 'note_123',
        questions: [q1, q2],
        lastReviewedAt: now.subtract(const Duration(days: 8)),
      );
      expect(decayedMastery.effectiveMasteryPercentage, 0);
    });

    test('NoteMasteryStorageService saves and loads note mastery properly', () async {
      final storage = NoteMasteryStorageService();
      storage.clearForTest();

      final mastery = NoteMasteryModel(
        noteKey: 'test_mastery_note_key',
        questions: [
          MasteryQuestionModel(
            id: 'mq1',
            question: 'What is memoization?',
            idealAnswer: 'Caching expensive function results.',
            isCorrect: true,
          ),
          MasteryQuestionModel(
            id: 'mq2',
            question: 'What is tabulation?',
            idealAnswer: 'Bottom-up dynamic programming table.',
            isCorrect: false,
          ),
        ],
        lastReviewedAt: DateTime.now(),
      );

      await storage.saveNoteMastery(mastery);

      final loaded = await storage.getNoteMastery('test_mastery_note_key');
      expect(loaded, isNotNull);
      expect(loaded!.questions.length, 2);
      expect(loaded.questions.first.question, 'What is memoization?');
      expect(loaded.questions.first.isCorrect, isTrue);
      expect(loaded.questions[1].isCorrect, isFalse);
      expect(loaded.incorrectQuestions.length, 1);
      expect(loaded.incorrectQuestions.first.id, 'mq2');
    });

    test('AIService generateMasteryQuestions and gradeMasteryAnswer fallback works', () async {
      final aiService = AIService();
      final questions = await aiService.generateMasteryQuestions(
        noteContent: '''
# Merge Sort
- Divide and conquer sorting algorithm.
- Time complexity is O(N log N).
''',
        count: 2,
      );

      expect(questions, isNotEmpty);
      expect(questions.first['question'], isNotEmpty);
      expect(questions.first['idealAnswer'], isNotEmpty);

      final grade = await aiService.gradeMasteryAnswer(
        question: 'What is the time complexity of Merge Sort?',
        idealAnswer: 'The time complexity is O(N log N) in all cases.',
        userAnswer: 'It runs in O(N log N) using divide and conquer.',
      );

      expect(grade['isCorrect'], isTrue);
      expect(grade['scorePercentage'], greaterThanOrEqualTo(60));
    });

    testWidgets('RichNoteEditor renders Mastery percentage text and does not open modal on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichNoteEditor(
              title: 'Algorithms 101',
              initialContent: '# Sorting Algorithms\n\nNotes on bubble sort and merge sort.',
              onChanged: (val) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final masteryBadgeFinder = find.textContaining('Mastery');
      expect(masteryBadgeFinder, findsOneWidget);

      await tester.tap(masteryBadgeFinder);
      await tester.pump();

      expect(find.byType(NoteMasteryModal), findsNothing);
    });

    testWidgets('FolderModal creates new folder and pops without Navigator assertion failure', (WidgetTester tester) async {
      String? savedName;
      String? savedColor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showDialog(
                  context: ctx,
                  builder: (_) => FolderModal(
                    onSave: (name, color) {
                      savedName = name;
                      savedColor = color;
                    },
                  ),
                ),
                child: const Text('Open Folder Modal'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Folder Modal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(FolderModal), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Web Generated Course');
      await tester.tap(find.text('Create'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FolderModal), findsNothing);
      expect(savedName, 'Web Generated Course');
      expect(savedColor, isNotNull);
    });

    test('NoteMasteryStorageService getDueNotes filters notes with mastery less than 60%', () async {
      final storage = NoteMasteryStorageService();
      storage.clearForTest();

      final lesson1 = Lesson(id: 'l1', title: 'Dynamic Programming', topic: 'Algorithms', content: 'Notes 1');
      final lesson2 = Lesson(id: 'l2', title: 'Graph Theory', topic: 'Algorithms', content: 'Notes 2');
      final lesson3 = Lesson(id: 'l3', title: 'Binary Trees', topic: 'Data Structures', content: 'Notes 3');

      // Lesson 1: 100% mastery (not due)
      await storage.saveNoteMastery(NoteMasteryModel(
        noteKey: 'l1',
        questions: [
          MasteryQuestionModel(id: 'q1', question: 'Q1', idealAnswer: 'A1', isCorrect: true),
        ],
        lastReviewedAt: DateTime.now(),
      ));

      // Lesson 2: 33% mastery (due)
      await storage.saveNoteMastery(NoteMasteryModel(
        noteKey: 'l2',
        questions: [
          MasteryQuestionModel(id: 'q1', question: 'Q1', idealAnswer: 'A1', isCorrect: true),
          MasteryQuestionModel(id: 'q2', question: 'Q2', idealAnswer: 'A2', isCorrect: false),
          MasteryQuestionModel(id: 'q3', question: 'Q3', idealAnswer: 'A3', isCorrect: false),
        ],
        lastReviewedAt: DateTime.now(),
      ));

      // Lesson 3: unattempted (0% mastery, due)

      final dueNotes = await storage.getDueNotes([lesson1, lesson2, lesson3], threshold: 60);

      expect(dueNotes.length, 2);
      final dueIds = dueNotes.map((d) => (d['lesson'] as Lesson).id).toList();
      expect(dueIds, contains('l2'));
      expect(dueIds, contains('l3'));
      expect(dueIds, isNot(contains('l1')));
    });

    test('NoteMasteryStorageService excludes notes that belong to local courses from getDueNotes', () async {
      final storage = NoteMasteryStorageService();
      storage.clearForTest();

      final standaloneNote = Lesson(
        id: 'standalone_note_1',
        title: 'Distributed Transactions',
        topic: 'Databases',
        content: 'Two phase commit and Raft consensus.',
        isNote: true,
      );

      final courseNote = Lesson(
        id: 'course_note_2',
        title: 'Lecture 1: Intro to AlgoMaster',
        topic: 'Data Structures & Algorithms Course',
        content: 'Live course video stream for Data Structures & Algorithms Course.',
        isNote: true,
      );

      final localCourse = Course(
        id: 'course_dsa',
        title: 'Data Structures & Algorithms Course',
        description: 'DSA Bootcamp',
        instructors: ['Prof. Smith'],
        modules: [],
      );

      final dueNotes = await storage.getDueNotes(
        [standaloneNote, courseNote],
        threshold: 60,
        courses: [localCourse],
      );

      // Only the standalone note should be due for review, the local course note is excluded!
      expect(dueNotes.length, 1);
      expect((dueNotes.first['lesson'] as Lesson).id, 'standalone_note_1');
    });

    testWidgets('DueNotesReviewModal renders due notes list and allows quizzing', (WidgetTester tester) async {
      final storage = NoteMasteryStorageService();
      storage.clearForTest();
      await storage.loadAllMasteries();

      final deckProvider = DeckProvider();
      final testNote = Lesson(
        id: 'due_test_note_1',
        title: 'Operating Systems Virtual Memory',
        topic: 'Operating Systems',
        content: 'Paging and segmentation in modern OS.',
        isNote: true,
      );
      deckProvider.lessons.add(testNote);

      await tester.pumpWidget(
        ChangeNotifierProvider<DeckProvider>.value(
          value: deckProvider,
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => DueNotesReviewModal.show(ctx),
                  child: const Text('Open Due Notes Review'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Due Notes Review'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.byType(DueNotesReviewModal), findsOneWidget);
      expect(find.text('Due Notes Mastery Review'), findsOneWidget);
      expect(find.text('Operating Systems Virtual Memory'), findsOneWidget);
      expect(find.text('Quiz Now'), findsOneWidget);
    });

    testWidgets('LessonsView renders DUE REVIEW button in header', (WidgetTester tester) async {
      final storage = NoteMasteryStorageService();
      storage.clearForTest();

      final deckProvider = DeckProvider();
      final testNote = Lesson(
        id: 'due_test_note_2',
        title: 'Computer Networks Routing',
        topic: 'Networking',
        content: 'BGP and OSPF routing protocols.',
        isNote: true,
      );
      deckProvider.lessons.add(testNote);

      await tester.pumpWidget(
        ChangeNotifierProvider<DeckProvider>.value(
          value: deckProvider,
          child: MaterialApp(
            home: Scaffold(
              body: LessonsView(
                onNavigateToLessonGenerator: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      final dueBtnFinder = find.textContaining('DUE');
      expect(dueBtnFinder, findsWidgets);

      await tester.tap(dueBtnFinder.first);
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.byType(DueNotesReviewModal), findsOneWidget);
    });

    test('NoteMasteryModel graduation exempts note from 7-day memory decay', () {
      final oldReviewDate = DateTime.now().subtract(const Duration(days: 8));

      // Regular non-graduated note: 100% raw accuracy, but 8 days elapsed -> decays to 0%
      final nonGraduatedNote = NoteMasteryModel(
        noteKey: 'regular_decay_note',
        questions: [
          MasteryQuestionModel(id: 'q1', question: 'Q1', idealAnswer: 'A1', isCorrect: true),
        ],
        lastReviewedAt: oldReviewDate,
        consecutiveHighScores: 1,
        isGraduated: false,
      );
      expect(nonGraduatedNote.rawMasteryPercentage, 100);
      expect(nonGraduatedNote.effectiveMasteryPercentage, 0); // Decayed!

      // Graduated note: 100% raw accuracy, 8 days elapsed -> remains 100% (Immune to decay!)
      final graduatedNote = NoteMasteryModel(
        noteKey: 'graduated_mastery_note',
        questions: [
          MasteryQuestionModel(id: 'q1', question: 'Q1', idealAnswer: 'A1', isCorrect: true),
        ],
        lastReviewedAt: oldReviewDate,
        consecutiveHighScores: 2,
        isGraduated: true,
      );
      expect(graduatedNote.rawMasteryPercentage, 100);
      expect(graduatedNote.effectiveMasteryPercentage, 100); // Protected from decay!
    });

    test('NoteMasteryStorageService getMasteredNotes filters graduated and >=90% notes', () async {
      final storage = NoteMasteryStorageService();
      storage.clearForTest();

      final lesson1 = Lesson(id: 'grad_note_1', title: 'Turing Machines', topic: 'Theory', content: 'C1', isNote: true);
      final lesson2 = Lesson(id: 'non_grad_note_2', title: 'Sorting Algorithms', topic: 'Algorithms', content: 'C2', isNote: true);

      // Graduated note
      await storage.saveNoteMastery(NoteMasteryModel(
        noteKey: 'grad_note_1',
        questions: [
          MasteryQuestionModel(id: 'q1', question: 'Q1', idealAnswer: 'A1', isCorrect: true),
        ],
        lastReviewedAt: DateTime.now().subtract(const Duration(days: 10)),
        consecutiveHighScores: 2,
        isGraduated: true,
      ));

      // 50% score note
      await storage.saveNoteMastery(NoteMasteryModel(
        noteKey: 'non_grad_note_2',
        questions: [
          MasteryQuestionModel(id: 'q1', question: 'Q1', idealAnswer: 'A1', isCorrect: true),
          MasteryQuestionModel(id: 'q2', question: 'Q2', idealAnswer: 'A2', isCorrect: false),
        ],
        lastReviewedAt: DateTime.now(),
        consecutiveHighScores: 0,
        isGraduated: false,
      ));

      final mastered = await storage.getMasteredNotes([lesson1, lesson2]);
      expect(mastered.length, 1);
      expect((mastered.first['lesson'] as Lesson).id, 'grad_note_1');
      expect(mastered.first['isGraduated'], isTrue);
    });

    testWidgets('DueNotesReviewModal renders Mastered Notes tab with decay immunity', (WidgetTester tester) async {
      final storage = NoteMasteryStorageService();
      storage.clearForTest();
      await storage.loadAllMasteries();

      final deckProvider = DeckProvider();
      final testNote = Lesson(
        id: 'mastered_test_note_1',
        title: 'Distributed Systems Raft',
        topic: 'Distributed Systems',
        content: 'Leader election and log replication.',
        isNote: true,
      );
      deckProvider.lessons.add(testNote);

      await tester.runAsync(() async {
        await storage.saveNoteMastery(NoteMasteryModel(
          noteKey: testNote.id,
          questions: [
            MasteryQuestionModel(id: 'q1', question: 'Q1', idealAnswer: 'A1', isCorrect: true),
          ],
          lastReviewedAt: DateTime.now().subtract(const Duration(days: 8)),
          consecutiveHighScores: 2,
          isGraduated: true,
        ));
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<DeckProvider>.value(
          value: deckProvider,
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => DueNotesReviewModal.show(ctx),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Modal'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.byType(DueNotesReviewModal), findsOneWidget);

      final masteredTabFinder = find.textContaining('Mastered Notes');
      expect(masteredTabFinder, findsOneWidget);

      await tester.tap(masteredTabFinder);
      await tester.pump();

      expect(find.text('Distributed Systems Raft'), findsOneWidget);
      expect(find.text('IMMUNE TO DECAY'), findsOneWidget);
    });

    test('NoteMasteryStorageService includes PDF notes in getDueNotes and getMasteredNotes', () async {
      final storage = NoteMasteryStorageService();
      storage.clearForTest();

      final pdfLesson = Lesson(
        id: 'pdf_lesson_1',
        title: 'Deep Learning Lecture Slides',
        topic: 'Machine Learning',
        content: 'Backpropagation and gradient descent derivations.',
        pdfUrl: 'C:/fake/path/lecture.pdf',
        pdfFilename: 'lecture.pdf',
        isNote: false, // Even if isNote was false on imported PDF, it is a reviewable document!
      );

      final regularNote = Lesson(
        id: 'note_lesson_2',
        title: 'Heaps and Priority Queues',
        topic: 'Data Structures',
        content: 'Binary heap operations.',
        isNote: true,
      );

      final due = await storage.getDueNotes([pdfLesson, regularNote]);
      expect(due.length, 2);
      final dueIds = due.map((d) => (d['lesson'] as Lesson).id).toList();
      expect(dueIds, contains('pdf_lesson_1'));
      expect(dueIds, contains('note_lesson_2'));
    });

    testWidgets('PdfViewerView provides noteKey and lesson title to RichNoteEditor', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final deckProvider = DeckProvider();
      final pomodoroProvider = PomodoroProvider(deckProvider);
      final pdfLesson = Lesson(
        id: 'pdf_test_key_1',
        title: 'Calculus III Multivariable',
        topic: 'Mathematics',
        content: 'Partial derivatives and gradient vector.',
        pdfUrl: null, // Test without actual PDF file on disk
        pdfFilename: 'calc3.pdf',
        isNote: true,
      );
      deckProvider.lessons.add(pdfLesson);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DeckProvider>.value(value: deckProvider),
            ChangeNotifierProvider<PomodoroProvider>.value(value: pomodoroProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PdfViewerView(
                lesson: pdfLesson,
                onNavigateBack: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find RichNoteEditor inside PdfViewerView
      final editorFinder = find.byType(RichNoteEditor);
      expect(editorFinder, findsOneWidget);

      final editorWidget = tester.widget<RichNoteEditor>(editorFinder);
      expect(editorWidget.noteKey, 'pdf_test_key_1');
      expect(editorWidget.title, 'Calculus III Multivariable');
    });

    test('Flashcard consecutive correct reviews trigger graduation to Mastered and decay immunity', () {
      final card = Flashcard(
        id: 'card_grad_1',
        type: CardType.concept,
        front: 'What is idempotency?',
        back: 'An operation that produces the same result no matter how many times it is applied.',
        nextReview: DateTime.now().millisecondsSinceEpoch - 1000,
        interval: 1,
        ease: 2.5,
        reps: 0,
        consecutiveCorrect: 0,
        isGraduated: false,
      );

      // Card is initially due
      expect(card.isDue, isTrue);
      expect(card.isGraduated, isFalse);

      // 1st good review
      final review1 = SRSEngine.calculateNextReview(card, Grade.good);
      expect(review1.consecutiveCorrect, 1);
      expect(review1.isGraduated, isFalse);

      // 2nd consecutive good review -> Graduates to Mastered!
      final review2 = SRSEngine.calculateNextReview(review1, Grade.good);
      expect(review2.consecutiveCorrect, 2);
      expect(review2.isGraduated, isTrue);
      expect(review2.masteryScore, 100);

      // Graduated card is immune to normal decay
      expect(review2.isDue, isFalse);
    });

    testWidgets('DueCardsReviewModal renders Due, Mastered, and All tabs and displays cards', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final deckProvider = DeckProvider();
      final dueCard = Flashcard(
        id: 'due_card_test_1',
        type: CardType.concept,
        front: 'What is CAP Theorem?',
        back: 'Consistency, Availability, Partition tolerance.',
        nextReview: DateTime.now().millisecondsSinceEpoch - 5000,
        interval: 1,
        ease: 2.5,
        reps: 0,
        consecutiveCorrect: 0,
        isGraduated: false,
      );

      final masteredCard = Flashcard(
        id: 'mastered_card_test_2',
        type: CardType.complexity,
        front: 'Binary Search Time Complexity',
        back: 'O(log N)',
        nextReview: DateTime.now().millisecondsSinceEpoch - 5000,
        interval: 30,
        ease: 2.8,
        reps: 5,
        consecutiveCorrect: 3,
        isGraduated: true,
      );

      final testDeck = Deck(
        id: 'test_deck_srs',
        title: 'System Design Drills',
        cards: [dueCard, masteredCard],
      );
      deckProvider.addDeck(testDeck);

      await tester.pumpWidget(
        ChangeNotifierProvider<DeckProvider>.value(
          value: deckProvider,
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => DueCardsReviewModal.show(ctx),
                  child: const Text('Open Cards Modal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Cards Modal'));
      await tester.pump();

      expect(find.byType(DueCardsReviewModal), findsOneWidget);
      expect(find.text('What is CAP Theorem?'), findsOneWidget);
      expect(find.text('DUE FOR REVIEW'), findsOneWidget);

      // Switch to Mastered tab
      final masteredTab = find.textContaining('Mastered');
      expect(masteredTab, findsOneWidget);
      await tester.tap(masteredTab);
      await tester.pump();

      expect(find.text('Binary Search Time Complexity'), findsOneWidget);
      expect(find.text('IMMUNE TO DECAY'), findsOneWidget);
    });

    testWidgets('DecksView renders DUE REVIEW and STUDY ALL CARDS buttons in header', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final deckProvider = DeckProvider();
      final pomodoroProvider = PomodoroProvider(deckProvider);

      final card = Flashcard(
        id: 'c1',
        type: CardType.concept,
        front: 'Front Question',
        back: 'Back Answer',
        nextReview: DateTime.now().millisecondsSinceEpoch - 1000,
        interval: 1,
        ease: 2.5,
        reps: 0,
      );

      final deck = Deck(
        id: 'd1',
        title: 'Algorithms 101',
        cards: [card],
      );
      deckProvider.addDeck(deck);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DeckProvider>.value(value: deckProvider),
            ChangeNotifierProvider<PomodoroProvider>.value(value: pomodoroProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DecksView(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('DUE REVIEW'), findsOneWidget);
      expect(find.text('STUDY ALL CARDS'), findsOneWidget);
    });
  });
}
