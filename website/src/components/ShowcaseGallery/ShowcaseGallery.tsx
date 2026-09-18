import { useState } from 'react';
import {
  Disc3,
  Compass,
  Mic2,
  Sliders,
  FolderHeart,
  Settings2,
  Maximize2,
} from 'lucide-react';
import styles from './ShowcaseGallery.module.css';

interface ScreenshotTab {
  id: string;
  label: string;
  badge: string;
  title: string;
  description: string;
  image: string;
  icon: React.ReactNode;
}

const TABS: ScreenshotTab[] = [
  {
    id: 'player',
    label: 'Now Playing',
    badge: '24-BIT UPSCALED',
    title: 'Audiophile Player & Live Telemetry',
    description:
      'Live stream telemetry, gold 24-Bit Upscaled master indicator, real-time waveform spectrum bars, dual-player crossfading, and hardware DAC direct pass-through.',
    image: '/screenshots/player.png',
    icon: <Disc3 size={17} />,
  },
  {
    id: 'home',
    label: 'Discovery',
    badge: '120-AXIS NEURAL',
    title: 'Adaptive Feeds & Dynamic Radio',
    description:
      'Dynamic Made For You catalog, Spotify-style trending carousels, 60-track sliding LRU window eliminating repetitions, and instant 1-tap playback.',
    image: '/screenshots/home.png',
    icon: <Compass size={17} />,
  },
  {
    id: 'lyrics',
    label: 'Universal Lyrics',
    badge: 'MULTI-SCRIPT SYNC',
    title: 'Bilingual Subtitles & Transliteration',
    description:
      'Apple Music-style synced lyrics with real-time translation italics, persistent script selection across tracks, and Brahmic, Pinyin, and Romaji transliteration.',
    image: '/screenshots/lyrics.png',
    icon: <Mic2 size={17} />,
  },
  {
    id: 'equalizer',
    label: 'DSP Equalizer',
    badge: 'STUDIO MASTER',
    title: 'Hardware Parametric EQ & Target Curves',
    description:
      '5-band parametric equalizer tuned on-device with zero cloud latency. Includes audiophile IEM curves (Harman, Moondrop VDSF, Tangzu Wan\u2019er) and spatial reverb.',
    image: '/screenshots/equalizer.png',
    icon: <Sliders size={17} />,
  },
  {
    id: 'library',
    label: 'Vault & Folders',
    badge: 'OFFLINE FIRST',
    title: 'Custom Folders & Local Audio Vault',
    description:
      'Organize your personal music collection into custom folders, sync favorites, play offline downloads, and scan local storage with zero cloud dependence.',
    image: '/screenshots/library.png',
    icon: <FolderHeart size={17} />,
  },
  {
    id: 'settings',
    label: 'Audio DNA',
    badge: 'LOSSLESS CONTROL',
    title: 'Stream Quality & Quad Themes',
    description:
      'Configure automatic network-aware quality switching (Opus 128k to 320k FLAC), inspect audio device routing, and switch between Noir Black, Noir White, Liquid Glass, and Material U.',
    image: '/screenshots/settings.png',
    icon: <Settings2 size={17} />,
  },
];

export function ShowcaseGallery() {
  const [activeTab, setActiveTab] = useState<string>('player');
  const [isZoomed, setIsZoomed] = useState<boolean>(false);

  const current = TABS.find((t) => t.id === activeTab) ?? TABS[0];

  return (
    <section id="showcase" className={styles.section}>
      <div className={styles.header}>
        <span className={styles.tag}>AUTHENTIC APP EXPERIENCE</span>
        <h2 className={styles.title}>Crafted for Audiophiles. Designed for Focus.</h2>
        <p className={styles.subtitle}>
          No web mockups. Every pixel here is captured directly from the live Noctra native engine across mobile and desktop.
        </p>
      </div>

      <div className={styles.tabNav}>
        {TABS.map((tab) => {
          const isActive = tab.id === activeTab;
          return (
            <button
              key={tab.id}
              type="button"
              className={`${styles.tabBtn} ${isActive ? styles.tabBtnActive : ''}`}
              onClick={() => setActiveTab(tab.id)}
            >
              <span className={styles.tabIcon}>{tab.icon}</span>
              <span>{tab.label}</span>
            </button>
          );
        })}
      </div>

      <div className={styles.displayContainer}>
        <div className={styles.metaCol}>
          <span className={styles.badgePill}>{current.badge}</span>
          <h3 className={styles.metaTitle}>{current.title}</h3>
          <p className={styles.metaDesc}>{current.description}</p>
          <div className={styles.metaPills}>
            <span className={styles.pillItem}>Zero Telemetry</span>
            <span className={styles.pillItem}>100% Offline Capable</span>
            <span className={styles.pillItem}>GPL-3.0 Open Source</span>
          </div>
          <button
            type="button"
            className={styles.zoomBtn}
            onClick={() => setIsZoomed(true)}
            aria-label="View screenshot full size"
          >
            <Maximize2 size={15} />
            <span>Enlarge Screenshot</span>
          </button>
        </div>

        <div className={styles.previewCol}>
          <div className={styles.phoneFrame}>
            <div className={styles.phoneSpeaker} />
            <img
              src={current.image}
              alt={current.title}
              className={styles.phoneImage}
              loading="lazy"
              onClick={() => setIsZoomed(true)}
            />
          </div>
        </div>
      </div>

      {isZoomed && (
        <div className={styles.modalBackdrop} onClick={() => setIsZoomed(false)}>
          <div className={styles.modalContent} onClick={(e) => e.stopPropagation()}>
            <img src={current.image} alt={current.title} className={styles.modalImage} />
            <button
              type="button"
              className={styles.modalCloseBtn}
              onClick={() => setIsZoomed(false)}
            >
              Close [ESC]
            </button>
          </div>
        </div>
      )}
    </section>
  );
}
