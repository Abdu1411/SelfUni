/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Layout } from './components/Layout';
import { Home } from './pages/Home';
import { StudySession } from './pages/StudySession';
import { LessonView } from './pages/LessonView';
import { CourseViewer } from './pages/CourseViewer';
import { ActiveViewProvider } from './context/ActiveViewContext';
import { PomodoroProvider } from './context/PomodoroContext';

export default function App() {
  return (
    <ActiveViewProvider>
      <PomodoroProvider>
        <BrowserRouter>
          <Layout>
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/deck/:deckId" element={<StudySession />} />
              <Route path="/lesson/:lessonId" element={<LessonView />} />
              <Route path="/course/:courseId" element={<CourseViewer />} />
            </Routes>
          </Layout>
        </BrowserRouter>
      </PomodoroProvider>
    </ActiveViewProvider>
  );
}
