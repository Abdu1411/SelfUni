import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/card_model.dart';
import '../../models/lesson_model.dart';
import 'storage_service.dart';

class AIService {
  final StorageService _storageService = StorageService();
  final String _baseUrl = 'https://api.deepseek.com/v1/chat/completions';
  
  Future<String?> _getApiKey() async {
    return await _storageService.getApiKey();
  }

  Future<Map<String, dynamic>> _callDeepSeek(List<Map<String, String>> messages, {bool jsonResponse = true}) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('DeepSeek API key is not configured. Please set it in Settings.');
    }

    final requestBody = {
      'model': 'deepseek-chat',
      'messages': messages,
      'max_tokens': 8192,
    };
    if (jsonResponse) {
      requestBody['response_format'] = {'type': 'json_object'};
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      
      if (jsonResponse) {
        String cleanContent = content.trim();
        // Remove <think>...</think> tags if model outputted reasoning
        cleanContent = cleanContent.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>'), '').trim();
        
        // Trim to outermost JSON boundaries if there is leading/trailing text
        // This will naturally ignore wrapping ```json ... ``` blocks
        final firstBrace = cleanContent.indexOf('{');
        final lastBrace = cleanContent.lastIndexOf('}');
        if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
          cleanContent = cleanContent.substring(firstBrace, lastBrace + 1);
        }

        try {
          return jsonDecode(cleanContent) as Map<String, dynamic>;
        } catch (e) {
          throw Exception('Failed to parse AI response into JSON: $e\nResponse snippet: ${cleanContent.length > 200 ? cleanContent.substring(0, 200) : cleanContent}');
        }
      } else {
        return {'content': content};
      }
    } else {
      throw Exception('Failed to communicate with DeepSeek API (${response.statusCode}): ${response.body}');
    }
  }

  Future<List<Flashcard>> generateDeck({
    required String topic,
    String? rawText,
  }) async {
    final systemPrompt = 'You are an expert computer science instructor. Respond ONLY with a valid JSON object containing a "cards" array.';
    final userPrompt = '''
    You are an expert Computer Science instructor.
    Your mission is to read and analyze the provided topic and/or content and convert it into a comprehensive deck of 15 Anki-style spaced repetition flashcards.
    
    CRITICAL UNIVERSAL CONVERSION RULE - IDIOMATIC CODE:
    - Auto-detect the primary programming language of the topic/content (e.g., Python, C++, Java, JavaScript, Dart, Go, Rust, SQL, etc.) from the content/context. Generate all code snippets and coding challenges in that language. If no specific language is used or mentioned, default to Python or pseudocode.
    - Translate any implementation details into clean, idiomatic, modern code of that detected language.
    - Use LaTeX math notation (\$O(N \\log N)\$, etc.) for all complexity bounds.
    
    CRITICAL CODE-IN-QUESTION INCLUSION RULE:
    - When asking about anything related to code, provide the relevant code snippet directly in the "front" field within a formatted ```language ... ``` code block (using the correct Markdown language identifier for the detected language, e.g. ```python, ```cpp, ```java, ```dart).
    
    MANDATORY ARCHETYPE DISTRIBUTION QUOTA (CRITICAL REQUIREMENT):
    You MUST generate a deck containing ALL 9 ARCHETYPES with the following strict minimums:
    1. 'Implementation' (AT LEAST 2 CARDS): Interactive coding challenges asking the student to write or complete code.
    2. 'Concept' (AT LEAST 1 CARD): Core theoretical intuition, definitions & "Why".
    3. 'Complexity' (AT LEAST 1 CARD): Time & Space Big-O analysis with LaTeX math.
    4. 'Pattern' (AT LEAST 1 CARD): Algorithmic pattern recognition.
    5. 'Cloze' (AT LEAST 1 CARD): Fill-in-the-blank using {{c1::answer}} notation in the question.
    6. 'Comparison' (AT LEAST 1 CARD): Head-to-head comparison.
    7. 'Trace' (AT LEAST 1 CARD): Step-by-step execution simulation.
    8. 'Invariant' (AT LEAST 1 CARD): Loop invariant or correctness proof.
    9. 'Debugging' (AT LEAST 1 CARD): Spotting a bug trap or logical pitfall.
    
    OUTPUT JSON SCHEMA:
    {
      "cards": [
        {
          "type": "Concept" | "Complexity" | "Pattern" | "Cloze" | "Comparison" | "Trace" | "Invariant" | "Debugging" | "Implementation",
          "front": "Markdown and LaTeX question",
          "back": "Detailed Markdown and LaTeX answer",
          "codeSnippet": "Optional code snippet"
        }
      ]
    }
    
    TOPIC / CONTENT:
    Topic: $topic
    
    Web Content / Context:
    ${rawText != null ? rawText.substring(0, rawText.length > 30000 ? 30000 : rawText.length) : 'Generate comprehensive deck on topic.'}
    ''';

    final result = await _callDeepSeek([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ]);

    final List<dynamic> cardsJson = (result['cards'] ?? result['flashcards'] ?? result['deck'] ?? result['data']) as List<dynamic>? ?? [];
    if (cardsJson.isEmpty) {
      throw Exception('AI returned empty flashcard list. Please check your topic and try again.');
    }

    return cardsJson.map((e) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final map = e is Map<String, dynamic> ? e : <String, dynamic>{};
      final front = map['front']?.toString() ?? map['question']?.toString() ?? 'Review topic: $topic';
      final back = map['back']?.toString() ?? map['answer']?.toString() ?? 'Detailed answer for $topic';
      final typeStr = map['type']?.toString() ?? 'Concept';

      return Flashcard(
        id: DateTime.now().millisecondsSinceEpoch.toString() + map.hashCode.toString(),
        type: CardTypeExtension.fromString(typeStr),
        front: front,
        back: back,
        codeSnippet: map['codeSnippet']?.toString(),
        nextReview: now,
        interval: 0,
        ease: 2.5,
        reps: 0,
      );
    }).toList();
  }

  Future<Lesson> generateLesson({
    required String topic,
    String? rawText,
  }) async {
    final systemPrompt = 'You are an elite Computer Science Professor. You write exhaustive, rigorous, textbook-grade lecture notes synthesizing multiple academic sources with formal LaTeX proofs, ASCII diagrams, and production Dart 3.x code.';
    final userPrompt = '''
    Synthesize comprehensive, masterclass-level Computer Science Lecture Notes.
    
    Topic: $topic
    
    Context & Source Material:
    ${rawText != null ? rawText.substring(0, rawText.length > 30000 ? 30000 : rawText.length) : 'Generate exhaustive academic lecture notes on this computer science topic.'}
    
    CRITICAL STRUCTURE & SECTION REQUIREMENTS:
    1. # [Engaging, Authoritative Academic Title]
    2. ## 1. Executive Overview & Mental Models
    3. ## 2. Theoretical Foundations & Mathematical Invariants (LaTeX math \$...\$)
    4. ## 3. Step-by-Step Algorithmic Mechanics & Visual Trace
    5. ## 4. Production Dart 3.x Implementation (in ```dart ... ``` blocks)
    6. ## 5. Rigorous Complexity Analysis (Time & Space)
    7. ## 6. Edge Cases, Pitfalls & Invariants
    8. ## 7. High-Yield Flashcard Review Summary
    
    CRITICAL CODE FORMATTING & SNIPPET PROHIBITION RULE:
    - NEVER use fenced code blocks (```...```) for single-line code snippets, individual expressions, variable names, or one-line function signatures.
    - Single-line code MUST ALWAYS use inline code formatting with single backticks (`like this`).
    - Fenced code blocks (```dart ... ```) are STRICTLY reserved for full, multi-line implementations (at least 2+ lines of code).
    - Prohibit any 1-line block code snippets throughout the notes.
    - NEVER use fenced code blocks with the "text" language identifier (i.e. ```text ... ```) to render plain text, lists, or general descriptions. Fenced blocks must only be used for multi-line programming code.

    CRITICAL TABLE FORMATTING RULE:
    - NEVER put fenced code blocks (```...```) inside markdown table cells. Tables must contain only plain text or inline code (`backticks`).
    - If you need to show a comparison of types, values, or examples that includes code, use a BULLET LIST instead of a table.
    - Do NOT split a single code example across multiple separate fenced code blocks. Each concept should have ONE complete code block.
    - When showing multiple examples (e.g. bool True/False), combine them in a SINGLE fenced code block separated by comments, not separate blocks.
    
    Return ONLY a JSON object:
    {
      "title": "Comprehensive Lecture Note Title",
      "topic": "$topic",
      "content": "Full markdown content with LaTeX math and Dart code"
    }
    ''';

    final result = await _callDeepSeek([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ]);

    final content = result['content']?.toString() ?? result['notes']?.toString() ?? result['lesson']?.toString() ?? '';
    if (content.isEmpty) {
      throw Exception('AI returned empty content for lecture notes. Please try again.');
    }

    return Lesson(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: result['title']?.toString() ?? '$topic - Lecture Notes',
      topic: result['topic']?.toString() ?? topic,
      content: content,
    );
  }

  Future<Map<String, String>> evaluateCode({
    required String prompt,
    required String code,
  }) async {
    final evaluationPrompt = '''
    You are an expert technical interviewer and senior software engineer. Evaluate the student's code submission in the programming language requested by the task prompt.
    
    TASK / PROMPT:
    $prompt
    
    STUDENT'S SUBMITTED CODE:
    $code
    
    EVALUATION INSTRUCTIONS:
    1. Correctness: Does the student's logic correctly handle all core cases and boundary conditions in the target programming language?
    2. Time & Space Complexity: Is the Big-O complexity optimal?
    3. Idiomatic Style: Proper language-specific idioms, patterns, strong/dynamic typing, and safety features.
    4. Feedback: Write a clear, structured review in Markdown.
    
    Grade the submission as one of:
    - "Easy": Flawless, optimal logic.
    - "Good": Correct logic, minor stylistic details.
    - "Again": Broken syntax, logical error, or missed fundamental invariant.
    
    Respond ONLY with a valid JSON object:
    {
      "grade": "Easy" | "Good" | "Again",
      "feedback": "Markdown feedback with constructive analysis and tips"
    }
    ''';

    final result = await _callDeepSeek([
      {'role': 'system', 'content': 'You are an expert software engineering interviewer. Respond ONLY with a valid JSON object containing "grade" and "feedback".'},
      {'role': 'user', 'content': evaluationPrompt},
    ]);

    return {
      'grade': result['grade']?.toString() ?? 'Good',
      'feedback': result['feedback']?.toString() ?? 'Feedback generated.',
    };
  }

  Future<String> chat({
    required List<Map<String, String>> history,
    String? contextText,
  }) async {
    final systemPrompt = '''
    You are an AI Tutor embedded in a spaced-repetition and study app called AlgoMaster SRS.
    Your goal is to help students learn Computer Science concepts through Socratic dialogue.
    If contextText is provided, use it to ground your answers.
    
    Context:
    ${contextText ?? 'None provided'}
    ''';
    
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history,
    ];
    
    final result = await _callDeepSeek(messages, jsonResponse: false);
    return result['content'] as String;
  }

  /// Suggests a clean, professional, short human-readable name based on a JSON/CSV file name and content preview
  Future<String> suggestHumanReadableCourseName({
    required String filename,
    String? sampleContent,
  }) async {
    try {
      final systemPrompt = 'You are an AI educational curriculum assistant. Output ONLY a valid JSON object with a "name" field containing a very short, clean, human-readable course title (maximum 3-4 words). Remove all course codes (e.g. MIT-1801, CS106B), raw timestamps, semester terms (e.g. Fall 2006), file extensions, underscores, or terms like "original".';
      final userPrompt = '''
Suggest a short, clean, human-readable course title (maximum 3-4 words) based on the provided filename and content snippet.

Raw Title: $filename
${sampleContent != null && sampleContent.isNotEmpty ? 'Content Snippet:\n${sampleContent.length > 600 ? sampleContent.substring(0, 600) : sampleContent}' : ''}

Output JSON Schema:
{
  "name": "Short Human Readable Course Name"
}
''';
      final result = await _callDeepSeek([
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ]);

      final suggestedName = result['name']?.toString().trim();
      if (suggestedName != null && suggestedName.isNotEmpty) {
        return suggestedName;
      }
    } catch (_) {
      // Fallback
    }

    String cleaned = filename.replaceAll(RegExp(r'\.[^/.]+$'), '').replaceAll('_', ' ').replaceAll('-', ' ').trim();
    return cleaned.split(' ').where((w) => w.isNotEmpty).map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  Future<String> formatTranscript({
    required String rawTranscript,
  }) async {
    final systemPrompt = 'You are a professional educational editor. You rewrite, paraphrase, simplify, and organize raw speech-to-text transcripts into highly readable, textbook-grade markdown notes with clear titled sections, clean formatting, and formal LaTeX mathematical notation where appropriate.';
    final userPrompt = '''
    Please process and restructure the following raw video lecture transcript. The transcript contains inline timestamps in the format [MM:SS] representing the start time of the spoken content.
    
    1. Divide the content into logical sections and give every section a clear, descriptive header (e.g. ## Introduction, ## Memory Allocation, etc.).
    2. Before every section header (and major subsection/paragraph), insert the closest corresponding timestamp from the raw transcript in the format `[MM:SS]` (e.g., `[05:23] ## Memory Allocation` or `[01:12] ## Introduction`).
    3. Rewrite, paraphrase, simplify, and explain the speech-to-text text so it reads like high-quality, professional educational notes. 
    4. Make it adhere strictly to Markdown style.
    5. If there is mathematical notation (like Big-O, algebra, equations, etc.), format it using formal LaTeX syntax (e.g. \$O(N \\log N)\$).
    
    RAW TRANSCRIPT:
    $rawTranscript
    ''';

    final result = await _callDeepSeek([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ], jsonResponse: false);

    return result['content']?.toString() ?? rawTranscript;
  }
}
