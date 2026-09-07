import { useState, useEffect } from 'react';
import type { ThemeType } from './types';
import { ReleaseProvider } from './context/ReleaseContext';
import { ThreeBackdrop } from './components/ThreeBackdrop/ThreeBackdrop';
import { Navbar } from './components/Navbar/Navbar';
import { Hero } from './components/Hero/Hero';
import { QuickDownloads } from './components/QuickDownloads/QuickDownloads';
import { LyricsPlayer } from './components/LyricsPlayer/LyricsPlayer';
import { AudioTelemetry } from './components/AudioTelemetry/AudioTelemetry';
import { AudiophileDSP } from './components/AudiophileDSP/AudiophileDSP';
import { PlaylistTransfer } from './components/PlaylistTransfer/PlaylistTransfer';
import { AppShowcase } from './components/AppShowcase/AppShowcase';
import { PrivacyAudit } from './components/PrivacyAudit/PrivacyAudit';
import { AllDownloads } from './components/AllDownloads/AllDownloads';
import { InstallGuide } from './components/InstallGuide/InstallGuide';
import { FAQ } from './components/FAQ/FAQ';
import { Footer } from './components/Footer/Footer';
import { ChangelogModal } from './components/ChangelogModal/ChangelogModal';
import './styles/base.css';

export default function App() {
  const [theme, setTheme] = useState<ThemeType>(() => {
    const saved = localStorage.getItem('noctra-theme') as ThemeType;
    if (saved === 'liquid-glass' || saved === 'noir-black' || saved === 'noir-white') {
      return saved;
    }
    return 'noir-black';
  });

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    document.body.setAttribute('data-theme', theme);
    localStorage.setItem('noctra-theme', theme);
  }, [theme]);

  const cycleTheme = () => {
    setTheme((prev) => {
      if (prev === 'noir-black') return 'liquid-glass';
      if (prev === 'liquid-glass') return 'noir-white';
      return 'noir-black';
    });
  };

  return (
    <ReleaseProvider>
      <div className="noctra-root">
        {/* 3D Interactive Three.js Backdrop */}
        <ThreeBackdrop theme={theme} />

        {/* Minimal Floating Navigation Bar */}
        <Navbar theme={theme} onCycleTheme={cycleTheme} />

        {/* Main Page Content */}
        <main style={{ position: 'relative', zIndex: 1 }}>
          <Hero />
          <QuickDownloads />
          <LyricsPlayer />
          <AudiophileDSP />
          <AudioTelemetry />
          <PlaylistTransfer />
          <AppShowcase />
          <PrivacyAudit />
          <AllDownloads />
          <InstallGuide />
          <FAQ />
        </main>

        {/* Footer */}
        <Footer theme={theme} />

        {/* Dynamic Changelog Modal */}
        <ChangelogModal />
      </div>
    </ReleaseProvider>
  );
}
