import express from 'express';
import OpenAI from 'openai';
import * as cheerio from 'cheerio';
import path from 'path';
import { fileURLToPath } from 'url';
import { createServer as createViteServer } from 'vite';
import dotenv from 'dotenv';
import multer from 'multer';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const isProd = process.env.NODE_ENV === 'production';
const port = process.env.PORT || 3000;

const app = express();
app.use(express.json());

import fs from 'fs';
import { PDFParse } from 'pdf-parse';

// Ensure public/uploads directory exists
const uploadsDir = path.join(__dirname, 'public', 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Multer storage with original extension preservation
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname) || '';
    const cleanName = path.basename(file.originalname, ext).replace(/[^a-zA-Z0-9_-]/g, '_');
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, `${cleanName}-${uniqueSuffix}${ext}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 } // 50MB limit
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// Serve uploaded media & PDF files
app.use('/uploads', express.static(uploadsDir));

// Media upload endpoint
app.post('/api/media/upload', upload.single('file'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }
  const file = req.file;
  const publicUrl = `/uploads/${file.filename}`;
  res.json({ url: publicUrl, filename: file.originalname });
});

// PDF Import & Parse endpoint
app.post('/api/pdf/parse', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No PDF file uploaded' });
    }

    const filePath = req.file.path;
    const publicUrl = `/uploads/${req.file.filename}`;
    let text = '';
    let numPages = 1;

    try {
      const dataBuffer = fs.readFileSync(filePath);
      if (typeof PDFParse === 'function') {
        const parser = new PDFParse({ data: dataBuffer });
        try {
          const textResult = await parser.getText();
          if (textResult) {
            text = textResult.text || '';
            numPages = (textResult as any).total || (textResult.pages ? textResult.pages.length : 1);
          }
        } finally {
          if (parser && typeof (parser as any).destroy === 'function') {
            await (parser as any).destroy();
          }
        }
      }
    } catch (parseErr) {
      console.warn('PDF text extraction notice (falling back, file stored safely):', parseErr);
    }

    // Clean up text
    const cleanText = text.replace(/\r\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim();

    res.json({
      url: publicUrl,
      filename: req.file.originalname,
      pages: numPages || 1,
      text: cleanText.slice(0, 50000),
      preview: cleanText.slice(0, 800)
    });
  } catch (error: any) {
    console.error('Error processing PDF:', error);
    res.status(500).json({ error: error.message || 'Failed to process PDF' });
  }
});


// ------------------- DeepSeek Client Setup -------------------
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;
if (!DEEPSEEK_API_KEY) {
  console.warn('⚠️  DEEPSEEK_API_KEY is not set. AI features will fail.');
}

// ✅ CORRECT base URL (always /v1)
const DEEPSEEK_BASE_URL = process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com/v1';

const deepseek = new OpenAI({
  apiKey: DEEPSEEK_API_KEY,
  baseURL: DEEPSEEK_BASE_URL,
});

// ✅ Use deepseek-chat (DeepSeek V3) by default (can be overridden with DEEPSEEK_MODEL env var)
const DEEPSEEK_MODEL = process.env.DEEPSEEK_MODEL || 'deepseek-chat';

console.log(`🔧 DeepSeek configured: baseURL=${DEEPSEEK_BASE_URL}, model=${DEEPSEEK_MODEL}`);
// -------------------------------------------------------------

function getYouTubeVideoId(urlStr: string): string | null {
  try {
    const url = new URL(urlStr);
    if (url.hostname.includes('youtube.com')) {
      return url.searchParams.get('v');
    }
    if (url.hostname.includes('youtu.be')) {
      return url.pathname.slice(1).split('?')[0];
    }
  } catch {}
  return null;
}

async function extractYouTubeTranscript(videoId: string): Promise<string | null> {
  try {
    const videoPageRes = await fetch(`https://www.youtube.com/watch?v=${videoId}`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9'
      }
    });
    if (!videoPageRes.ok) return null;
    const html = await videoPageRes.text();
    
    // Look for captionTracks in ytInitialPlayerResponse
    const playerResponseMatch = html.match(/ytInitialPlayerResponse\s*=\s*({.+?});(?:var\s+meta|<\/script|\n)/s);
    if (!playerResponseMatch) return null;
    
    const playerResponse = JSON.parse(playerResponseMatch[1]);
    const captionTracks = playerResponse?.captions?.playerCaptionsTracklistRenderer?.captionTracks;
    if (!captionTracks || !captionTracks.length) return null;
    
    // Prioritize English caption track or fallback to first available
    const enTrack = captionTracks.find((t: any) => t.languageCode === 'en' || t.vssId?.includes('.en')) || captionTracks[0];
    if (!enTrack?.baseUrl) return null;
    
    const transcriptRes = await fetch(enTrack.baseUrl);
    if (!transcriptRes.ok) return null;
    const transcriptXml = await transcriptRes.text();
    
    // Parse XML transcript <text ...>content</text>
    const $ = cheerio.load(transcriptXml, { xmlMode: true });
    const lines: string[] = [];
    $('text').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        // Decode HTML entities
        const decoded = cheerio.load(text).text();
        lines.push(decoded);
      }
    });
    
    if (lines.length > 0) {
      const title = playerResponse?.videoDetails?.title || 'YouTube Video Lecture';
      return `[YouTube Video: ${title}]\n\nTranscript:\n${lines.join(' ')}`;
    }
  } catch (err) {
    console.warn('YouTube transcript extraction failed, falling back to standard page fetch:', err);
  }
  return null;
}

