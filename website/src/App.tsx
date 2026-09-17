import { useEffect } from 'react';
import { ReleaseProvider } from './context/ReleaseContext';
import { ThreeBackdrop } from './components/ThreeBackdrop/ThreeBackdrop';
import Navbar from './components/Navbar/Navbar';
import Hero from './components/Hero/Hero';
import { Features } from './components/Features/Features';
import { AppShowcase } from './components/AppShowcase/AppShowcase';
import { AllDownloads } from './components/AllDownloads/AllDownloads';
import { InstallGuide } from './components/InstallGuide/InstallGuide';
import { FAQ } from './components/FAQ/FAQ';
import { Footer } from './components/Footer/Footer';
import { ChangelogModal } from './components/ChangelogModal/ChangelogModal';
import { FloatingPlayer } from './components/FloatingPlayer/FloatingPlayer';
import './styles/base.css';

export default function App() {
  // Theme is owned by the Navbar switcher (writes data-theme + localStorage).
  // This effect only guarantees a theme exists on first paint.
  useEffect(() => {
    if (!document.documentElement.dataset.theme) {
      document.documentElement.dataset.theme = 'noir-black';
    }
  }, []);

  return (
    <ReleaseProvider>
      <div className="noctra-root">
        {/* 3D Interactive Three.js Backdrop */}
        <ThreeBackdrop />

        {/* Navigation */}
        <Navbar />

        {/* Main Page Content */}
        <main style={{ position: 'relative', zIndex: 1 }}>
          <Hero />
          <Features />
          <AppShowcase />
          <AllDownloads />
          <InstallGuide />
          <FAQ />
        </main>

        {/* Footer */}
        <Footer />

        {/* Dynamic Changelog Modal */}
        <ChangelogModal />

        {/* Persistent Floating Mini-Player Dock (matches the Flutter app) */}
        <FloatingPlayer />
      </div>
    </ReleaseProvider>
  );
}
