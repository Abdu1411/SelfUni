import Dexie, { Table } from 'dexie';
import { useLiveQuery } from 'dexie-react-hooks';
import { Deck, Card, Folder, Lesson, Course } from './types';

export interface ReviewLog {
  id?: number;
  deckId: string;
  cardId: string;
  grade: string;
  timestamp: number;
}

export interface TimeLog {
  id?: number;
  date: number;
  durationSeconds: number;
}

class AlgoDatabase extends Dexie {
  decks!: Table<Deck, string>;
  reviews!: Table<ReviewLog, number>;
  folders!: Table<Folder, string>;
  lessons!: Table<Lesson, string>;
  courses!: Table<Course, string>;
  timeLogs!: Table<TimeLog, number>;

  constructor() {
    super('AlgoMasterDB');
    this.version(1).stores({
      decks: 'id, title, createdAt',
      reviews: '++id, deckId, cardId, timestamp'
    });
    this.version(2).stores({
      decks: 'id, title, createdAt',
      reviews: '++id, deckId, cardId, timestamp'
    });
    this.version(3).stores({
      decks: 'id, title, folderId, createdAt',
      reviews: '++id, deckId, cardId, timestamp',
      folders: 'id, name, createdAt'
    });
    this.version(4).stores({
      decks: 'id, title, folderId, createdAt',
      reviews: '++id, deckId, cardId, timestamp',
      folders: 'id, name, createdAt',
      lessons: 'id, title, folderId, createdAt'
    });
    this.version(5).stores({
      decks: 'id, title, folderId, createdAt',
      reviews: '++id, deckId, cardId, timestamp',
      folders: 'id, name, createdAt',
      lessons: 'id, title, folderId, createdAt',
      courses: 'id, title, createdAt'
    });
    this.version(6).stores({
      decks: 'id, title, folderId, createdAt',
      reviews: '++id, deckId, cardId, timestamp',
      folders: 'id, name, createdAt',
      lessons: 'id, title, folderId, createdAt',
      courses: 'id, title, createdAt',
      timeLogs: '++id, date, durationSeconds'
    });
  }
}

export const db = new AlgoDatabase();

const EMPTY_ARRAY: any[] = [];

