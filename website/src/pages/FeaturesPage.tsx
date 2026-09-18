import type { ReactNode } from 'react';
import {
  Sparkles,
  Sliders,
  Mic2,
  Radio,
  Palette,
  ShieldCheck,
  Bluetooth,
  ArrowRight,
} from 'lucide-react';
import { Link } from '../router/Router';
import styles from './FeaturesPage.module.css';

interface FeatureBlock {
  id: string;
  icon: ReactNode;
  badge: string;
  title: string;
  subtitle: string;
  details: string[];
  specs: { label: string; value: string }[];
}

const FEATURE_BLOCKS: FeatureBlock[] = [
  {
    id: 'upscaler',
    icon: <Sparkles size={24} />,
    badge: 'ON-DEVICE DSP ENGINE',
    title: 'Lossless 24-Bit Audio Upscaler',
    subtitle:
      'Reconstruct harmonics and restore lost high-frequency air from lossy MP3/AAC compression directly on-device in a dedicated background isolate.',
    details: [
      'Pure-Dart background isolate architecture with zero UI thread interruption.',
      'Dynamic Nyquist sample-rate bounds preventing high-frequency aliasing.',
      'Dual-channel stereo isolation state machine eliminating cross-channel bleed.',
      'True lossless 24-bit PCM WAV export with hyperbolic tangent soft limiting.',
      'Automatic cache resolution: upscaled tracks play immediately with bit-perfect fidelity.',
    ],
    specs: [
      { label: 'Bit Depth', value: '24-Bit Linear PCM' },
      { label: 'Harmonic Range', value: '12 kHz – 22 kHz' },
      { label: 'Execution', value: 'On-Device Isolate' },
      { label: 'Format', value: 'Lossless WAV' },
    ],
  },
  {
    id: 'equalizer',
    icon: <Sliders size={24} />,
    badge: 'STUDIO MASTER DSP',
    title: 'Hardware Parametric EQ & Audiophile Presets',
    subtitle:
      'Fine-tune frequency curves with hardware-accelerated DSP filters and industry-standard in-ear monitor (IEM) target curves.',
    details: [
      '5-band parametric equalizer processed locally on the native audio thread.',
      'Audiophile target curves: Harman Target 2019, Moondrop VDSF, Tangzu Wan\u2019er.',
      'Studio Master enhancements: Lossless 320k, Spatial 3D Audio, and Concert Reverb.',
      'Zero cloud round-trips — your custom EQ configurations remain private and instant.',
    ],
    specs: [
      { label: 'Bands', value: '5-Band Parametric' },
      { label: 'Preamp Gain', value: '-12 dB to +12 dB' },
      { label: 'IEM Presets', value: 'Harman / VDSF / Custom' },
      { label: 'Latency', value: '< 2 ms Hardware DSP' },
    ],
  },
  {
    id: 'lyrics',
    icon: <Mic2 size={24} />,
    badge: 'UNIVERSAL TRANSLITERATION',
    title: 'Bilingual Lyrics & Multi-Script Transliteration',
    subtitle:
      'Apple Music-style synchronized lyrics with automatic translation consolidation, Brahmic Sanscript transliteration, and persistent script preferences.',
    details: [
      'Offline Brahmic matrix transliteration across Devanagari, Gurmukhi, Bengali, Gujarati, Telugu, Tamil, Kannada, Malayalam, and Odia.',
      'Asian script transliteration: Chinese Hanzi to Pinyin with tone markers, Japanese Kanji/Kana to Romaji, and Korean Hangul to Romanization.',
      'Persistent transliteration script: your chosen reading script remains active across continuous track changes.',
      'Preserves exact word-level synchronized timestamps without desynchronization.',
    ],
    specs: [
      { label: 'Scripts Supported', value: '12+ Global Scripts' },
      { label: 'Offline Matrix', value: 'Pure Dart Sanscript' },
      { label: 'Sync Resolution', value: 'Word-Level <mm:ss.xx>' },
      { label: 'Latency', value: '0 ms (Pre-compiled)' },
    ],
  },
  {
    id: 'streaming',
    icon: <Radio size={24} />,
    badge: '6-TIER RESOLVER',
    title: 'Multi-Source Composite Audio Streaming',
    subtitle:
      'Resilient composite stream resolver seamlessly negotiating JioSaavn 320kbps CD decryption, YouTube Music Opus/AAC, and local offline caches.',
    details: [
      'Tiered fallback prioritizes cached 24-bit upscaled WAVs and local files before streaming.',
      'Direct JioSaavn 320kbps CD quality decryption with uncompressed 500x500 album art.',
      'YouTube Music InnerTube REST JSON extractor with single-flight request deduplication.',
      'Adaptive timeout scaling on 2G/3G slow networks with exponential backoff and jitter.',
    ],
    specs: [
      { label: 'Max Bitrate', value: '320 kbps / FLAC' },
      { label: 'Resolution Tiers', value: '6 Fallback Tiers' },
      { label: 'Network Guard', value: 'Adaptive 2G-5G' },
      { label: 'Host Security', value: 'Strict CDN Whitelist' },
    ],
  },
  {
    id: 'themes',
    icon: <Palette size={24} />,
    badge: 'QUAD SIGNATURE SYSTEM',
    title: 'Noir Black, Noir White, Liquid Glass & Material U',
    subtitle:
      'A refined aesthetic language tailored for OLED battery savings, modern gallery minimalism, translucent sapphire depth, and Android 12+ wallpaper dynamic color.',
    details: [
      'Noir Black: Pure OLED obsidian (#070709) with high-contrast titanium typography.',
      'Noir White: Studio porcelain canvas with sharp dark typography and subtle borders.',
      'Liquid Glass: Deep sapphire canvas with real-time blur and aurora cyan accents.',
      'Material U: OS wallpaper dynamic palette extraction with branded seed fallback.',
    ],
    specs: [
      { label: 'Themes', value: '4 First-Class Palettes' },
      { label: 'Token Model', value: 'Semantic Design Tokens' },
      { label: 'OS Sync', value: 'System Brightness & Accent' },
      { label: 'Contrast', value: 'Elevated High-Contrast' },
    ],
  },
  {
    id: 'speaker-mesh',
    icon: <Bluetooth size={24} />,
    badge: 'LOCAL SYNC',
    title: 'Speaker Mesh & SyncCast Party Mode',
    subtitle:
      'Turn every phone in the room into an synchronized multi-room speaker system using sample-accurate local clock synchronization.',
    details: [
      'NTP-style peer-to-peer clock synchronization keeping playback aligned under 5ms.',
      'Operates completely offline over local Wi-Fi or mobile hotspot — zero internet required.',
      'Each connected device can route audio to its own paired Bluetooth speaker or headphones.',
      'Host controls collaborative queue while allowing guest requests in real time.',
    ],
    specs: [
      { label: 'Protocol', value: 'Local WebSocket NTP' },
      { label: 'Sync Accuracy', value: '< 5 ms Sample Sync' },
      { label: 'Cloud Required', value: 'No (100% Local LAN)' },
      { label: 'Output', value: 'Independent Bluetooth' },
    ],
  },
  {
    id: 'privacy',
    icon: <ShieldCheck size={24} />,
    badge: 'ZERO TELEMETRY',
    title: 'Privacy Sovereignty & Anti-SSRF Security',
    subtitle:
      'Engineered without user accounts, without tracking SDKs, and with rigorous network perimeter guards.',
    details: [
      'Zero telemetry: no Google Analytics, no Firebase, no tracking beacons.',
      'Anti-SSRF guard: rejects all private loopback IP ranges, link-local, and insecure HTTP URLs.',
      'Taste vector stays on device: neural embeddings are computed and stored in local SQLite.',
      '100% open source under GNU General Public License v3.0.',
    ],
    specs: [
      { label: 'Telemetry', value: '0% None' },
      { label: 'Account', value: 'Not Required' },
      { label: 'License', value: 'GPL-3.0' },
      { label: 'Security', value: 'Host Whitelist & Anti-SSRF' },
    ],
  },
];

