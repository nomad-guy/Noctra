import { useState, useEffect } from 'react';
import {
  Headphones,
  Mic2,
  Sliders,
  Library,
  Cpu,
  Compass,
  Search,
  Palette,
  Play,
  Pause,
  Cloud,
  Radio,
  RotateCw,
  Moon,
  Settings,
  Menu,
  Sparkles,
  ArrowLeft,
  Smartphone,
  Layers,
} from 'lucide-react';
import type { ShowcaseItem } from '../../types';
import { webAudioSynth } from '../../utils/webAudioSynth';
import styles from './AppShowcase.module.css';

interface ArtistData {
  id: string;
  name: string;
  role: string;
  bio: string;
  avatar: string;
  releasesCount: number;
}

const ARTISTS_DATA: ArtistData[] = [
  {
    id: 'karan',
    name: 'Karan Aujla',
    role: 'Indian singer and rapper (born 1997)',
    bio: 'Jaskaran Singh Aujla is an Indian singer, rapper and songwriter who is primarily associated with Punjabi music. He is known for numerous chart-topping records across global and UK Asian charts.',
    avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
    releasesCount: 6,
  },
  {
    id: 'weeknd',
    name: 'The Weeknd',
    role: 'Canadian singer, songwriter & producer',
    bio: 'Abel Makkonen Tesfaye is known for his sonic versatility, dark lyricism, and cinematic falsetto vocal production across multi-platinum albums.',
    avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80',
    releasesCount: 14,
  },
  {
    id: 'diljit',
    name: 'Diljit Dosanjh',
    role: 'Global Punjabi Icon & Singer',
    bio: 'Diljit Dosanjh is an international music icon, breaking records at Coachella and filling stadiums worldwide with folk and contemporary pop fusion.',
    avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&auto=format&fit=crop&q=80',
    releasesCount: 18,
  },
  {
    id: 'shubh',
    name: 'Shubh',
    role: 'Rapper and Songwriter',
    bio: 'Shubneet Singh is known for minimalist drill rhythms, charismatic vocal delivery, and viral chart successes like Cheques, Baller, and No Love.',
    avatar: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150&auto=format&fit=crop&q=80',
    releasesCount: 4,
  },
];

