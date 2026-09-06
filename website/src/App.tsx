import { useState, useEffect } from 'react';
import { 
  Download, 
  Check, 
  Copy, 
  Play, 
  Pause, 
  Shuffle, 
  Sliders, 
  FileJson, 
  FileSpreadsheet, 
  ExternalLink, 
  Smartphone, 
  Monitor, 
  Terminal, 
  Sparkles, 
  Music, 
  Send 
} from 'lucide-react';

type ThemeType = 'liquid-glass' | 'noir-black' | 'noir-white';
type PlatformType = 'windows' | 'linux' | 'android' | 'ios';

interface ShowcaseItem {
  id: string;
  title: string;
  desc: string;
  icon: string;
  screenshot: string;
  captionTitle: string;
  captionDesc: string;
  badges: string[];
}

const SHOWCASE_ITEMS: ShowcaseItem[] = [
  {
    id: 'player',
    title: 'Hi-Res Player',
    desc: 'Bit-depth & telemetry',
    icon: '🎧',
    screenshot: 'screenshots/player.png',
    captionTitle: 'Pragmatic Audio Telemetry',
    captionDesc: 'Master 320k & 24-bit Hi-Res badges, real-time waveform seekbar, 3D soundstage virtualizer, and concert hall acoustic presets.',
    badges: ['Master 320k', '3D Virtualizer', 'Concert Acoustics', 'AI Radio']
  },
  {
    id: 'lyrics',
    title: 'Bilingual Lyrics',
    desc: 'Subtitles & transliteration',
    icon: '🎤',
    screenshot: 'screenshots/lyrics.png',
    captionTitle: 'Apple Music / Spotify Style Subtitles',
    captionDesc: 'Bilingual LRC lines sharing matching timestamps consolidate automatically into a primary sung vocal with a subtle, dimmed italic translation subtitle.',
    badges: ['Auto Consolidation', 'Subtle Subtitles', 'Devanagari', 'Gurmukhi', 'Urdu']
  },
  {
    id: 'equalizer',
    title: 'IEM DSP Curves',
    desc: 'Harman, Moondrop & Wan\'er',
    icon: '🎚️',
    screenshot: 'screenshots/equalizer.png',
    captionTitle: 'Audiophile IEM Target Presets',
    captionDesc: 'Hardware-level parametric frequency curves for Harman IEM, Moondrop VDSF, and Tangzu Wan\'er with 5-band DSP and Bass Boost.',
    badges: ['Harman Target', 'Moondrop VDSF', 'Tangzu Wan\'er', '5-Band DSP']
  },
  {
    id: 'library',
    title: 'Library & Remix',
    desc: 'Shuffle, remix & transfer',
    icon: '📁',
    screenshot: 'screenshots/library.png',
    captionTitle: 'Custom Folders, Shuffle & Algorithmic Remix',
    captionDesc: 'One-tap Shuffle and deterministic algorithmic Remix for all custom playlists, Spotify imports, and local collections with SQLite persistence.',
    badges: ['Shuffle', 'Remix Reorder', 'Universal Transfer', 'SQLite Vault']
  },
  {
    id: 'ai_studio',
    title: 'AI Taste Studio',
    desc: 'On-device taste vectors',
    icon: '🧠',
    screenshot: 'screenshots/ai_studio.png',
    captionTitle: 'Neural Taste Modeling',
    captionDesc: '120-dimensional neural embedding maps user acoustic traits and classifies listening into archetypes with zero cloud telemetry.',
    badges: ['120D Embeddings', 'Audio DNA Radar', 'Zero Cloud', 'Seed Stations']
  },
  {
    id: 'home',
    title: 'Discovery Feed',
    desc: 'Global charts & artists',
    icon: '🌌',
    screenshot: 'screenshots/home.png',
    captionTitle: 'Curated Charts & Artists',
    captionDesc: 'Real-time trending charts, Wikipedia artist discographies, and locally embedded recommendation graphs.',
    badges: ['Global Top 50', 'Explore Artists', 'Offline Vault', 'Dynamic Mixes']
  },
  {
    id: 'search',
    title: 'Instant Search',
    desc: 'High-fidelity catalog filters',
    icon: '🔍',
    screenshot: 'screenshots/search.png',
    captionTitle: 'Multi-Source Catalog Explorer',
    captionDesc: 'Instant as-you-type search across Deezer Hi-Fi, Qobuz, Apple Music catalogs, and direct YouTube audio streams.',
    badges: ['High Fidelity Filter', 'Direct Stream', 'Album Search', 'Lossless Badge']
  },
  {
    id: 'settings',
    title: 'Triple Noir',
    desc: 'Obsidian & Liquid Glass',
    icon: '⚙️',
    screenshot: 'screenshots/settings.png',
    captionTitle: 'Swiss Minimalist Themes',
    captionDesc: 'Choose between Obsidian Noir Black, Editorial Noir White, or Sapphire Liquid Glass with synchronized Android launcher icons.',
    badges: ['Noir Black', 'Noir White', 'Liquid Glass', 'Dynamic Icons']
  }
];

const LYRIC_DEMO: Record<string, { line1: string; line2: string; line3: string; line4: string }> = {
  latin: {
    line1: 'Dum-da-ra-ra-re, dum-da-ra-re...',
    line2: 'Saamne se nikla mere chaand yeh abhi',
    line3: 'Poora ho gaya ho jaise khwaab yeh koi',
    line4: 'Haan, yeh kaisi hawaayein hain jo tere gaalon ko chhoo ke guzarti hain?'
  },
  devanagari: {
    line1: 'दम-दा-रा-रा-रे, दम-दा-रा-रे...',
    line2: 'सामने से निकला मेरे चाँद ये अभी',
    line3: 'पूरा हो गया हो जैसे ख़्वाब ये कोई',
    line4: 'हाँ, ये कैसी हवाएँ हैं जो तेरे गालों को छू के गुज़रती हैं?'
  },
  gurmukhi: {
    line1: 'ਦਮ-ਦਾ-ਰਾ-ਰਾ-ਰੇ, ਦਮ-ਦਾ-ਰਾ-ਰੇ...',
    line2: 'ਸਾਮਨੇ ਸੇ ਨਿਕਲਾ ਮੇਰੇ ਚਾਂਦ ਯੇਹ ਅਭੀ',
    line3: 'ਪੂਰਾ ਹੋ ਗਯਾ ਹੋ ਜੈਸੇ ਖ਼੍ਵਾਬ ਯੇਹ ਕੋਈ',
    line4: 'ਹਾਂ, ਯੇਹ ਕੈਸੀ ਹਵਾਏਂ ਹੈਂ ਜੋ ਤੇਰੇ ਗਾਲੋਂ ਕੋ ਛੂ ਕੇ ਗੁਜ਼ਰਤੀ ਹੈਂ?'
  },
  urdu: {
    line1: 'دم-دا-را-را-رے، دم-دا-را-رے...',
    line2: 'سامنے سے نکلا میرے چاند یہ ابھی',
    line3: 'پورا ہو گیا ہو جیسے خواب یہ کوئی',
    line4: 'ہاں، یہ کیسی ہوائیں ہیں جو تیرے گالوں کو چھو کے گزرتی ہیں؟'
  }
};

