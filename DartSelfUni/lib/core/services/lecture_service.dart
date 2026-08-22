import '../../models/lecture_model.dart';

class LectureService {
  static final List<Lecture> _sampleLectures = [
    Lecture(
      id: 'lec_live_1',
      title: 'Advanced System Design: Distributed Caching & Redis Patterns',
      instructor: 'Dr. Alex Rivera',
      description: 'Join us live as we explore cache eviction policies, write-through vs write-back strategies, and distributed locking in high-throughput systems.',
      category: 'System Design',
      videoId: 'dQw4w9WgXcQ',
      thumbnailUrl: 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=600',
      status: LectureStatus.live,
      scheduledAt: DateTime.now().subtract(const Duration(minutes: 25)),
      durationMinutes: 60,
      attendeesCount: 428,
      timestamps: [
        LectureTimestamp(time: '00:00', seconds: 0, title: 'Introduction & Agenda'),
        LectureTimestamp(time: '08:15', seconds: 495, title: 'Cache Read Policies (Cache-Aside)'),
        LectureTimestamp(time: '21:30', seconds: 1290, title: 'Cache Write Strategies'),
        LectureTimestamp(time: '42:10', seconds: 2530, title: 'Redis Cluster & Sentinel Overview'),
      ],
      notesSummary: '''
• Cache-Aside pattern reads from cache first; on miss, queries DB and populates cache.
• Write-Through writes to cache and DB synchronously.
• Write-Back writes to cache immediately and updates DB asynchronously for higher throughput.
• LRU (Least Recently Used) and LFU (Least Frequently Used) are key eviction policies.
      ''',
      generatedFlashcards: [
        {
          'front': 'What is the main advantage of Write-Back caching?',
          'back': 'Extremely fast write throughput because database writes happen asynchronously.'
        },
        {
          'front': 'Explain the Cache-Aside pattern workflow.',
          'back': 'Application checks cache first. On miss, reads from DB and updates cache before returning.'
        },
        {
          'front': 'What is the difference between LRU and LFU eviction?',
          'back': 'LRU removes items unaccessed for the longest time; LFU removes items with lowest access frequency.'
        }
      ],
    ),
    Lecture(
      id: 'lec_up_1',
      title: 'Dynamic Programming: Master 2D Grid DP Problems',
      instructor: 'Prof. Elena Rostova',
      description: 'Step-by-step masterclass on formulating recurrence relations for 2D matrix paths, minimum path sum, and subset sum.',
      category: 'Algorithms',
      videoId: 'vLnPwxZdW4w',
      thumbnailUrl: 'https://images.unsplash.com/photo-1509228468518-180dd4864904?w=600',
      status: LectureStatus.upcoming,
      scheduledAt: DateTime.now().add(const Duration(hours: 3)),
      durationMinutes: 75,
      attendeesCount: 184,
      timestamps: [],
      notesSummary: 'Upcoming lecture notes will be generated live during the session.',
      generatedFlashcards: [],
    ),
    Lecture(
      id: 'lec_up_2',
      title: 'Flutter Desktop & Cross-Platform State Management',
      instructor: 'Sarah Jenkins',
      description: 'In-depth exploration of Provider, Riverpod, and clean architectural boundaries in modern Flutter applications.',
      category: 'Mobile & Desktop Dev',
      videoId: 'vLnPwxZdW4w',
      thumbnailUrl: 'https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=600',
      status: LectureStatus.upcoming,
      scheduledAt: DateTime.now().add(const Duration(days: 1, hours: 2)),
      durationMinutes: 90,
      attendeesCount: 310,
      timestamps: [],
      notesSummary: 'Upcoming session schedule.',
      generatedFlashcards: [],
    ),
    Lecture(
      id: 'lec_rec_1',
      title: 'Graph Theory Foundations: BFS, DFS & Dijkstra',
      instructor: 'Dr. Alex Rivera',
      description: 'Comprehensive recorded lecture on graph representations (Adjacency Matrix vs List) and shortest path algorithms.',
      category: 'Algorithms',
      videoId: 'bIA8HEEUxZI',
      thumbnailUrl: 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=600',
      status: LectureStatus.recorded,
      scheduledAt: DateTime.now().subtract(const Duration(days: 4)),
      durationMinutes: 55,
      attendeesCount: 1250,
      timestamps: [
        LectureTimestamp(time: '02:00', seconds: 120, title: 'Adjacency List vs Matrix'),
        LectureTimestamp(time: '14:30', seconds: 870, title: 'Breadth-First Search (BFS) Implementation'),
        LectureTimestamp(time: '31:00', seconds: 1860, title: 'Dijkstra Priority Queue Optimization'),
      ],
      notesSummary: '''
• Adjacency List uses O(V + E) space, ideal for sparse graphs.
• BFS uses a FIFO queue and finds the unweighted shortest path.
• Dijkstra uses a min-priority queue (Binary Heap) with O((V + E) log V) time complexity.
      ''',
      generatedFlashcards: [
        {
          'front': 'What is the time complexity of Dijkstra with Min-Heap?',
          'back': 'O((V + E) log V)'
        },
        {
          'front': 'When is BFS guaranteed to find the shortest path?',
          'back': 'When all edge weights are non-negative and equal (unweighted graph).'
        }
      ],
    ),
    Lecture(
      id: 'lec_rec_2',
      title: 'Database Indexing B-Trees vs LSM-Trees',
      instructor: 'Michael Chen',
      description: 'Deep dive into storage engines: relational B-Tree page layouts vs NoSQL Log-Structured Merge Trees.',
      category: 'System Design',
      videoId: 'bIA8HEEUxZI',
      thumbnailUrl: 'https://images.unsplash.com/photo-1544383835-bda2bc66a55d?w=600',
      status: LectureStatus.recorded,
      scheduledAt: DateTime.now().subtract(const Duration(days: 8)),
      durationMinutes: 80,
      attendeesCount: 940,
      timestamps: [
        LectureTimestamp(time: '05:00', seconds: 300, title: 'B-Tree Anatomy'),
        LectureTimestamp(time: '35:00', seconds: 2100, title: 'LSM-Tree MemTable & SSTables'),
      ],
      notesSummary: 'B-Trees excel at random read operations, while LSM-Trees maximize write throughput by appending sequentially to log files.',
      generatedFlashcards: [
        {
          'front': 'Why are LSM-Trees faster for write-heavy workloads?',
          'back': 'They write sequentially to in-memory MemTables and SSTable files rather than doing random disk rewrites.'
        }
      ],
    ),
  ];

