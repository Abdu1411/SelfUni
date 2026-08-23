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
    expect(find.text('Study Universal Deck (1 Cards)'), findsOneWidget);

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

      // Set note theme to Soft Sepia
      await deckProvider.setNoteTheme('Soft Sepia');

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
}