const RANKED_CHARTS = [
  {
    rank: 1,
    title: 'New Song 2026 | Top 10',
    artist: 'Sagar Bairagi',
    art: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=260&auto=format&fit=crop&q=80',
    badge: 'FLAC 24-bit',
  },
  {
    rank: 2,
    title: 'Vaaroon Trending Version',
    artist: 'Ginny Diwan, Anand Bh...',
    art: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=260&auto=format&fit=crop&q=80',
    badge: 'FLAC 24-bit',
  },
  {
    rank: 3,
    title: 'Jukebox Melodies 2026',
    artist: 'Amit Trivedi, Jasleen Royal',
    art: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=260&auto=format&fit=crop&q=80',
    badge: 'Master 320k',
  },
  {
    rank: 4,
    title: 'Starboy Remaster',
    artist: 'The Weeknd, Daft Punk',
    art: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=260&auto=format&fit=crop&q=80',
    badge: 'FLAC 24/192',
  },
];

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
  const [viewMode, setViewMode] = useState<'interactive' | 'screenshots'>('interactive');
  const [activeItem, setActiveItem] = useState<ShowcaseItem>(SHOWCASE_ITEMS[0]);
  const [activeNavTab, setActiveNavTab] = useState<'home' | 'search' | 'library' | 'ai_studio'>('home');
  const [activeFilterChip, setActiveFilterChip] = useState<string>("Today's Top Hits");
  const [activeArtist, setActiveArtist] = useState<ArtistData | null>(null);
  const [isArtistBioExpanded, setIsArtistBioExpanded] = useState<boolean>(false);
  const [isPlayingInApp, setIsPlayingInApp] = useState<boolean>(false);
  const [currentSong, setCurrentSong] = useState(RANKED_CHARTS[0]);
  const [currentTimeStr, setCurrentTimeStr] = useState<string>('08:59');
  const [isRefreshing, setIsRefreshing] = useState<boolean>(false);

  const getFormattedBio = (bio: string, expanded: boolean) => {
    if (expanded || bio.length <= 140) return bio;
    finalPeriod: {
      const period = bio.indexOf('. ', 100);
      if (period !== -1 && period <= 180) {
        return bio.substring(0, period + 1);
      }
    }
    const slice = bio.substring(0, 150);
    const lastSpace = slice.lastIndexOf(' ');
    return (lastSpace > 50 ? slice.substring(0, lastSpace) : slice) + '...';
  };

  useEffect(() => {
    const updateTime = () => {
      const now = new Date();
      const h = String(now.getHours()).padStart(2, '0');
      const m = String(now.getMinutes()).padStart(2, '0');
      setCurrentTimeStr(`${h}:${m}`);
    };
    updateTime();
    const timer = setInterval(updateTime, 30000);
    return () => clearInterval(timer);
  }, []);

  const handlePlaySong = (song: typeof RANKED_CHARTS[0]) => {
    setCurrentSong(song);
    webAudioSynth.play();
    setIsPlayingInApp(true);
  };

  const toggleAppPlay = () => {
    const state = webAudioSynth.toggle();
    setIsPlayingInApp(state);
  };

  const triggerRefresh = () => {
    setIsRefreshing(true);
    setTimeout(() => setIsRefreshing(false), 800);
  };

  return (
    <section id="showcase" className={styles.section}>
      <div className="section-header">
        <span className="section-tag">1:1 NATIVE EXPERIENCE</span>
        <h2 className="section-title">Experience Noctra Exactly as It Runs on Hardware.</h2>
        <p className="section-subtitle">
          Test drive the live 1:1 replica of Noctra's mobile interface right in your browser, or inspect authentic OLED captures.
        </p>
      </div>

      {/* Mode Switcher */}
      <div className={styles.modeSwitchContainer}>
        <div className={styles.modeSwitcher} role="group" aria-label="Showcase View Mode">
          <button
            type="button"
            className={`${styles.modeBtn} ${viewMode === 'interactive' ? styles.modeBtnActive : ''}`}
            onClick={() => setViewMode('interactive')}
          >
            <Smartphone size={16} />
            <span>Interactive Live App (1:1 Replica)</span>
          </button>
          <button
            type="button"
            className={`${styles.modeBtn} ${viewMode === 'screenshots' ? styles.modeBtnActive : ''}`}
            onClick={() => setViewMode('screenshots')}
          >
            <Layers size={16} />
            <span>Hardware Screenshots</span>
          </button>
        </div>
      </div>

      <div className={styles.container}>
        {/* Left Side: Features or Description */}
        <div className={styles.tabList}>
          {viewMode === 'screenshots' ? (
            SHOWCASE_ITEMS.map((item) => {
              const isActive = item.id === activeItem.id;
              return (
                <button
                  key={item.id}
                  type="button"
                  className={`${styles.tabItem} ${isActive ? styles.tabItemActive : ''}`}
                  onClick={() => setActiveItem(item)}
                >
                  <div className={styles.tabHeader}>
                    <span className={styles.tabIcon}>
                      {item.id === 'player' && <Headphones size={18} />}
                      {item.id === 'lyrics' && <Mic2 size={18} />}
                      {item.id === 'equalizer' && <Sliders size={18} />}
                      {item.id === 'library' && <Library size={18} />}
                      {item.id === 'ai_studio' && <Cpu size={18} />}
                      {item.id === 'home' && <Compass size={18} />}
                      {item.id === 'search' && <Search size={18} />}
                      {item.id === 'settings' && <Palette size={18} />}
                    </span>
                    <span className={styles.tabTitle}>{item.title}</span>
                  </div>
                  <span className={styles.tabDesc}>{item.desc}</span>
                </button>
              );
            })
          ) : (
            <div className={styles.captionCard}>
              <span className={styles.badgePill}>REAL-TIME REPLICA</span>
              <h3 className={styles.captionTitle}>Autonomous Mobile Architecture</h3>
              <p className={styles.captionDesc}>
                This interactive frame mirrors Noctra's pure Flutter architecture. Explore curated charts, tap artists to read Wikipedia bios, toggle AI seed stations, and audition lossless playback.
              </p>
              <div className={styles.badgeList}>
                <span className={styles.badgePill}>Zero Cloud Telemetry</span>
                <span className={styles.badgePill}>SQLite Vault</span>
                <span className={styles.badgePill}>InnerTube Stream</span>
                <span className={styles.badgePill}>24-bit / 192k FLAC</span>
                <span className={styles.badgePill}>Harman IEM Curve</span>
              </div>
            </div>
          )}
        </div>

        {/* Center/Right Side: Mobile Device Mockup */}
        <div className={styles.previewArea}>
          <div className={styles.phoneFrame}>
            <div className={styles.phoneNotch}>
              <div className={styles.notchCamera} />
            </div>

            <div className={styles.phoneScreen}>
              {viewMode === 'screenshots' ? (
                <img
                  src={activeItem.screenshot}
                  alt={activeItem.title}
                  className={styles.screenImg}
                  key={activeItem.screenshot}
                />
              ) : (
                /* 1:1 INTERACTIVE NOCTRA MOBILE APP */
                <div className={styles.phoneAppShell}>
                  {/* Android Status Bar */}
                  <div className={styles.phoneStatusBar}>
                    <span>{currentTimeStr}</span>
                    <div className={styles.statusRight}>
                      <span className={styles.statusDevicePill}>1 device</span>
                      <span>5G</span>
                      <span>78%</span>
                    </div>
                  </div>

                  {/* App Bar matching Flutter HomeScreenAppBar */}
                  <div className={styles.phoneAppBar}>
                    <div className={styles.appBarLeft}>
                      <button type="button" className={styles.appBarBtn} title="Drawer Menu">
                        <Menu size={15} />
                      </button>
                      <span className={styles.appBarBrand}>NOCTRA</span>
                    </div>

                    <div className={styles.appBarActions}>
                      <button type="button" className={styles.appBarBtn} title="SyncCast Active">
                        <Cloud size={14} />
                      </button>
                      <button type="button" className={styles.appBarBtn} title="AI Radio">
                        <Radio size={14} />
                      </button>
                      <button
                        type="button"
                        className={styles.appBarBtn}
                        onClick={triggerRefresh}
                        title="Refresh Feeds"
                      >
                        <RotateCw
                          size={14}
                          style={{
                            transform: isRefreshing ? 'rotate(360deg)' : 'none',
                            transition: 'transform 0.6s ease',
                          }}
                        />
                      </button>
                      <button type="button" className={styles.appBarBtn} title="Theme Mode">
                        <Moon size={14} />
                      </button>
                      <button type="button" className={styles.appBarBtn} title="Settings">
                        <Settings size={14} />
                      </button>
                    </div>
                  </div>

                  {/* Scrollable Screen Body */}
                  <div className={styles.phoneScrollBody}>
                    {activeNavTab === 'home' && (
                      <>
                        {/* Greeting Row */}
                        <div className={styles.greetingRow}>
                          <h2 className={styles.greetingTitle}>Good Morning</h2>
                          <div className={styles.readyBadge}>
                            <span className={styles.readyDot} />
                            <span>READY</span>
                          </div>
                        </div>

                        {/* Global Charts Header */}
                        <div className={styles.subHeaderRow}>
                          <span className={styles.subHeaderTitle}>Global Charts</span>
                          <span className={styles.subHeaderTag}>HINDI & ENGLISH</span>
                        </div>

                        {/* Ranked Cards Carousel */}
                        <div className={styles.rankedCarousel}>
                          {RANKED_CHARTS.map((card) => (
                            <div
                              key={card.rank}
                              className={styles.rankedCard}
                              onClick={() => handlePlaySong(card)}
                              role="button"
                              tabIndex={0}
                            >
                              <div className={styles.rankedArtWrapper}>
                                <img src={card.art} alt={card.title} className={styles.rankedArt} />
                                <div className={styles.rankBadge}>{card.rank}</div>
                              </div>
                              <div className={styles.rankedMeta}>
                                <span className={styles.rankedTitle}>{card.title}</span>
                                <span className={styles.rankedArtist}>{card.artist}</span>
                              </div>
                            </div>
                          ))}
                        </div>

                        {/* Explore Artists Section */}
                        <div className={styles.artistsHeader}>
                          <span className={styles.artistsHeaderTitle}>EXPLORE ARTISTS</span>
                          <span className={styles.artistsHeaderSub}>Wikipedia Bios & Radio</span>
                        </div>

                        <div className={styles.artistsCarousel}>
                          {ARTISTS_DATA.map((art) => (
                            <button
                              key={art.id}
                              type="button"
                              className={styles.artistItem}
                              onClick={() => setActiveArtist(art)}
                            >
                              <div className={styles.artistAvatarWrapper}>
                                <img src={art.avatar} alt={art.name} className={styles.artistAvatar} />
                              </div>
                              <span className={styles.artistName}>{art.name}</span>
                            </button>
                          ))}
                        </div>

                        {/* Filter Chips Row */}
                        <div className={styles.subHeaderRow}>
                          <span className={styles.subHeaderTitle}>Global Charts</span>
                          <span className={styles.subHeaderTag}>Live Dynamic</span>
                        </div>

                        <div className={styles.filterPillsRow}>
                          {["Today's Top Hits", 'Global Top 50', 'Viral Hits', 'Late Night Drive'].map(
                            (pill) => (
                              <button
                                key={pill}
                                type="button"
                                className={`${styles.filterPill} ${activeFilterChip === pill ? styles.filterPillActive : ''}`}
                                onClick={() => setActiveFilterChip(pill)}
                              >
                                {pill}
                              </button>
                            )
                          )}
                        </div>
                      </>
                    )}

                    {activeNavTab === 'search' && (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                        <div style={{ background: 'rgba(255,255,255,0.08)', borderRadius: '12px', padding: '8px 12px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <Search size={14} color="rgba(255,255,255,0.5)" />
                          <span style={{ fontSize: '0.72rem', color: 'rgba(255,255,255,0.5)' }}>Search songs, artists, catalogs...</span>
                        </div>
                        <span style={{ fontSize: '0.68rem', fontWeight: 800, color: 'rgba(255,255,255,0.6)' }}>MULTI-SOURCE CATALOG</span>
                        {RANKED_CHARTS.map((c) => (
                          <div
                            key={c.rank}
                            onClick={() => handlePlaySong(c)}
                            style={{ display: 'flex', alignItems: 'center', gap: '10px', background: 'rgba(255,255,255,0.04)', padding: '6px 8px', borderRadius: '10px', cursor: 'pointer' }}
                          >
                            <img src={c.art} alt="" style={{ width: '36px', height: '36px', borderRadius: '6px', objectFit: 'cover' }} />
                            <div style={{ display: 'flex', flexDirection: 'column', flex: 1, minWidth: 0 }}>
                              <span style={{ fontSize: '0.72rem', fontWeight: 700, color: '#fff', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{c.title}</span>
                              <span style={{ fontSize: '0.62rem', color: 'rgba(255,255,255,0.5)' }}>{c.artist} &bull; {c.badge}</span>
                            </div>
                            <Play size={13} fill="#fff" />
                          </div>
                        ))}
                      </div>
                    )}

                    {activeNavTab === 'library' && (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <span style={{ fontSize: '1rem', fontWeight: 800 }}>Your Music Vault</span>
                          <span className={styles.subHeaderTag}>SQLite 0ms</span>
                        </div>
                        <div style={{ display: 'flex', gap: '6px' }}>
                          <button type="button" className={styles.artistPrimaryBtn}>
                            <Sparkles size={12} /> Shuffle All
                          </button>
                          <button type="button" className={styles.artistSecondaryBtn}>
                            Remix Reorder
                          </button>
                        </div>
                        <div style={{ background: 'rgba(255,255,255,0.04)', padding: '10px', borderRadius: '12px' }}>
                          <span style={{ fontSize: '0.72rem', fontWeight: 700, display: 'block' }}>Favorites & Audiophile Vault</span>
                          <span style={{ fontSize: '0.62rem', color: 'rgba(255,255,255,0.5)' }}>128 local FLAC & Master 320k tracks</span>
                        </div>
                      </div>
                    )}

                    {activeNavTab === 'ai_studio' && (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <span style={{ fontSize: '1rem', fontWeight: 800 }}>AI Taste Studio</span>
                          <span className={styles.subHeaderTag}>120D Embeddings</span>
                        </div>
                        <div style={{ background: 'rgba(255,255,255,0.04)', padding: '12px', borderRadius: '14px', textAlign: 'center' }}>
                          <span style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.5)', display: 'block', marginBottom: '4px' }}>CURRENT ACOUSTIC ARCHETYPE</span>
                          <span style={{ fontSize: '0.88rem', fontWeight: 800, color: '#64B5F6' }}>Nocturnal Audiophile Nomad</span>
                          <div style={{ display: 'flex', justifyContent: 'space-around', marginTop: '10px', fontSize: '0.65rem' }}>
                            <div><strong>88%</strong><br /><span style={{ color: 'rgba(255,255,255,0.5)' }}>Energy</span></div>
                            <div><strong>42%</strong><br /><span style={{ color: 'rgba(255,255,255,0.5)' }}>Acoustic</span></div>
                            <div><strong>71%</strong><br /><span style={{ color: 'rgba(255,255,255,0.5)' }}>Valence</span></div>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>

                  {/* In-Phone Mini-Player Dock */}
                  <div className={styles.phoneMiniDock} onClick={toggleAppPlay}>
                    <div className={styles.miniDockLeft}>
                      <img src={currentSong.art} alt="" className={styles.miniDockArt} />
                      <div className={styles.miniDockMeta}>
                        <span className={styles.miniDockTitle}>{currentSong.title}</span>
                        <span className={styles.miniDockSub}>{currentSong.artist}</span>
                      </div>
                    </div>
                    <button type="button" className={styles.miniPlayBtn} aria-label="Play or pause">
                      {isPlayingInApp ? <Pause size={12} fill="#070709" /> : <Play size={12} fill="#070709" />}
                    </button>
                  </div>

                  {/* Bottom Navigation Bar */}
                  <div className={styles.phoneBottomNav}>
                    <button
                      type="button"
                      className={`${styles.navTabBtn} ${activeNavTab === 'home' ? styles.navTabBtnActive : ''}`}
                      onClick={() => setActiveNavTab('home')}
                    >
                      <Compass size={16} />
                      <span>Home</span>
                    </button>

                    <button
                      type="button"
                      className={`${styles.navTabBtn} ${activeNavTab === 'search' ? styles.navTabBtnActive : ''}`}
                      onClick={() => setActiveNavTab('search')}
                    >
                      <Search size={16} />
                      <span>Search</span>
                    </button>

                    <button
                      type="button"
                      className={`${styles.navTabBtn} ${activeNavTab === 'library' ? styles.navTabBtnActive : ''}`}
                      onClick={() => setActiveNavTab('library')}
                    >
                      <Library size={16} />
                      <span>Library</span>
                    </button>

                    <button
                      type="button"
                      className={`${styles.navTabBtn} ${activeNavTab === 'ai_studio' ? styles.navTabBtnActive : ''}`}
                      onClick={() => setActiveNavTab('ai_studio')}
                    >
                      <Sparkles size={16} />
                      <span>AI Studio</span>
                    </button>
                  </div>

                  {/* Artist Profile Modal (Matches the User's Screenshot with Overflow Fixed!) */}
                  {activeArtist && (
                    <div className={styles.artistSheetOverlay}>
                      <div className={styles.artistSheetHeader}>
                        <button
                          type="button"
                          className={styles.appBarBtn}
                          onClick={() => setActiveArtist(null)}
                        >
                          <ArrowLeft size={16} />
                        </button>
                        <span className={styles.artistSheetTitle}>
                          OFFICIAL ARTIST PROFILE &bull; EXPLORE DISCOGRAPHY
                        </span>
                        <div style={{ width: 26 }} />
                      </div>

                      <div className={styles.artistHeroCard}>
                        <img src={activeArtist.avatar} alt={activeArtist.name} className={styles.artistBigAvatar} />
                        <span className={styles.artistSheetName}>{activeArtist.name}</span>
                        <span style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.5)' }}>{activeArtist.role}</span>
                        <div
                          style={{
                            background: 'rgba(0, 0, 0, 0.35)',
                            padding: '8px 10px',
                            borderRadius: '10px',
                            cursor: 'pointer',
                            textAlign: 'left',
                            width: '100%',
                          }}
                          onClick={() => setIsArtistBioExpanded(!isArtistBioExpanded)}
                        >
                          <p className={styles.artistSheetBio} style={{ margin: 0 }}>
                            {getFormattedBio(activeArtist.bio, isArtistBioExpanded)}
                          </p>
                          {activeArtist.bio.length > 140 && (
                            <span
                              style={{
                                fontSize: '0.6rem',
                                fontWeight: 700,
                                color: 'rgba(255,255,255,0.6)',
                                marginTop: '4px',
                                display: 'inline-block',
                              }}
                            >
                              {isArtistBioExpanded ? 'Show less' : 'Read more'}
                            </span>
                          )}
                        </div>

                        <div className={styles.artistActionsRow}>
                          <button
                            type="button"
                            className={styles.artistPrimaryBtn}
                            onClick={() => {
                              handlePlaySong({
                                rank: 1,
                                title: `${activeArtist.name} - Top Hits`,
                                artist: activeArtist.name,
                                art: activeArtist.avatar,
                                badge: 'FLAC 24-bit',
                              });
                            }}
                          >
                            <Play size={12} fill="#070709" /> Play All
                          </button>
                          <button type="button" className={styles.artistSecondaryBtn}>
                            <Sparkles size={12} /> AI Radio
                          </button>
                        </div>
                      </div>

                      <div style={{ padding: '0 12px 20px 12px' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                          <span style={{ fontSize: '0.78rem', fontWeight: 800 }}>Discography</span>
                          <span style={{ fontSize: '0.65rem', color: 'rgba(255,255,255,0.5)' }}>{activeArtist.releasesCount} releases</span>
                        </div>
                        <div style={{ display: 'flex', gap: '6px', overflowX: 'auto', marginBottom: '14px' }}>
                          {['All', 'Albums', 'Singles & EPs', 'Features'].map((chip, idx) => (
                            <span
                              key={chip}
                              style={{
                                fontSize: '0.62rem',
                                padding: '3px 9px',
                                borderRadius: '9999px',
                                background: idx === 0 ? '#fff' : 'rgba(255,255,255,0.08)',
                                color: idx === 0 ? '#000' : 'rgba(255,255,255,0.8)',
                                fontWeight: 700,
                              }}
                            >
                              {chip}
                            </span>
                          ))}
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>

          {viewMode === 'screenshots' && (
            <div className={styles.captionCard}>
              <h3 className={styles.captionTitle}>{activeItem.captionTitle}</h3>
              <p className={styles.captionDesc}>{activeItem.captionDesc}</p>
              <div className={styles.badgeList}>
                {activeItem.badges.map((b, idx) => (
                  <span key={idx} className={styles.badgePill}>{b}</span>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
