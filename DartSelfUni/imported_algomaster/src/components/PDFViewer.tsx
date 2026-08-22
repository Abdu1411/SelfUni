import React, { useState } from 'react';
import { FileText, ExternalLink, Download, Maximize2, Minimize2, ZoomIn, ZoomOut, RotateCcw } from 'lucide-react';

interface PDFViewerProps {
  pdfUrl: string;
  filename?: string;
  pageCount?: number;
  onExtractText?: () => void;
}

export const PDFViewer: React.FC<PDFViewerProps> = ({
  pdfUrl,
  filename = 'Document.pdf',
  pageCount,
}) => {
  const [isFullscreen, setIsFullscreen] = useState(false);

  return (
    <div
      className={`bg-white/98 rounded-3xl shadow-md border border-slate-200/90 flex flex-col transition-all overflow-hidden ${
        isFullscreen
          ? 'fixed inset-4 z-50 shadow-2xl border-slate-300'
          : 'relative w-full h-[620px] 2xl:h-[750px]'
      }`}
    >
      {/* Top PDF Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-3 px-4 py-3 bg-slate-900 text-white border-b border-slate-800 shrink-0">
        <div className="flex items-center gap-2.5 min-w-0">
          <div className="w-8 h-8 rounded-xl bg-rose-500/20 text-rose-400 border border-rose-500/30 flex items-center justify-center shrink-0">
            <FileText className="w-4 h-4" />
          </div>
          <div className="min-w-0">
            <h3 className="text-xs font-bold font-mono truncate text-slate-100" title={filename}>
              {filename}
            </h3>
            {pageCount ? (
              <p className="text-[10px] text-slate-400 font-sans">
                {pageCount} {pageCount === 1 ? 'page' : 'pages'}
              </p>
            ) : null}
          </div>
        </div>

        {/* Action Controls */}
        <div className="flex items-center gap-1.5 shrink-0">
          <a
            href={pdfUrl}
            target="_blank"
            rel="noreferrer"
            className="p-1.5 text-slate-300 hover:text-white hover:bg-slate-800 rounded-lg transition-colors"
            title="Open in new browser tab"
          >
            <ExternalLink className="w-4 h-4" />
          </a>

          <a
            href={pdfUrl}
            download={filename}
            className="p-1.5 text-slate-300 hover:text-white hover:bg-slate-800 rounded-lg transition-colors"
            title="Download PDF"
          >
            <Download className="w-4 h-4" />
          </a>

          <button
            type="button"
            onClick={() => setIsFullscreen(!isFullscreen)}
            className="p-1.5 text-slate-300 hover:text-white hover:bg-slate-800 rounded-lg transition-colors cursor-pointer"
            title={isFullscreen ? 'Exit Fullscreen' : 'Fullscreen PDF'}
          >
            {isFullscreen ? <Minimize2 className="w-4 h-4" /> : <Maximize2 className="w-4 h-4" />}
          </button>
        </div>
      </div>

      {/* Embedded PDF Viewer Container */}
      <div className="flex-1 w-full h-full bg-slate-950 relative min-h-0">
        <iframe
          src={`${pdfUrl}#toolbar=1&navpanes=1&view=FitH`}
          title={filename}
          className="w-full h-full border-0"
        />
      </div>
    </div>
  );
};
