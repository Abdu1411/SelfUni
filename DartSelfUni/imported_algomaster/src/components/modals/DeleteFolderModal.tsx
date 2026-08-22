import React, { useState } from 'react';
import { AlertTriangle, X } from 'lucide-react';
import { Folder } from '../../types';

interface DeleteFolderModalProps {
  folder: Folder | null;
  onClose: () => void;
  onConfirm: (deleteContents: boolean) => Promise<void>;
}

export function DeleteFolderModal({ folder, onClose, onConfirm }: DeleteFolderModalProps) {
  const [deleteDecksWithFolder, setDeleteDecksWithFolder] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  if (!folder) return null;

  const handleDelete = async () => {
    setIsDeleting(true);
    try {
      await onConfirm(deleteDecksWithFolder);
      onClose();
    } finally {
      setIsDeleting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl shadow-2xl border border-slate-200 max-w-md w-full p-6 animate-scaleIn">
        <div className="flex items-start gap-3.5 mb-4">
          <div className="w-10 h-10 rounded-xl bg-rose-50 text-rose-600 flex items-center justify-center shrink-0 border border-rose-200">
            <AlertTriangle className="w-5 h-5" />
          </div>
          <div className="flex-1">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-bold text-slate-900">Delete "{folder.name}"?</h3>
              <button onClick={onClose} className="text-slate-400 hover:text-slate-600 p-1">
                <X className="w-4 h-4" />
              </button>
            </div>
            <p className="text-xs text-slate-500 mt-1">
              Choose how you want to handle the decks and lessons currently stored inside this folder.
            </p>
          </div>
        </div>

        <div className="space-y-2.5 my-4 bg-slate-50 p-3.5 rounded-2xl border border-slate-200">
          <label className="flex items-start gap-2.5 cursor-pointer">
            <input
              type="radio"
              name="deleteChoice"
              checked={!deleteDecksWithFolder}
              onChange={() => setDeleteDecksWithFolder(false)}
              className="mt-0.5 text-blue-600 cursor-pointer"
            />
            <div>
              <span className="text-xs font-bold text-slate-800 block">Keep Decks & Notes (Move to Unfiled)</span>
              <span className="text-[11px] text-slate-500 block">The folder will be deleted, but all items are preserved safely.</span>
            </div>
          </label>

          <div className="border-t border-slate-200 my-2"></div>

          <label className="flex items-start gap-2.5 cursor-pointer">
            <input
              type="radio"
              name="deleteChoice"
              checked={deleteDecksWithFolder}
              onChange={() => setDeleteDecksWithFolder(true)}
              className="mt-0.5 text-rose-600 cursor-pointer"
            />
            <div>
              <span className="text-xs font-bold text-rose-600 block">Delete Folder and All Contained Items</span>
              <span className="text-[11px] text-slate-500 block">Permanently delete this folder and all flashcard decks & lessons inside it.</span>
            </div>
          </label>
        </div>

        <div className="flex justify-end gap-2.5 pt-2">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-bold transition-all cursor-pointer"
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={isDeleting}
            onClick={handleDelete}
            className="px-5 py-2 bg-rose-600 hover:bg-rose-500 text-white rounded-xl text-xs font-bold transition-all shadow-md cursor-pointer disabled:opacity-50"
          >
            {isDeleting ? 'Deleting...' : 'Delete Folder'}
          </button>
        </div>
      </div>
    </div>
  );
}
