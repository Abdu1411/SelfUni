import React, { createContext, useContext, useState, useCallback } from 'react';

export interface ActiveResource {
  title: string;
  type: 'flashcard' | 'lesson' | 'deck' | 'dashboard' | 'general';
  contextText: string;
  suggestedPrompts?: string[];
}

interface ActiveViewContextType {
  activeResource: ActiveResource | null;
  setActiveResource: (resource: ActiveResource | null) => void;
  isAskAiOpen: boolean;
  openAskAi: (initialQuery?: string, customContext?: string) => void;
  closeAskAi: () => void;
  modalInitialQuery: string;
  modalCustomContext?: string;
}

const ActiveViewContext = createContext<ActiveViewContextType | undefined>(undefined);

export function ActiveViewProvider({ children }: { children: React.ReactNode }) {
  const [activeResource, setActiveResource] = useState<ActiveResource | null>(null);
  const [isAskAiOpen, setIsAskAiOpen] = useState(false);
  const [modalInitialQuery, setModalInitialQuery] = useState('');
  const [modalCustomContext, setModalCustomContext] = useState<string | undefined>(undefined);

  const openAskAi = useCallback((initialQuery?: string, customContext?: string) => {
    setModalInitialQuery(initialQuery || '');
    setModalCustomContext(customContext);
    setIsAskAiOpen(true);
  }, []);

  const closeAskAi = useCallback(() => {
    setIsAskAiOpen(false);
    setModalInitialQuery('');
    setModalCustomContext(undefined);
  }, []);

  return (
    <ActiveViewContext.Provider
      value={{
        activeResource,
        setActiveResource,
        isAskAiOpen,
        openAskAi,
        closeAskAi,
        modalInitialQuery,
        modalCustomContext,
      }}
    >
      {children}
    </ActiveViewContext.Provider>
  );
}

export function useActiveView() {
  const context = useContext(ActiveViewContext);
  if (!context) {
    throw new Error('useActiveView must be used within an ActiveViewProvider');
  }
  return context;
}