async function extractTextFromUrl(url: string) {
  try {
    // 1. Check if local PDF upload
    if (url.startsWith('/uploads/') || url.toLowerCase().includes('.pdf')) {
      const filename = path.basename(url.split('?')[0]);
      const localPath = path.join(uploadsDir, filename);
      if (fs.existsSync(localPath)) {
        const dataBuffer = fs.readFileSync(localPath);
        if (typeof PDFParse === 'function') {
          const parser = new PDFParse({ data: dataBuffer });
          try {
            const res = await parser.getText();
            if (res && res.text && res.text.trim()) {
              return `[PDF Document: ${filename}]\n\n${res.text.trim().slice(0, 40000)}`;
            }
          } finally {
            if (parser && typeof (parser as any).destroy === 'function') {
              await (parser as any).destroy();
            }
          }
        }
      }
    }

    const ytId = getYouTubeVideoId(url);
    if (ytId) {
      const ytTranscript = await extractYouTubeTranscript(ytId);
      if (ytTranscript && ytTranscript.trim().length > 100) {
        return ytTranscript.slice(0, 40000);
      }
    }

    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      }
    });
    if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
    const html = await response.text();
    const $ = cheerio.load(html);

    // Remove non-content elements
    $('script, style, nav, footer, iframe, img, svg, noscript, header').remove();

    // Extract main text
    const bodyText = $('article, main, .content, #content, body').text();
    return bodyText.replace(/\s+/g, ' ').trim().slice(0, 40000);
  } catch (error) {
    console.error('Error fetching URL:', error);
    throw new Error('Failed to fetch content from URL. Please check the URL or provide a topic title.');
  }
}

const VALID_ARCHETYPES = new Set([
  'Concept',
  'Complexity',
  'Pattern',
  'Cloze',
  'Comparison',
  'Trace',
  'Invariant',
  'Debugging',
  'Implementation'
]);

function normalizeCardArchetypes(cards: any[]): any[] {
  return cards.map(card => {
    if (!card || typeof card !== 'object') return card;
    const frontText = (card.front || '').trim();
    let rawType = (card.type || '').trim();

    // Match case-insensitively to valid archetype
    let detectedType = Array.from(VALID_ARCHETYPES).find(
      arch => arch.toLowerCase() === rawType.toLowerCase()
    );

    // 1. Cloze Deletion check
    if (frontText.includes('{{') || rawType.toLowerCase().includes('cloze')) {
      detectedType = 'Cloze';
    }
    // 2. Implementation check (asks to write/implement code)
    else if (
      /^(write|implement|create|code|complete|develop|build|construct|solve|program)\s+(a\s+|an\s+|the\s+)?(dart\s+)?(function|class|method|algorithm|solution|program|tree|graph|queue|stack|heap|code|snippet)\b/i.test(frontText) ||
      /\b(implement\s+the\s+following|write\s+a\s+dart\s+function|write\s+code\s+to|code\s+the\s+algorithm|implement\s+in\s+dart|coding\s+challenge)\b/i.test(frontText)
    ) {
      detectedType = 'Implementation';
    }
    // 3. Complexity check (asks for Big-O / time / space bounds)
    else if (
      /\b(time\s+complexity|space\s+complexity|worst-case\s+time|best-case|average-case|big-o|asymptotic|O\(|\$\\mathcal\{O\}|\\Theta|tight\s+bound)\b/i.test(frontText) ||
      rawType.toLowerCase().includes('complexity') ||
      rawType.toLowerCase().includes('big-o')
    ) {
      detectedType = 'Complexity';
    }
    // 4. Debugging check (spot bug / edge case / fix error)
    else if (
      /\b(bug|debug|error|what\s+is\s+wrong|fix|flaw|pitfall|null\s+safety\s+issue|exception)\b/i.test(frontText) ||
      rawType.toLowerCase().includes('debug')
    ) {
      detectedType = 'Debugging';
    }
    // 5. Comparison check (compare / trade-off / versus)
    else if (
      /\b(compare|difference\s+between|versus|\bvs\b|trade-off|when\s+to\s+use\s+.*instead\s+of)\b/i.test(frontText) ||
      rawType.toLowerCase().includes('comparison')
    ) {
      detectedType = 'Comparison';
    }
    // 6. Invariant check (loop invariant, proof, mathematical property)
    else if (
      /\b(invariant|loop\s+invariant|correctness\s+proof|induction|termination\s+condition)\b/i.test(frontText) ||
      rawType.toLowerCase().includes('invariant')
    ) {
      detectedType = 'Invariant';
    }
    // 7. Trace check (trace execution, recursion tree, state dry run)
    else if (
      /\b(trace|dry\s+run|step-by-step|what\s+does\s+the\s+following\s+return|output\s+of|execution\s+tree|recursion\s+tree)\b/i.test(frontText) ||
      rawType.toLowerCase().includes('trace')
    ) {
      detectedType = 'Trace';
    }
    // 8. Pattern check (algorithmic pattern / technique trigger)
    else if (
      /\b(pattern|two\s+pointers|sliding\s+window|monotonic|dynamic\s+programming|divide\s+and\s+conquer|greedy|bfs|dfs|backtracking|technique\s+should)\b/i.test(frontText) ||
      rawType.toLowerCase().includes('pattern')
    ) {
      detectedType = 'Pattern';
    }

    card.type = detectedType || 'Concept';

    // If front already embeds a code block, eliminate redundant codeSnippet field to prevent duplicate display
    if (frontText.includes('```') && card.codeSnippet) {
      delete card.codeSnippet;
    }

    return card;
  });
}

function safeParseJSONArray(rawText: string) {
  let text = (rawText || '').trim();
  if (text.startsWith('```')) {
    text = text.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '').trim();
  }

  if (!text) {
    throw new Error('DeepSeek AI returned an empty response. Please try submitting your topic again.');
  }

  try {
    const res = JSON.parse(text);
    let cardsArray: any[] = [];
    if (Array.isArray(res) && res.length > 0) cardsArray = res;
    else if (res && typeof res === 'object') {
      if (Array.isArray(res.cards) && res.cards.length > 0) cardsArray = res.cards;
      else if (Array.isArray(res.data) && res.data.length > 0) cardsArray = res.data;
      else {
        const values = Object.values(res);
        const foundArray = values.find(v => Array.isArray(v) && v.length > 0);
        if (foundArray) cardsArray = foundArray as any[];
      }
    }

    if (cardsArray.length > 0) {
      return normalizeCardArchetypes(cardsArray);
    }
  } catch (e) {
    // Attempt to recover truncated JSON
    const firstBracket = text.indexOf('[');
    const lastObjectEnd = text.lastIndexOf('}');
    if (firstBracket !== -1 && lastObjectEnd !== -1 && lastObjectEnd > firstBracket) {
      try {
        const candidate = text.substring(firstBracket, lastObjectEnd + 1) + ']';
        const res2 = JSON.parse(candidate);
        if (Array.isArray(res2) && res2.length > 0) return normalizeCardArchetypes(res2);
      } catch (err2) {
        // Fall through
      }
    }
    throw new Error(`Failed to parse AI flashcards: ${e instanceof Error ? e.message : String(e)}`);
  }

  throw new Error('AI returned 0 flashcards. Please try a more specific topic.');
}