const SAMPLE_MANIFEST_JSON = `{
  "format": "noctra_playlist_v1",
  "version": "1.0.5",
  "exportedAt": "2026-09-06T21:30:00Z",
  "playlist": {
    "name": "Midnight Audiophile Studio",
    "trackCount": 3,
    "songs": [
      {
        "title": "Tum Se Hi",
        "artist": "Mohit Chauhan, Pritam",
        "durationMs": 321000,
        "format": "FLAC 24-bit/192kHz",
        "artwork": "https://images.noctra.app/covers/rockstar.jpg"
      },
      {
        "title": "Midnight City",
        "artist": "M83",
        "durationMs": 243000,
        "format": "FLAC 16-bit/44.1kHz",
        "artwork": "https://images.noctra.app/covers/m83.jpg"
      },
      {
        "title": "Starboy",
        "artist": "The Weeknd, Daft Punk",
        "durationMs": 230000,
        "format": "Opus 48kHz Master",
        "artwork": "https://images.noctra.app/covers/starboy.jpg"
      }
    ]
  }
}`;

const SAMPLE_CSV = `Title,Artist,Duration (sec),Format,Tags
"Tum Se Hi","Mohit Chauhan, Pritam",321,"FLAC 24/192","Audiophile, Acoustic"
"Midnight City","M83",243,"FLAC 16/44.1","Synthwave, Electronic"
"Starboy","The Weeknd, Daft Punk",230,"Opus 48k","Pop, R&B"`;

const THEME_CONFIGS: Record<ThemeType, { id: ThemeType; name: string; icon: string; fontBadge: string; nextThemeName: string }> = {
  'liquid-glass': {
    id: 'liquid-glass',
    name: 'Liquid Glass',
    icon: '💧',
    fontBadge: 'Outfit Sans',
    nextThemeName: 'Noir Black',
  },
  'noir-black': {
    id: 'noir-black',
    name: 'Noir Black',
    icon: '🌑',
    fontBadge: 'Space & Mono',
    nextThemeName: 'Noir White',
  },
  'noir-white': {
    id: 'noir-white',
    name: 'Noir White',
    icon: '☀️',
    fontBadge: 'Newsreader Serif',
    nextThemeName: 'Liquid Glass',
  },
};

