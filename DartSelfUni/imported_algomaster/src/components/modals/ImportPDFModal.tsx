import React, { useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  FileText,
  Upload,
  Sparkles,
  BookOpen,
  Folder as FolderIcon,
  X,
  Loader2,
  CheckCircle2,
  AlertCircle
} from 'lucide-react';
import { Folder, Lesson } from '../../types';

interface ImportPDFModalProps {
  isOpen: boolean;
  onClose: () => void;
  folders: Folder[];
  onAddLesson: (lesson: Lesson) => Promise<void> | void;
}

export const ImportPDFModal: React.FC<ImportPDFModalProps> = ({
  isOpen,
  onClose,
  folders,
  onAddLesson,
}) => {
  const navigate = useNavigate();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [file, setFile] = useState<File | null>(null);
  const [topic, setTopic] = useState('');
  const [title, setTitle] = useState('');
  const [selectedFolderId, setSelectedFolderId] = useState<string>('');
  const [isUploading, setIsUploading] = useState(false);
  const [isSynthesizing, setIsSynthesizing] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<string>('');
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleFileSelect = (selectedFile: File) => {
    if (!selectedFile.name.toLowerCase().endsWith('.pdf')) {
      setError('Please select a valid .pdf file.');
      return;
    }
    setError(null);
    setFile(selectedFile);
    const baseName = selectedFile.name.replace(/\.[^/.]+$/, '');
    if (!title) setTitle(baseName);
    if (!topic) setTopic('Computer Science');
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFileSelect(e.dataTransfer.files[0]);
    }
  };

  const handleImportAndOpen = async () => {
    if (!file) {
      setError('Please select a PDF file to import.');
      return;
    }

    setIsUploading(true);
    setUploadProgress('Uploading and processing PDF...');
    setError(null);

    try {
      const formData = new FormData();
      formData.append('file', file);

      const res = await fetch('/api/pdf/parse', {
        method: 'POST',
        body: formData,
      });

      if (!res.ok) {
        const errJson = await res.json().catch(() => null);
        throw new Error(errJson?.error || `Server error (${res.status}): Failed to parse PDF`);
      }

      const data = await res.json();
      setUploadProgress('Creating in-app PDF document & notes...');

      const initialNotes = `# ${title || file.name}\n\n*Imported from PDF: \`${file.name}\` (${data.pages || 1} pages)*\n\n## 📝 Live PDF Notes\n- Take notes on key definitions, equations, and algorithmic invariants here.\n- Click **"Make Flashcards"** or **"Generate CS Lesson"** above to synthesize cards anytime.\n\n---\n\n### 📑 PDF Text Preview:\n${data.preview ? `> ${data.preview.slice(0, 400)}...` : ''}`;

      const lessonId = Date.now().toString(36) + Math.random().toString(36).substring(2, 7);
      const createdLesson: Lesson = {
        id: lessonId,
        title: title || file.name,
        topic: topic || 'Computer Science',
        content: initialNotes,
        folderId: selectedFolderId || undefined,
        pdfUrl: data.url,
        pdfFilename: data.filename || file.name,
        pdfPages: data.pages || 1,
        sources: [`PDF: ${file.name}`],
        createdAt: Date.now(),
      };

      await onAddLesson(createdLesson);

      onClose();
      navigate(`/lesson/${createdLesson.id}`);
    } catch (err: any) {
      console.error('PDF import failed:', err);
      setError(err.message || 'Failed to upload and import PDF');
    } finally {
      setIsUploading(false);
      setUploadProgress('');
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-fadeIn">
      <div className="bg-white rounded-3xl shadow-2xl border border-slate-200/90 w-full max-w-lg overflow-hidden flex flex-col max-h-[90vh]">
        {/* Modal Header */}
        <div className="p-6 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-rose-50 border border-rose-200/80 text-rose-600 flex items-center justify-center shadow-2xs">
              <FileText className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-base font-extrabold text-slate-900">Import PDF Document</h2>
              <p className="text-xs text-slate-500">View PDFs in-app side-by-side with your lecture notes</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-xl transition-colors cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Modal Body */}
        <div className="p-6 space-y-5 overflow-y-auto custom-scrollbar flex-1">
          {error && (
            <div className="p-3 bg-rose-50 border border-rose-200 rounded-xl flex items-center gap-2 text-xs font-semibold text-rose-700">
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          {/* Drag & Drop Zone */}
          <div
            onDragOver={handleDragOver}
            onDrop={handleDrop}
            onClick={() => fileInputRef.current?.click()}
            className={`border-2 border-dashed rounded-2xl p-6 text-center cursor-pointer transition-all ${
              file
                ? 'border-emerald-500 bg-emerald-50/40'
                : 'border-slate-300 hover:border-rose-400 bg-slate-50/50 hover:bg-rose-50/30'
            }`}
          >
            <input
              type="file"
              ref={fileInputRef}
              accept=".pdf,application/pdf"
              className="hidden"
              onChange={(e) => {
                if (e.target.files && e.target.files[0]) {
                  handleFileSelect(e.target.files[0]);
                }
              }}
            />

            {file ? (
              <div className="space-y-2">
                <div className="w-12 h-12 rounded-2xl bg-emerald-100 text-emerald-700 flex items-center justify-center mx-auto shadow-2xs">
                  <CheckCircle2 className="w-6 h-6" />
                </div>
                <p className="text-sm font-bold text-slate-900 font-mono truncate max-w-xs mx-auto">
                  {file.name}
                </p>
                <p className="text-xs text-slate-500 font-sans">
                  {(file.size / (1024 * 1024)).toFixed(2)} MB • Ready to import
                </p>
                <span className="text-[11px] text-emerald-700 font-bold underline">
                  Click to choose a different PDF
                </span>
              </div>
            ) : (
              <div className="space-y-2">
                <div className="w-12 h-12 rounded-2xl bg-slate-100 text-slate-500 flex items-center justify-center mx-auto">
                  <Upload className="w-6 h-6" />
                </div>
                <p className="text-sm font-bold text-slate-800">
                  Drag and drop your PDF here, or <span className="text-rose-600 underline">browse files</span>
                </p>
                <p className="text-xs text-slate-400">
                  Textbooks, lecture slides, papers, or homework sheets (up to 50MB)
                </p>
              </div>
            )}
          </div>

          {/* Form Metadata */}
          <div className="space-y-3.5">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">
                Document Title
              </label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="e.g. Introduction to Dynamic Programming"
                className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm font-medium text-slate-900 focus:bg-white focus:outline-none focus:ring-2 focus:ring-rose-500/20 focus:border-rose-500 transition-all"
              />
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Topic / Category
                </label>
                <input
                  type="text"
                  value={topic}
                  onChange={(e) => setTopic(e.target.value)}
                  placeholder="e.g. Algorithms"
                  className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium text-slate-900 focus:bg-white focus:outline-none focus:ring-2 focus:ring-rose-500/20 focus:border-rose-500 transition-all"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Folder (Optional)
                </label>
                <select
                  value={selectedFolderId}
                  onChange={(e) => setSelectedFolderId(e.target.value)}
                  className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium text-slate-900 focus:bg-white focus:outline-none focus:ring-2 focus:ring-rose-500/20 focus:border-rose-500 transition-all"
                >
                  <option value="">No folder (Root)</option>
                  {folders.map((f) => (
                    <option key={f.id} value={f.id}>
                      📁 {f.name}
                    </option>
                  ))}
                </select>
              </div>
            </div>
          </div>
        </div>

        {/* Modal Footer */}
        <div className="p-5 border-t border-slate-100 bg-slate-50/50 flex flex-col sm:flex-row items-center justify-between gap-3 shrink-0">
          <button
            type="button"
            onClick={onClose}
            disabled={isUploading}
            className="w-full sm:w-auto px-4 py-2 text-xs font-bold text-slate-600 hover:text-slate-900 hover:bg-slate-200/60 rounded-xl transition-colors cursor-pointer"
          >
            Cancel
          </button>

          <button
            type="button"
            onClick={handleImportAndOpen}
            disabled={!file || isUploading}
            className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-6 py-2.5 bg-gradient-to-r from-rose-600 to-pink-600 hover:from-rose-500 hover:to-pink-500 text-white font-bold rounded-xl text-xs uppercase tracking-wider shadow-md hover:shadow-lg transition-all disabled:opacity-50 cursor-pointer active:scale-95 whitespace-nowrap"
          >
            {isUploading ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                {uploadProgress || 'Importing PDF...'}
              </>
            ) : (
              <>
                <FileText className="w-4 h-4" />
                Import & Open PDF
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
};