export function useDecks() {
  const rawDecks = useLiveQuery(() => db.decks.toArray(), [], EMPTY_ARRAY);
  const rawFolders = useLiveQuery(() => db.folders.toArray(), [], EMPTY_ARRAY);
  const rawReviews = useLiveQuery(() => db.reviews.toArray(), [], EMPTY_ARRAY);
  const rawLessons = useLiveQuery(() => db.lessons.toArray(), [], EMPTY_ARRAY);
  const rawCourses = useLiveQuery(() => db.courses.toArray(), [], EMPTY_ARRAY);
  const rawTimeLogs = useLiveQuery(() => db.timeLogs.toArray(), [], EMPTY_ARRAY);

  const decks = Array.isArray(rawDecks) ? rawDecks : EMPTY_ARRAY;
  const folders = Array.isArray(rawFolders) ? rawFolders : EMPTY_ARRAY;
  const reviews = Array.isArray(rawReviews) ? rawReviews : EMPTY_ARRAY;
  const lessons = Array.isArray(rawLessons) ? rawLessons : EMPTY_ARRAY;
  const courses = Array.isArray(rawCourses) ? rawCourses : EMPTY_ARRAY;
  const timeLogs = Array.isArray(rawTimeLogs) ? rawTimeLogs : EMPTY_ARRAY;

  const addDeck = async (deck: Deck) => {
    await db.decks.add(deck);
  };

  const deleteDeck = async (id: string) => {
    await db.decks.delete(id);
  };

  const updateDeck = async (deck: Deck) => {
    await db.decks.put(deck);
  };

  const renameDeck = async (deckId: string, title: string) => {
    const deck = await db.decks.get(deckId);
    if (deck && title.trim()) {
      deck.title = title.trim();
      await db.decks.put(deck);
    }
  };

  const updateCard = async (deckId: string, updatedCard: Card) => {
    const deck = await db.decks.get(deckId);
    if (deck) {
      deck.cards = deck.cards.map(card => card.id === updatedCard.id ? updatedCard : card);
      await db.decks.put(deck);
    }
  };

  const addCardToDeck = async (deckId: string, card: Card) => {
    const deck = await db.decks.get(deckId);
    if (deck) {
      deck.cards = [...deck.cards, card];
      await db.decks.put(deck);
    }
  };

  const deleteCardFromDeck = async (deckId: string, cardId: string) => {
    const deck = await db.decks.get(deckId);
    if (deck) {
      deck.cards = deck.cards.filter(card => card.id !== cardId);
      await db.decks.put(deck);
    }
  };

  // Folder Operations
  const addFolder = async (name: string, color?: string): Promise<Folder> => {
    const newFolder: Folder = {
      id: crypto.randomUUID(),
      name: name.trim(),
      color: color || '#2563eb',
      createdAt: Date.now()
    };
    await db.folders.add(newFolder);
    return newFolder;
  };

  const updateFolder = async (id: string, name: string, color?: string) => {
    const folder = await db.folders.get(id);
    if (folder) {
      folder.name = name.trim();
      if (color) folder.color = color;
      await db.folders.put(folder);
    }
  };

  const deleteFolder = async (id: string, deleteDecksInside: boolean = false) => {
    const allDecks = await db.decks.toArray();
    for (const d of allDecks) {
      if (d.folderId === id) {
        if (deleteDecksInside) {
          await db.decks.delete(d.id);
        } else {
          d.folderId = undefined;
          await db.decks.put(d);
        }
      }
    }
    const allLessons = await db.lessons.toArray();
    for (const l of allLessons) {
      if (l.folderId === id) {
        if (deleteDecksInside) {
          await db.lessons.delete(l.id);
        } else {
          l.folderId = undefined;
          await db.lessons.put(l);
        }
      }
    }
    await db.folders.delete(id);
  };

  const moveDeckToFolder = async (deckId: string, folderId?: string) => {
    const deck = await db.decks.get(deckId);
    if (deck) {
      deck.folderId = folderId || undefined;
      await db.decks.put(deck);
    }
  };

  // Lesson Operations
  const addLesson = async (lesson: Lesson) => {
    await db.lessons.add(lesson);
  };

  const addLessonsBulk = async (newLessons: Lesson[]) => {
    await db.lessons.bulkAdd(newLessons);
  };

  const updateLesson = async (lesson: Lesson) => {
    await db.lessons.put(lesson);
  };

  const deleteLesson = async (id: string) => {
    await db.lessons.delete(id);
  };

  const renameLesson = async (id: string, title: string) => {
    const lesson = await db.lessons.get(id);
    if (lesson && title.trim()) {
      lesson.title = title.trim();
      await db.lessons.put(lesson);
    }
  };

  const moveLessonToFolder = async (lessonId: string, folderId?: string) => {
    const lesson = await db.lessons.get(lessonId);
    if (lesson) {
      lesson.folderId = folderId || undefined;
      await db.lessons.put(lesson);
    }
  };

  // Course Operations
  const addCourse = async (course: Course) => {
    await db.courses.add(course);
  };

  const deleteCourse = async (id: string) => {
    await db.courses.delete(id);
  };
  
  const logReview = async (deckId: string, cardId: string, grade: string) => {
    await db.reviews.add({
      deckId,
      cardId,
      grade,
      timestamp: Date.now()
    });
  };

  const logStudyTime = async (durationSeconds: number) => {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    
    // Check if there is already a log for today
    const todaysLog = await db.timeLogs.where('date').equals(today).first();
    if (todaysLog && todaysLog.id) {
      await db.timeLogs.update(todaysLog.id, {
        durationSeconds: todaysLog.durationSeconds + durationSeconds
      });
    } else {
      await db.timeLogs.add({
        date: today,
        durationSeconds: durationSeconds
      });
    }
  };

  // Reset all study statistics and review logs
  const resetAllStats = async () => {
    await db.reviews.clear();
    const allDecks = await db.decks.toArray();
    for (const deck of allDecks) {
      deck.cards = deck.cards.map(card => ({
        ...card,
        interval: 0,
        ease: 2.5,
        reps: 0,
        nextReview: Date.now()
      }));
      await db.decks.put(deck);
    }
  };

  // Stats calculation
  const getStats = () => {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const dayMs = 24 * 60 * 60 * 1000;

    // Calculate Streak
    let streak = 0;
    const reviewDays = new Set(reviews.map(r => {
      const d = new Date(r.timestamp);
      return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
    }));

    if (reviewDays.size > 0) {
      for (let i = 0; i < 365; i++) {
        const checkDay = today - (i * dayMs);
        if (reviewDays.has(checkDay)) {
          streak++;
        } else if (i === 0) {
          // it's okay if they haven't studied yet today
          continue;
        } else {
          break;
        }
      }
    }

    // Calculate Weekly Velocity (Last 7 Days)
    const weekData = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((dayName, idx) => {
      return { day: dayName, cardsReviewed: 0, _dateIndex: idx };
    });
    
    // Sort weekData to start 6 days ago and end today
    const sortedWeekData = [];
    for (let i = 6; i >= 0; i--) {
      const targetDate = new Date(today - (i * dayMs));
      const baseObj = weekData[targetDate.getDay()];
      sortedWeekData.push({ day: baseObj.day, cardsReviewed: 0, timestamp: targetDate.getTime() });
    }

    let weeklyVelocity = 0;
    reviews.forEach(r => {
      if (r.timestamp >= today - (6 * dayMs)) {
        weeklyVelocity++;
        const rDate = new Date(r.timestamp);
        const rDayStart = new Date(rDate.getFullYear(), rDate.getMonth(), rDate.getDate()).getTime();
        const bin = sortedWeekData.find(w => w.timestamp === rDayStart);
        if (bin) bin.cardsReviewed++;
      }
    });

    // Calculate Mastery per deck (as surrogate for category)
    const masteryData = (decks || []).map(deck => {
      const cards = Array.isArray(deck?.cards) ? deck.cards : [];
      const totalCards = cards.length;
      if (totalCards === 0) return { subject: (deck?.title || 'Deck').substring(0, 12), level: 0, fullMark: 100 };
      
      // Calculate based on ease and reps for reviewed cards (unreviewed cards with reps === 0 count as 0%)
      const totalScore = cards.reduce((acc, card) => {
        if (!card?.reps || card.reps === 0) return acc;
        const easeScore = Math.min(100, (((card.ease || 2.5)) / 3.0) * 100);
        const repScore = Math.min(100, (card.reps || 0) * 10);
        return acc + ((easeScore * 0.7) + (repScore * 0.3));
      }, 0);
      
      return {
        subject: (deck?.title || 'Deck').substring(0, 10),
        level: Math.round(totalScore / totalCards),
        fullMark: 100
      };
    }).slice(0, 6);

    // Fill with empty if less than 3 decks to make chart look okay
    while (masteryData.length < 3) {
      masteryData.push({ subject: '---', level: 0, fullMark: 100 });
    }

    let totalStudyTimeToday = 0;
    let totalStudyTimeWeek = 0;

    timeLogs.forEach((log: TimeLog) => {
      if (log.date === today) {
        totalStudyTimeToday += log.durationSeconds;
      }
      if (log.date >= today - (6 * dayMs)) {
        totalStudyTimeWeek += log.durationSeconds;
      }
    });

    return {
      streak,
      weeklyVelocity,
      activityData: sortedWeekData,
      masteryData,
      totalStudyTimeToday,
      totalStudyTimeWeek
    };
  };

  return { 
    decks, 
    folders,
    lessons,
    courses,
    reviews, 
    addDeck, 
    deleteDeck, 
    updateDeck,
    renameDeck,
    updateCard, 
    addCardToDeck, 
    deleteCardFromDeck,
    addFolder,
    updateFolder,
    deleteFolder,
    moveDeckToFolder,
    addLesson,
    addLessonsBulk,
    updateLesson,
    deleteLesson,
    renameLesson,
    moveLessonToFolder,
    addCourse,
    deleteCourse,
    logReview, 
    logStudyTime,
    resetAllStats, 
    stats: getStats() 
  };
}