export default function App() {
  const [theme, setTheme] = useState<ThemeType>(() => {
    const saved = localStorage.getItem('noctra-theme') as ThemeType;
    if (saved === 'liquid-glass' || saved === 'noir-black' || saved === 'noir-white') {
      return saved;
    }
    return 'liquid-glass';
  });

  const [platform, setPlatform] = useState<PlatformType>('windows');
  const [activeShowcase, setActiveShowcase] = useState<ShowcaseItem>(SHOWCASE_ITEMS[0]);
  const [activeScript, setActiveScript] = useState<string>('latin');
  const [isPlaying, setIsPlaying] = useState<boolean>(true);
  const [audioFormat, setAudioFormat] = useState<'24/192' | '16/44.1' | 'opus'>('24/192');
  const [soundstage, setSoundstage] = useState<'stereo' | '3d' | 'concert' | 'atmos'>('3d');
  const [transferTab, setTransferTab] = useState<'preview' | 'json' | 'csv'>('preview');
  const [eqPreset, setEqPreset] = useState<'harman' | 'moondrop' | 'waner'>('harman');
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    document.body.setAttribute('data-theme', theme);
    localStorage.setItem('noctra-theme', theme);
  }, [theme]);

  const cycleTheme = () => {
    setTheme((prev) => {
      if (prev === 'liquid-glass') return 'noir-black';
      if (prev === 'noir-black') return 'noir-white';
      return 'liquid-glass';
    });
  };

  const currentTheme = THEME_CONFIGS[theme] || THEME_CONFIGS['liquid-glass'];

  const getBrandLogo = () => {
    switch (theme) {
      case 'noir-black':
        return './images/logo_noctra_noir_black.png';
      case 'noir-white':
        return './images/logo_noctra_noir_white.png';
      case 'liquid-glass':
      default:
        return './images/logo_noctra_liquid_glass.png';
    }
  };

  const copyText = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  return (
    <div className={`noctra-app theme-${theme}`} data-theme={theme}>
      {/* Glow mesh backdrop */}
      <div className="glow-mesh glow-1" />
      <div className="glow-mesh glow-2" />
      <div className="glow-mesh glow-3" />

      {/* Navigation Header */}
      {/* Sleek Minimal Floating Header */}
      <header className="site-header">
        <div className="nav-container">
          <a href="#" className="brand-badge">
            <img src={getBrandLogo()} alt="Noctra" className="brand-logo" />
            <span className="brand-name">NOCTRA</span>
          </a>

          <nav className="nav-links">
            <a href="#showcase">Features</a>
            <a href="#player-demo">Telemetry</a>
            <a href="#transfer-studio">Transfer</a>
            <a href="#downloads">Downloads</a>
          </nav>

          <div className="nav-actions">
            {/* Minimal Theme Switcher Icon */}
            <button 
              className="minimal-theme-btn"
              onClick={cycleTheme}
              title={`Active: ${currentTheme.name} (${currentTheme.fontBadge}). Tap to switch.`}
              type="button"
              aria-label="Switch Theme"
            >
              <span className="minimal-theme-icon">{currentTheme.icon}</span>
            </button>

            {/* Telegram Official Logo Only */}
            <a 
              href="https://t.me/Noctra_app" 
              target="_blank" 
              rel="noopener noreferrer" 
              className="tg-logo-btn"
              title="Join Noctra Telegram Channel (@Noctra_app)"
              aria-label="Noctra Telegram Channel"
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M12 2C6.48 2 2 6.48 2 12C2 17.52 6.48 22 12 22C17.52 22 22 17.52 22 12C22 6.48 17.52 2 12 2ZM16.64 8.8C16.49 10.38 15.84 14.22 15.51 15.99C15.37 16.74 15.09 16.99 14.83 17.02C14.25 17.07 13.81 16.64 13.25 16.27C12.37 15.69 11.87 15.33 11.02 14.77C10.03 14.12 10.67 13.76 11.24 13.18C11.39 13.03 13.95 10.7 14 10.49C14.01 10.45 14.01 10.33 13.94 10.27C13.87 10.21 13.77 10.23 13.7 10.25C13.6 10.27 12.01 11.32 8.94 13.38C8.5 13.68 8.1 13.83 7.74 13.82C7.34 13.81 6.57 13.59 6 13.4C5.3 13.17 4.75 13.05 4.8 12.67C4.83 12.47 5.11 12.27 5.64 12.06C8.88 10.65 11.04 9.72 12.12 9.27C15.2 7.98 15.84 7.76 16.26 7.76C16.35 7.76 16.56 7.78 16.69 7.89C16.8 7.98 16.83 8.11 16.84 8.2C16.83 8.27 16.85 8.48 16.64 8.8Z" fill="currentColor"/>
              </svg>
            </a>

            {/* Minimal Download Button */}
            <a href="#downloads" className="btn btn-primary btn-sm">
              <Download size={14} />
              <span>Get Noctra</span>
            </a>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section className="hero-section">
        <div className="hero-pill">
          <span className="pulse-dot" />
          <span>v1.0.5 Production Release &bull; Native Windows .exe &bull; Linux .deb &bull; Android APK &bull; iOS .ipa</span>
        </div>

        <h1 className="hero-title">
          Autonomous Music.<br />
          <span className="gradient-text">Pure Acoustic Sovereignty.</span>
        </h1>

        <p className="hero-subtitle">
          Bit-perfect lossless FLAC up to <strong>24-bit / 192 kHz</strong>, consolidated bilingual subtitles, on-device taste neural vectors, playlist remixing, and cross-device transfer manifests. Single-file native packages for <strong>Windows, Linux, Android, and iOS</strong>.
        </p>

        <div className="hero-cta-group">
          <a href="#downloads" className="btn btn-primary btn-large">
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Download size={20} />
              <span>Download Native Packages</span>
            </div>
            <span className="btn-subtext">Windows • Linux • Android • iOS</span>
          </a>
          <a 
            href="https://t.me/Noctra_app" 
            target="_blank" 
            rel="noopener noreferrer" 
            className="btn btn-telegram-large"
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Send size={20} />
              <span>Join Telegram Channel</span>
            </div>
            <span className="btn-subtext">@Noctra_app • Announcements</span>
          </a>
        </div>

        {/* Direct OS Quick Links */}
        <div className="hero-os-pills">
          <span className="hero-pills-label">Direct Builds:</span>
          <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-Setup-x64.exe" className="hero-os-pill">
            <Monitor size={13} /> Windows (.exe)
          </a>
          <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/noctra_1.0.5_amd64.deb" className="hero-os-pill">
            <Terminal size={13} /> Linux (.deb)
          </a>
          <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-arm64-v8a.apk" className="hero-os-pill">
            <Smartphone size={13} /> Android (.apk)
          </a>
          <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5.ipa" className="hero-os-pill">
            <Sparkles size={13} /> iOS (.ipa)
          </a>
        </div>

        {/* Metrics Strip */}
        <div className="metrics-strip">
          <div className="metric-card">
            <span className="metric-value">24-bit / 192kHz</span>
            <span className="metric-label">Lossless Master FLAC</span>
          </div>
          <div className="metric-divider" />
          <div className="metric-card">
            <span className="metric-value">4 Platforms</span>
            <span className="metric-label">Win • Linux • Android • iOS</span>
          </div>
          <div className="metric-divider" />
          <div className="metric-card">
            <span className="metric-value">0%</span>
            <span className="metric-label">Cloud Telemetry</span>
          </div>
          <div className="metric-divider" />
          <div className="metric-card">
            <span className="metric-value">Harman & Moondrop</span>
            <span className="metric-label">Audiophile IEM Targets</span>
          </div>
        </div>
      </section>

      {/* Interactive Live Audio Telemetry Player */}
      <section id="player-demo" className="player-demo-section">
        <div className="section-header">
          <span className="section-tag">INTERACTIVE AUDIO DEMO</span>
          <h2 className="section-title">Experience Bit-Perfect Audio Telemetry</h2>
          <p className="section-subtitle">Noctra exposes real-time hardware audio pipeline indicators so you always know your exact sample rate, bit depth, and acoustic stage.</p>
        </div>

        <div className="player-demo-card">
          <div className="player-demo-top">
            <div className="player-demo-art">
              <img src="screenshots/player.png" alt="Album Cover" className="demo-art-img" />
              <button 
                className="play-overlay-btn" 
                onClick={() => setIsPlaying(!isPlaying)}
                title={isPlaying ? "Pause simulated stream" : "Play simulated stream"}
              >
                {isPlaying ? <Pause size={24} /> : <Play size={24} />}
              </button>
            </div>

            <div className="player-demo-info">
              <div className="player-demo-tags">
                <span className={`format-badge ${audioFormat === '24/192' ? 'active' : ''}`} onClick={() => setAudioFormat('24/192')}>
                  {audioFormat === '24/192' ? '● FLAC 24-bit / 192 kHz' : 'FLAC 24-bit / 192 kHz'}
                </span>
                <span className={`format-badge ${audioFormat === '16/44.1' ? 'active' : ''}`} onClick={() => setAudioFormat('16/44.1')}>
                  {audioFormat === '16/44.1' ? '● FLAC 16-bit / 44.1 kHz' : 'FLAC 16-bit / 44.1 kHz'}
                </span>
                <span className={`format-badge ${audioFormat === 'opus' ? 'active' : ''}`} onClick={() => setAudioFormat('opus')}>
                  {audioFormat === 'opus' ? '● Opus 48 kHz / 320k' : 'Opus 48 kHz / 320k'}
                </span>
              </div>

              <h3 className="demo-track-title">Tum Se Hi (Studio Master Mix)</h3>
              <p className="demo-track-artist">Mohit Chauhan &bull; Pritam &bull; Jab We Met</p>

              <div className="soundstage-selector">
                <span className="soundstage-label">Acoustic Soundstage:</span>
                <div className="soundstage-chips">
                  {(['stereo', '3d', 'concert', 'atmos'] as const).map((mode) => (
                    <button 
                      key={mode} 
                      className={`chip ${soundstage === mode ? 'active' : ''}`}
                      onClick={() => setSoundstage(mode)}
                    >
                      {mode === 'stereo' && 'Direct Stereo'}
                      {mode === '3d' && '3D Virtualizer'}
                      {mode === 'concert' && 'Concert Hall'}
                      {mode === 'atmos' && 'Dolby Matrix'}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>

          {/* Real-time frequency bars */}
          <div className="player-demo-waveform">
            <div className="spectrum-bars">
              {[65, 80, 45, 90, 70, 85, 95, 60, 75, 90, 80, 65, 88, 72, 92, 58, 84, 66, 78, 88].map((val, idx) => (
                <div 
                  key={idx} 
                  className={`spectrum-bar ${isPlaying ? 'animated' : 'idle'}`} 
                  style={{ 
                    height: isPlaying ? `${val}%` : '15%',
                    animationDelay: `${(idx % 6) * 0.12}s`
                  }} 
                />
              ))}
            </div>
            <div className="waveform-labels">
              <span>0:42</span>
              <span className="waveform-mode-tag">
                {audioFormat === '24/192' ? 'LOSSLESS 9,216 kbps' : audioFormat === '16/44.1' ? 'LOSSLESS 1,411 kbps' : 'OPUS 320 kbps'}
              </span>
              <span>5:21</span>
            </div>
          </div>
        </div>
      </section>

      {/* NEW IN v1.0.5: Universal Playlist Transfer Protocol & Remix */}
      <section id="transfer-studio" className="transfer-studio-section">
        <div className="section-header">
          <span className="section-tag">NEW IN V1.0.5</span>
          <h2 className="section-title">Universal Playlist Transfer & Algorithmic Remix</h2>
          <p className="section-subtitle">Export and transfer playlists across devices via lossless JSON manifest (<code>.noctra.json</code>) or spreadsheet CSV (<code>.csv</code>). 100% on-device with zero account lock-in.</p>
        </div>

        <div className="transfer-card">
          <div className="transfer-header-row">
            <div className="transfer-tabs">
              <button 
                className={`tab-btn ${transferTab === 'preview' ? 'active' : ''}`}
                onClick={() => setTransferTab('preview')}
              >
                <Music size={16} />
                <span>Visual Playlist</span>
              </button>
              <button 
                className={`tab-btn ${transferTab === 'json' ? 'active' : ''}`}
                onClick={() => setTransferTab('json')}
              >
                <FileJson size={16} />
                <span>JSON Manifest (.noctra.json)</span>
              </button>
              <button 
                className={`tab-btn ${transferTab === 'csv' ? 'active' : ''}`}
                onClick={() => setTransferTab('csv')}
              >
                <FileSpreadsheet size={16} />
                <span>Universal CSV (.csv)</span>
              </button>
            </div>

            <div className="transfer-actions">
              {transferTab === 'json' && (
                <button 
                  className="btn btn-glass btn-sm"
                  onClick={() => copyText(SAMPLE_MANIFEST_JSON, 'manifest')}
                >
                  {copiedKey === 'manifest' ? <Check size={14} /> : <Copy size={14} />}
                  <span>{copiedKey === 'manifest' ? 'Copied Manifest!' : 'Copy JSON'}</span>
                </button>
              )}
              {transferTab === 'csv' && (
                <button 
                  className="btn btn-glass btn-sm"
                  onClick={() => copyText(SAMPLE_CSV, 'csv')}
                >
                  {copiedKey === 'csv' ? <Check size={14} /> : <Copy size={14} />}
                  <span>{copiedKey === 'csv' ? 'Copied CSV!' : 'Copy CSV'}</span>
                </button>
              )}
            </div>
          </div>

          <div className="transfer-content-box">
            {transferTab === 'preview' && (
              <div className="playlist-preview-grid">
                <div className="playlist-meta-panel">
                  <div className="playlist-art-badge">
                    <Sparkles size={28} />
                  </div>
                  <h4>Midnight Audiophile Studio</h4>
                  <span className="playlist-badge">v1.0.5 SQLite Folder</span>
                  <p>Preserves artist credits, high-res cover art links, and sample rate telemetry.</p>
                  
                  <div className="playlist-btn-group">
                    <button className="btn btn-primary btn-sm" onClick={() => alert("Simulated 1-tap Shuffle activated!")}>
                      <Shuffle size={14} />
                      <span>1-Tap Shuffle</span>
                    </button>
                    <button className="btn btn-glass btn-sm" onClick={() => alert("Simulated Algorithmic Remix Reorder!")}>
                      <Sparkles size={14} />
                      <span>Remix Reorder</span>
                    </button>
                  </div>
                </div>

                <div className="playlist-track-list">
                  <div className="track-item">
                    <span className="track-num">01</span>
                    <div className="track-details">
                      <span className="track-name">Tum Se Hi</span>
                      <span className="track-sub">Mohit Chauhan &bull; Pritam</span>
                    </div>
                    <span className="track-tag-pill">24/192 FLAC</span>
                  </div>
                  <div className="track-item">
                    <span className="track-num">02</span>
                    <div className="track-details">
                      <span className="track-name">Midnight City</span>
                      <span className="track-sub">M83</span>
                    </div>
                    <span className="track-tag-pill">16/44.1 FLAC</span>
                  </div>
                  <div className="track-item">
                    <span className="track-num">03</span>
                    <div className="track-details">
                      <span className="track-name">Starboy</span>
                      <span className="track-sub">The Weeknd &bull; Daft Punk</span>
                    </div>
                    <span className="track-tag-pill">Opus 320k</span>
                  </div>
                </div>
              </div>
            )}

            {transferTab === 'json' && (
              <pre className="code-display-block">
                <code>{SAMPLE_MANIFEST_JSON}</code>
              </pre>
            )}

            {transferTab === 'csv' && (
              <pre className="code-display-block">
                <code>{SAMPLE_CSV}</code>
              </pre>
            )}
          </div>
        </div>
      </section>

      {/* Interactive Device Showcase */}
      <section id="showcase" className="showcase-section">
        <div className="section-header">
          <span className="section-tag">AUTHENTIC HARDWARE SCREENSHOTS</span>
          <h2 className="section-title">Designed for Audiophiles. Refined for Your Eyes.</h2>
          <p className="section-subtitle">Real screen captures rendered on physical 120Hz OLED hardware with Noctra's signature Triple Noir design system.</p>
        </div>

        <div className="showcase-container">
          <div className="showcase-tabs" role="tablist">
            {SHOWCASE_ITEMS.map((item) => (
              <button
                key={item.id}
                className={`tab-btn ${activeShowcase.id === item.id ? 'active' : ''}`}
                onClick={() => setActiveShowcase(item)}
              >
                <div className="tab-header-row">
                  <span className="tab-icon">{item.icon}</span>
                  <span className="tab-title">{item.title}</span>
                </div>
                <span className="tab-desc">{item.desc}</span>
              </button>
            ))}
          </div>

          <div className="phone-mockup-wrapper">
            <div className="phone-frame">
              <div className="phone-notch" />
              <div className="phone-screen">
                <img 
                  src={activeShowcase.screenshot} 
                  alt={activeShowcase.title} 
                  className="screen-img"
                  key={activeShowcase.screenshot}
                />
              </div>
            </div>

            <div className="phone-caption-card">
              <h3>{activeShowcase.captionTitle}</h3>
              <p>{activeShowcase.captionDesc}</p>
              <div className="badge-list">
                {activeShowcase.badges.map((badge, idx) => (
                  <span key={idx} className="badge-pill">{badge}</span>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Bilingual Lyrics & AksharaEngine */}
      <section id="lyrics" className="lyrics-section">
        <div className="section-header">
          <span className="section-tag">INNOVATIVE LYRIC ENGINE</span>
          <h2 className="section-title">Apple Music &bull; Spotify Style Bilingual Subtitles</h2>
          <p className="section-subtitle">When lyrics contain dual languages sharing the same timestamp, Noctra automatically consolidates them: sung vocals in primary focus, English translation in dimmed italic subtitles.</p>
        </div>

        <div className="lyrics-studio-card">
          <div className="script-selector-row">
            <span className="script-label">AksharaEngine Script Switcher:</span>
            <div className="script-buttons">
              {(['latin', 'devanagari', 'gurmukhi', 'urdu'] as const).map((script) => (
                <button
                  key={script}
                  className={`script-btn ${activeScript === script ? 'active' : ''}`}
                  onClick={() => setActiveScript(script)}
                >
                  {script === 'latin' && 'Latin / Romanized'}
                  {script === 'devanagari' && 'Devanagari (हिन्दी)'}
                  {script === 'gurmukhi' && 'Gurmukhi (ਪੰਜਾਬੀ)'}
                  {script === 'urdu' && 'Urdu (اردو)'}
                </button>
              ))}
            </div>
          </div>

          <div className="lyrics-karaoke-box">
            <div className="lyric-line past">
              <span className="sung-vocal">{LYRIC_DEMO[activeScript].line1}</span>
              <span className="translation-subtitle">Dum-da-ra-ra-re, humming into the breeze...</span>
            </div>
            
            <div className="lyric-line past">
              <span className="sung-vocal">{LYRIC_DEMO[activeScript].line2}</span>
              <span className="translation-subtitle">My moon just stepped out right in front of me</span>
            </div>

            <div className="lyric-line active">
              <span className="sung-vocal active-glow">{LYRIC_DEMO[activeScript].line3}</span>
              <span className="translation-subtitle active-sub">As if some long-awaited dream has finally come true</span>
            </div>

            <div className="lyric-line future">
              <span className="sung-vocal">{LYRIC_DEMO[activeScript].line4}</span>
              <span className="translation-subtitle">Yes, what gentle winds are these that brush past your cheeks?</span>
            </div>
          </div>
        </div>
      </section>

      {/* Audiophile IEM Target Curves */}
      <section id="audiophile" className="audiophile-section">
        <div className="section-header">
          <span className="section-tag">DSP EQUALIZATION</span>
          <h2 className="section-title">Hardware-Level Audiophile IEM Target Curves</h2>
          <p className="section-subtitle">Switch seamlessly between Harman IEM 2019, Moondrop VDSF, and Tangzu Wan'er target response curves via 5-band parametric DSP.</p>
        </div>

        <div className="audiophile-grid">
          <div className="eq-preset-card">
            <h3>Target Response Selector</h3>
            <div className="eq-presets-list">
              <button 
                className={`eq-btn ${eqPreset === 'harman' ? 'active' : ''}`}
                onClick={() => setEqPreset('harman')}
              >
                <div className="eq-btn-header">
                  <strong>Harman IEM 2019</strong>
                  <span className="eq-badge">+6dB Sub-Bass Shelf</span>
                </div>
                <p>Natural acoustic pinna gain with a controlled sub-bass shelf for universal musicality.</p>
              </button>

              <button 
                className={`eq-btn ${eqPreset === 'moondrop' ? 'active' : ''}`}
                onClick={() => setEqPreset('moondrop')}
              >
                <div className="eq-btn-header">
                  <strong>Moondrop VDSF Target</strong>
                  <span className="eq-badge">Diffuse-Field Midrange</span>
                </div>
                <p>Airy treble extension, clinical vocal resolution, and transparent spatial separation.</p>
              </button>

              <button 
                className={`eq-btn ${eqPreset === 'waner' ? 'active' : ''}`}
                onClick={() => setEqPreset('waner')}
              >
                <div className="eq-btn-header">
                  <strong>Tangzu Wan'er Warm Curve</strong>
                  <span className="eq-badge">Smooth Fatigue-Free</span>
                </div>
                <p>Warm lower-midrange presence, velvety vocals, and smooth non-fatiguing treble.</p>
              </button>
            </div>
          </div>

          <div className="eq-visualizer-card">
            <div className="eq-visualizer-header">
              <Sliders size={18} />
              <span>5-Band Parametric Hardware Gains</span>
            </div>

            <div className="faders-row">
              <div className="fader-col">
                <div className="fader-bar"><div className="fader-fill" style={{ height: eqPreset === 'harman' ? '75%' : eqPreset === 'moondrop' ? '50%' : '65%' }} /></div>
                <span className="fader-hz">60 Hz</span>
                <span className="fader-db">{eqPreset === 'harman' ? '+5.2dB' : eqPreset === 'moondrop' ? '+1.5dB' : '+3.8dB'}</span>
              </div>
              <div className="fader-col">
                <div className="fader-bar"><div className="fader-fill" style={{ height: eqPreset === 'harman' ? '60%' : eqPreset === 'moondrop' ? '45%' : '70%' }} /></div>
                <span className="fader-hz">250 Hz</span>
                <span className="fader-db">{eqPreset === 'harman' ? '+2.0dB' : eqPreset === 'moondrop' ? '0.0dB' : '+3.5dB'}</span>
              </div>
              <div className="fader-col">
                <div className="fader-bar"><div className="fader-fill" style={{ height: eqPreset === 'harman' ? '50%' : eqPreset === 'moondrop' ? '65%' : '55%' }} /></div>
                <span className="fader-hz">1 kHz</span>
                <span className="fader-db">{eqPreset === 'harman' ? '0.0dB' : eqPreset === 'moondrop' ? '+2.8dB' : '+1.0dB'}</span>
              </div>
              <div className="fader-col">
                <div className="fader-bar"><div className="fader-fill" style={{ height: eqPreset === 'harman' ? '70%' : eqPreset === 'moondrop' ? '80%' : '60%' }} /></div>
                <span className="fader-hz">4 kHz</span>
                <span className="fader-db">{eqPreset === 'harman' ? '+4.1dB' : eqPreset === 'moondrop' ? '+6.2dB' : '+2.4dB'}</span>
              </div>
              <div className="fader-col">
                <div className="fader-bar"><div className="fader-fill" style={{ height: eqPreset === 'harman' ? '65%' : eqPreset === 'moondrop' ? '75%' : '50%' }} /></div>
                <span className="fader-hz">12 kHz</span>
                <span className="fader-db">{eqPreset === 'harman' ? '+3.0dB' : eqPreset === 'moondrop' ? '+5.5dB' : '0.0dB'}</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Multi-Platform Native Downloads Hub */}
      <section id="downloads" className="download-section">
        <div className="section-header">
          <span className="section-tag">NATIVE CROSS-PLATFORM INSTALLERS</span>
          <h2 className="section-title">Download Noctra v1.0.5</h2>
          <p className="section-subtitle">Single-file standalone native installers compiled directly from source for Windows, Linux, Android, and iOS.</p>
        </div>

        {/* Quick 4-Platform Direct Download Cards Grid */}
        <div className="quick-download-grid">
          {/* Windows */}
          <div className="quick-download-card">
            <div className="quick-platform-badge-row">
              <span className="platform-tag windows-tag">WINDOWS</span>
              <span className="version-pill">v1.0.5</span>
            </div>
            <div className="quick-icon-title">
              <Monitor size={30} className="quick-os-icon win-icon" />
              <div>
                <h3>Windows</h3>
                <span className="os-subtext">Windows 10 / 11 (x64)</span>
              </div>
            </div>
            <p className="quick-desc">Inno Setup standalone installer bundling JustAudio C++ bitstream engine & desktop shortcuts.</p>
            <div className="quick-file-meta">
              <code>Noctra-1.0.5-Setup-x64.exe</code>
              <span className="meta-size">24.5 MB</span>
            </div>
            <a 
              href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-Setup-x64.exe" 
              className="btn btn-primary btn-block"
            >
              <Download size={16} />
              <span>Download .exe</span>
            </a>
          </div>

          {/* Linux */}
          <div className="quick-download-card">
            <div className="quick-platform-badge-row">
              <span className="platform-tag linux-tag">LINUX</span>
              <span className="version-pill">v1.0.5</span>
            </div>
            <div className="quick-icon-title">
              <Terminal size={30} className="quick-os-icon linux-icon" />
              <div>
                <h3>Linux</h3>
                <span className="os-subtext">Ubuntu / Debian / Mint</span>
              </div>
            </div>
            <p className="quick-desc">Native .deb package with ALSA & PulseAudio pipewire integration and app icon.</p>
            <div className="quick-file-meta">
              <code>noctra_1.0.5_amd64.deb</code>
              <span className="meta-size">18.2 MB</span>
            </div>
            <a 
              href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/noctra_1.0.5_amd64.deb" 
              className="btn btn-primary btn-block"
            >
              <Download size={16} />
              <span>Download .deb</span>
            </a>
          </div>

          {/* Android */}
          <div className="quick-download-card featured-download-card">
            <div className="quick-platform-badge-row">
              <span className="platform-tag android-tag">ANDROID</span>
              <span className="featured-badge">RECOMMENDED</span>
            </div>
            <div className="quick-icon-title">
              <Smartphone size={30} className="quick-os-icon android-icon" />
              <div>
                <h3>Android</h3>
                <span className="os-subtext">Phones, Tablets & DAP (8.0+)</span>
              </div>
            </div>
            <p className="quick-desc">ARM64 & Universal APKs with media lockscreen controls and in-app updates.</p>
            <div className="quick-file-meta">
              <code>Noctra-1.0.5-arm64-v8a.apk</code>
              <span className="meta-size">22.9 MB</span>
            </div>
            <a 
              href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-arm64-v8a.apk" 
              className="btn btn-primary btn-block"
            >
              <Download size={16} />
              <span>Download APK</span>
            </a>
          </div>

          {/* iOS */}
          <div className="quick-download-card">
            <div className="quick-platform-badge-row">
              <span className="platform-tag ios-tag">APPLE IOS</span>
              <span className="version-pill">v1.0.5</span>
            </div>
            <div className="quick-icon-title">
              <Sparkles size={30} className="quick-os-icon ios-icon" />
              <div>
                <h3>iOS</h3>
                <span className="os-subtext">iPhone & iPad (iOS 14+)</span>
              </div>
            </div>
            <p className="quick-desc">Sideloadable IPA bundle ready for AltStore, SideStore, and Sideloadly.</p>
            <div className="quick-file-meta">
              <code>Noctra-1.0.5.ipa</code>
              <span className="meta-size">19.8 MB</span>
            </div>
            <a 
              href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5.ipa" 
              className="btn btn-primary btn-block"
            >
              <Download size={16} />
              <span>Download .ipa</span>
            </a>
          </div>
        </div>

        <div className="hub-divider">
          <span>OR INSPECT VERIFICATION HASHES & TERMINAL INSTRUCTIONS</span>
        </div>

        {/* Platform Selection Tabs */}
        <div className="platform-tabs-bar">
          <button 
            className={`platform-btn ${platform === 'windows' ? 'active' : ''}`}
            onClick={() => setPlatform('windows')}
          >
            <Monitor size={18} />
            <span>Windows (.exe)</span>
          </button>
          <button 
            className={`platform-btn ${platform === 'linux' ? 'active' : ''}`}
            onClick={() => setPlatform('linux')}
          >
            <Terminal size={18} />
            <span>Linux (.deb)</span>
          </button>
          <button 
            className={`platform-btn ${platform === 'android' ? 'active' : ''}`}
            onClick={() => setPlatform('android')}
          >
            <Smartphone size={18} />
            <span>Android (APK)</span>
          </button>
          <button 
            className={`platform-btn ${platform === 'ios' ? 'active' : ''}`}
            onClick={() => setPlatform('ios')}
          >
            <Sparkles size={18} />
            <span>iOS (.ipa)</span>
          </button>
        </div>

        <div className="platform-card-container">
          {/* WINDOWS */}
          {platform === 'windows' && (
            <div className="download-card featured">
              <div className="featured-ribbon">WINDOWS STANDALONE</div>
              <div className="download-card-header">
                <div className="arch-badge">WINDOWS 10 / 11 (X64)</div>
                <h3>Noctra-1.0.5-Setup-x64.exe</h3>
                <span className="card-filesize">24.5 MB &bull; Inno Setup 1-Click Installer</span>
              </div>
              <p>Self-contained Windows executable bundling Flutter runtime, JustAudio C++ engine, desktop audio telemetry visualizer, and system shortcuts.</p>
              
              <div className="download-features-list">
                <span>✓ Zero external DLLs needed (bundled C++ audio core)</span>
                <span>✓ Start Menu & Desktop Shortcuts with uninstaller</span>
                <span>✓ Hi-Res ASIO / WASAPI bitstream audio support</span>
              </div>

              <div className="hash-box">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span className="hash-label">SHA-256 Checksum:</span>
                  <button 
                    onClick={() => copyText('ef26a48e97329c50120ec0e4d3056b1dbfcefe0c80597068c38eece315c39f09', 'win-hash')} 
                    style={{ background: 'none', border: 'none', color: 'var(--accent-cyan)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '0.72rem' }}
                  >
                    {copiedKey === 'win-hash' ? <Check size={12} /> : <Copy size={12} />}
                    <span>{copiedKey === 'win-hash' ? 'Copied' : 'Copy'}</span>
                  </button>
                </div>
                <code className="hash-code">ef26a48e97329c50120ec0e4d3056b1dbfcefe0c80597068c38eece315c39f09</code>
              </div>

              <a 
                href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-Setup-x64.exe" 
                className="btn btn-primary btn-block"
              >
                <Download size={18} />
                <span>Download Windows Installer (.exe)</span>
              </a>
            </div>
          )}

          {/* LINUX */}
          {platform === 'linux' && (
            <div className="download-card featured">
              <div className="featured-ribbon">DEBIAN / UBUNTU</div>
              <div className="download-card-header">
                <div className="arch-badge">AMD64 / X86_64</div>
                <h3>noctra_1.0.5_amd64.deb</h3>
                <span className="card-filesize">18.2 MB &bull; Debian Native Package</span>
              </div>
              <p>Native package for Ubuntu, Debian, Linux Mint, and Pop!_OS with desktop entry, system icon integration, and ALSA/PulseAudio audio pipeline.</p>
              
              <div className="terminal-install-box">
                <code>sudo dpkg -i noctra_1.0.5_amd64.deb</code>
                <button 
                  onClick={() => copyText('sudo dpkg -i noctra_1.0.5_amd64.deb', 'dpkg')}
                  className="btn-icon"
                  title="Copy terminal command"
                >
                  {copiedKey === 'dpkg' ? <Check size={14} /> : <Copy size={14} />}
                </button>
              </div>

              <div className="hash-box">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span className="hash-label">SHA-256 Checksum:</span>
                  <button 
                    onClick={() => copyText('216eaed3afccb6bc824a5e5d33536bc1cf9c45acf04f6db787b45868939b75fe', 'deb-hash')} 
                    style={{ background: 'none', border: 'none', color: 'var(--accent-cyan)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '0.72rem' }}
                  >
                    {copiedKey === 'deb-hash' ? <Check size={12} /> : <Copy size={12} />}
                    <span>{copiedKey === 'deb-hash' ? 'Copied' : 'Copy'}</span>
                  </button>
                </div>
                <code className="hash-code">216eaed3afccb6bc824a5e5d33536bc1cf9c45acf04f6db787b45868939b75fe</code>
              </div>

              <a 
                href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/noctra_1.0.5_amd64.deb" 
                className="btn btn-primary btn-block"
              >
                <Download size={18} />
                <span>Download Debian Package (.deb)</span>
              </a>
            </div>
          )}

          {/* ANDROID */}
          {platform === 'android' && (
            <div className="download-grid">
              <div className="download-card featured">
                <div className="featured-ribbon">RECOMMENDED</div>
                <div className="download-card-header">
                  <div className="arch-badge">ARM64-V8A</div>
                  <h3>Noctra ARM64</h3>
                  <span className="card-filesize">22.9 MB &bull; v1.0.5 Release</span>
                </div>
                <p>Optimized for modern 64-bit Android smartphones & tablets. Smallest footprint and highest native execution speed.</p>
                
                <div className="hash-box">
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span className="hash-label">SHA-256 Checksum:</span>
                    <button 
                      onClick={() => copyText('e142847b723fa8a9b48357a7eba5dd605726ae62c0e39521cb2cf1b8a9b47fb1', 'arm-hash')} 
                      style={{ background: 'none', border: 'none', color: 'var(--accent-cyan)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '0.72rem' }}
                    >
                      {copiedKey === 'arm-hash' ? <Check size={12} /> : <Copy size={12} />}
                      <span>{copiedKey === 'arm-hash' ? 'Copied' : 'Copy'}</span>
                    </button>
                  </div>
                  <code className="hash-code">e142847b723fa8a9b48357a7eba5dd605726ae62c0e39521cb2cf1b8a9b47fb1</code>
                </div>

                <a 
                  href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-arm64-v8a.apk" 
                  className="btn btn-primary btn-block"
                >
                  <Download size={18} />
                  <span>Download arm64-v8a APK</span>
                </a>
              </div>

              <div className="download-card">
                <div className="download-card-header">
                  <div className="arch-badge">UNIVERSAL</div>
                  <h3>Noctra Universal</h3>
                  <span className="card-filesize">63.2 MB &bull; v1.0.5 Release</span>
                </div>
                <p>Bundles all native architectures (ARM64, ARMv7, x86_64). Guarantees 100% compatibility across all Android devices.</p>
                
                <div className="hash-box">
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span className="hash-label">SHA-256 Checksum:</span>
                    <button 
                      onClick={() => copyText('5b79893b41498ac3d188d81cfde2db841980fdbd5b485d44af628c1a994aad7f', 'uni-hash')} 
                      style={{ background: 'none', border: 'none', color: 'var(--accent-cyan)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '0.72rem' }}
                    >
                      {copiedKey === 'uni-hash' ? <Check size={12} /> : <Copy size={12} />}
                      <span>{copiedKey === 'uni-hash' ? 'Copied' : 'Copy'}</span>
                    </button>
                  </div>
                  <code className="hash-code">5b79893b41498ac3d188d81cfde2db841980fdbd5b485d44af628c1a994aad7f</code>
                </div>

                <a 
                  href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-Universal.apk" 
                  className="btn btn-glass btn-block"
                >
                  <Download size={18} />
                  <span>Download Universal APK</span>
                </a>
              </div>
            </div>
          )}

          {/* IOS */}
          {platform === 'ios' && (
            <div className="download-card featured">
              <div className="featured-ribbon">SIDELOADABLE PACKAGE</div>
              <div className="download-card-header">
                <div className="arch-badge">IPHONE & IPAD</div>
                <h3>Noctra-1.0.5.ipa</h3>
                <span className="card-filesize">19.8 MB &bull; AltStore / SideStore Ready</span>
              </div>
              <p>Sideloadable iOS application package ready for installation on any non-jailbroken or jailbroken iPhone running iOS 14.0+.</p>

              <div className="ios-instructions-box">
                <strong>Easy 3-Step Sideloading:</strong>
                <ol>
                  <li>Download <code>Noctra-1.0.5.ipa</code> from the release link below.</li>
                  <li>Open <strong>AltStore</strong>, <strong>SideStore</strong>, or <strong>Sideloadly</strong> on your phone/PC.</li>
                  <li>Select the IPA and install. Enjoy pure lossless audio on iOS!</li>
                </ol>
              </div>

              <div className="hash-box">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span className="hash-label">SHA-256 Checksum:</span>
                  <button 
                    onClick={() => copyText('10a0ce8941eb4dc7005b9b8cb0525c4cc44238855295ed95e660e2469f303d36', 'ipa-hash')} 
                    style={{ background: 'none', border: 'none', color: 'var(--accent-cyan)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '0.72rem' }}
                  >
                    {copiedKey === 'ipa-hash' ? <Check size={12} /> : <Copy size={12} />}
                    <span>{copiedKey === 'ipa-hash' ? 'Copied' : 'Copy'}</span>
                  </button>
                </div>
                <code className="hash-code">10a0ce8941eb4dc7005b9b8cb0525c4cc44238855295ed95e660e2469f303d36</code>
              </div>

              <a 
                href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5.ipa" 
                className="btn btn-primary btn-block"
              >
                <Download size={18} />
                <span>Download Noctra.ipa</span>
              </a>
            </div>
          )}
        </div>

        <div className="other-downloads">
          <span>Other Downloads:</span>
          <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-armeabi-v7a.apk" className="link-tag">armeabi-v7a APK</a>
          <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-x86_64.apk" className="link-tag">x86_64 APK</a>
          <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5.aab" className="link-tag">Google Play .aab</a>
          <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/SHA256SUMS.txt" className="link-tag">Official SHA256SUMS.txt</a>
          <a href="https://github.com/nomad-guy/Noctra/releases/tag/v1.0.5" target="_blank" rel="noopener noreferrer" className="link-tag">→ View GitHub Release v1.0.5</a>
        </div>
      </section>

      {/* Community & Telegram Channel Section */}
      <section className="community-section">
        <div className="community-card">
          <div className="community-content">
            <div className="community-icon-box">
              <Send size={32} />
            </div>
            <div>
              <span className="community-pill">OFFICIAL TELEGRAM CHANNEL</span>
              <h2 className="community-title">Join the Noctra Community on Telegram</h2>
              <p className="community-desc">
                Get real-time release announcements, early test builds, discuss audiophile IEM target curves, and chat with fellow music sovereignty enthusiasts.
              </p>
            </div>
          </div>
          <div className="community-actions">
            <a 
              href="https://t.me/Noctra_app" 
              target="_blank" 
              rel="noopener noreferrer" 
              className="btn btn-telegram-large"
            >
              <Send size={18} />
              <span>Join @Noctra_app</span>
              <ExternalLink size={14} />
            </a>
            <span className="community-subtext">Free & open to everyone &bull; Instant updates</span>
          </div>
        </div>
      </section>

      {/* Privacy Comparison Table */}
      <section id="privacy" className="privacy-section">
        <div className="privacy-container">
          <span className="section-tag">UNCOMPROMISING DATA SOVEREIGNTY</span>
          <h2 className="section-title">Why Noctra is Architecturally Private</h2>
          <p className="section-subtitle">Commercial music apps collect millions of telemetry metrics per day. Noctra collects exactly zero bytes.</p>

          <div className="privacy-comparison-table">
            <div className="table-row table-header">
              <div>Privacy Dimension</div>
              <div>Commercial Music Apps</div>
              <div className="safe">Noctra</div>
            </div>
            <div className="table-row">
              <div>Account & Email Tracking</div>
              <div className="danger">Mandatory Login & Phone Numbers</div>
              <div className="safe">0 Accounts &bull; Instant Play</div>
            </div>
            <div className="table-row">
              <div>Telemetry & Analytics</div>
              <div className="danger">Background Trackers & Fingerprinting</div>
              <div className="safe">0% Remote Telemetry &bull; Strict Sandbox</div>
            </div>
            <div className="table-row">
              <div>Listening Taste Profile</div>
              <div className="danger">Monetized for Cloud Ad Targeting</div>
              <div className="safe">On-Device Encrypted SQLite Vault</div>
            </div>
            <div className="table-row">
              <div>Playlist & Library Portability</div>
              <div className="danger">Locked Behind Proprietary Walls</div>
              <div className="safe">Open JSON (.noctra.json) & Universal CSV</div>
            </div>
          </div>
        </div>
      </section>

      {/* FAQ Accordion */}
      <section id="faq" className="faq-section">
        <div className="section-header">
          <span className="section-tag">FREQUENTLY ASKED QUESTIONS</span>
          <h2 className="section-title">Answers to Common Inquiries</h2>
        </div>

        <div className="faq-accordion">
          <details className="faq-item" open>
            <summary className="faq-question">
              <span>What is new in Noctra v1.0.5?</span>
              <span className="faq-arrow">+</span>
            </summary>
            <div className="faq-answer">
              <p>v1.0.5 brings single-file native installers for <strong>Windows (.exe)</strong>, <strong>Linux (.deb)</strong>, and <strong>iOS (.ipa)</strong> alongside Android. It also introduces 1-tap Shuffle & Algorithmic Remix for all custom playlists, plus a pure-Dart cross-device playlist transfer protocol supporting JSON manifests and universal CSV.</p>
            </div>
          </details>

          <details className="faq-item">
            <summary className="faq-question">
              <span>Do I need an account or subscription to use Noctra?</span>
              <span className="faq-arrow">+</span>
            </summary>
            <div className="faq-answer">
              <p>No. Noctra is completely authentication-less. You do not need an email, phone number, or password. All playlists, favorites, and listening records are saved on your local device in an encrypted SQLite database.</p>
            </div>
          </details>

          <details className="faq-item">
            <summary className="faq-question">
              <span>Is the audio really lossless?</span>
              <span className="faq-arrow">+</span>
            </summary>
            <div className="faq-answer">
              <p>Yes. Noctra resolves pure FLAC bitstreams up to 24-bit / 192 kHz from uncompressed streaming repositories. Real-time audio telemetry in the player displays live codec, sample rate, and bit depth.</p>
            </div>
          </details>

          <details className="faq-item">
            <summary className="faq-question">
              <span>How do I install Noctra on iOS?</span>
              <span className="faq-arrow">+</span>
            </summary>
            <div className="faq-answer">
              <p>Download <code>Noctra-1.0.5.ipa</code> from the releases section. Open AltStore, SideStore, Sideloadly, or TrollStore, select the IPA, and install it to your iPhone or iPad with zero jailbreaking required.</p>
            </div>
          </details>

          <details className="faq-item">
            <summary className="faq-question">
              <span>How do bilingual synchronized lyrics work?</span>
              <span className="faq-arrow">+</span>
            </summary>
            <div className="faq-answer">
              <p>In songs where contributors uploaded synchronized dual-language transcripts (e.g. Hindi in Romanized English alongside a pure English translation), Noctra consolidates identical timestamps (&le; 150ms) so the translated line displays as a subtle italic subtitle beneath the active vocal line.</p>
            </div>
          </details>
        </div>
      </section>

      {/* Footer */}
      <footer className="site-footer">
        <div className="footer-container">
          <div className="footer-brand">
            <img src={getBrandLogo()} alt="Noctra" className="footer-logo" />
            <div>
              <span className="footer-name">NOCTRA</span>
              <p className="footer-motto">Autonomous, Privacy-Sovereign Music Intelligence.</p>
            </div>
          </div>

          <div className="footer-links">
            <a href="https://t.me/Noctra_app" target="_blank" rel="noopener noreferrer">Telegram Channel</a>
            <a href="https://github.com/nomad-guy/Noctra" target="_blank" rel="noopener noreferrer">GitHub</a>
            <a href="https://github.com/nomad-guy/Noctra/releases/tag/v1.0.5" target="_blank" rel="noopener noreferrer">Releases (v1.0.5)</a>
            <a href="https://github.com/nomad-guy/Noctra/blob/main/CODE_OF_CONDUCT.md" target="_blank" rel="noopener noreferrer">Code of Conduct</a>
            <a href="https://github.com/nomad-guy/Noctra/blob/main/CONTRIBUTING.md" target="_blank" rel="noopener noreferrer">Contributing</a>
            <a href="https://github.com/nomad-guy/Noctra/blob/main/SECURITY.md" target="_blank" rel="noopener noreferrer">Security Policy</a>
            <a href="https://github.com/nomad-guy/Noctra/blob/main/LICENSE" target="_blank" rel="noopener noreferrer">GPL-3.0 License</a>
          </div>

          <div className="footer-copyright">
            <p>&copy; 2026 Noctra. Built with precision for pure acoustic freedom. Distributed strictly for personal, educational, and research purposes under the GPL-3.0 license.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}
