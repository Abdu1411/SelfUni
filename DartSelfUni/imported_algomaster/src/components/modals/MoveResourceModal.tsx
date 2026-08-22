import React, { useState, useEffect } from 'react';
import { FolderGit2, X } from 'lucide-react';
import { Folder } from '../../types';

interface MoveResourceModalProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  itemTitle: string;
  itemType: 'deck' | 'lesson';
  currentFolderId?: string;
  folders: Folder[];
  onMove: (targetFolderId?: string) => Promise<void>;
}

export function MoveResourceModal({
  isOpen,
  onClose,
  title,
  itemTitle,
  itemType,
  currentFolderId,
  folders,
  onMove
}: MoveResourceModalProps) {
  const [selectedFolderId, setSelectedFolderId] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    setSelectedFolderId(currentFolderId || '');
  }, [currentFolderId, isOpen]);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      await onMove(selectedFolderId || undefined);
      onClose();
    } finally {
      setIsSubmitting(false);
    }
  };

  const isDeck = itemType === 'deck';

  return (
    <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl shadow-2xl border border-slate-200 max-w-md w-full p-6 animate-scaleIn">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2.5">
            <div className={`w-8 h-8 rounded-xl ${isDeck ? 'bg-blue-50 text-blue-600 border-blue-200' : 'bg-emerald-50 text-emerald-700 border-emerald-200'} flex items-center justify-center border shadow-2xs`}>
              <FolderGit2 className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-base font-bold text-slate-900">{title}</h3>
              <p className="text-xs text-slate-500 font-sans line-clamp-1 italic">{itemTitle}</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-slate-600 p-1 rounded-lg hover:bg-slate-100 cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
              Select Destination Folder
            </label>
            <select
              value={selectedFolderId}
              onChange={(e) => setSelectedFolderId(e.target.value)}
              className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 text-slate-800 text-xs font-sans cursor-pointer"
            >
              <option value="">📁 Unfiled / Root Library (No Folder)</option>
              {folders.map((f) => (
                <option key={f.id} value={f.id}>
                  📁 {f.name}
                </option>
              ))}
            </select>
          </div>

          <div className="flex justify-end gap-2.5 pt-3">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-bold transition-all cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className={`px-5 py-2 ${isDeck ? 'bg-blue-600 hover:bg-blue-500' : 'bg-emerald-600 hover:bg-emerald-500'} text-white rounded-xl text-xs font-bold transition-all shadow-md disabled:opacity-50 cursor-pointer`}
            >
              {isSubmitting ? 'Moving...' : 'Move Item'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
