import React, { useState, useEffect } from 'react';
import { FolderPlus, Edit2, X, Check } from 'lucide-react';
import { Folder } from '../../types';

interface FolderModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (name: string, color?: string) => Promise<void>;
  initialFolder?: Folder | null;
}

const colorOptions = [
  { label: 'Blue', hex: '#2563eb' },
  { label: 'Indigo', hex: '#4f46e5' },
  { label: 'Cyan', hex: '#0891b2' },
  { label: 'Emerald', hex: '#059669' },
  { label: 'Amber', hex: '#d97706' },
  { label: 'Rose', hex: '#e11d48' },
  { label: 'Purple', hex: '#9333ea' },
  { label: 'Slate', hex: '#475569' }
];

export function FolderModal({ isOpen, onClose, onSubmit, initialFolder }: FolderModalProps) {
  const [name, setName] = useState('');
  const [color, setColor] = useState('#2563eb');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const isEditing = !!initialFolder;

  useEffect(() => {
    if (initialFolder) {
      setName(initialFolder.name);
      setColor(initialFolder.color || '#2563eb');
    } else {
      setName('');
      setColor('#2563eb');
    }
  }, [initialFolder, isOpen]);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;
    setIsSubmitting(true);
    try {
      await onSubmit(name.trim(), color);
      onClose();
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl shadow-2xl border border-slate-200 max-w-md w-full p-6 animate-scaleIn">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2.5">
            <div
              className="w-8 h-8 rounded-xl flex items-center justify-center border shadow-2xs"
              style={{ backgroundColor: `${color}15`, borderColor: `${color}40`, color: color }}
            >
              {isEditing ? <Edit2 className="w-4 h-4" /> : <FolderPlus className="w-4 h-4" />}
            </div>
            <div>
              <h3 className="text-base font-bold text-slate-900">
                {isEditing ? 'Rename Folder' : 'Create New Folder'}
              </h3>
              <p className="text-xs text-slate-500 font-sans">
                {isEditing ? 'Update folder name or color' : 'Group flashcard decks and CS lecture notes'}
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

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
              Folder Name
            </label>
            <input
              type="text"
              required
              autoFocus
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Graph Algorithms, Dynamic Programming..."
              className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 text-slate-800 text-xs font-sans"
            />
          </div>

          <div>
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-2">
              Folder Accent Color
            </label>
            <div className="flex items-center gap-2.5 flex-wrap">
              {colorOptions.map((c) => (
                <button
                  key={c.hex}
                  type="button"
                  onClick={() => setColor(c.hex)}
                  className={`w-7 h-7 rounded-xl transition-all cursor-pointer flex items-center justify-center ${
                    color === c.hex
                      ? 'ring-2 ring-offset-2 ring-slate-400 scale-110 shadow-sm'
                      : 'hover:scale-105 opacity-80 hover:opacity-100'
                  }`}
                  style={{ backgroundColor: c.hex }}
                  title={c.label}
                >
                  {color === c.hex && <Check className="w-3.5 h-3.5 text-white" />}
                </button>
              ))}
            </div>
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
              disabled={!name.trim() || isSubmitting}
              className="px-5 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-xl text-xs font-bold transition-all shadow-md disabled:opacity-50 cursor-pointer"
            >
              {isEditing ? 'Save Changes' : 'Create Folder'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