// ==================== ENDPOINTS ====================

app.post('/api/generate-deck', async (req, res) => {
  try {
    const { url, urls, topic, rawText, startTime, endTime, count } = req.body;
    let contextText = '';

    const allUrls: string[] = Array.isArray(urls)
      ? urls.filter((u): u is string => typeof u === 'string' && u.trim().length > 0)
      : (url && typeof url === 'string' && url.trim() ? [url.trim()] : []);

    if (allUrls.length > 0) {
      const results = await Promise.allSettled(allUrls.map(u => extractTextFromUrl(u)));
      results.forEach((r, idx) => {
        if (r.status === 'fulfilled' && r.value) {
          contextText += `\n\n=== SOURCE ${idx + 1}: ${allUrls[idx]} ===\n${r.value}\n`;
        }
      });
    }

    if (rawText && typeof rawText === 'string' && rawText.trim()) {
      contextText += `\n\n=== USER NOTES & LECTURE TRANSCRIPT ===\n${rawText.trim().slice(0, 20000)}\n`;
    }

    const isClippedVideo = (startTime !== undefined && endTime !== undefined);
    // Standard decks guarantee all 9 archetypes + 2 implementations (min 10 cards)
    const targetCardCount = count ? Math.max(10, Number(count)) : (isClippedVideo ? 3 : 15);

    const effectiveTopic = (topic && topic.trim())
      ? topic.trim()
      : (allUrls[0] ? `Computer Science & Algorithms from ${allUrls[0]}` : 'Computer Science Mastery');

    let systemPrompt = '';
    let userPrompt = '';

    if (isClippedVideo) {
      // Specialized LLM prompt for live lecture timestamp clipping with LaTeX math & Markdown
      systemPrompt = 'You are an elite Computer Science Professor. You synthesize precise, high-yield spaced repetition flashcards from specific video lecture segments with full Markdown and LaTeX math support.';

      userPrompt = `
      You are analyzing a targeted segment of a live computer science lecture video:
      - Video Interval: ${startTime} to ${endTime}
      - Topic: ${effectiveTopic}
      
      TASK:
      Synthesize EXACTLY ${targetCardCount} high-yield, conceptual flashcards covering the EXACT concepts, invariants, and implementation details taught in this specific ${startTime} - ${endTime} segment. (For a 1-minute clip, you must not exceed 3 cards).
      
      MANDATORY FORMATTING & NOTATION REQUIREMENTS:
      1. MATH NOTATION (LaTeX):
         - Use standard LaTeX math notation for all time/space complexity, variables, and math formulas.
         - Inline math: use single dollar signs, e.g. $O(N \\log N)$, $\\mathcal{O}(1)$, $T(n) = 2T(n/2) + O(n)$, $\\lfloor \\frac{n}{2} \\rfloor$.
         - Block math: use double dollar signs, e.g. $$ \\sum_{i=1}^n i = \\frac{n(n+1)}{2} $$.
      
      2. RICH MARKDOWN & CODE:
         - Use clean Markdown styling with bolding, lists, headers, and inline code (\`...\`).
         - All code MUST be valid, idiomatic, and robust inside appropriate \`\`\`language ... \`\`\` blocks.
      
      3. CRITICAL CODE-IN-QUESTION INCLUSION RULE:
         - When asking about anything related to code (e.g. tracing execution, identifying bugs, finding Big-O complexity, loop invariants, or method behavior), you MUST include the relevant code directly in the "front" (question) field inside a formatted \`\`\`language ... \`\`\` block.
         - The code provided in the question must provide the context to reason about WITHOUT giving away the answer/solution being tested.
      
      4. APPROPRIATE CARD TYPES (Choose the best ${targetCardCount} archetypes for this segment):
         - 'Concept': Deep conceptual intuition and "Why".
         - 'Complexity': Precise Time & Space complexity using LaTeX math ($O(...)$).
         - 'Pattern': Problem recognition and when to apply this technique.
         - 'Cloze': Anki cloze deletion with math/code syntax: {{c1::$O(\\log N)$}} or {{c1::list.sublist(mid)}}.
         - 'Implementation': Focused coding challenge testing the core logic from this segment.
         - 'Invariant': Loop invariant, correctness proof, or boundary condition.
      
      OUTPUT FORMAT:
      Respond ONLY with a valid JSON object:
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
      
      CONTEXT & NOTES:
      ${contextText ? contextText.slice(0, 30000) : 'Synthesize targeted cards for this lecture clip.'}
      `;
    } else {
      // Standard comprehensive deck generation prompt
      systemPrompt = 'You are an expert computer science instructor. Respond ONLY with a valid JSON object containing a "cards" array.';

      userPrompt = `
      You are an expert Computer Science instructor.
      Your mission is to read and analyze the provided topic and/or content from a web document / article URL and convert it into a comprehensive deck of ${targetCardCount} Anki-style spaced repetition flashcards.
      
      CRITICAL UNIVERSAL CONVERSION RULE - IDIOMATIC CODE:
      - Translate any implementation details into clean, idiomatic, modern code.
      - Use LaTeX math notation ($O(N \\log N)$, etc.) for all complexity bounds.
      
      CRITICAL CODE-IN-QUESTION INCLUSION RULE:
      - When asking about anything related to code (e.g. analyzing time/space complexity of a function, tracing execution, finding a bug, loop invariants, or explaining how an algorithm works), you MUST provide the relevant code snippet directly in the "front" (question) field within a formatted \`\`\`language ... \`\`\` code block.
      - Ensure the code provided in the question gives the necessary context for the question WITHOUT revealing or giving away the core answer/solution that the student needs to provide.
      
      MANDATORY ARCHETYPE DISTRIBUTION QUOTA (CRITICAL REQUIREMENT):
      You MUST generate a deck containing ALL 9 ARCHETYPES with the following strict minimums:
      1. 'Implementation' (AT LEAST 2 CARDS): Interactive coding challenges asking the student to write or complete code.
      2. 'Concept' (AT LEAST 1 CARD): Core theoretical intuition, definitions & "Why".
      3. 'Complexity' (AT LEAST 1 CARD): Time & Space Big-O analysis with LaTeX math ($O(N \\log N)$, etc.).
      4. 'Pattern' (AT LEAST 1 CARD): Algorithmic pattern recognition (Sliding Window, Two Pointers, DFS/BFS, Monotonic Stack, etc.).
      5. 'Cloze' (AT LEAST 1 CARD): Fill-in-the-blank active recall using {{c1::answer}} notation in the question.
      6. 'Comparison' (AT LEAST 1 CARD): Head-to-head comparison between two algorithms or data structures.
      7. 'Trace' (AT LEAST 1 CARD): Step-by-step execution simulation or dry run.
      8. 'Invariant' (AT LEAST 1 CARD): Loop invariant, correctness proof, or boundary condition.
      9. 'Debugging' (AT LEAST 1 CARD): Spotting a bug trap or logical pitfall.
      
      CRITICAL:
      - Every single card MUST have its "type" property explicitly set to one of the 9 archetypes above.
      - There MUST be at least 2 'Implementation' cards and at least 1 card of each of the other 8 archetypes.
      - NEVER return cards with only 'Concept' or only 'Implementation'.
      
      OUTPUT JSON SCHEMA:
      Respond ONLY with a valid JSON object matching this schema:
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
      Topic: ${effectiveTopic}
      
      Web Content / Context:
      ${contextText ? contextText.slice(0, 30000) : 'Generate comprehensive deck on topic.'}
      `;
    }

    const completion = await deepseek.chat.completions.create({
      model: DEEPSEEK_MODEL,
      messages: [
        {
          role: 'system',
          content: systemPrompt
        },
        {
          role: 'user',
          content: userPrompt
        }
      ],
      response_format: { type: 'json_object' },
      max_tokens: 4096,
    });

    const text = completion.choices[0]?.message?.content || '{}';
    const parsedCards = safeParseJSONArray(text);
    res.json(parsedCards);
  } catch (error: any) {
    console.error('Generate Deck Error:', error);
    res.status(500).json({ error: error.message || 'Failed to generate content with DeepSeek' });
  }
});

