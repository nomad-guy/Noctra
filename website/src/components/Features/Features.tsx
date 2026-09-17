import {
  Sliders,
  Sparkles,
  Mic2,
  Download,
  Palette,
  Radio,
  ShieldCheck,
  MonitorSmartphone,
  WifiOff,
  Bluetooth,
  Clock,
  Share2,
} from 'lucide-react';
import styles from './Features.module.css';

interface Feature {
  icon: React.ReactNode;
  title: string;
  desc: string;
  tags: string[];
  span?: 'wide' | 'tall';
}

const FEATURES: Feature[] = [
  {
    icon: <Sliders size={20} />,
    title: 'Real DSP, on-device',
    desc: 'A 5-band parametric equalizer with audiophile IEM target presets — Harman, Moondrop VDSF, Tangzu Wan\u2019er — plus bass boost, reverb, and volume normalization. All processed locally, zero cloud round-trips.',
    tags: ['Parametric EQ', 'IEM Presets', 'Bass Boost', 'Reverb'],
    span: 'wide',
  },
  {
    icon: <Sparkles size={20} />,
    title: 'Neural recommendations',
    desc: 'A real on-device MLP trained from your listening — likes, replays, skips, downloads, session context — with MMR diversity and controlled exploration. Your taste vector never leaves the device.',
    tags: ['On-device MLP', 'Taste vector', 'MMR diversity'],
  },
  {
    icon: <Mic2 size={20} />,
    title: 'Bilingual synced lyrics',
    desc: 'Apple Music-style subtitles. Dual-language LRC lines consolidate automatically so translations render as subtle italics beneath the active vocal line. Devanagari, Gurmukhi, Urdu, and more.',
    tags: ['LRC sync', 'Devanagari', 'Gurmukhi'],
  },
  {
    icon: <Download size={20} />,
    title: 'Downloads that actually work',
    desc: 'Atomic .part downloads with SHA-256 integrity checks, resume after interruption, and a bulk library downloader. Airplane mode is a first-class mode, not a failure mode.',
    tags: ['Atomic writes', 'Integrity checks', 'Bulk download'],
  },
  {
    icon: <Bluetooth size={20} />,
    title: 'Speaker Mesh',
    desc: 'Every phone in the room becomes a speaker. NTP-style clock sync keeps playback sample-accurate across devices, each free to route to its own Bluetooth speaker.',
    tags: ['Clock sync', 'LAN only', 'BT routing'],
  },
  {
    icon: <WifiOff size={20} />,
    title: 'Offline first',
    desc: 'Search your library, play downloads, and open generated playlists with no network at all. Cached artwork and metadata keep everything instant.',
    tags: ['Full offline', 'Instant library'],
  },
  {
    icon: <Palette size={20} />,
    title: 'Three honest themes',
    desc: 'Noir Black, Noir White, and Liquid Glass — the exact themes from the app, synced to this website with one tap.',
    tags: ['Noir Black', 'Noir White', 'Liquid Glass'],
  },
  {
    icon: <Radio size={20} />,
    title: 'AI Radio & seed stations',
    desc: 'Infinite radio from any track with repeat prevention via a 60-track sliding window, autoplay between songs, and session-aware intent.',
    tags: ['Infinite radio', 'No repeats'],
  },
  {
    icon: <Clock size={20} />,
    title: 'Sleep timer',
    desc: 'Fade out gently at a set time or at the end of the current track — with a proper volume ramp that never fights the duck or crossfade engine.',
    tags: ['End of track', 'Smooth fade'],
  },
  {
    icon: <Share2 size={20} />,
    title: 'Playlist transfer',
    desc: 'Import Spotify and YouTube playlists by URL, match tracks across providers with a fuzzy matching guard, and keep everything in your local vault.',
    tags: ['Spotify import', 'YT import'],
  },
  {
    icon: <ShieldCheck size={20} />,
    title: 'Privacy by architecture',
    desc: 'No accounts, no analytics, no telemetry. Listening data lives in an encrypted SQLite database on your device. Export diagnostics as .txt whenever you want.',
    tags: ['Zero telemetry', 'Local SQLite'],
  },
  {
    icon: <MonitorSmartphone size={20} />,
    title: 'One codebase, four platforms',
    desc: 'Android, Windows, Linux, and iOS share the same core — feature parity where the platform allows it, graceful degradation where it does not.',
    tags: ['Android', 'Windows', 'Linux', 'iOS'],
  },
];

export function Features() {
  return (
    <section id="features" className={styles.section}>
      <div className="section-header">
        <span className="section-tag">FEATURES</span>
        <h2 className="section-title">Everything a music player should be.</h2>
        <p className="section-subtitle">
          Noctra is built by people who listen carefully — to music, and to
          their players. Every feature below ships in the current release.
        </p>
      </div>

      <div className={styles.grid}>
        {FEATURES.map((f) => (
          <article
            key={f.title}
            className={`glass-card glass-card-hover ${styles.card} ${f.span === 'wide' ? styles.wide : ''}`}
          >
            <div className={styles.iconWrap}>{f.icon}</div>
            <h3 className={styles.title}>{f.title}</h3>
            <p className={styles.desc}>{f.desc}</p>
            <div className={styles.tagRow}>
              {f.tags.map((t) => (
                <span key={t} className={styles.tag}>
                  {t}
                </span>
              ))}
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}
