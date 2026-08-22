import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { ArrowLeft, PlayCircle, FileText, Book, Sparkles, CheckCircle2, ChevronRight, Video, FileCode } from 'lucide-react';
import { useDecks } from '../store';
import { Course, CourseModule, CourseItem } from '../types';
import { useActiveView } from '../context/ActiveViewContext';
import * as pdfjsLib from 'pdfjs-dist';
import pdfWorker from 'pdfjs-dist/build/pdf.worker.mjs?url';

pdfjsLib.GlobalWorkerOptions.workerSrc = pdfWorker;

export function CourseViewer() {
  const { courseId } = useParams<{ courseId: string }>();
  const { courses } = useDecks();
  const { setActiveResource } = useActiveView();
  const course = courses.find((c) => c.id === courseId);

  const [activeItem, setActiveItem] = useState<CourseItem | null>(null);
  const [mediaUrl, setMediaUrl] = useState<string | null>(null);
  const [htmlContent, setHtmlContent] = useState<string | null>(null);
  const [sourceText, setSourceText] = useState<string>('');
  const [htmlVideoLinks, setHtmlVideoLinks] = useState<{url: string, label: string}[]>([]);
  const [error, setError] = useState<string | null>(null);
  
  // Set first item active on load
  useEffect(() => {
    if (course && !activeItem && course.modules.length > 0 && course.modules[0].items.length > 0) {
      setActiveItem(course.modules[0].items[0]);
    }
  }, [course, activeItem]);

  // Load media when activeItem changes
  useEffect(() => {
    if (!activeItem || !course?.directoryHandle || !activeItem.path) return;

    let objectUrl: string | null = null;
    let extractedText = '';
    setError(null);
    setMediaUrl(null);
    setHtmlContent(null);
    setSourceText('');
    setActiveResource(null);

    const loadContent = async () => {
      try {
        // Request permissions if not granted (needed when reopening app)
        const opts = { mode: 'read' as const };
        if ((await course.directoryHandle.queryPermission(opts)) !== 'granted') {
          const perm = await course.directoryHandle.requestPermission(opts);
          if (perm !== 'granted') throw new Error('Permission to access directory denied.');
        }

        const findFileByName = async (dirHandle: any, filename: string): Promise<any> => {
          for await (const entry of dirHandle.values()) {
            if (entry.kind === 'file' && entry.name === filename) {
              return await dirHandle.getFileHandle(entry.name);
            } else if (entry.kind === 'directory') {
              try {
                // Ignore .git or node_modules just in case
                if (entry.name === '.git' || entry.name === 'node_modules') continue;
                const subHandle = await dirHandle.getDirectoryHandle(entry.name);
                const result = await findFileByName(subHandle, filename);
                if (result) return result;
              } catch (e) {
                // Ignore permission or read errors on subdirs
              }
            }
          }
          return null;
        };

        const getFileByPath = async (dirHandle: any, path: string) => {
          let parts = path.split('/').filter(p => p);
          
          if (parts.length > 2 && parts[0] === 'courses') {
            parts = parts.slice(2);
          }

          const filename = parts[parts.length - 1];

          try {
            let current = dirHandle;
            for (let i = 0; i < parts.length - 1; i++) {
              current = await current.getDirectoryHandle(parts[i]);
            }
            return await current.getFileHandle(filename);
          } catch (err) {
            console.warn(`Exact path failed for ${path}, attempting recursive search for ${filename}...`);
            const fallbackHandle = await findFileByName(dirHandle, filename);
            if (fallbackHandle) return fallbackHandle;
            throw err;
          }
        };

        const fileHandle = await getFileByPath(course.directoryHandle, activeItem.path!);
        const file = await fileHandle.getFile();

        if (activeItem.type === 'video') {
          const videoBlob = new Blob([await file.arrayBuffer()], { type: 'video/mp4' });
          objectUrl = URL.createObjectURL(videoBlob);
          setMediaUrl(objectUrl);
          
          extractedText = activeItem.description || `Video Lecture: ${activeItem.title}`;
          setActiveResource({
            title: activeItem.title,
            type: 'lesson',
            contextText: extractedText,
            suggestedPrompts: [
              'Summarize the key points of this lecture',
              'Generate a study plan based on this lecture',
              'Explain the core concepts mentioned in this topic'
            ]
          });
          setSourceText(extractedText);
        } else if (activeItem.type === 'pdf') {
          const arrayBuffer = await file.arrayBuffer();
          // Explicitly set the MIME type to application/pdf so the browser renders it inline
          // instead of downloading it or failing to load the blob.
          const pdfBlob = new Blob([arrayBuffer], { type: 'application/pdf' });
          objectUrl = URL.createObjectURL(pdfBlob);
          setMediaUrl(objectUrl);

          // Extract text from PDF in the background
          try {
            const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise;
            let fullText = '';
            // Only extract first 30 pages to prevent freezing on massive textbooks
            const numPages = Math.min(pdf.numPages, 30);
            for (let i = 1; i <= numPages; i++) {
              const page = await pdf.getPage(i);
              const content = await page.getTextContent();
              const pageText = content.items.map((item: any) => item.str).join(' ');
              fullText += pageText + '\n\n';
            }
            extractedText = fullText;
            setActiveResource({
              title: activeItem.title,
              type: 'lesson',
              contextText: extractedText,
              suggestedPrompts: [
                'Summarize the main concepts in this PDF',
                'Extract the key formulas or algorithms mentioned',
                'Create flashcard questions for this material'
              ]
            });
            setSourceText(extractedText);
          } catch (e) {
            console.error('Failed to extract PDF text:', e);
            setActiveResource({
              title: activeItem.title,
              type: 'lesson',
              contextText: activeItem.description || `PDF: ${activeItem.title}`
            });
          }

        } else if (activeItem.type === 'html') {
          const text = await file.text();
          setHtmlContent(text);
          
          // Strip HTML tags for clean AI context
          const tempDiv = document.createElement('div');
          tempDiv.innerHTML = text;
          extractedText = tempDiv.textContent || tempDiv.innerText || '';
          
          setActiveResource({
            title: activeItem.title,
            type: 'lesson',
            contextText: extractedText,
            suggestedPrompts: [
              'Summarize these lecture notes',
              'Explain this topic to me like I am 5',
              'What are the main takeaways from these notes?'
            ]
          });
          setSourceText(extractedText);
          
          // Parse HTML for video links to display as prominent buttons
          try {
            const parser = new DOMParser();
            const doc = parser.parseFromString(text, 'text/html');
            const links: { url: string; label: string }[] = [];
            
            doc.querySelectorAll('iframe').forEach(iframe => {
              const src = iframe.getAttribute('src');
              if (src && (src.includes('youtube.com') || src.includes('youtu.be') || src.includes('vimeo.com'))) {
                links.push({ url: src, label: 'Watch Embedded Video' });
              }
            });

            doc.querySelectorAll('a').forEach(a => {
              const href = a.getAttribute('href');
              if (href && (href.includes('youtube.com') || href.includes('youtu.be'))) {
                links.push({ url: href, label: 'Watch on YouTube' });
              } else if (href && href.endsWith('.mp4')) {
                links.push({ url: href, label: 'Download / Watch MP4' });
              }
            });

            // Deduplicate by URL
            const uniqueLinks = links.filter((v, i, a) => a.findIndex(t => t.url === v.url) === i);
            setHtmlVideoLinks(uniqueLinks);
          } catch (e) {
            console.error('Failed to parse HTML for video links', e);
            setHtmlVideoLinks([]);
          }
        }
      } catch (err: any) {
        console.error('Error reading local file:', err);
        setError('Failed to read local file. Ensure the original folder is still accessible.');
      }
    };

    loadContent();

    return () => {
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [activeItem, course]);

  if (!course) {
    return (
      <div className="p-12 text-center">
        <h2 className="text-xl font-bold text-slate-700">Course not found</h2>
        <Link to="/" className="text-blue-600 hover:underline mt-4 inline-block">Return to Workspace</Link>
      </div>
    );
  }

  const getIcon = (type: string) => {
    switch (type) {
      case 'video': return <Video className="w-4 h-4" />;
      case 'pdf': return <FileText className="w-4 h-4" />;
      case 'html': return <FileCode className="w-4 h-4" />;
      default: return <Book className="w-4 h-4" />;
    }
  };

  return (
    <div className="flex h-screen bg-slate-50 font-sans">
      {/* Sidebar Syllabus */}
      <div className="w-80 bg-white border-r border-slate-200 flex flex-col h-full shadow-sm z-10">
        <div className="p-5 border-b border-slate-100 shrink-0">
          <Link to="/" className="inline-flex items-center gap-1.5 text-xs font-bold text-slate-500 hover:text-slate-900 mb-4 transition-colors">
            <ArrowLeft className="w-3.5 h-3.5" /> Workspace
          </Link>
          <h1 className="font-black text-slate-900 text-lg leading-tight line-clamp-2" title={course.title}>
            {course.title}
          </h1>
          <p className="text-xs text-slate-500 mt-1">{course.modules.reduce((acc, m) => acc + m.items.length, 0)} items</p>
        </div>

        <div className="flex-1 overflow-y-auto p-3 space-y-4">
          {course.modules.map((module) => (
            <div key={module.id} className="space-y-1">
              <h3 className="px-3 py-1.5 text-[11px] font-extrabold uppercase tracking-wider text-slate-400">
                {module.title}
              </h3>
              {module.items.map((item) => {
                const isActive = activeItem?.id === item.id;
                return (
                  <button
                    key={item.id}
                    onClick={() => setActiveItem(item)}
                    className={`w-full text-left px-3 py-2.5 rounded-xl transition-all flex items-start gap-3 cursor-pointer ${
                      isActive 
                        ? 'bg-blue-50/80 text-blue-900 shadow-2xs border border-blue-100' 
                        : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900 border border-transparent'
                    }`}
                  >
                    <div className={`mt-0.5 shrink-0 ${isActive ? 'text-blue-600' : 'text-slate-400'}`}>
                      {getIcon(item.type)}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className={`text-sm font-bold truncate ${isActive ? 'text-blue-900' : 'text-slate-700'}`}>
                        {item.title}
                      </p>
                    </div>
                  </button>
                );
              })}
            </div>
          ))}
        </div>
      </div>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden relative">
        {/* Header */}
        <header className="h-16 shrink-0 bg-white border-b border-slate-200 flex items-center justify-between px-6 shadow-2xs">
          <h2 className="font-bold text-slate-800 text-sm truncate pr-4">
            {activeItem?.title || 'Select a lesson'}
          </h2>
          {activeItem && (
            <Link
              to={`/?tab=deck-generator&topic=${encodeURIComponent(activeItem.title)}`}
              state={{ sourceText, courseName: course.title }}
              className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white text-xs font-bold uppercase tracking-wider rounded-xl transition-all shadow-md cursor-pointer shrink-0"
            >
              <Sparkles className="w-4 h-4" />
              Generate Flashcards
            </Link>
          )}
        </header>

        {/* Viewer */}
        <main className={`flex-1 overflow-y-auto bg-slate-100 flex justify-center ${activeItem?.type === 'pdf' ? 'p-0' : 'p-6'}`}>
          <div className={`w-full flex flex-col ${activeItem?.type === 'pdf' ? 'max-w-none h-full' : 'max-w-5xl'}`}>
            {error ? (
              <div className="bg-rose-50 border border-rose-200 rounded-2xl p-6 text-center text-rose-700">
                <p>{error}</p>
                <button 
                  onClick={() => window.location.reload()}
                  className="mt-4 px-4 py-2 bg-white rounded-lg shadow-sm font-bold text-sm"
                >
                  Request Permissions Again
                </button>
              </div>
            ) : !activeItem ? (
              <div className="flex items-center justify-center h-full text-slate-400">
                Select an item from the sidebar
              </div>
            ) : (
              <div className={`bg-white shadow-sm border-slate-200 overflow-hidden flex flex-col ${activeItem?.type === 'pdf' ? 'h-full border-0 rounded-none' : 'rounded-2xl border min-h-[600px]'}`}>
                {activeItem.type === 'video' && mediaUrl && (
                  <div className="bg-black flex-1 relative aspect-video">
                    <video 
                      src={mediaUrl} 
                      controls 
                      className="absolute inset-0 w-full h-full"
                      autoPlay
                    />
                  </div>
                )}

                {activeItem.type === 'pdf' && mediaUrl && (
                  <object 
                    data={mediaUrl} 
                    type="application/pdf" 
                    className="w-full h-full flex-1 border-0"
                  >
                    <div className="flex flex-col items-center justify-center h-full p-8 text-center bg-slate-50">
                      <FileText className="w-12 h-12 text-slate-400 mb-4" />
                      <p className="text-slate-600 font-bold mb-2">Unable to display PDF inline.</p>
                      <a 
                        href={mediaUrl} 
                        target="_blank" 
                        rel="noopener noreferrer"
                        className="text-blue-600 hover:underline"
                      >
                        Click here to download or open it in a new tab.
                      </a>
                    </div>
                  </object>
                )}

                {activeItem.type === 'html' && htmlContent && (
                  <div className="flex-1 flex flex-col bg-white overflow-y-auto">
                    {htmlVideoLinks.length > 0 && (
                      <div className="p-6 bg-slate-50 border-b border-slate-200 flex flex-wrap gap-3 items-center">
                        <span className="text-xs font-bold text-slate-500 uppercase tracking-widest mr-2">Lecture Media:</span>
                        {htmlVideoLinks.map((link, idx) => (
                          <a
                            key={idx}
                            href={link.url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-rose-500 to-red-600 hover:from-rose-600 hover:to-red-700 text-white text-xs font-bold rounded-xl transition-all shadow-md hover:shadow-lg"
                          >
                            <PlayCircle className="w-4 h-4" />
                            {link.label}
                          </a>
                        ))}
                      </div>
                    )}
                    <div className="p-8 prose prose-slate max-w-none">
                      <div dangerouslySetInnerHTML={{ __html: htmlContent }} />
                    </div>
                  </div>
                )}

                {activeItem.description && (
                  <div className="p-6 bg-slate-50 border-t border-slate-100">
                    <p className="text-sm text-slate-600 leading-relaxed font-sans">
                      {activeItem.description}
                    </p>
                  </div>
                )}
              </div>
            )}
          </div>
        </main>
      </div>
    </div>
  );
}