app.post('/api/generate-lesson', async (req, res) => {
  try {
    const { url, urls, topic, rawText } = req.body;
    let contextText = '';

    const allUrls: string[] = Array.isArray(urls)
      ? urls.filter((u): u is string => typeof u === 'string' && u.trim().length > 0)
      : (url && typeof url === 'string' && url.trim() ? [url.trim()] : []);

    if (allUrls.length > 0) {
      const results = await Promise.allSettled(allUrls.map(u => extractTextFromUrl(u)));
      results.forEach((r, idx) => {
        if (r.status === 'fulfilled' && r.value) {
          contextText += `\n\n=== SOURCE [${idx + 1}] (${allUrls[idx]}) ===\n${r.value}\n`;
        }
      });
    }

    if (rawText && typeof rawText === 'string' && rawText.trim()) {
      contextText += `\n\n=== USER NOTES & LECTURE TRANSCRIPTS ===\n${rawText.trim().slice(0, 25000)}\n`;
    }

    const effectiveTopic = (topic && topic.trim())
      ? topic.trim()
      : (allUrls[0] ? `Computer Science Notes on ${allUrls[0]}` : 'Computer Science Algorithms & Systems');

    const systemPrompt = 'You are an elite Computer Science Professor, Principal Software Engineer, and ACM Fellow. You write exhaustive, rigorous, textbook-grade lecture notes synthesizing multiple academic and documentation sources with formal LaTeX proofs, ASCII diagrams, and production Dart 3.x code.';

    const userPrompt = `
    Synthesize comprehensive, masterclass-level Computer Science Lecture Notes from the following sources, topic, and materials:
    
    Topic: ${effectiveTopic}
    Sources: ${allUrls.join(', ') || 'Provided topic context'}
    
    Context & Source Material:
    ${contextText ? contextText.slice(0, 35000) : 'Generate exhaustive academic lecture notes on this computer science topic.'}
    
    CRITICAL STRUCTURE & SECTION REQUIREMENTS:
    1. # [Engaging, Authoritative Academic Title]
    2. ## 1. Executive Overview & Mental Models
       - Core intuition, the fundamental problem solved, and real-world system analogies.
    3. ## 2. Theoretical Foundations & Mathematical Invariants
       - Formal definitions and mathematical equations using LaTeX syntax ($O(N \\log N)$, recurrence relations, invariants).
    4. ## 3. Step-by-Step Algorithmic Mechanics & Visual Trace
       - Step-by-step walkthrough accompanied by clear ASCII diagrams or memory trace tables.
    5. ## 4. Production Dart 3.x Implementation
       - 100% sound null safety, strong typing, clean documentation comments, generics, and edge case handling in \`\`\`dart ... \`\`\` codeblocks.
    6. ## 5. Rigorous Complexity Analysis (Time & Space)
       - Formal Big-O proofs for Best, Average, and Worst cases with LaTeX math notation.
    7. ## 6. Edge Cases, Pitfalls & Invariants
       - Common traps, empty/null cases, overflow, and invariant preservation.
    8. ## 7. High-Yield Flashcard Review Summary
       - 3-5 core takeaways for spaced repetition review.
    
    Return ONLY a JSON object:
    {
      "title": "Comprehensive Lecture Note Title",
      "topic": "${effectiveTopic}",
      "sources": ${JSON.stringify(allUrls)},
      "content": "Full markdown content with LaTeX math and Dart code"
    }
    `;

    const completion = await deepseek.chat.completions.create({
      model: DEEPSEEK_MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ],
      response_format: { type: 'json_object' },
      max_tokens: 4096,
    });

    const text = completion.choices[0]?.message?.content || '{}';
    let parsed: any = {};
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = {
        title: `${effectiveTopic} - Lecture Notes`,
        topic: effectiveTopic,
        sources: allUrls,
        content: text
      };
    }

    if (!parsed.sources || !Array.isArray(parsed.sources)) {
      parsed.sources = allUrls;
    }

    res.json(parsed);
  } catch (error: any) {
    console.error('Generate Lesson Error:', error);
    res.status(500).json({ error: error.message || 'Failed to generate lecture notes' });
  }
});

