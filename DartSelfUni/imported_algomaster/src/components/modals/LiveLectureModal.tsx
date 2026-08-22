import React, { useState } from 'react';
import { Video, X, FileText, Upload, FolderGit2 } from 'lucide-react';
import { Folder } from '../../types';

interface LiveLectureModalProps {
  isOpen: boolean;
  onClose: () => void;
  folders: Folder[];
  onCreate: (lectureData: {
    title: string;
    topic: string;
    videoUrl: string;
    folderId?: string;
  }) => Promise<void>;
  onBulkCreate?: (courseName: string, lectures: { title: string; url: string }[]) => Promise<void>;
}

export function LiveLectureModal({ isOpen, onClose, folders, onCreate, onBulkCreate }: LiveLectureModalProps) {
  const [title, setTitle] = useState('');
  const [topic, setTopic] = useState('');
  const [videoUrl, setVideoUrl] = useState('');
  const [folderId, setFolderId] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const [tab, setTab] = useState<'single' | 'bulk'>('single');
  const [courseName, setCourseName] = useState('');
  const [extractedLinks, setExtractedLinks] = useState<{title: string, url: string}[]>([]);
  const [bulkUrl, setBulkUrl] = useState('');
  const [isExtracting, setIsExtracting] = useState(false);
  const [extractError, setExtractError] = useState('');

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !topic.trim() || !videoUrl.trim()) return;

    setIsSubmitting(true);
    try {
      await onCreate({
        title: title.trim(),
        topic: topic.trim(),
        videoUrl: videoUrl.trim(),
        folderId: folderId || undefined
      });
      setTitle('');
      setTopic('');
      setVideoUrl('');
      setFolderId('');
      onClose();
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleExtractFromUrl = async () => {
    if (!bulkUrl.trim()) return;
    setIsExtracting(true);
    setExtractError('');
    setExtractedLinks([]);

    try {
      let text = '';
      try {
        const directRes = await fetch(bulkUrl);
        if (directRes.ok) {
          text = await directRes.text();
        } else {
          throw new Error('Direct fetch failed');
        }
      } catch (err) {
        try {
          const proxyUrl = `/api/proxy?url=${encodeURIComponent(bulkUrl)}`;
          const proxyRes = await fetch(proxyUrl);
          if (!proxyRes.ok) throw new Error('Local proxy failed');
          text = await proxyRes.text();
        } catch (err2) {
          throw new Error('Could not fetch the URL. The page might be protected or invalid.');
        }
      }
      
      processExtractedText(text);
    } catch (err: any) {
      console.error(err);
      setExtractError(err.message || 'Could not access the page. Check the URL or try again.');
    } finally {
      setIsExtracting(false);
    }
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setIsExtracting(true);
    setExtractError('');
    setExtractedLinks([]);

    const reader = new FileReader();
    reader.onload = (event) => {
      const text = event.target?.result as string;
      if (text) {
        if (!courseName) {
           setCourseName(file.name.replace(/\.[^/.]+$/, ""));
        }
        processExtractedText(text, file.name);
      } else {
        setExtractError('Could not read file.');
      }
      setIsExtracting(false);
    };
    reader.onerror = () => {
      setExtractError('Error reading file.');
      setIsExtracting(false);
    };
    reader.readAsText(file);
  };

  const processExtractedText = (text: string, filename?: string) => {
    const links: {title: string, url: string}[] = [];
    let isJson = false;
    let isCsv = filename?.toLowerCase().endsWith('.csv');

    if (isCsv) {
      const lines = text.split('\n');
      lines.forEach((line, index) => {
        if (!line.trim()) return;
        const cols = line.split(',');
        if (cols.length >= 2) {
          let title = cols[0].trim();
          let url = cols[1].trim();
          if (title.startsWith('http')) {
            url = cols[0].trim();
            title = cols[1].trim();
          }
          title = title.replace(/^["']|["']$/g, '');
          url = url.replace(/^["']|["']$/g, '');
          
          if (url.includes('youtube.com') || url.includes('youtu.be')) {
            if (!links.find(l => l.url === url)) {
              links.push({ title: title || `Lecture ${index}`, url });
            }
          }
        } else if (cols.length === 1) {
          let url = cols[0].trim().replace(/^["']|["']$/g, '');
          if (url.includes('youtube.com') || url.includes('youtu.be')) {
            if (!links.find(l => l.url === url)) {
              links.push({ title: `Lecture ${index}`, url });
            }
          }
        }
      });
    } else {
      try {
        const parsed = JSON.parse(text);
        isJson = true;
        
        const processArray = (arr: any[]) => {
          arr.forEach((item, index) => {
            if (item && typeof item === 'object') {
              const url = item.url || item.link || item.href || item.videoUrl || 
                          (item.video_metadata?.youtube_id ? `https://www.youtube.com/watch?v=${item.video_metadata.youtube_id}` : null) || 
                          item.video_files?.archive_url;
              const title = item.title || item.name || item.label || `Lecture ${index + 1}`;
              if (url && typeof url === 'string') {
                if (!links.find(l => l.url === url)) {
                  links.push({ title, url });
                }
              }
            }
          });
        };

        if (Array.isArray(parsed)) {
          processArray(parsed);
        } else if (parsed && typeof parsed === 'object') {
          for (const key of ['lectures', 'data', 'items', 'videos', 'lessons']) {
            if (Array.isArray(parsed[key])) {
              processArray(parsed[key]);
              break;
            }
          }
        }
      } catch (e) {
        // Not JSON, parse as HTML and extract ytInitialData for YouTube playlists
        const ytMatch = text.match(/var ytInitialData = (\{.*?\});<\/script>/);
        if (ytMatch && ytMatch[1]) {
          try {
            const ytData = JSON.parse(ytMatch[1]);
            const extractVids = (obj: any) => {
              if (!obj || typeof obj !== 'object') return;
              if (obj.videoId && obj.title && obj.title.runs && obj.title.runs.length > 0) {
                const url = `https://www.youtube.com/watch?v=${obj.videoId}`;
                const title = obj.title.runs[0].text;
                if (!links.find(l => l.url === url) && title !== 'Private video' && title !== 'Deleted video') {
                  links.push({ title, url });
                }
              }
              Object.values(obj).forEach(extractVids);
            };
            extractVids(ytData);
          } catch(err) {
            console.error('Failed to parse ytInitialData', err);
          }
        }

        const parser = new DOMParser();
        const doc = parser.parseFromString(text, 'text/html');
        
        const anchors = Array.from(doc.querySelectorAll('a'));
        anchors.forEach((a, index) => {
          const href = a.getAttribute('href') || '';
          if (href.includes('youtube.com/watch') || href.includes('youtu.be/')) {
            const title = a.textContent?.trim() || `Lecture ${index + 1}`;
            const cleanUrl = href.split('&list=')[0];
            if (!links.find(l => l.url === cleanUrl || l.url === href)) {
              links.push({ title, url: href });
            }
          }
        });

        const iframes = Array.from(doc.querySelectorAll('iframe'));
        iframes.forEach((iframe, index) => {
           const src = iframe.getAttribute('src') || '';
           if (src.includes('youtube.com/embed/')) {
             const title = iframe.getAttribute('title')?.trim() || `Lecture ${index + 1}`;
             if (!links.find(l => l.url === src)) {
               links.push({ title, url: src });
             }
           }
        });
      }
    }
    
    if (links.length === 0) {
      setExtractError('No YouTube videos or valid data found on this page.');
    } else {
      setExtractedLinks(links);
      if (!courseName && !isJson && !isCsv) {
         const parser = new DOMParser();
         const doc = parser.parseFromString(text, 'text/html');
         const pageTitle = doc.querySelector('title')?.textContent;
         if (pageTitle) {
           setCourseName(pageTitle.trim());
         }
      }
    }
  };

  const handleBulkSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!courseName.trim() || extractedLinks.length === 0 || !onBulkCreate) return;

    setIsSubmitting(true);
    try {
      await onBulkCreate(courseName.trim(), extractedLinks);
      setCourseName('');
      setExtractedLinks([]);
      onClose();
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl shadow-2xl border border-slate-200 max-w-lg w-full p-6 animate-scaleIn">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-rose-50 text-rose-600 flex items-center justify-center border border-rose-200 shadow-2xs">
              <Video className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-base font-bold text-slate-900">Schedule / Add Live Lecture</h3>
              <p className="text-xs text-slate-500 font-sans">
                Attach YouTube video streams or recorded courses with interactive notes
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-slate-600 p-1 rounded-lg hover:bg-slate-100 cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="flex gap-2 mb-6 p-1 bg-slate-100 rounded-xl">
          <button
            onClick={() => setTab('single')}
            className={`flex-1 py-1.5 text-xs font-bold rounded-lg transition-all ${
              tab === 'single' ? 'bg-white text-slate-800 shadow-sm' : 'text-slate-500 hover:text-slate-700'
            }`}
          >
            Single Lecture
          </button>
          <button
            onClick={() => setTab('bulk')}
            className={`flex-1 py-1.5 text-xs font-bold rounded-lg transition-all ${
              tab === 'bulk' ? 'bg-white text-slate-800 shadow-sm' : 'text-slate-500 hover:text-slate-700'
            }`}
          >
            Bulk Import
          </button>
        </div>

        {tab === 'single' ? (
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
              Lecture Title
            </label>
            <input
              type="text"
              required
              autoFocus
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="e.g. Masterclass: Dynamic Programming in Dart"
              className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-rose-500/20 focus:border-rose-500 text-slate-800 text-xs font-sans"
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
                Topic / Subject
              </label>
              <input
                type="text"
                required
                value={topic}
                onChange={(e) => setTopic(e.target.value)}
                placeholder="e.g. Graphs, Trees, Sorts"
                className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-rose-500/20 focus:border-rose-500 text-slate-800 text-xs font-sans"
              />
            </div>

            <div>
              <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
                Assign to Folder
              </label>
              <select
                value={folderId}
                onChange={(e) => setFolderId(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-rose-500/20 focus:border-rose-500 text-slate-800 text-xs font-sans cursor-pointer"
              >
                <option value="">📁 Unfiled (No Folder)</option>
                {folders.map((f) => (
                  <option key={f.id} value={f.id}>
                    📁 {f.name}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div>
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
              YouTube Video URL / Live Stream URL
            </label>
            <input
              type="url"
              required
              value={videoUrl}
              onChange={(e) => setVideoUrl(e.target.value)}
              placeholder="https://www.youtube.com/watch?v=..."
              className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-rose-500/20 focus:border-rose-500 text-slate-800 text-xs font-sans"
            />
          </div>

          <div className="flex justify-end gap-2.5 pt-3">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-bold transition-all cursor-pointer disabled:opacity-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!title.trim() || !topic.trim() || !videoUrl.trim() || isSubmitting}
              className="px-5 py-2 bg-rose-600 hover:bg-rose-500 text-white rounded-xl text-xs font-bold transition-all shadow-md disabled:opacity-50 cursor-pointer"
            >
              {isSubmitting ? 'Creating...' : 'Add Live Lecture'}
            </button>
          </div>

          {isSubmitting && (
            <div className="mt-4 pt-4 border-t border-slate-100">
              <div className="flex justify-between text-[10px] font-bold text-rose-600 mb-2 uppercase tracking-wider">
                <span>Creating Lecture...</span>
                <span className="animate-pulse">Please wait</span>
              </div>
              <div className="w-full h-1.5 bg-slate-100 rounded-full overflow-hidden">
                <div className="h-full bg-rose-500 rounded-full w-2/3 animate-pulse"></div>
              </div>
            </div>
          )}
        </form>
        ) : (
        <form onSubmit={handleBulkSubmit} className="space-y-4">
          <div>
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
              Course Name (Will be created as a new folder)
            </label>
            <input
              type="text"
              required
              autoFocus
              value={courseName}
              onChange={(e) => setCourseName(e.target.value)}
              placeholder="e.g. CS50 2024"
              className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-rose-500/20 focus:border-rose-500 text-slate-800 text-xs font-sans"
            />
          </div>

          <div>
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
              Upload JSON/HTML/CSV File
            </label>
            <input
              type="file"
              accept=".json,.html,.htm,.txt,.csv"
              onChange={handleFileUpload}
              className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:border-rose-500 text-slate-800 text-xs font-sans file:mr-4 file:py-1.5 file:px-3 file:rounded-lg file:border-0 file:text-xs file:font-bold file:bg-slate-200 file:text-slate-700 hover:file:bg-slate-300"
            />
          </div>

          <div className="flex items-center gap-3 my-2 opacity-60">
            <div className="h-px bg-slate-300 flex-1"></div>
            <span className="text-[10px] font-bold text-slate-500 uppercase">OR FETCH URL</span>
            <div className="h-px bg-slate-300 flex-1"></div>
          </div>

          <div>
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
              Web Page URL (Containing Videos)
            </label>
            <div className="flex gap-2">
              <input
                type="url"
                value={bulkUrl}
                onChange={(e) => {
                  setBulkUrl(e.target.value);
                  setExtractError('');
                  setExtractedLinks([]);
                }}
                placeholder="https://example.com/course-page"
                className="flex-1 px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-rose-500/20 focus:border-rose-500 text-slate-800 text-xs font-sans"
              />
              <button
                type="button"
                onClick={handleExtractFromUrl}
                disabled={!bulkUrl.trim() || isExtracting || isSubmitting}
                className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-white rounded-xl text-xs font-bold transition-all disabled:opacity-50 cursor-pointer flex items-center justify-center min-w-[100px] shadow-sm"
              >
                {isExtracting ? 'Extracting...' : 'Extract'}
              </button>
            </div>
            
            {extractError && (
              <p className="mt-2 text-[10px] font-bold text-rose-600 bg-rose-50 p-2 rounded-lg border border-rose-100">
                {extractError}
              </p>
            )}

            {extractedLinks.length > 0 && (
              <div className="mt-3 p-3 bg-emerald-50 border border-emerald-100 rounded-xl text-emerald-800 text-xs flex items-center justify-between">
                <span className="font-bold">Extracted {extractedLinks.length} lectures!</span>
                <span className="text-[10px] opacity-70 truncate max-w-[150px]">{extractedLinks[0].title}...</span>
              </div>
            )}
          </div>

          <div className="flex justify-end gap-2.5 pt-3 border-t border-slate-100 mt-6">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-bold transition-all cursor-pointer disabled:opacity-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!courseName.trim() || extractedLinks.length === 0 || isSubmitting}
              className="px-5 py-2 bg-rose-600 hover:bg-rose-500 text-white rounded-xl text-xs font-bold transition-all shadow-md disabled:opacity-50 cursor-pointer"
            >
              {isSubmitting ? 'Importing...' : `Import ${extractedLinks.length} Lectures`}
            </button>
          </div>

          {isSubmitting && (
            <div className="mt-4 pt-4 border-t border-slate-100">
              <div className="flex justify-between text-[10px] font-bold text-rose-600 mb-2 uppercase tracking-wider">
                <span>Importing {extractedLinks.length} Lectures...</span>
                <span className="animate-pulse">Processing file</span>
              </div>
              <div className="w-full h-1.5 bg-slate-100 rounded-full overflow-hidden relative">
                <div className="absolute top-0 left-0 h-full bg-rose-500 rounded-full w-full animate-pulse"></div>
              </div>
            </div>
          )}
        </form>
        )}
      </div>
    </div>
  );
}
