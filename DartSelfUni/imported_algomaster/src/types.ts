export type CardType = 
  | 'Concept' 
  | 'Complexity' 
  | 'Pattern' 
  | 'Cloze' 
  | 'Comparison' 
  | 'Trace' 
  | 'Invariant' 
  | 'Debugging' 
  | 'Implementation';

export const ARCHETYPE_CONFIG: Record<
  CardType,
  { label: string; icon: string; bg: string; text: string; border: string }
> = {
  Concept: { label: 'Concept', icon: '💡', bg: 'bg-amber-50', text: 'text-amber-800', border: 'border-amber-200' },
  Complexity: { label: 'Complexity', icon: '⚡', bg: 'bg-purple-50', text: 'text-purple-800', border: 'border-purple-200' },
  Pattern: { label: 'Pattern', icon: '🎯', bg: 'bg-blue-50', text: 'text-blue-800', border: 'border-blue-200' },
  Cloze: { label: 'Cloze Deletion', icon: '🧩', bg: 'bg-emerald-50', text: 'text-emerald-800', border: 'border-emerald-200' },
  Comparison: { label: 'Comparison', icon: '⚖️', bg: 'bg-indigo-50', text: 'text-indigo-800', border: 'border-indigo-200' },
  Trace: { label: 'Trace', icon: '🔍', bg: 'bg-cyan-50', text: 'text-cyan-800', border: 'border-cyan-200' },
  Invariant: { label: 'Invariant', icon: '🛡️', bg: 'bg-teal-50', text: 'text-teal-800', border: 'border-teal-200' },
  Debugging: { label: 'Debugging', icon: '🐛', bg: 'bg-rose-50', text: 'text-rose-800', border: 'border-rose-200' },
  Implementation: { label: 'Dart Coding', icon: '💻', bg: 'bg-sky-50', text: 'text-sky-800', border: 'border-sky-200' },
};

export interface Card {
  id: string;
  type: CardType;
  front: string;
  back: string;
  codeSnippet?: string;
  
  // SRS data
  nextReview: number;
  interval: number;
  ease: number;
  reps: number;
}

export interface Folder {
  id: string;
  name: string;
  color?: string;
  createdAt: number;
}

export interface Deck {
  id: string;
  title: string;
  folderId?: string;
  cards: Card[];
  createdAt: number;
}

export interface Lesson {
  id: string;
  title: string;
  topic: string;
  sourceUrl?: string;
  sources?: string[];
  content: string;
  folderId?: string;
  createdAt: number;
  videoUrl?: string; // YouTube embed URL for live courses
  pdfUrl?: string; // Uploaded PDF URL for in-app viewing
  pdfFilename?: string; // Original uploaded PDF filename
  pdfPages?: number; // Total number of pages in the PDF
  lastWatchedTime?: number; // Last playback timestamp in seconds
  multimedia?: MediaItem[]; // Array of attached media items
}

// New type for multimedia items
export type MediaItem = {
  id: string;
  type: 'image' | 'audio' | 'pdf' | 'video' | 'other';
  url: string;
  caption?: string;
};

// --- Course Export Types ---
export interface CourseItem {
  id: string;
  title: string;
  type: 'video' | 'pdf' | 'html' | 'resource' | 'unknown';
  fileKey?: string; // The UUID in content_map.json
  path?: string; // The relative path in the local directory
  description?: string;
  isCompleted?: boolean;
}

export interface CourseModule {
  id: string;
  title: string;
  items: CourseItem[];
}

export interface Course {
  id: string;
  title: string;
  description: string;
  instructors: string[];
  coverImageUrl?: string; // We can use an object URL or local path
  modules: CourseModule[];
  directoryHandle?: any; // FileSystemDirectoryHandle (any to avoid TS dom lib errors if not configured)
  createdAt: number;
  lastAccessed?: number;
}
