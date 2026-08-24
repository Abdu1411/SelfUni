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
    final systemPrompt = 'You are an expert academic instructor. Respond ONLY with a valid JSON object containing a "cards" array.';
    final userPrompt = '''
    You are an expert academic and technical instructor.
    Your mission is to read and analyze the provided topic and/or content and convert it into a comprehensive deck of 15 Anki-style spaced repetition flashcards.
    
    CRITICAL UNIVERSAL CONVERSION RULE - IDIOMATIC CODE / SUBJECT DETECT:
    - Auto-detect the primary subject of the topic/content. If the topic involves algorithms, data structures, programming, or coding in general, auto-detect the programming language and generate code snippets/challenges in that language.
    - If the topic is a non-programming subject (e.g., mathematics, science, history, law, medicine, finance), focus card content on key conceptual relationships, formulas, definitions, and explanations.
    - Use LaTeX math notation (\$O(N \\log N)\$, \$E = mc^2\$, etc.) for all equations and complexity bounds.
    
    CRITICAL CODE-IN-QUESTION INCLUSION RULE:
    - When asking about anything related to code, provide the relevant code snippet directly in the "front" field within a formatted ```language ... ``` code block.
    
    MANDATORY ARCHETYPE DISTRIBUTION QUOTA (CRITICAL REQUIREMENT):
    You MUST generate a deck containing a mixture of the following archetypes:
    1. 'Implementation' (Coding challenges) OR 'Explain' (Conceptual explanations):
       - If the topic involves coding/programming, you MUST generate AT LEAST 2 'Implementation' cards (interactive coding challenges asking the student to write or complete code).
       - If the topic is non-programming or theoretical, you MUST generate AT LEAST 2 'Explain' cards (conceptual questions asking the student to write a detailed explanation of a topic in their own words) instead of 'Implementation' cards.
    2. 'Concept' (AT LEAST 1 CARD): Core theoretical intuition, definitions & "Why".
    3. 'Complexity' (AT LEAST 1 CARD): Time/space complexity or structural complexity analysis.
    4. 'Pattern' (AT LEAST 1 CARD): Pattern recognition (algorithmic templates or subject-specific frameworks).
    5. 'Cloze' (AT LEAST 1 CARD): Fill-in-the-blank using {{c1::answer}} notation in the question.
    6. 'Comparison' (AT LEAST 1 CARD): Head-to-head comparison.
    7. 'Trace' (AT LEAST 1 CARD): Step-by-step state tracing or process simulation.
    8. 'Invariant' (AT LEAST 1 CARD): System invariants, structural rules, or fundamental correctness truths.
    9. 'Debugging' (AT LEAST 1 CARD): Spotting a bug, error, logical pitfall, or factual misconception.
    
    OUTPUT JSON SCHEMA:
    {
      "cards": [
        {
          "type": "Concept" | "Complexity" | "Pattern" | "Cloze" | "Comparison" | "Trace" | "Invariant" | "Debugging" | "Implementation" | "Explain",
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

  Future<Map<String, String>> evaluateExplanation({
    required String prompt,
    required String explanation,
  }) async {
    final evaluationPrompt = '''
    You are an expert academic tutor. Evaluate the student's open-ended explanation/answer to the following conceptual question.
    
    QUESTION / PROMPT:
    $prompt
    
    STUDENT'S EXPLANATION:
    $explanation
    
    EVALUATION INSTRUCTIONS:
    1. Accuracy: Did the student explain the concept correctly?
    2. Completeness: Did they address all key points of the question?
    3. Clarity: Is the explanation clear, logical, and well-structured?
    4. Feedback: Write a clear, structured review in Markdown.
    
    Grade the submission as one of:
    - "Easy": Complete, accurate, and exceptionally clear.
    - "Good": Mostly correct and clear, with minor omissions or slight inaccuracies.
    - "Again": Major misconceptions, incorrect facts, or completely missed the point.
    
    Respond ONLY with a valid JSON object:
    {
      "grade": "Easy" | "Good" | "Again",
      "feedback": "Markdown feedback with constructive analysis, corrections, and tips"
    }
    ''';

    final result = await _callDeepSeek([
      {'role': 'system', 'content': 'You are an expert academic tutor. Respond ONLY with a valid JSON object containing "grade" and "feedback".'},
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
    2. Place the closest corresponding timestamp from the raw transcript on its own line immediately ABOVE every section header (and major subsection/paragraph), in the format `[MM:SS]` (e.g.:
       [01:12]
       ## Introduction
       
       or
       
       [05:23]
       ## Memory Allocation). Do NOT place the timestamp on the same line as the header, as that breaks Markdown formatting.
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

  /// Translates lecture / study notes into Arabic while preserving Markdown structure, code blocks, and LaTeX math formulas.
  Future<String> translateNotesToArabic({
    required String notes,
  }) async {
    if (notes.trim().isEmpty) return notes;

    try {
      final apiKey = await _getApiKey();
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        final systemPrompt = '''
You are an expert academic translator and Computer Science professor specializing in English-to-Arabic technical translation.
Translate the provided study / lecture notes from English to natural, precise, and academically rigorous Arabic while preserving the exact original Markdown formatting.

