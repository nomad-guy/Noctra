import { useState } from 'react';
import {
  Headphones,
  Mic2,
  Sliders,
  Library,
  Cpu,
  Compass,
  Search,
  Palette,
} from 'lucide-react';
import type { ShowcaseItem } from '../../types';
import styles from './AppShowcase.module.css';

function getShowcaseIcon(id: string) {
  switch (id) {
    case 'player':
      return <Headphones size={18} strokeWidth={2} />;
    case 'lyrics':
      return <Mic2 size={18} strokeWidth={2} />;
    case 'equalizer':
      return <Sliders size={18} strokeWidth={2} />;
    case 'library':
      return <Library size={18} strokeWidth={2} />;
    case 'ai_studio':
      return <Cpu size={18} strokeWidth={2} />;
    case 'home':
      return <Compass size={18} strokeWidth={2} />;
    case 'search':
      return <Search size={18} strokeWidth={2} />;
    case 'settings':
      return <Palette size={18} strokeWidth={2} />;
    default:
      return <Headphones size={18} strokeWidth={2} />;
  }
}

const SHOWCASE_ITEMS: ShowcaseItem[] = [
  {
    id: 'player',
    title: 'Hi-Res Player',
    desc: 'Bit-depth & telemetry',
    icon: 'player',
    screenshot: 'screenshots/player.png',
    captionTitle: 'Pragmatic Audio Telemetry',
    captionDesc: 'Master 320k & 24-bit Hi-Res badges, real-time waveform seekbar, 3D soundstage virtualizer, and concert hall acoustic presets.',
    badges: ['Master 320k', '3D Virtualizer', 'Concert Acoustics', 'AI Radio'],
  },
  {
    id: 'lyrics',
    title: 'Bilingual Lyrics',
    desc: 'Subtitles & transliteration',
    icon: 'lyrics',
    screenshot: 'screenshots/lyrics.png',
    captionTitle: 'Apple Music / Spotify Style Subtitles',
    captionDesc: 'Bilingual LRC lines sharing matching timestamps consolidate automatically into a primary sung vocal with a subtle, dimmed italic translation subtitle.',
    badges: ['Auto Consolidation', 'Subtle Subtitles', 'Devanagari', 'Gurmukhi', 'Urdu'],
  },
  {
    id: 'equalizer',
    title: 'IEM DSP Curves',
    desc: "Harman, Moondrop & Wan'er",
    icon: 'equalizer',
    screenshot: 'screenshots/equalizer.png',
    captionTitle: 'Audiophile IEM Target Presets',
    captionDesc: "Hardware-level parametric frequency curves for Harman IEM, Moondrop VDSF, and Tangzu Wan'er with 5-band DSP and Bass Boost.",
    badges: ['Harman Target', 'Moondrop VDSF', "Tangzu Wan'er", '5-Band DSP'],
  },
  {
    id: 'library',
    title: 'Library & Remix',
    desc: 'Shuffle, remix & transfer',
    icon: 'library',
    screenshot: 'screenshots/library.png',
    captionTitle: 'Custom Folders, Shuffle & Algorithmic Remix',
    captionDesc: 'One-tap Shuffle and deterministic algorithmic Remix for all custom playlists, Spotify imports, and local collections with SQLite persistence.',
    badges: ['Shuffle', 'Remix Reorder', 'Universal Transfer', 'SQLite Vault'],
  },
  {
    id: 'ai_studio',
    title: 'AI Taste Studio',
    desc: 'On-device taste vectors',
    icon: 'ai_studio',
    screenshot: 'screenshots/ai_studio.png',
    captionTitle: 'Neural Taste Modeling',
    captionDesc: '120-dimensional neural embedding maps user acoustic traits and classifies listening into archetypes with zero cloud telemetry.',
    badges: ['120D Embeddings', 'Audio DNA Radar', 'Zero Cloud', 'Seed Stations'],
  },
  {
    id: 'home',
    title: 'Discovery Feed',
    desc: 'Global charts & artists',
    icon: 'home',
    screenshot: 'screenshots/home.png',
    captionTitle: 'Curated Charts & Artists',
    captionDesc: 'Real-time trending charts, Wikipedia artist discographies, and locally embedded recommendation graphs.',
    badges: ['Global Top 50', 'Explore Artists', 'Offline Vault', 'Dynamic Mixes'],
  },
  {
    id: 'search',
    title: 'Instant Search',
    desc: 'High-fidelity catalog filters',
    icon: 'search',
    screenshot: 'screenshots/search.png',
    captionTitle: 'Multi-Source Catalog Explorer',
    captionDesc: 'Instant as-you-type search across Deezer Hi-Fi, Qobuz, Apple Music catalogs, and direct YouTube audio streams.',
    badges: ['High Fidelity Filter', 'Direct Stream', 'Album Search', 'Lossless Badge'],
  },
  {
    id: 'settings',
    title: 'Triple Noir',
    desc: 'Obsidian & Liquid Glass',
    icon: 'settings',
    screenshot: 'screenshots/settings.png',
    captionTitle: 'Swiss Minimalist Themes',
    captionDesc: 'Choose between Obsidian Noir Black, Editorial Noir White, or Sapphire Liquid Glass with synchronized Android launcher icons.',
    badges: ['Noir Black', 'Noir White', 'Liquid Glass', 'Dynamic Icons'],
  },
];

export function AppShowcase() {
  const [activeItem, setActiveItem] = useState<ShowcaseItem>(SHOWCASE_ITEMS[0]);

  return (
    <section id="showcase" className={styles.section}>
      <div className="section-header">
        <span className="section-tag">AUTHENTIC HARDWARE SCREENSHOTS</span>
        <h2 className="section-title">Designed for Audiophiles. Refined for Your Eyes.</h2>
        <p className="section-subtitle">
          Real screen captures rendered on physical 120Hz OLED hardware with Noctra's signature Triple Noir design system.
        </p>
      </div>

      <div className={styles.container}>
        <div className={styles.tabList} role="tablist">
          {SHOWCASE_ITEMS.map((item) => {
            const isActive = item.id === activeItem.id;
            return (
              <button
                key={item.id}
                type="button"
                className={`${styles.tabItem} ${isActive ? styles.tabItemActive : ''}`}
                onClick={() => setActiveItem(item)}
              >
                <div className={styles.tabHeader}>
                  <span className={styles.tabIcon}>{getShowcaseIcon(item.id)}</span>
                  <span className={styles.tabTitle}>{item.title}</span>
                </div>
                <span className={styles.tabDesc}>{item.desc}</span>
              </button>
            );
          })}
        </div>

        <div className={styles.previewArea}>
          <div className={styles.phoneFrame}>
            <div className={styles.phoneNotch} />
            <div className={styles.phoneScreen}>
              <img
                src={activeItem.screenshot}
                alt={activeItem.title}
                className={styles.screenImg}
                key={activeItem.screenshot}
              />
            </div>
          </div>

          <div className={styles.captionCard}>
            <h3 className={styles.captionTitle}>{activeItem.captionTitle}</h3>
            <p className={styles.captionDesc}>{activeItem.captionDesc}</p>
            <div className={styles.badgeList}>
              {activeItem.badges.map((b, idx) => (
                <span key={idx} className={styles.badgePill}>{b}</span>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