app.post('/api/scrub-lesson', async (req, res) => {
  try {
    const { url, topic, rawText } = req.body;
    let contextText = '';

    if (url) {
      contextText = await extractTextFromUrl(url);
    }

    if (rawText && typeof rawText === 'string' && rawText.trim()) {
      contextText += `\n\n=== USER NOTES & LECTURE TRANSCRIPT ===\n${rawText.trim().slice(0, 25000)}\n`;
    }

    const effectiveTopic = (topic && topic.trim())
      ? topic.trim()
      : (url ? 'Algorithms & Data Structures Lecture' : 'Dart Data Structures and Algorithms Mastery');

    const systemPrompt = 'You are an elite Computer Science Professor and Principal Software Engineer. You write world-class, exhaustive, pedagogical CS lecture notes with rigorous mathematical proofs (LaTeX), ASCII visual traces, and production Dart 3.x implementations.';

    const userPrompt = `
    Analyze the following lecture topic, video context, or notes, and scrub/transform it into comprehensive, structured Computer Science Lecture Notes.
    
    Topic: ${effectiveTopic}
    Video/Article URL: ${url || 'N/A'}
    
    Context & Materials:
    ${contextText ? contextText.slice(0, 30000) : 'Generate comprehensive lecture notes on this computer science topic.'}
    
    CRITICAL REQUIREMENTS:
    1. STRUCTURE & SECTIONS:
       - # [Engaging Academic Title]
       - ## Executive Summary & Core Intuition (The "Why" and real-world analogy)
       - ## Mathematical Foundations & Invariants (Formal definitions using LaTeX math: $O(...)$, $\\mathcal{O}(...)$, sums, recurrence relations)
       - ## Step-by-Step Algorithmic Mechanics (Step walkthrough with ASCII diagram or visual flow)
       - ## Canonical Dart 3.x Implementation (100% sound null safety, strong typing, clean documentation comments)
       - ## Rigorous Complexity Analysis (Formal Time and Space Big-O analysis with proofs)
       - ## Edge Cases, Pitfalls & Invariants (Common failure modes, boundary conditions, zero/null/overflow handling)
       - ## Key Takeaways & Flashcard Study Summary
    
    2. CODE & SYNTAX:
       - ALL code snippets must be 100% idiomatic, modern Dart 3.x inside \`\`\`dart ... \`\`\` codeblocks.
       - Use proper Dart collection types, generics, and null safety.
    
    3. MATH & NOTATION:
       - Use LaTeX syntax for math: single dollar signs \`$O(N \\log N)$\` for inline, double dollar signs \`$$...$$\` for block equations.
    
    Return a JSON object with:
    {
      "title": "Comprehensive Lecture Note Title",
      "topic": "${effectiveTopic}",
      "content": "The complete markdown lecture notes content"
    }
    `;

    const completion = await deepseek.chat.completions.create({
      model: DEEPSEEK_MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ],
      response_format: { type: 'json_object' },
      max_tokens: 4096,
    });

    const text = completion.choices[0]?.message?.content || '{}';
    let parsed: any = {};
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = {
        title: `${effectiveTopic} - Lecture Notes`,
        topic: effectiveTopic,
        content: text
      };
    }

    res.json(parsed);
  } catch (error: any) {
    console.error('Scrub Lesson Error:', error);
    res.status(500).json({ error: error.message || 'Failed to scrub and generate lecture notes' });
  }
});