MANDATORY RULES:
1. PRESERVE ALL MARKDOWN SYNTAX: Keep all headers (#, ##, ###), bullet lists (*, -), numbered lists, tables, callout blockquotes ([!NOTE], [!TIP], [!IMPORTANT], [!WARNING], [!CAUTION]), bold (**text**), italics (*text*), and image syntax (![alt](path)).
2. DO NOT TRANSLATE CODE: Keep all code inside fenced code blocks (```...```) and inline backticks (`...`) verbatim without altering syntax, variable names, functions, or language keywords.
3. DO NOT TRANSLATE LATEX MATH: Preserve all LaTeX math expressions (\$...\$ and \$\$...\$\$) verbatim (e.g. \$O(N \\log N)\$, \$E = mc^2\$).
4. ACCURATE TECHNICAL ARABIC: Translate Computer Science and technical terms into accepted Arabic academic terminology, optionally including the English term in parentheses when clarifying for students (e.g. "شجرة البحث الثنائية (Binary Search Tree)").
5. OUTPUT ONLY THE TRANSLATED TEXT: Do NOT include any intro, pleasantries, explanations, or commentary. Output ONLY the translated Markdown.
''';

        final userPrompt = '''
Translate the following notes to Arabic:

$notes
''';

        final result = await _callDeepSeek([
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ], jsonResponse: false);

        final translated = result['content']?.toString().trim();
        if (translated != null && translated.isNotEmpty) {
          return translated;
        }
      }
    } catch (_) {
      // Fallback if DeepSeek is unavailable or encounters an error
    }

    return await _fallbackTranslateToArabic(notes);
  }

  Future<String> _fallbackTranslateToArabic(String text) async {
    if (text.trim().isEmpty) return text;
    try {
      final lines = text.split('\n');
      final buffer = StringBuffer();
      bool inCodeBlock = false;
      List<String> textLinesToTranslate = [];

      Future<void> flushTextLines() async {
        if (textLinesToTranslate.isEmpty) return;
        final joined = textLinesToTranslate.join('\n');
        textLinesToTranslate.clear();
        if (joined.trim().isEmpty) {
          buffer.writeln(joined);
          return;
        }
        try {
          final url = Uri.parse(
            'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=ar&dt=t&q=${Uri.encodeComponent(joined)}',
          );
          final response = await http.get(url).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            if (decoded is List && decoded.isNotEmpty && decoded[0] is List) {
              final translatedParts = (decoded[0] as List)
                  .map((part) => (part is List && part.isNotEmpty) ? part[0]?.toString() ?? '' : '')
                  .join();
              if (translatedParts.isNotEmpty) {
                buffer.writeln(translatedParts);
                return;
              }
            }
          }
        } catch (_) {}
        buffer.writeln(joined);
      }

      for (final line in lines) {
        if (line.trim().startsWith('```')) {
          await flushTextLines();
          inCodeBlock = !inCodeBlock;
          buffer.writeln(line);
          continue;
        }
        if (inCodeBlock) {
          buffer.writeln(line);
          continue;
        }
        textLinesToTranslate.add(line);
        if (textLinesToTranslate.length >= 25) {
          await flushTextLines();
        }
      }
      await flushTextLines();
      final result = buffer.toString().trim();
      return result.isNotEmpty ? result : text;
    } catch (_) {
      return text;
    }
  }

  /// Detects the primary natural language and text direction (RTL/LTR) of a note using DeepSeek AI, with heuristic fallback.
  Future<Map<String, dynamic>> detectNoteLanguage({required String text}) async {
    if (text.trim().isEmpty) {
      return {'language': 'English', 'isRtl': false, 'code': 'en'};
    }

    try {
      final apiKey = await _getApiKey();
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        final systemPrompt = 'You are a linguistic analyzer. Identify the primary natural language and text direction of the text. Respond ONLY with a valid JSON object.';
        final sample = text.length > 600 ? text.substring(0, 600) : text;
        final userPrompt = '''
Identify the primary language and text direction of this note text snippet.
Text Snippet:
$sample

JSON Output schema:
{
  "language": "Arabic" | "English" | "Persian" | "Hebrew" | "Urdu" | "Spanish" | "French" | "German" | "Chinese" | "Japanese" | "Russian" | "Other",
  "isRtl": true | false,
  "code": "ar" | "en" | "fa" | "he" | "ur" | "es" | "fr" | "de" | "zh" | "ja" | "ru"
}
''';

        final result = await _callDeepSeek([
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ], jsonResponse: true);

        final isRtl = result['isRtl'] == true || (result['isRtl']?.toString().toLowerCase() == 'true');
        return {
          'language': result['language']?.toString() ?? (isRtl ? 'Arabic' : 'English'),
          'isRtl': isRtl,
          'code': result['code']?.toString() ?? (isRtl ? 'ar' : 'en'),
        };
      }
    } catch (_) {}

    return detectLanguageHeuristic(text);
  }

  /// Fast local script heuristic to determine language and RTL direction without network call.
  static Map<String, dynamic> detectLanguageHeuristic(String text) {
    if (text.trim().isEmpty) {
      return {'language': 'English', 'isRtl': false, 'code': 'en'};
    }

    // Strip code blocks and LaTeX math before analyzing natural language characters
    final clean = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'`[^`]*`'), '')
        .replaceAll(RegExp(r'\$\$[\s\S]*?\$\$'), '')
        .replaceAll(RegExp(r'\$[^\$]*\$'), '');

    int arabicChars = 0;
    int hebrewChars = 0;
    int latinChars = 0;
    int cjkChars = 0;
    int cyrillicChars = 0;

    for (final rune in clean.runes) {
      // Arabic, Persian, Urdu, etc.
      if ((rune >= 0x0600 && rune <= 0x06FF) ||
          (rune >= 0x0750 && rune <= 0x077F) ||
          (rune >= 0x08A0 && rune <= 0x08FF) ||
          (rune >= 0xFB50 && rune <= 0xFDFF) ||
          (rune >= 0xFE70 && rune <= 0xFEFF)) {
        arabicChars++;
      } else if (rune >= 0x0590 && rune <= 0x05FF) {
        hebrewChars++;
      } else if ((rune >= 0x0041 && rune <= 0x005A) || (rune >= 0x0061 && rune <= 0x007A)) {
        latinChars++;
      } else if (rune >= 0x4E00 && rune <= 0x9FFF) {
        cjkChars++;
      } else if (rune >= 0x0400 && rune <= 0x04FF) {
        cyrillicChars++;
      }
    }

    if (arabicChars > 0 && arabicChars >= (latinChars * 0.25)) {
      return {'language': 'Arabic', 'isRtl': true, 'code': 'ar'};
    }
    if (hebrewChars > 0 && hebrewChars >= (latinChars * 0.25)) {
      return {'language': 'Hebrew', 'isRtl': true, 'code': 'he'};
    }
    if (cjkChars > latinChars) {
      return {'language': 'Chinese', 'isRtl': false, 'code': 'zh'};
    }
    if (cyrillicChars > latinChars) {
      return {'language': 'Russian', 'isRtl': false, 'code': 'ru'};
    }
    return {'language': 'English', 'isRtl': false, 'code': 'en'};
  }

  /// Returns true if the text contains predominant RTL script (Arabic, Hebrew, Persian, etc.).
  static bool isRtlContent(String text) {
    return detectLanguageHeuristic(text)['isRtl'] == true;
  }

  /// Generates insightful conceptual and analytical questions testing mastery of the given note.
  Future<List<Map<String, String>>> generateMasteryQuestions({
    required String noteContent,
    int count = 3,
  }) async {
    if (noteContent.trim().isEmpty) return [];

    try {
      final apiKey = await _getApiKey();
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        final sample = noteContent.length > 2500 ? noteContent.substring(0, 2500) : noteContent;
        final systemPrompt = '''
You are an expert tutor creating an active-recall mastery quiz based on the student's study notes.
Generate exactly $count concise, deep conceptual/application questions that test real understanding.
For each question, provide an ideal, complete reference answer.

Output ONLY a valid JSON object:
{
  "questions": [
    {
      "question": "What is the key invariant in ...?",
      "idealAnswer": "The key invariant is that ..."
    }
  ]
}
''';
        final userPrompt = 'Notes:\n$sample';

        final response = await _callDeepSeek([
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ], jsonResponse: true);

        if (response['questions'] is List) {
          final list = response['questions'] as List;
          return list
              .map((item) => item is Map
                  ? {
                      'question': item['question']?.toString() ?? '',
                      'idealAnswer': item['idealAnswer']?.toString() ?? '',
                    }
                  : <String, String>{})
              .where((item) => item['question'] != null && item['question']!.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}

    // Resilient fallback generator based on note structure
    return _generateFallbackMasteryQuestions(noteContent, count: count);
  }

  List<Map<String, String>> _generateFallbackMasteryQuestions(String content, {int count = 3}) {
    final lines = content.split('\n');
    final headers = <String>[];
    final bullets = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#') && trimmed.replaceAll('#', '').trim().isNotEmpty) {
        headers.add(trimmed.replaceAll(RegExp(r'^#+\s*'), ''));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ') || trimmed.startsWith('> ')) {
        final text = trimmed.substring(2).trim();
        if (text.length > 15) bullets.add(text);
      }
    }

    final questions = <Map<String, String>>[];

    for (final header in headers) {
      if (questions.length >= count) break;
      questions.add({
        'question': 'Explain the key concepts and mechanisms behind "$header".',
        'idealAnswer': 'A complete explanation of $header covering its definition, properties, and practical applications as outlined in the notes.',
      });
    }

    for (final bullet in bullets) {
      if (questions.length >= count) break;
      questions.add({
        'question': 'What are the main insights and details regarding: "$bullet"?',
        'idealAnswer': bullet,
      });
    }

    if (questions.isEmpty) {
      questions.add({
        'question': 'Summarize the core takeaways and principles from these study notes in your own words.',
        'idealAnswer': 'Key principles and main concepts summarized directly from the lecture notes.',
      });
    }

    return questions;
  }

  /// Grades a student's typed answer against the ideal benchmark answer.
  Future<Map<String, dynamic>> gradeMasteryAnswer({
    required String question,
    required String idealAnswer,
    required String userAnswer,
  }) async {
    if (userAnswer.trim().isEmpty) {
      return {
        'isCorrect': false,
        'scorePercentage': 0,
        'feedback': 'No answer was provided.',
        'idealComparison': idealAnswer,
      };
    }

    try {
      final apiKey = await _getApiKey();
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        final systemPrompt = '''
You are an encouraging but rigorous academic evaluator.
Evaluate the student's answer against the ideal reference answer for the given question.
Determine if the student understands the core concept (grant credit if the essence is correct even if phrasing differs).

Output ONLY a valid JSON object:
{
  "isCorrect": true,
  "scorePercentage": 85,
  "feedback": "Great explanation! You captured the main point...",
  "idealComparison": "Key elements to remember: ..."
}
''';
        final userPrompt = '''
Question: $question
Ideal Benchmark Answer: $idealAnswer
Student's Typed Answer: $userAnswer
''';

        final response = await _callDeepSeek([
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ], jsonResponse: true);

        final isCorrect = response['isCorrect'] == true ||
            (response['isCorrect']?.toString().toLowerCase() == 'true') ||
            ((int.tryParse(response['scorePercentage']?.toString() ?? '0') ?? 0) >= 60);

        final score = (int.tryParse(response['scorePercentage']?.toString() ?? '0') ?? (isCorrect ? 100 : 30)).clamp(0, 100);

        return {
          'isCorrect': isCorrect,
          'scorePercentage': score,
          'feedback': response['feedback']?.toString() ?? (isCorrect ? 'Correct! Good understanding.' : 'Needs review.'),
          'idealComparison': response['idealComparison']?.toString() ?? idealAnswer,
        };
      }
    } catch (_) {}

    // Fallback heuristic evaluation
    final userWords = userAnswer.toLowerCase().split(RegExp(r'\W+')).where((w) => w.length > 3).toSet();
    final idealWords = idealAnswer.toLowerCase().split(RegExp(r'\W+')).where((w) => w.length > 3).toSet();

    if (idealWords.isEmpty || userWords.isEmpty) {
      final isNotEmpty = userAnswer.trim().length >= 10;
      return {
        'isCorrect': isNotEmpty,
        'scorePercentage': isNotEmpty ? 70 : 20,
        'feedback': isNotEmpty ? 'Answer recorded.' : 'Please provide more detail.',
        'idealComparison': idealAnswer,
      };
    }

    final intersection = userWords.intersection(idealWords);
    final ratio = intersection.length / idealWords.length;
    final isCorrect = ratio >= 0.25 || userAnswer.trim().length >= 30;
    final score = (ratio * 100).round().clamp(isCorrect ? 60 : 20, 100);

    return {
      'isCorrect': isCorrect,
      'scorePercentage': score,
      'feedback': isCorrect
          ? 'Well done! You demonstrated understanding of the core concepts.'
          : 'Review this concept: key benchmark points were missed.',
      'idealComparison': idealAnswer,
    };
  }
}
