import React, { useState } from 'react';
import { X, FolderOpen, Loader2, BookOpen, AlertCircle } from 'lucide-react';
import { useDecks } from '../../store';
import { Course, CourseModule, CourseItem } from '../../types';

interface ImportCourseModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export function ImportCourseModal({ isOpen, onClose }: ImportCourseModalProps) {
  const { addCourse } = useDecks();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [progress, setProgress] = useState<string>('');

  if (!isOpen) return null;

  const handleSelectFolder = async () => {
    try {
      setError(null);
      setIsLoading(true);
      setProgress('Waiting for folder selection...');

      // 1. Request directory handle
      const dirHandle = await (window as any).showDirectoryPicker();
      
      setProgress('Reading course metadata...');
      
      // 2. Read root data.json
      let rootData = { course_title: 'Imported Course', course_description: '' };
      try {
        const dataHandle = await dirHandle.getFileHandle('data.json');
        const dataFile = await dataHandle.getFile();
        const dataText = await dataFile.text();
        rootData = JSON.parse(dataText);
      } catch (e) {
        console.warn('No root data.json found, using generic metadata.');
      }

      // 3. Read content_map.json
      let contentMap: Record<string, string> = {};
      try {
        const mapHandle = await dirHandle.getFileHandle('content_map.json');
        const mapFile = await mapHandle.getFile();
        const mapText = await mapFile.text();
        contentMap = JSON.parse(mapText);
      } catch (e) {
        console.warn('No content_map.json found.');
      }

      setProgress('Scanning course resources...');

      // 4. Extract resources from content_map
      const modulesMap: Record<string, CourseItem[]> = {
        'Videos': [],
        'Lecture Notes': [],
        'Assignments': [],
        'Other Resources': []
      };

      let scannedCount = 0;
      const totalToScan = Object.keys(contentMap).length;

      if (totalToScan === 0) {
        // Fallback: Generic folder scanner if no content_map is found
        setProgress('No OCW metadata found. Scanning generic folder structure...');
        
        const scanDirectory = async (handle: any, currentPath: string, parentName: string) => {
          for await (const entry of handle.values()) {
            if (entry.kind === 'file') {
              const fileExt = entry.name.split('.').pop()?.toLowerCase();
              const isVideo = fileExt === 'mp4' || fileExt === 'webm';
              const isPdf = fileExt === 'pdf';
              const isHtml = fileExt === 'html' || fileExt === 'htm';

              if (isVideo || isPdf || isHtml) {
                const item: CourseItem = {
                  id: crypto.randomUUID(),
                  title: entry.name.replace(/\.[^/.]+$/, ""), // remove extension
                  type: isVideo ? 'video' : isPdf ? 'pdf' : 'html',
                  path: currentPath ? `${currentPath}/${entry.name}` : entry.name,
                };
                
                // Group by the immediate parent folder name, or 'Resources' if in root
                const moduleName = parentName || 'Root Resources';
                if (!modulesMap[moduleName]) {
                  modulesMap[moduleName] = [];
                }
                modulesMap[moduleName].push(item);
              }
            } else if (entry.kind === 'directory') {
              if (entry.name === '.git' || entry.name === 'node_modules') continue;
              try {
                const subHandle = await handle.getDirectoryHandle(entry.name);
                await scanDirectory(
                  subHandle, 
                  currentPath ? `${currentPath}/${entry.name}` : entry.name,
                  entry.name
                );
              } catch (e) {
                // Ignore unreadable dirs
              }
            }
          }
        };

        await scanDirectory(dirHandle, '', '');
        rootData.course_title = dirHandle.name || 'Imported Folder';
      } else {
        // Normal OCW content_map parsing

      // Helper to traverse directory paths like "video_galleries/lecture-videos/data.json"
      const getFileByPath = async (path: string) => {
        const parts = path.split('/').filter(p => p);
        let current = dirHandle;
        for (let i = 0; i < parts.length - 1; i++) {
          current = await current.getDirectoryHandle(parts[i]);
        }
        return await current.getFileHandle(parts[parts.length - 1]);
      };

      for (const [uuid, path] of Object.entries(contentMap)) {
        scannedCount++;
        if (scannedCount % 10 === 0) {
          setProgress(`Scanning resources... (${scannedCount}/${totalToScan})`);
        }

        if (path.endsWith('data.json')) {
          try {
            const fileHandle = await getFileByPath(path);
            const file = await fileHandle.getFile();
            const text = await file.text();
            const resourceData = JSON.parse(text);

            if (resourceData.file) {
              const fileExt = resourceData.file.split('.').pop()?.toLowerCase();
              const isVideo = fileExt === 'mp4' || fileExt === 'webm';
              const isPdf = fileExt === 'pdf';
              const isHtml = fileExt === 'html' || fileExt === 'htm';

              if (isVideo || isPdf || isHtml) {
                const item: CourseItem = {
                  id: uuid,
                  title: resourceData.title || resourceData.file.split('/').pop() || 'Untitled',
                  type: isVideo ? 'video' : isPdf ? 'pdf' : isHtml ? 'html' : 'resource',
                  path: resourceData.file,
                  description: resourceData.description
                };

                const lowerPath = path.toLowerCase();
                if (lowerPath.includes('video')) modulesMap['Videos'].push(item);
                else if (lowerPath.includes('note') || lowerPath.includes('recitation')) modulesMap['Lecture Notes'].push(item);
                else if (lowerPath.includes('problem') || lowerPath.includes('exam') || lowerPath.includes('assignment')) modulesMap['Assignments'].push(item);
                else modulesMap['Other Resources'].push(item);
              }
            }
          } catch (e) {
            // Skip unreadable files
          }
        }
      }
      } // <-- Close the else block

      // 5. Build Course object
      const modules: CourseModule[] = [];
      Object.entries(modulesMap).forEach(([title, items], idx) => {
        if (items.length > 0) {
          // Sort items by title (e.g., "Lecture 1", "Lecture 2")
          items.sort((a, b) => a.title.localeCompare(b.title, undefined, { numeric: true }));
          modules.push({
            id: `mod-${idx}`,
            title,
            items
          });
        }
      });

      const newCourse: Course = {
        id: crypto.randomUUID(),
        title: rootData.course_title || 'Imported Course',
        description: (rootData.course_description as any)?.toString() || '',
        instructors: (rootData as any).instructors?.map((i: any) => `${i.first_name} ${i.last_name}`) || [],
        modules,
        directoryHandle: dirHandle,
        createdAt: Date.now()
      };

      setProgress('Saving course...');
      await addCourse(newCourse);

      setIsLoading(false);
      onClose();

    } catch (err: any) {
      console.error(err);
      if (err.name === 'AbortError') {
        setError('Folder selection was cancelled.');
      } else {
        setError(err.message || 'Failed to import course.');
      }
      setIsLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm animate-fadeIn">
      <div className="bg-white rounded-3xl w-full max-w-md shadow-2xl overflow-hidden border border-slate-200">
        <div className="flex items-center justify-between p-6 border-b border-slate-100">
          <h2 className="text-xl font-black text-slate-900 flex items-center gap-2">
            <BookOpen className="w-5 h-5 text-blue-600" />
            Import Local Course
          </h2>
          <button onClick={onClose} className="p-2 text-slate-400 hover:text-slate-600 rounded-xl hover:bg-slate-100 transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6">
          <div className="mb-6 bg-blue-50/50 p-4 rounded-2xl border border-blue-100">
            <p className="text-sm text-blue-800 font-sans leading-relaxed">
              Select a downloaded course folder (e.g., an MIT OpenCourseWare export). 
              The app will read the course structure locally without uploading any heavy video files.
            </p>
          </div>

          {error && (
            <div className="mb-6 p-4 bg-rose-50 border border-rose-200 rounded-2xl flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-rose-600 shrink-0 mt-0.5" />
              <p className="text-sm text-rose-800 font-sans">{error}</p>
            </div>
          )}

          {isLoading ? (
            <div className="flex flex-col items-center justify-center py-8">
              <Loader2 className="w-8 h-8 text-blue-600 animate-spin mb-4" />
              <p className="text-sm font-bold text-slate-700">{progress}</p>
            </div>
          ) : (
            <button
              onClick={handleSelectFolder}
              className="w-full py-4 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white font-bold rounded-2xl transition-all shadow-md flex items-center justify-center gap-2 cursor-pointer"
            >
              <FolderOpen className="w-5 h-5" />
              Select Course Folder
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
