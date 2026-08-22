import React, { useState, useMemo } from 'react';
import { Link } from 'react-router-dom';
import {
  Video,
  Plus,
  Play,
  Search,
  X,
  ExternalLink,
  Trash2,
  FolderGit2,
  Folder as FolderIcon,
  Edit2
} from 'lucide-react';
import { Lesson, Folder } from '../types';

interface LiveLecturesViewProps {
  lessons: Lesson[];
  folders: Folder[];
  onOpenCreateLive: () => void;
  onOpenMoveLesson: (lesson: Lesson) => void;
  onDeleteLesson: (lessonId: string) => void;
  activeFolderId: string | null;
  onOpenRenameFolder?: (folder: Folder) => void;
  onOpenDeleteFolder?: (folder: Folder) => void;
}

export function LiveLecturesView({
  lessons,
  folders,
  onOpenCreateLive,
  onOpenMoveLesson,
  onDeleteLesson,
  activeFolderId,
  onOpenRenameFolder,
  onOpenDeleteFolder
}: LiveLecturesViewProps) {
  const [searchQuery, setSearchQuery] = useState('');

  const liveLessons = useMemo(() => {
    const list = (lessons || []).filter((l) => !!l.videoUrl);
    if (!searchQuery.trim()) return list;
    const q = searchQuery.toLowerCase();
    return list.filter(
      (l) =>
        (l.title || '').toLowerCase().includes(q) ||
        (l.topic || '').toLowerCase().includes(q)
    );
  }, [lessons, searchQuery]);

  const extractYtId = (url: string) => {
    const match = url.match(/[?&]v=([^&#]*)/) || url.match(/youtu\.be\/([^?&#]+)/);
    return match ? match[1] : null;
  };

  const groupedLessons = useMemo(() => {
    const grouped: Record<string, Lesson[]> = {};
    liveLessons.forEach(l => {
      const key = l.folderId || 'unfiled';
      if (!grouped[key]) grouped[key] = [];
      grouped[key].push(l);
    });

    // Sort lessons naturally by title (e.g. "Lecture 2" before "Lecture 10")
    for (const key in grouped) {
      grouped[key].sort((a, b) => {
        const titleA = a.title || '';
        const titleB = b.title || '';
        return titleA.localeCompare(titleB, undefined, { numeric: true, sensitivity: 'base' });
      });
    }

    return grouped;
  }, [liveLessons]);

  return (
    <div className="space-y-6 animate-fadeIn">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white/95 border border-slate-200/90 rounded-3xl p-5 sm:p-6 shadow-xs backdrop-blur-md">
        <div>
          <div className="flex items-center gap-2 text-xs font-bold text-slate-400 mb-1">
            {activeFolderId ? (
              <Link to="?tab=live" className="hover:text-rose-600 transition-colors cursor-pointer">
                Live Lectures
              </Link>
            ) : (
              <span>Library</span>
            )}
            <span>/</span>
            <span className="text-rose-700">
              {activeFolderId 
                ? (folders.find(f => f.id === activeFolderId)?.name || 'Unfiled Lectures')
                : 'Live Lectures'}
            </span>
          </div>

          <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2.5">
            <Video className="w-6 h-6 text-rose-600" />
            {activeFolderId 
                ? (folders.find(f => f.id === activeFolderId)?.name || 'Unfiled Lectures')
                : 'Live Lectures & Video Streams'}
          </h1>
          <p className="text-xs text-slate-500 font-sans mt-0.5">
            Interactive video masterclasses with synchronized code notes and term breakdowns
          </p>
        </div>

        <button
          onClick={onOpenCreateLive}
          className="inline-flex items-center gap-2 px-4 py-2.5 bg-rose-600 hover:bg-rose-500 text-white rounded-xl text-xs font-bold uppercase tracking-wider transition-all shadow-md cursor-pointer self-start sm:self-auto"
        >
          <Plus className="w-4 h-4" />
          Add Live Stream
        </button>
      </div>

      {/* Search Bar */}
      <div className="flex items-center justify-between gap-3 bg-white/80 p-3 rounded-2xl border border-slate-200/80 shadow-2xs">
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search live streams..."
            className="w-full pl-9 pr-8 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-sans text-slate-800 placeholder-slate-400 focus:bg-white focus:outline-none focus:ring-2 focus:ring-rose-500/20 focus:border-rose-500"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          )}
        </div>
      </div>

      {/* Live Lectures Grid */}
      {liveLessons.length === 0 ? (
        <div className="bg-white/80 rounded-3xl border border-dashed border-slate-200 p-8 text-center">
          <div className="w-12 h-12 rounded-2xl bg-rose-50 text-rose-600 flex items-center justify-center mx-auto mb-3 border border-rose-200">
            <Video className="w-6 h-6" />
          </div>
          <h3 className="text-sm font-bold text-slate-800">No Live Video Lectures Added</h3>
          <p className="text-xs text-slate-500 font-sans mt-1 max-w-sm mx-auto">
            Attach YouTube algorithm masterclasses or recorded streams to take notes side-by-side with video.
          </p>
          <button
            onClick={onOpenCreateLive}
            className="mt-4 inline-flex items-center gap-1.5 px-4 py-2 bg-rose-600 text-white rounded-xl text-xs font-bold hover:bg-rose-500 transition-all cursor-pointer shadow-md"
          >
            <Plus className="w-3.5 h-3.5" />
            Add First Live Stream
          </button>
        </div>
      ) : !activeFolderId ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {Object.entries(groupedLessons).map(([folderId, folderLessons]) => {
            const folder = folders.find((f) => f.id === folderId);
            return (
              <Link
                key={folderId}
                to={`?tab=live&folder=${folderId}`}
                className="group bg-white/95 rounded-3xl shadow-xs border border-slate-200/90 p-8 flex flex-col items-center justify-center text-center transition-all duration-300 hover:border-rose-300 hover:shadow-md hover:-translate-y-1 cursor-pointer"
              >
                <div className="w-20 h-20 rounded-3xl bg-gradient-to-br from-rose-50 to-pink-50 flex items-center justify-center border border-rose-100 shadow-inner mb-5 group-hover:scale-110 transition-transform duration-500">
                  <FolderIcon className="w-10 h-10 text-rose-500 fill-rose-500/20" />
                </div>
                <h3 className="font-black text-lg text-slate-900 group-hover:text-rose-600 transition-colors mb-2">
                  {folder ? folder.name : 'Unfiled Lectures'}
                </h3>
                <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg text-xs font-bold bg-slate-100 text-slate-500 group-hover:bg-rose-50 group-hover:text-rose-600 transition-colors">
                  <Video className="w-3.5 h-3.5" />
                  {folderLessons.length} {folderLessons.length === 1 ? 'lecture' : 'lectures'}
                </span>
              </Link>
            );
          })}
        </div>
      ) : (
        <div className="space-y-6">
          <div className="flex items-center justify-between gap-2 mb-2 pb-2 border-b border-slate-100">
            <Link to="?tab=live" className="text-sm font-bold text-slate-500 hover:text-rose-600 transition-colors flex items-center gap-1">
              <span className="text-lg leading-none">&larr;</span> Back to Folders
            </Link>

            {activeFolderId && activeFolderId !== 'unfiled' && (
              <div className="flex items-center gap-2">
                {onOpenRenameFolder && (
                  <button
                    onClick={() => {
                      const folder = folders.find((f) => f.id === activeFolderId);
                      if (folder) onOpenRenameFolder(folder);
                    }}
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-bold transition-all cursor-pointer shadow-2xs"
                  >
                    <Edit2 className="w-3.5 h-3.5" />
                    Rename Course
                  </button>
                )}
                {onOpenDeleteFolder && (
                  <button
                    onClick={() => {
                      const folder = folders.find((f) => f.id === activeFolderId);
                      if (folder) onOpenDeleteFolder(folder);
                    }}
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-rose-50 hover:bg-rose-100 text-rose-700 rounded-xl text-xs font-bold transition-all cursor-pointer shadow-2xs"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                    Delete Course
                  </button>
                )}
              </div>
            )}
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {(groupedLessons[activeFolderId] || []).map((lesson) => {
              const ytId = lesson.videoUrl ? extractYtId(lesson.videoUrl) : null;
              const thumbUrl = ytId ? `https://img.youtube.com/vi/${ytId}/mqdefault.jpg` : null;

              return (
                <div
                  key={lesson.id}
                  className="group relative bg-white/95 rounded-3xl shadow-xs border border-slate-200/90 overflow-hidden flex flex-col justify-between transition-all duration-300 hover:border-rose-300 hover:shadow-md hover:-translate-y-0.5"
                >
                  <div>
                    {thumbUrl ? (
                      <Link to={`/lesson/${lesson.id}`} className="relative block aspect-video bg-slate-900 overflow-hidden">
                        <img
                          src={thumbUrl}
                          alt={lesson.title}
                          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                        />
                        <div className="absolute inset-0 bg-slate-950/30 group-hover:bg-slate-950/10 transition-colors flex items-center justify-center">
                          <div className="w-12 h-12 rounded-2xl bg-rose-600/90 text-white flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
                            <Play className="w-5 h-5 fill-current ml-0.5" />
                          </div>
                        </div>
                      </Link>
                    ) : (
                      <div className="aspect-video bg-gradient-to-br from-slate-800 to-slate-950 flex items-center justify-center text-white p-4">
                        <Video className="w-10 h-10 text-rose-500" />
                      </div>
                    )}

                    <div className="p-5">
                      <div className="flex items-center justify-between gap-2 mb-2">
                        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-mono font-bold bg-rose-50 text-rose-700 border border-rose-200">
                          {lesson.topic}
                        </span>
                      </div>

                      <Link to={`/lesson/${lesson.id}`} className="block group-hover:text-rose-600 transition-colors">
                        <h3 className="font-bold text-sm text-slate-900 line-clamp-2 leading-snug">
                          {lesson.title}
                        </h3>
                      </Link>
                    </div>
                  </div>

                  <div className="p-5 pt-0 flex items-center justify-between border-t border-slate-100 mt-2">
                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => onOpenMoveLesson(lesson)}
                        className="p-1.5 text-slate-400 hover:text-rose-600 rounded-lg hover:bg-rose-50 cursor-pointer"
                        title="Move to Folder"
                      >
                        <FolderGit2 className="w-3.5 h-3.5" />
                      </button>
                      <button
                        onClick={() => onDeleteLesson(lesson.id)}
                        className="p-1.5 text-slate-400 hover:text-rose-600 rounded-lg hover:bg-rose-50 cursor-pointer"
                        title="Delete Lecture"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>

                    <Link
                      to={`/lesson/${lesson.id}`}
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-200 rounded-xl text-xs font-bold transition-all"
                    >
                      Watch & Notes <Play className="w-3 h-3 fill-current" />
                    </Link>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