  List<Lecture> getLectures() => _sampleLectures;

  List<Lecture> getLiveLectures() => _sampleLectures.where((l) => l.status == LectureStatus.live).toList();
  List<Lecture> getUpcomingLectures() => _sampleLectures.where((l) => l.status == LectureStatus.upcoming).toList();
  List<Lecture> getRecordedLectures() => _sampleLectures.where((l) => l.status == LectureStatus.recorded).toList();

  List<LectureChatMessage> getSampleChatMessages(String lectureId) {
    return [
      LectureChatMessage(
        id: '1',
        senderName: 'Sarah K.',
        message: 'Hello everyone! Excited for today\'s topic on caching.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
      ),
      LectureChatMessage(
        id: '2',
        senderName: 'Dr. Alex Rivera',
        message: 'Welcome everyone! Feel free to drop questions in chat as we go.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        isInstructor: true,
      ),
      LectureChatMessage(
        id: '3',
        senderName: 'David Chen',
        message: 'Is cache stampede a risk when all keys expire simultaneously?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
        isQuestion: true,
      ),
      LectureChatMessage(
        id: '4',
        senderName: 'Dr. Alex Rivera',
        message: 'Great question David! Yes, we mitigate stampede using probabilistic early expiration or mutex locks.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isInstructor: true,
      ),
    ];
  }

  List<TranscriptSegment> getLectureTranscript(String lectureTitle) {
    return [
      TranscriptSegment(
        startSeconds: 0,
        timeText: '00:00',
        speaker: 'Instructor',
        text: 'Welcome everyone! Today we are diving deep into $lectureTitle, exploring production architecture and optimization strategies.',
      ),
      TranscriptSegment(
        startSeconds: 35,
        timeText: '00:35',
        speaker: 'Instructor',
        text: 'Before we look at code implementations, let\'s establish the core problem statement, initial conditions, and state invariants.',
      ),
      TranscriptSegment(
        startSeconds: 110,
        timeText: '01:50',
        speaker: 'Instructor',
        text: 'Notice how the recurrence relation bounds both time and space complexity. We want to avoid redundant recalculations across subproblems.',
      ),
      TranscriptSegment(
        startSeconds: 210,
        timeText: '03:30',
        speaker: 'Instructor',
        text: 'When handling edge cases, always verify your boundary conditions first. For instance, evaluating empty input arrays or single-element states.',
      ),
      TranscriptSegment(
        startSeconds: 310,
        timeText: '05:10',
        speaker: 'Instructor',
        text: 'Let\'s write out the idiomatic implementation line-by-line and trace execution across memory buffers and pointer states.',
      ),
      TranscriptSegment(
        startSeconds: 450,
        timeText: '07:30',
        speaker: 'Instructor',
        text: 'Notice the memory layout here. Keeping variables in local cache registers dramatically reduces latency overhead in high-throughput loops.',
      ),
      TranscriptSegment(
        startSeconds: 600,
        timeText: '10:00',
        speaker: 'Instructor',
        text: 'To summarize this section, maintaining structural invariants ensures optimal logarithmic performance under high concurrency loads.',
      ),
      TranscriptSegment(
        startSeconds: 780,
        timeText: '13:00',
        speaker: 'Instructor',
        text: 'Let me pause here for questions. Notice in the diagram how the data flow avoids bottleneck points.',
      ),
    ];
  }
}