export function FeaturesPage() {
  return (
    <div className={styles.container}>
      <header className={styles.header}>
        <span className={styles.tag}>ENGINEERING EXCELLENCE</span>
        <h1 className={styles.title}>Under the Hood of Noctra</h1>
        <p className={styles.subtitle}>
          Explore the on-device DSP pipeline, neural recommendation vectors, multi-script lyrics matrix, and security architecture.
        </p>
      </header>

      <div className={styles.featureList}>
        {FEATURE_BLOCKS.map((block) => (
          <section key={block.id} id={block.id} className={styles.blockCard}>
            <div className={styles.blockHeader}>
              <div className={styles.blockIconWrapper}>{block.icon}</div>
              <div className={styles.blockMeta}>
                <span className={styles.blockBadge}>{block.badge}</span>
                <h2 className={styles.blockTitle}>{block.title}</h2>
              </div>
            </div>

            <p className={styles.blockSubtitle}>{block.subtitle}</p>

            <div className={styles.blockBody}>
              <div className={styles.detailsCol}>
                <h3 className={styles.colHeading}>Key Capabilities</h3>
                <ul className={styles.detailsList}>
                  {block.details.map((detail, idx) => (
                    <li key={idx} className={styles.detailItem}>
                      <span className={styles.bullet}>•</span>
                      <span>{detail}</span>
                    </li>
                  ))}
                </ul>
              </div>

              <div className={styles.specsCol}>
                <h3 className={styles.colHeading}>Specifications</h3>
                <div className={styles.specsGrid}>
                  {block.specs.map((spec) => (
                    <div key={spec.label} className={styles.specBox}>
                      <span className={styles.specLabel}>{spec.label}</span>
                      <span className={styles.specValue}>{spec.value}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </section>
        ))}
      </div>

      <div className={styles.bottomCta}>
        <h2>Experience Noctra Firsthand</h2>
        <p>Download the latest release for your platform and hear the difference.</p>
        <Link to="/download" className={styles.btnPrimary}>
          <span>Go to Downloads</span>
          <ArrowRight size={16} />
        </Link>
      </div>
    </div>
  );
}
