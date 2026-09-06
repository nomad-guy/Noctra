import { useState, useEffect, useRef } from 'react';
import { Play, Pause, AlignCenter } from 'lucide-react';
import styles from './LyricsPlayer.module.css';

type ScriptType = 'latin' | 'devanagari' | 'gurmukhi' | 'urdu';

interface LyricItem {
  id: number;
  timeSec: number;
  timeLabel: string;
  sung: Record<ScriptType, string>;
  translation: string;
}

const LYRIC_TRACK: LyricItem[] = [
  {
    id: 0,
    timeSec: 3,
    timeLabel: '0:03',
    sung: {
      latin: 'Dum-da-ra-ra-re, dum-da-ra-re...',
      devanagari: 'दम-दा-रा-रा-रे, दम-दा-रा-रे...',
      gurmukhi: 'ਦਮ-ਦਾ-ਰਾ-ਰਾ-ਰੇ, ਦਮ-ਦਾ-ਰਾ-ਰੇ...',
      urdu: 'دم-دا-را-را-رے، دم-دا-را-رے...',
    },
    translation: 'Dum-da-ra-ra-re, humming into the breeze...',
  },
  {
    id: 1,
    timeSec: 8,
    timeLabel: '0:08',
    sung: {
      latin: 'Saamne se nikla mere chaand yeh abhi',
      devanagari: 'सामने से निकला मेरे चाँद ये अभी',
      gurmukhi: 'ਸਾਮਨੇ ਸੇ ਨਿਕਲਾ ਮੇਰੇ ਚਾਂਦ ਯੇਹ ਅਭੀ',
      urdu: 'سامنے سے نکلا میرے چاند یہ ابھی',
    },
    translation: 'My moon just stepped out right in front of me',
  },
  {
    id: 2,
    timeSec: 14,
    timeLabel: '0:14',
    sung: {
      latin: 'Poora ho gaya ho jaise khwaab yeh koi',
      devanagari: 'पूरा हो गया हो जैसे ख़्वाब ये कोई',
      gurmukhi: 'ਪੂਰਾ ਹੋ ਗਯਾ ਹੋ ਜੈਸੇ ਖ਼੍ਵਾਬ ਯੇਹ ਕੋਈ',
      urdu: 'پورا ہو گیا ہو جیسے خواب یہ کوئی',
    },
    translation: 'As if some long-awaited dream has finally come true',
  },
  {
    id: 3,
    timeSec: 20,
    timeLabel: '0:20',
    sung: {
      latin: 'Haan, yeh kaisi hawaayein hain jo tere gaalon ko chhoo ke guzarti hain?',
      devanagari: 'हाँ, ये कैसी हवाएँ हैं जो तेरे गालों को छू के गुज़रती हैं?',
      gurmukhi: 'ਹਾਂ, ਯੇਹ ਕੈਸੀ ਹਵਾਏਂ ਹੈਂ ਜੋ ਤੇਰੇ ਗਾਲੋਂ ਕੋ ਛੂ ਕੇ ਗੁਜ਼ਰਤੀ ਹੈਂ?',
      urdu: 'ہاں، یہ کیسی ہوائیں ہیں جو تیرے گالوں کو چھو کے گزرتی ہیں؟',
    },
    translation: 'Yes, what gentle winds are these that brush past your cheeks?',
  },
];

