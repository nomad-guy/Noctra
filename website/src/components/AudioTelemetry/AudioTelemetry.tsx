import { useState, useEffect } from 'react';
import { Play, Pause } from 'lucide-react';
import styles from './AudioTelemetry.module.css';

export function AudioTelemetry() {
  const [isPlaying, setIsPlaying] = useState<boolean>(true);
  const [audioFormat, setAudioFormat] = useState<'24/192' | '16/44.1' | 'opus'>('24/192');
  const [soundstage, setSoundstage] = useState<'stereo' | '3d' | 'concert' | 'atmos'>('3d');
  const [barHeights, setBarHeights] = useState<number[]>([
    65, 80, 45, 90, 70, 85, 95, 60, 75, 90, 80, 65, 88, 72, 92, 58, 84, 66, 78, 88, 70, 85, 90, 60
  ]);

  // Live bar fluctuation when playing
  useEffect(() => {
    if (!isPlaying) {
      setBarHeights((prev) => prev.map(() => 15));
      return;
    }

    const interval = setInterval(() => {
      setBarHeights((prev) =>
        prev.map(() => Math.floor(Math.random() * 65) + 30)
      );
    }, 180);

    return () => clearInterval(interval);
  }, [isPlaying]);

  return (
    <section id="telemetry" className={styles.section}>
      <div className="section-header">
        <span className="section-tag">INTERACTIVE AUDIO DEMO</span>
        <h2 className="section-title">Experience Bit-Perfect Audio Telemetry</h2>
        <p className="section-subtitle">
          Noctra exposes real-time hardware audio pipeline indicators so you always know your exact sample rate, bit depth, and acoustic stage.
        </p>
      </div>

      <div className={styles.card}>
        <div className={styles.topRow}>
          <div className={styles.artWrapper}>
            <img src="screenshots/player.png" alt="Album Cover" className={styles.artImg} />
            <button
              type="button"
              className={styles.playOverlayBtn}
              onClick={() => setIsPlaying(!isPlaying)}
              title={isPlaying ? 'Pause simulated stream' : 'Play simulated stream'}
              aria-label={isPlaying ? 'Pause' : 'Play'}
            >
              {isPlaying ? <Pause size={28} /> : <Play size={28} />}
            </button>
          </div>

          <div className={styles.infoCol}>
            <div className={styles.formatTags}>
              <button
                type="button"
                className={`${styles.formatBadge} ${audioFormat === '24/192' ? styles.formatBadgeActive : ''}`}
                onClick={() => setAudioFormat('24/192')}
              >
                ● FLAC 24-bit / 192 kHz
              </button>
              <button
                type="button"
                className={`${styles.formatBadge} ${audioFormat === '16/44.1' ? styles.formatBadgeActive : ''}`}
                onClick={() => setAudioFormat('16/44.1')}
              >
                FLAC 16-bit / 44.1 kHz
              </button>
              <button
                type="button"
                className={`${styles.formatBadge} ${audioFormat === 'opus' ? styles.formatBadgeActive : ''}`}
                onClick={() => setAudioFormat('opus')}
              >
                Opus 48 kHz / 320k
              </button>
            </div>

            <h3 className={styles.trackTitle}>Tum Se Hi (Studio Master Mix)</h3>
            <p className={styles.trackArtist}>Mohit Chauhan &bull; Pritam &bull; Jab We Met</p>

            <div className={styles.soundstageRow}>
              <span className={styles.soundstageLabel}>Acoustic Stage:</span>
              <div className={styles.stageChips}>
                {(['stereo', '3d', 'concert', 'atmos'] as const).map((mode) => (
                  <button
                    key={mode}
                    type="button"
                    className={`${styles.stageChip} ${soundstage === mode ? styles.stageChipActive : ''}`}
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

        {/* Real-time Spectrum Waveform */}
        <div className={styles.waveformBox}>
          <div className={styles.spectrumBars}>
            {barHeights.map((h, idx) => (
              <div
                key={idx}
                className={styles.bar}
                style={{ height: `${h}%` }}
              />
            ))}
          </div>

          <div className={styles.waveformLabels}>
            <span>0:42</span>
            <span className={styles.modeTag}>
              {audioFormat === '24/192'
                ? 'BITSTREAM LOSSLESS 9,216 kbps'
                : audioFormat === '16/44.1'
                ? 'LOSSLESS 1,411 kbps'
                : 'OPUS MASTER 320 kbps'}
            </span>
            <span>5:21</span>
          </div>
        </div>
      </div>
    </section>
  );
}