app.post('/api/evaluate-code', async (req, res) => {
  try {
    const { prompt, code, expectedSolution, language = 'dart' } = req.body;

    const evaluationPrompt = `
    You are an expert technical interviewer, ACM Fellow, and senior Dart 3.x engineer evaluating a student's code submission.
    
    TASK / PROMPT:
    ${prompt}
    
    ${expectedSolution ? `OFFICIAL REFERENCE / EXPECTED SOLUTION:\n${expectedSolution}\n` : ''}
    
    STUDENT'S SUBMITTED DART 3.x CODE:
    \`\`\`dart
    ${code}
    \`\`\`
    
    EVALUATION INSTRUCTIONS:
    1. Correctness: Does the student's Dart logic correctly handle all core cases and boundary conditions?
    2. Time & Space Complexity: Is the Big-O optimal ($O(...)$)?
    3. Idiomatic Dart: Proper strong typing, sound null safety, efficient collections/methods.
    4. Feedback: Write a clear, encouraging, structured review (1-2 paragraphs) in Markdown format highlighting strengths, edge cases, and line-by-line optimizations.
    
    Grade the submission as one of:
    - "Easy": Flawless, optimal logic with idiomatic Dart code.
    - "Good": Correct logic, minor stylistic or minor suboptimal details.
    - "Again": Broken syntax, logical error, infinite loop, or missed fundamental invariant.
    
    Respond ONLY with a valid JSON object:
    {
      "grade": "Easy" | "Good" | "Again",
      "feedback": "Markdown feedback with constructive analysis and tips"
    }
    `;

    const completion = await deepseek.chat.completions.create({
      model: DEEPSEEK_MODEL,
      messages: [
        {
          role: 'system',
          content: 'You are an expert technical interviewer and Dart instructor. Respond ONLY with a valid JSON object containing "grade" and "feedback".'
        },
        {
          role: 'user',
          content: evaluationPrompt
        }
      ],
      response_format: { type: 'json_object' }
    });

    const text = completion.choices[0]?.message?.content || '{}';
    let cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '').trim();
    }
    
    let parsed: any = {};
    try {
      parsed = JSON.parse(cleaned);
    } catch {
      parsed = {
        grade: 'Good',
        feedback: text
      };
    }

    if (!parsed.grade) parsed.grade = 'Good';
    if (!parsed.feedback) parsed.feedback = text;

    res.json(parsed);
  } catch (error: any) {
    console.error('Evaluate Code Error:', error);
    res.status(500).json({ error: error.message || 'Failed to evaluate code with DeepSeek' });
  }
});

