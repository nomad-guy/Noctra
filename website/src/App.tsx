import { useState, useEffect } from 'react';
import { 
  ShieldCheck, 
  Download, 
  Check, 
  Copy, 
  Volume2
} from 'lucide-react';

type ThemeType = 'liquid-glass' | 'noir-black' | 'noir-white';

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

  const [activeShowcase, setActiveShowcase] = useState<ShowcaseItem>(SHOWCASE_ITEMS[0]);
  const [activeScript, setActiveScript] = useState<string>('latin');
  const [copiedArm, setCopiedArm] = useState(false);
  const [copiedUni, setCopiedUni] = useState(false);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
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

  const copyToClipboard = (text: string, type: 'arm' | 'uni') => {
    navigator.clipboard.writeText(text);
    if (type === 'arm') {
      setCopiedArm(true);
      setTimeout(() => setCopiedArm(false), 2000);
    } else {
      setCopiedUni(true);
      setTimeout(() => setCopiedUni(false), 2000);
    }
  };

  return (
    <div className="noctra-app">
      {/* Glow layers */}
      <div className="glow-mesh glow-1" />
      <div className="glow-mesh glow-2" />
      <div className="glow-mesh glow-3" />

      {/* Navigation */}
      <header className="site-header">
        <div className="nav-container">
          <a href="#" className="brand-badge">
            <img src={getBrandLogo()} alt="Noctra" className="brand-logo" />
            <span className="brand-name">NOCTRA</span>
            <span className="version-tag">v1.0.4</span>
          </a>

          <nav className="nav-links">
            <a href="#showcase">Showcase</a>
            <a href="#lyrics">Bilingual Lyrics</a>
            <a href="#audio-engine">Hi-Res Audio</a>
            <a href="#privacy">Privacy</a>
            <a href="#download">Download</a>
            <a href="#faq">FAQ</a>
          </nav>

          <div className="nav-actions">
            {/* Single Tap Theme & Typography Switcher */}
            <button 
              className="theme-tap-btn"
              onClick={cycleTheme}
              title={`Active: ${currentTheme.name} (${currentTheme.fontBadge}). Tap to switch to ${currentTheme.nextThemeName}.`}
              type="button"
            >
              <span className="theme-tap-icon">{currentTheme.icon}</span>
              <div className="theme-tap-info">
                <span className="theme-tap-name">
                  {currentTheme.name}
                  <span className="theme-tap-arrow">↻</span>
                </span>
                <span className="theme-tap-font-badge">{currentTheme.fontBadge}</span>
              </div>
            </button>

            <a 
              href="https://github.com/nomad-guy/Noctra" 
              target="_blank" 
              rel="noopener noreferrer" 
              className="btn btn-glass"
              title="GitHub Repository"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                <path fillRule="evenodd" clipRule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" />
              </svg>
              <span>GitHub</span>
            </a>
            <a href="#download" className="btn btn-primary">
              <Download size={16} />
              <span>Get APK</span>
            </a>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section className="hero-section">
        <div className="hero-pill">
          <span className="pulse-dot" />
          <span>v1.0.4 Release • Bilingual Lyric Subtitles • Audiophile IEM Target Curves</span>
        </div>

        <h1 className="hero-title">
          Autonomous Music.<br />
          <span className="gradient-text">Pure Acoustic Freedom.</span>
        </h1>

        <p className="hero-subtitle">
          Bit-perfect lossless FLAC streaming up to <strong>24-bit / 192 kHz</strong>, Apple Music-style bilingual lyric translation subtitles, parametric IEM acoustic curves, and on-device AI soundscapes. No accounts. <strong>Zero telemetry.</strong>
        </p>

        <div className="hero-cta-group">
          <a href="#download" className="btn btn-primary btn-large">
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Download size={20} />
              <span>Download for Android</span>
            </div>
            <span className="btn-subtext">arm64-v8a • Free & Open Source</span>
          </a>
          <a href="#showcase" className="btn btn-glass btn-large">
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Volume2 size={20} />
              <span>Explore Live UI</span>
            </div>
            <span className="btn-subtext">RMX3395 Real Device Captures</span>
          </a>
        </div>

        {/* Metrics Strip */}
        <div className="metrics-strip">
          <div className="metric-card">
            <span className="metric-value">24-bit / 192kHz</span>
            <span className="metric-label">Lossless FLAC Master</span>
          </div>
          <div className="metric-divider" />
          <div className="metric-card">
            <span className="metric-value">0%</span>
            <span className="metric-label">Remote Telemetry</span>
          </div>
          <div className="metric-divider" />
          <div className="metric-card">
            <span className="metric-value">3 Scripts</span>
            <span className="metric-label">Hindi • Punjabi • Urdu</span>
          </div>
          <div className="metric-divider" />
          <div className="metric-card">
            <span className="metric-value">Harman & Moondrop</span>
            <span className="metric-label">Audiophile IEM Curves</span>
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
              <div className="caption-badges">
                {activeShowcase.badges.map((b, i) => (
                  <span key={i} className="badge">{b}</span>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Bilingual Lyrics Spotlight */}
      <section id="lyrics" className="feature-spotlight-section">
        <div className="spotlight-container">
          <div className="spotlight-text">
            <span className="section-tag">NEW IN V1.0.4</span>
            <h2 className="section-title">Synchronized Bilingual Lyrics with Translation Subtitles</h2>
            <p className="section-subtitle">
              No more repetitive lines or awkward double-rendering. When songs feature dual-language LRC transcripts, Noctra automatically consolidates identical timestamps (≤ 150ms) into a primary vocal line paired with a subtle, dimmed italic translation subtitle.
            </p>

            <div className="feature-bullets">
              <div className="bullet-item">
                <div className="bullet-icon">⚡</div>
                <div>
                  <h4>Smart Timestamp Consolidation</h4>
                  <p>Lines sharing identical or near-identical timestamps (≤ 150ms) are intelligently consolidated into primary text and subtitle.</p>
                </div>
              </div>
              <div className="bullet-item">
                <div className="bullet-icon">🔤</div>
                <div>
                  <h4>Native Script Priority</h4>
                  <p>Regional scripts (Devanagari, Gurmukhi, Urdu) are automatically assigned to the vocal line, while English translations stay anchored below.</p>
                </div>
              </div>
              <div className="bullet-item">
                <div className="bullet-icon">🛡️</div>
                <div>
                  <h4>Transliteration Protection</h4>
                  <p>Switch between Hindi, Punjabi, and Urdu scripts on the fly without corrupting the English translation subtitle.</p>
                </div>
              </div>
            </div>
          </div>

          {/* Interactive Lyrics Card */}
          <div className="lyrics-preview-card">
            <div className="lyrics-preview-header">
              <div className="track-mini">
                <span className="pulse-dot active" />
                <div>
                  <div className="track-title">Mere Hi Liye</div>
                  <div className="track-artist">Aditya Rikhari • Synchronized LRC</div>
                </div>
              </div>
              <div className="script-chips">
                <button 
                  className={`chip-btn ${activeScript === 'latin' ? 'active' : ''}`}
                  onClick={() => setActiveScript('latin')}
                >
                  Original
                </button>
                <button 
                  className={`chip-btn ${activeScript === 'devanagari' ? 'active' : ''}`}
                  onClick={() => setActiveScript('devanagari')}
                >
                  देवनागरी (Hindi)
                </button>
                <button 
                  className={`chip-btn ${activeScript === 'gurmukhi' ? 'active' : ''}`}
                  onClick={() => setActiveScript('gurmukhi')}
                >
                  ਗੁਰਮੁਖੀ (Punjabi)
                </button>
                <button 
                  className={`chip-btn ${activeScript === 'urdu' ? 'active' : ''}`}
                  onClick={() => setActiveScript('urdu')}
                >
                  اردو (Urdu)
                </button>
              </div>
            </div>

            <div className="lyrics-lines-container">
              <div className="lyric-line past">
                <div className="primary-text">{LYRIC_DEMO[activeScript].line1}</div>
                <div className="sub-text">(Intro Chorus)</div>
              </div>
              <div className="lyric-line active">
                <div className="primary-text">{LYRIC_DEMO[activeScript].line2}</div>
                <div className="sub-text">My moon (beloved) just passed right in front of me</div>
              </div>
              <div className="lyric-line future">
                <div className="primary-text">{LYRIC_DEMO[activeScript].line3}</div>
                <div className="sub-text">As if some dream of mine came true</div>
              </div>
              <div className="lyric-line future">
                <div className="primary-text">{LYRIC_DEMO[activeScript].line4}</div>
                <div className="sub-text">Yes, what kind of winds are these that brush against your cheeks?</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Audio Engine Features */}
      <section id="audio-engine" className="audio-engine-section">
        <div className="section-header">
          <span className="section-tag">AUDIOPHILE SOUND ARCHITECTURE</span>
          <h2 className="section-title">Bit-Perfect Signal Flow. Hardware IEM Curves.</h2>
          <p className="section-subtitle">Engineered from the ground up for critical listeners, high-impedance headphones, and audiophile in-ear monitors.</p>
        </div>

        <div className="grid-container">
          <div className="grid-card">
            <div className="card-icon">⚡</div>
            <h3>True Lossless FLAC</h3>
            <p>Bit-perfect audio stream resolution supporting up to <strong>24-bit / 192 kHz</strong> uncompressed audio streams straight into your external or internal DAC.</p>
            <div className="card-tags">
              <span>FLAC</span>
              <span>ALAC</span>
              <span>Opus 160k</span>
              <span>Direct HTTPS</span>
            </div>
          </div>

          <div className="grid-card">
            <div className="card-icon">🎚️</div>
            <h3>Audiophile IEM Presets</h3>
            <p>Built-in parametric target response curves mapped to legendary acoustic signatures including <strong>Harman IEM 2019</strong>, <strong>Moondrop VDSF</strong>, and <strong>Tangzu Wan'er</strong>.</p>
            <div className="card-tags">
              <span>Harman Target</span>
              <span>Moondrop VDSF</span>
              <span>5-Band DSP</span>
              <span>Hardware FX</span>
            </div>
          </div>

          <div className="grid-card">
            <div className="card-icon">🌌</div>
            <h3>Spatial 3D Virtualizer</h3>
            <p>Dynamic soundstage widening algorithm combined with <strong>Dolby Atmos</strong> spatial detection and natural room acoustics resonance modeling.</p>
            <div className="card-tags">
              <span>Dolby Atmos</span>
              <span>3D Soundstage</span>
              <span>Concert Hall</span>
              <span>Bass Boost</span>
            </div>
          </div>

          <div className="grid-card">
            <div className="card-icon">📡</div>
            <h3>Multi-Tier Fallback</h3>
            <p>Self-healing 6-tier stream resolution pipeline: local vault → validated lossless stream → high-fidelity Deezer → Qobuz Studio → InnerTube resilient fallback.</p>
            <div className="card-tags">
              <span>Self-Healing</span>
              <span>Zero Buffering</span>
              <span>Pristine Bitstream</span>
            </div>
          </div>

          <div className="grid-card">
            <div className="card-icon">🎨</div>
            <h3>Triple Noir Themes</h3>
            <p>Crafted with Swiss minimalism: <strong>Noir Black</strong> (#0A0A0A), <strong>Noir White</strong> (high-contrast daylight), and <strong>Liquid Glass</strong> sapphire refraction with dynamic launcher icon sync.</p>
            <div className="card-tags">
              <span>Obsidian Glass</span>
              <span>Adaptive Icons</span>
              <span>120Hz Fluid</span>
            </div>
          </div>

          <div className="grid-card">
            <div className="card-icon">📻</div>
            <h3>SyncCast Party Mode</h3>
            <p>Broadcast synchronized low-latency audio to nearby devices over local Wi-Fi. Turn any room or group of friends into a unified multi-speaker sound system.</p>
            <div className="card-tags">
              <span>Zero Server Relay</span>
              <span>LAN Wi-Fi</span>
              <span>Sub-15ms Latency</span>
            </div>
          </div>
        </div>
      </section>

      {/* Privacy Comparison */}
      <section id="privacy" className="privacy-section">
        <div className="privacy-card">
          <div className="privacy-header">
            <div className="privacy-shield-icon">
              <ShieldCheck size={40} />
            </div>
            <div>
              <span className="section-tag">RADICAL PRIVACY BY DESIGN</span>
              <h2>Zero Telemetry. Zero Tracking. No Cloud Middlemen.</h2>
            </div>
          </div>

          <p className="privacy-body">
            Commercial music streaming applications collect millions of telemetry data points per day—including skip patterns, background location, Wi-Fi SSIDs, device identifiers, and listening psychology. <strong>Noctra collects exactly zero bytes.</strong>
          </p>

          <div className="privacy-comparison-table">
            <div className="table-row table-header">
              <div>Privacy Vector</div>
              <div>Commercial Streaming Apps</div>
              <div className="safe">Noctra</div>
            </div>
            <div className="table-row">
              <div>Account & Identity</div>
              <div className="danger">Mandatory (Email / Phone / OAuth)</div>
              <div className="safe">0 Accounts • Launch & Play</div>
            </div>
            <div className="table-row">
              <div>Remote Telemetry</div>
              <div className="danger">Continuous Analytics & Trackers</div>
              <div className="safe">0% Telemetry • Strict Local Sandbox</div>
            </div>
            <div className="table-row">
              <div>Listening Taste Graph</div>
              <div className="danger">Stored in Cloud Ad Profiles</div>
              <div className="safe">On-Device Encrypted SQLite Vault</div>
            </div>
            <div className="table-row">
              <div>Network Queries</div>
              <div className="danger">Proprietary Surveillance Relays</div>
              <div className="safe">Direct Client-to-Public Endpoints</div>
            </div>
          </div>
        </div>
      </section>

      {/* Download Hub */}
      <section id="download" className="download-section">
        <div className="section-header">
          <span className="section-tag">OFFICIAL PRODUCTION ARTIFACTS</span>
          <h2 className="section-title">Download Noctra v1.0.4</h2>
          <p className="section-subtitle">Compiled with ProGuard & R8 optimization. Signed and verified for modern Android devices (Android 8.0+).</p>
        </div>

        <div className="download-grid">
          {/* arm64-v8a */}
          <div className="download-card featured">
            <div className="featured-ribbon">RECOMMENDED</div>
            <div className="download-card-header">
              <div className="arch-badge">ARM64-V8A</div>
              <h3>Noctra ARM64</h3>
              <span className="card-filesize">22.9 MB • v1.0.4 Release</span>
            </div>
            <p>Optimized for modern 64-bit Android smartphones & tablets. Smallest footprint and highest native execution speed.</p>
            
            <div className="hash-box">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span className="hash-label">SHA-256 Checksum:</span>
                <button 
                  onClick={() => copyToClipboard('545024a2e4dc4389fe5cc1e1d1b470165523fd3ad942178d0093687639d656aa', 'arm')} 
                  style={{ background: 'none', border: 'none', color: 'var(--accent-cyan)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '0.72rem' }}
                >
                  {copiedArm ? <Check size={12} /> : <Copy size={12} />}
                  <span>{copiedArm ? 'Copied' : 'Copy'}</span>
                </button>
              </div>
              <code className="hash-code">545024a2e4dc4389fe5cc1e1d1b470165523fd3ad942178d0093687639d656aa</code>
            </div>

            <a 
              href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.4/Noctra-1.0.4-arm64-v8a.apk" 
              className="btn btn-primary btn-block"
            >
              <Download size={18} />
              <span>Download arm64-v8a APK</span>
            </a>
          </div>

          {/* Universal */}
          <div className="download-card">
            <div className="download-card-header">
              <div className="arch-badge">UNIVERSAL</div>
              <h3>Noctra Universal</h3>
              <span className="card-filesize">63.2 MB • v1.0.4 Release</span>
            </div>
            <p>Bundles all native architectures (ARM64, ARMv7, x86_64). Guarantees 100% compatibility across all Android devices.</p>
            
            <div className="hash-box">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span className="hash-label">SHA-256 Checksum:</span>
                <button 
                  onClick={() => copyToClipboard('ee7558a611a95432f6d52102d9283ca6bd0e572b46d4e3e3b07bb58dd5b8647f', 'uni')} 
                  style={{ background: 'none', border: 'none', color: 'var(--accent-cyan)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '0.72rem' }}
                >
                  {copiedUni ? <Check size={12} /> : <Copy size={12} />}
                  <span>{copiedUni ? 'Copied' : 'Copy'}</span>
                </button>
              </div>
              <code className="hash-code">ee7558a611a95432f6d52102d9283ca6bd0e572b46d4e3e3b07bb58dd5b8647f</code>
            </div>

            <a 
              href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.4/Noctra-1.0.4-universal.apk" 
              className="btn btn-glass btn-block"
            >
              <Download size={18} />
              <span>Download Universal APK</span>
            </a>
          </div>
        </div>

        <div className="other-downloads">
          <span>Other Architectures:</span>
          <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.4/Noctra-1.0.4-armeabi-v7a.apk" className="link-tag">armeabi-v7a (20.9 MB)</a>
          <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.4/Noctra-1.0.4-x86_64.apk" className="link-tag">x86_64 (24.4 MB)</a>
          <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.4/SHA256SUMS.txt" className="link-tag">Official SHA256SUMS.txt</a>
          <a href="https://github.com/nomad-guy/Noctra/releases/tag/v1.0.4" className="link-tag">→ All GitHub Releases</a>
        </div>
      </section>

      {/* FAQ */}
      <section id="faq" className="faq-section">
        <div className="section-header">
          <span className="section-tag">FREQUENTLY ASKED QUESTIONS</span>
          <h2 className="section-title">Answers to Common Inquiries</h2>
        </div>

        <div className="faq-accordion">
          <details className="faq-item" open>
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
              <span>How do bilingual synchronized lyrics work?</span>
              <span className="faq-arrow">+</span>
            </summary>
            <div className="faq-answer">
              <p>In songs where contributors uploaded synchronized dual-language transcripts (e.g. Hindi in Romanized English alongside a pure English translation), Noctra consolidates identical timestamps (≤ 150ms) so the translated line displays as a subtle italic subtitle beneath the active vocal line.</p>
            </div>
          </details>

          <details className="faq-item">
            <summary className="faq-question">
              <span>Where are downloaded songs stored on Android?</span>
              <span className="faq-arrow">+</span>
            </summary>
            <div className="faq-answer">
              <p>Tracks are stored in standard music storage (by default <code>/storage/emulated/0/Music/Noctra/</code>). You can customize your storage directory directly from <em>Settings & Storage</em>.</p>
            </div>
          </details>

          <details className="faq-item">
            <summary className="faq-question">
              <span>Can I build Noctra from source code?</span>
              <span className="faq-arrow">+</span>
            </summary>
            <div className="faq-answer">
              <p>Yes! Noctra is fully open-source under the GPL-3.0 license. Simply clone the repository from GitHub, run <code>flutter pub get</code>, and build with <code>flutter build apk --release</code>.</p>
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
            <a href="https://github.com/nomad-guy/Noctra" target="_blank" rel="noopener noreferrer">GitHub Repository</a>
            <a href="https://github.com/nomad-guy/Noctra/releases/tag/v1.0.4" target="_blank" rel="noopener noreferrer">Release Notes</a>
            <a href="https://github.com/nomad-guy/Noctra/blob/main/LICENSE" target="_blank" rel="noopener noreferrer">GPL-3.0 License</a>
            <a href="https://github.com/nomad-guy/Noctra/issues" target="_blank" rel="noopener noreferrer">Report an Issue</a>
          </div>

          <div className="footer-copyright">
            <p>© 2026 Noctra. Built with precision for pure acoustic freedom. Distributed strictly for personal, educational, and research purposes.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}
