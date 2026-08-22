import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:selfuni/models/card_model.dart';
import 'package:selfuni/models/deck_model.dart';
import 'package:selfuni/models/lesson_model.dart';
import 'package:selfuni/providers/active_view_provider.dart';
import 'package:selfuni/providers/deck_provider.dart';
import 'package:selfuni/views/dashboard_view.dart';
import 'package:selfuni/views/lesson_detail_view.dart';
import 'package:selfuni/views/studio_view.dart';
import 'package:selfuni/views/study_session_view.dart';
import 'package:selfuni/widgets/common/markdown_view.dart';

void main() {
  testWidgets('LessonDetailView renders Quick Actions buttons properly', (WidgetTester tester) async {
    final sampleLesson = Lesson(
      id: 'test-lesson-1',
      title: 'Dynamic Programming Patterns',
      topic: 'Algorithms',
      content: '# Dynamic Programming\n\nThis note explains memoization and tabulation.',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ActiveViewProvider()),
          ChangeNotifierProvider(create: (_) => DeckProvider()),
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

    // 1. When opened normally (no due cards), shows caught up state with Relearn button (not a black screen)
    await tester.pumpWidget(
      MaterialApp(
        home: StudySessionView(deck: deck),
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

    final deckProvider = DeckProvider();
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
      ChangeNotifierProvider.value(
        value: deckProvider,
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
    expect(find.text('Universal Deck (1 Cards)'), findsOneWidget);

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

    final deckProvider = DeckProvider();
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
      ChangeNotifierProvider.value(
        value: deckProvider,
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

  testWidgets('MarkdownView renders GitHub-flavored Markdown, alerts, and code blocks using flutter_markdown_plus', (WidgetTester tester) async {
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

    expect(find.text('NOTE'), findsOneWidget);
    expect(find.text('This is a key theoretical note about directed acyclic graphs.'), findsOneWidget);
    expect(find.text('Complexity Table'), findsOneWidget);
    expect(find.text('DART'), findsOneWidget);
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

    final RenderBox renderBox = tester.renderObject(codeBlockFinder);
    // On 1200px wide screen, 40% of width = 480px
    expect(renderBox.size.width, closeTo(480, 5));
  });
}
