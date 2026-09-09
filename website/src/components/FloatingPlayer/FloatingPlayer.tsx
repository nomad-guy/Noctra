import { useState, useEffect, useRef } from 'react';
import { Play, Pause, SkipBack, SkipForward, Volume2, VolumeX, Sparkles } from 'lucide-react';
import { webAudioSynth } from '../../utils/webAudioSynth';
import styles from './FloatingPlayer.module.css';

interface SongTrack {
  id: string;
  title: string;
  artist: string;
  badge: string;
  coverUrl: string;
  durationSec: number;
}

const DEMO_TRACKS: SongTrack[] = [
  {
    id: 'track-1',
    title: 'Starboy (Lossless Master)',
    artist: 'The Weeknd, Daft Punk',
    badge: 'FLAC 24-bit / 192k',
    coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=150&auto=format&fit=crop&q=80',
    durationSec: 230,
  },
  {
    id: 'track-2',
    title: 'Vaaroon Trending Version',
    artist: 'Ginny Diwan, Anand Bh...',
    badge: 'FLAC 24-bit / 96k',
    coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150&auto=format&fit=crop&q=80',
    durationSec: 195,
  },
  {
    id: 'track-3',
    title: 'New Song 2026 | Top 10',
    artist: 'Sagar Bairagi',
    badge: 'Master 320k',
    coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=150&auto=format&fit=crop&q=80',
    durationSec: 212,
  },
  {
    id: 'track-4',
    title: 'Lover (Audiophile Master)',
    artist: 'Diljit Dosanjh',
    badge: 'FLAC 24-bit / 192k',
    coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=150&auto=format&fit=crop&q=80',
    durationSec: 184,
  },
];

interface Props {
  currentTrackIndex?: number;
  onTrackChange?: (index: number) => void;
}