export function LyricsPlayer() {
  const [activeScript, setActiveScript] = useState<ScriptType>('latin');
  const [activeLineIdx, setActiveLineIdx] = useState<number>(2); // Default to line 3 as showcase
  const [isPlaying, setIsPlaying] = useState<boolean>(true);
  const [currentTime, setCurrentTime] = useState<number>(15);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Simulated playback timer
  useEffect(() => {
    if (!isPlaying) {
      if (timerRef.current) clearInterval(timerRef.current);
      return;
    }

    timerRef.current = setInterval(() => {
      setCurrentTime((prev) => {
        const next = prev >= 24 ? 0 : prev + 1;
        // Find which line is active based on time
        if (next < 8) setActiveLineIdx(0);
        else if (next < 14) setActiveLineIdx(1);
        else if (next < 20) setActiveLineIdx(2);
        else setActiveLineIdx(3);
        return next;
      });
    }, 1000);

    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [isPlaying]);

  const handleLineClick = (idx: number) => {
    setActiveLineIdx(idx);
    setCurrentTime(LYRIC_TRACK[idx].timeSec);
  };

  const formatSeconds = (sec: number) => {
    const mins = Math.floor(sec / 60);
    const remainder = sec % 60;
    return `${mins}:${remainder < 10 ? '0' : ''}${remainder}`;
  };

  const isRTL = activeScript === 'urdu';

  return (
    <section id="lyrics" className={styles.section}>
      <div className="section-header">
        <span className="section-tag">INNOVATIVE LYRIC ENGINE</span>
        <h2 className="section-title">Apple Music &bull; Spotify Style Bilingual Subtitles</h2>
        <p className="section-subtitle">
          When lyrics contain dual languages sharing the same timestamp, Noctra automatically consolidates them: sung vocals in primary focus, English translation in dimmed italic subtitles.
        </p>
      </div>

      <div className={styles.studioCard}>
        {/* Top Controls: AksharaEngine & Simulated Player bar */}
        <div className={styles.controlBar}>
          <div className={styles.scriptSelectorGroup}>
            <span className={styles.scriptLabel}>AksharaEngine:</span>
            <div className={styles.scriptButtons}>
              <button
                type="button"
                className={`${styles.scriptBtn} ${activeScript === 'latin' ? styles.scriptBtnActive : ''}`}
                onClick={() => setActiveScript('latin')}
              >
                Latin / Romanized
              </button>
              <button
                type="button"
                className={`${styles.scriptBtn} ${activeScript === 'devanagari' ? styles.scriptBtnActive : ''}`}
                onClick={() => setActiveScript('devanagari')}
              >
                Devanagari (हिन्दी)
              </button>
              <button
                type="button"
                className={`${styles.scriptBtn} ${activeScript === 'gurmukhi' ? styles.scriptBtnActive : ''}`}
                onClick={() => setActiveScript('gurmukhi')}
              >
                Gurmukhi (ਪੰਜਾਬੀ)
              </button>
              <button
                type="button"
                className={`${styles.scriptBtn} ${activeScript === 'urdu' ? styles.scriptBtnActive : ''}`}
                onClick={() => setActiveScript('urdu')}
              >
                Urdu (اردو)
              </button>
            </div>
          </div>

          <div className={styles.playerSimBar}>
            <button
              type="button"
              className={styles.playPauseBtn}
              onClick={() => setIsPlaying(!isPlaying)}
              title={isPlaying ? 'Pause simulation' : 'Play simulation'}
              aria-label={isPlaying ? 'Pause' : 'Play'}
            >
              {isPlaying ? <Pause size={15} /> : <Play size={15} />}
            </button>
            <div className={styles.trackInfoMini}>
              <span className={styles.trackTitleMini}>Tum Se Hi &bull; Jab We Met</span>
              <span className={styles.trackTimeMini}>{formatSeconds(currentTime)} / 0:24</span>
            </div>
          </div>
        </div>

        {/* Real-time Bilingual Karaoke Container */}
        <div className={`${styles.karaokeBox} ${isRTL ? styles.rtl : ''}`}>
          {LYRIC_TRACK.map((line, idx) => {
            const isActive = idx === activeLineIdx;
            const isPast = idx < activeLineIdx;

            let lineStateClass = styles.futureLine;
            if (isActive) lineStateClass = styles.activeLine;
            else if (isPast) lineStateClass = styles.pastLine;

            return (
              <div
                key={line.id}
                className={`${styles.lyricLine} ${lineStateClass}`}
                onClick={() => handleLineClick(idx)}
                title="Click line to jump playback"
              >
                <span className={styles.sungVocal}>{line.sung[activeScript]}</span>
                <span className={styles.translationSubtitle}>{line.translation}</span>
              </div>
            );
          })}
        </div>

        {/* Floating Sync with Song Button matching Flutter app */}
        <div className={styles.syncFooter}>
          <button
            type="button"
            className={styles.syncChip}
            onClick={() => {
              setActiveLineIdx(2);
              setCurrentTime(14);
              setIsPlaying(true);
            }}
          >
            <AlignCenter size={14} />
            <span>Sync with Song</span>
          </button>
        </div>
      </div>
    </section>
  );
}