app.post('/api/ask-ai', async (req, res) => {
  try {
    const { inquiry, context } = req.body;
    if (!inquiry || !inquiry.trim()) {
      return res.status(400).json({ error: 'Inquiry prompt is required.' });
    }

    const prompt = `
    You are AlgoMaster AI powered by DeepSeek, an elite computer science professor, principal engineer, and master tutor in algorithms, data structures, and the Dart language.
    
    USER'S INQUIRY:
    "${inquiry}"
    
    ${context ? `
    =======================================================
    CURRENT RESOURCE CONTEXT (WHAT THE USER IS CURRENTLY VIEWING):
    =======================================================
    ${context}
    =======================================================
    IMPORTANT CONTEXT INSTRUCTION:
    The user is currently viewing the resource detailed above.
    If the user's question is asking to explain, simplify, optimize, quiz, debug, compare, or elaborate on what they are currently viewing, directly reference and deeply analyze this active context.
    ` : ''}
    
    RESPONSE GUIDELINES:
    1. Answer authoritatively, clearly, and concisely with deep technical depth.
    2. Whenever providing code examples, ALWAYS use modern, idiomatic Dart (null safety, generics, Typed collections, pattern matching, records).
    3. Include exact time complexity (Big-O) and space complexity analysis formatted in LaTeX ($O(1)$, $O(N \\log N)$, $O(V + E)$).
    4. Format with clean GitHub-Flavored Markdown (GFM), including subheadings, code blocks (\`\`\`dart ... \`\`\`), and callout quotes.
    5. If the user asks for a quiz or code challenge on their currently viewed material, generate an active recall question with hidden or progressive hints.
    `;

    const completion = await deepseek.chat.completions.create({
      model: DEEPSEEK_MODEL,
      messages: [
        {
          role: 'system',
          content: 'You are AlgoMaster AI powered by DeepSeek, an elite computer science professor and Dart algorithm expert.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      max_tokens: 4096,
    });

    const answer = completion.choices[0]?.message?.content || 'No response generated.';
    res.json({ answer });
  } catch (error: any) {
    console.error('Ask AI Error:', error);
    res.status(500).json({ error: error.message || 'Failed to process inquiry with DeepSeek AI' });
  }
});

app.post('/api/format-card-archetype', async (req, res) => {
  try {
    const { question, answer, targetType } = req.body;
    if (!question || !answer) {
      return res.status(400).json({ error: 'Question and answer are required.' });
    }

    const archetype = targetType || 'Concept';

    const prompt = `
    You are an expert spaced repetition system (SRS) instructional designer and Dart algorithm coach.
    
    Convert the following AI inquiry & answer into an optimized, high-yield SRS flashcard of archetype: "${archetype}".
    
    ORIGINAL INQUIRY:
    "${question}"
    
    ORIGINAL AI ANSWER:
    "${answer}"
    
    TARGET ARCHETYPE:
    "${archetype}"
    
    ARCHETYPE REQUIREMENTS:
    - Concept: "Why" & core intuition. Front poses an active recall question. Back provides concise, authoritative explanation.
    - Complexity: Big-O analysis. Front asks for time/space complexity and worst-case bounds. If analyzing a code snippet, provide the snippet in the front without revealing the answer. Back gives exact Big-O and mathematical proof ($O(N)$, $O(\\log N)$).
    - Pattern: Recognition of algorithmic patterns (Two Pointers, Monotonic Queue, Sliding Window, Bit Manipulation, etc.).
    - Cloze: Fill-in-the-blank active recall using {{c1::key term or formula}} in the front question for the key invariant, formula, or method call.
    - Comparison: Structured head-to-head comparison highlighting time/space trade-offs between two approaches.
    - Trace: Step-by-step state simulation or recursion tree trace with code snippet provided in front.
    - Invariant: Loop or structural invariants that guarantee correctness.
    - Debugging: A subtle bug trap, edge case, or Dart null-safety pitfall with buggy code snippet in front and correction in back.
    - Implementation: A coding challenge in modern idiomatic Dart with starter signature and test assertions.
    
    CRITICAL CODE-IN-QUESTION RULE:
    - Whenever asking anything related to code (e.g. complexity of a function, finding a bug, tracing state), include the relevant Dart code snippet in the "front" (question) field in a \`\`\`dart ... \`\`\` block, without revealing the answer.
    
    OUTPUT SCHEMA:
    Return a JSON object with:
    {
      "type": "${archetype}",
      "front": "Refined front prompt for active recall (Markdown)",
      "back": "Refined back explanation for active recall (Markdown)",
      "codeSnippet": "Optional Dart code snippet if applicable"
    }
    `;

    const completion = await deepseek.chat.completions.create({
      model: DEEPSEEK_MODEL,
      messages: [
        {
          role: 'system',
          content: 'You are an expert SRS flashcard designer. Respond ONLY with a valid JSON object matching the requested schema.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      response_format: { type: 'json_object' }
    });

    const text = completion.choices[0]?.message?.content || '{}';
    let cardData: any = {};
    try {
      cardData = JSON.parse(text);
    } catch {
      cardData = {};
    }

    res.json({
      type: archetype,
      front: cardData.front || question,
      back: cardData.back || answer,
      codeSnippet: cardData.codeSnippet || undefined
    });
  } catch (error: any) {
    console.error('Format Card Archetype Error:', error);
    res.status(500).json({ error: error.message || 'Failed to convert to card archetype' });
  }
});

app.post('/api/generate-lesson', async (req, res) => {
  try {
    const { url, urls, rawText, topic } = req.body;

    // Normalize source list
    const sourceList: string[] = [];
    if (Array.isArray(urls)) {
      urls.forEach((u: string) => {
        if (u && typeof u === 'string' && u.trim()) sourceList.push(u.trim());
      });
    } else if (typeof urls === 'string' && urls.trim()) {
      urls.split(/[\n,]+/).forEach((u: string) => {
        if (u.trim()) sourceList.push(u.trim());
      });
    }
    if (url && typeof url === 'string' && url.trim() && !sourceList.includes(url.trim())) {
      sourceList.unshift(url.trim());
    }

    let combinedContext = '';
    const validSourcesUsed: string[] = [];

    // Fetch all URLs in parallel
    if (sourceList.length > 0) {
      const fetchResults = await Promise.allSettled(
        sourceList.map(async (srcUrl) => {
          const text = await extractTextFromUrl(srcUrl);
          return { url: srcUrl, text };
        })
      );

      fetchResults.forEach((resItem, idx) => {
        const targetUrl = sourceList[idx];
        if (resItem.status === 'fulfilled' && resItem.value.text) {
          validSourcesUsed.push(targetUrl);
          combinedContext += `\n\n=== SOURCE [${idx + 1}]: ${targetUrl} ===\n${resItem.value.text.slice(0, 15000)}\n`;
        } else {
          console.warn(`Could not extract from URL: ${targetUrl}`);
        }
      });
    }

    // Add pasted raw text / transcripts if provided
    if (rawText && typeof rawText === 'string' && rawText.trim()) {
      combinedContext += `\n\n=== SOURCE [Pasted Transcript / Supplementary Notes]: ===\n${rawText.trim().slice(0, 20000)}\n`;
      validSourcesUsed.push('Pasted Text / Lecture Notes');
    }

    const effectiveTopic = (topic && topic.trim())
      ? topic.trim()
      : (sourceList.length > 0 ? 'Computer Science Multi-Source Lecture Note' : 'Advanced Data Structures & Algorithms');

    const prompt = `
    You are an elite computer science professor and senior software engineer creating definitive lecture notes from multiple multimedia sources.
    
    MISSION:
    Synthesize comprehensive, structured study lecture notes from all the computer science sources provided below (multiple articles, documentation, repository references, and lecture notes).
    Merge the best explanations, architectural diagrams, algorithms, and practical considerations into one master study document.
    Format these as a professor or senior engineer would prepare notes for students, with clear organization, logical progression, and a balance between theory and implementation.
    
    CONTENT REQUIREMENTS:
    1. Core Concepts & Architecture: Extract and thoroughly explain all key computer science concepts, data structures, algorithms, design patterns, and architectural principles across the provided sources.
    2. Code & Implementation: Provide clean, well-commented, and idiomatic Dart (and polyglot where helpful) code snippets to demonstrate how concepts work in practice.
    3. Efficiency Analysis: Always analyze the time and space complexity of algorithms and data structures using Big-O notation ($O(N)$, $O(\\log N)$, $O(1)$, etc.).
    4. Terminology: Define all specialized jargon clearly.
    5. Systems & Trade-offs: Connect software choices to foundational hardware principles (memory hierarchy, CPU cache, heap vs stack allocation) and discuss engineering trade-offs.
    
    FORMATTING GUIDELINES:
    - Use appropriate markdown headings (# Title, ## Section, ### Subsections) to create a logical hierarchical structure.
    - Format all mathematical expressions, complexity bounds, and boolean logic using LaTeX (enclosed in $ or $$ delimiters).
    - Use explicit markdown code blocks with language identifiers (e.g. \`\`\`dart) for all code snippets.
    - Include text-based Mermaid.js diagrams (\`\`\`mermaid ... \`\`\`) whenever a concept benefits from visual representation.
    
    TOPIC:
    ${effectiveTopic}
    
    COMBINED SOURCE CONTENTS (${validSourcesUsed.length} Sources Provided):
    ${combinedContext ? combinedContext.slice(0, 35000) : 'Generate comprehensive lecture notes based on the topic.'}
    
    OUTPUT:
    Return a JSON object with:
    {
      "title": "A concise, authoritative title for the lecture note (e.g. Lecture 04: Self-Balancing Red-Black Trees & Cache Locality)",
      "topic": "The primary subject category",
      "content": "The complete, exhaustive lecture notes in rich Markdown."
    }
    `;

    const completion = await deepseek.chat.completions.create({
      model: DEEPSEEK_MODEL,
      messages: [
        {
          role: 'system',
          content: 'You are an elite computer science professor and senior software engineer. Respond ONLY with a valid JSON object matching the requested schema.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      response_format: { type: 'json_object' },
      max_tokens: 8192,
    });

    let text = completion.choices[0]?.message?.content || '{}';
    if (text.trim().startsWith('```')) {
      text = text.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '').trim();
    }

    const data = JSON.parse(text);
    res.json({
      ...data,
      sources: validSourcesUsed.length > 0 ? validSourcesUsed : (sourceList.length > 0 ? sourceList : undefined),
      sourceUrl: validSourcesUsed[0] || sourceList[0] || undefined
    });
  } catch (error: any) {
    console.error('Generate Lesson Error:', error);
    res.status(500).json({ error: error.message || 'Failed to generate CS lecture notes with DeepSeek' });
  }
});

// ==================== SERVER START ====================

async function startServer() {
  if (isProd) {
    app.use(express.static(path.join(__dirname, 'dist')));
    app.get('*', (req, res) => {
      res.sendFile(path.join(__dirname, 'dist', 'index.html'));
    });
  } else {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  }

  app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
  });
}

startServer();