export function FloatingPlayer({ currentTrackIndex = 0, onTrackChange }: Props) {
  const [internalTrackIdx, setInternalTrackIdx] = useState<number>(0);
  const trackIdx = currentTrackIndex !== undefined ? (currentTrackIndex + internalTrackIdx) % DEMO_TRACKS.length : internalTrackIdx;
  const [isPlaying, setIsPlaying] = useState(false);
  const [isMuted, setIsMuted] = useState(false);
  const [progressSec, setProgressSec] = useState(42);
  const [waveHeights, setWaveHeights] = useState<number[]>([12, 18, 24, 16, 20, 14, 22, 10]);
  const animFrameRef = useRef<number | null>(null);

  const activeTrack = DEMO_TRACKS[trackIdx % DEMO_TRACKS.length];

  const togglePlay = async () => {
    const nextState = webAudioSynth.toggle();
    setIsPlaying(nextState);
  };

  const handleNext = () => {
    setInternalTrackIdx((prev) => (prev + 1) % DEMO_TRACKS.length);
    setProgressSec(0);
    onTrackChange?.((trackIdx + 1) % DEMO_TRACKS.length);
  };

  const handlePrev = () => {
    setInternalTrackIdx((prev) => (prev - 1 + DEMO_TRACKS.length) % DEMO_TRACKS.length);
    setProgressSec(0);
    onTrackChange?.((trackIdx - 1 + DEMO_TRACKS.length) % DEMO_TRACKS.length);
  };

  const toggleMute = () => {
    if (isMuted) {
      webAudioSynth.setVolume(1);
      setIsMuted(false);
    } else {
      webAudioSynth.setVolume(0);
      setIsMuted(true);
    }
  };

  // Waveform animation loop
  useEffect(() => {
    const updateWave = () => {
      if (isPlaying) {
        const analyser = webAudioSynth.getAnalyser();
        if (analyser) {
          const buffer = new Uint8Array(analyser.frequencyBinCount);
          analyser.getByteFrequencyData(buffer);
          const newHeights = [
            Math.max(6, (buffer[1] || 20) / 7),
            Math.max(6, (buffer[3] || 35) / 6),
            Math.max(6, (buffer[5] || 50) / 5.5),
            Math.max(6, (buffer[7] || 40) / 6.5),
            Math.max(6, (buffer[9] || 45) / 6),
            Math.max(6, (buffer[11] || 30) / 7),
            Math.max(6, (buffer[13] || 48) / 5.8),
            Math.max(6, (buffer[15] || 25) / 7.5),
          ];
          setWaveHeights(newHeights);
        } else {
          // Fallback natural oscillation
          setWaveHeights((prev) =>
            prev.map(() => 6 + Math.floor(Math.random() * 20))
          );
        }
      } else {
        setWaveHeights([4, 6, 8, 5, 7, 4, 6, 4]);
      }
      animFrameRef.current = requestAnimationFrame(updateWave);
    };

    animFrameRef.current = requestAnimationFrame(updateWave);
    return () => {
      if (animFrameRef.current) cancelAnimationFrame(animFrameRef.current);
    };
  }, [isPlaying]);

  // Progress ticker
  useEffect(() => {
    if (!isPlaying) return;
    const interval = setInterval(() => {
      setProgressSec((prev) => {
        if (prev >= activeTrack.durationSec) {
          handleNext();
          return 0;
        }
        return prev + 1;
      });
    }, 1000);
    return () => clearInterval(interval);
  }, [isPlaying, activeTrack.durationSec]);

  const progressPercent = Math.min(100, (progressSec / activeTrack.durationSec) * 100);

  const formatTime = (sec: number) => {
    const m = Math.floor(sec / 60);
    const s = Math.floor(sec % 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  return (
    <div className={styles.dockContainer} role="region" aria-label="Noctra Floating Mini-Player">
      {/* Interactive scrubber */}
      <div
        className={styles.scrubBar}
        onClick={(e) => {
          const rect = e.currentTarget.getBoundingClientRect();
          const clickPos = (e.clientX - rect.left) / rect.width;
          setProgressSec(Math.floor(clickPos * activeTrack.durationSec));
        }}
        title="Seek position"
      >
        <div className={styles.scrubProgress} style={{ width: `${progressPercent}%` }} />
      </div>

      <div className={styles.mainRow}>
        {/* Track Info */}
        <div className={styles.trackInfoGroup}>
          <div className={`${styles.artWrapper} ${isPlaying ? styles.vinylSpin : ''}`}>
            <img src={activeTrack.coverUrl} alt={activeTrack.title} className={styles.albumArt} />
          </div>
          <div className={styles.textMeta}>
            <div className={styles.titleRow}>
              <span className={styles.trackTitle}>{activeTrack.title}</span>
              <span className={styles.badgeLossless}>{activeTrack.badge}</span>
            </div>
            <span className={styles.trackArtist}>
              {activeTrack.artist} &bull; {formatTime(progressSec)} / {formatTime(activeTrack.durationSec)}
            </span>
          </div>
        </div>

        {/* Real-time Waveform Equalizer */}
        <div className={styles.waveformContainer} aria-hidden="true" title="Real-time 24-bit audio stream">
          {waveHeights.map((h, i) => (
            <div
              key={i}
              className={styles.waveBar}
              style={{ height: `${h}px`, opacity: isPlaying ? 0.95 : 0.3 }}
            />
          ))}
        </div>

        {/* Controls */}
        <div className={styles.controlsGroup}>
          <button
            type="button"
            className={styles.iconBtn}
            onClick={toggleMute}
            aria-label={isMuted ? 'Unmute' : 'Mute'}
            title={isMuted ? 'Unmute' : 'Mute'}
          >
            {isMuted ? <VolumeX size={17} /> : <Volume2 size={17} />}
          </button>

          <button
            type="button"
            className={styles.iconBtn}
            onClick={handlePrev}
            aria-label="Previous Track"
            title="Previous Track"
          >
            <SkipBack size={17} />
          </button>

          <button
            type="button"
            className={styles.playBtn}
            onClick={togglePlay}
            aria-label={isPlaying ? 'Pause' : 'Play'}
            title={isPlaying ? 'Pause Audio' : 'Play Live High-Res Synthesizer'}
          >
            {isPlaying ? <Pause size={19} fill="currentColor" /> : <Play size={19} fill="currentColor" />}
          </button>

          <button
            type="button"
            className={styles.iconBtn}
            onClick={handleNext}
            aria-label="Next Track"
            title="Next Track"
          >
            <SkipForward size={17} />
          </button>

          <a
            href="#audiophile"
            className={styles.iconBtn}
            title="Acoustic DSP Presets"
            aria-label="DSP Presets"
          >
            <Sparkles size={16} />
          </a>
        </div>
      </div>
    </div>
  );
}
