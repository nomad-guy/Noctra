import { useState } from 'react';
import { Sliders } from 'lucide-react';
import styles from './AudiophileDSP.module.css';

type EQPresetType = 'harman' | 'moondrop' | 'waner';

interface PresetData {
  id: EQPresetType;
  name: string;
  badge: string;
  desc: string;
  gains: { hz: string; db: string; height: string }[];
}

const PRESETS: Record<EQPresetType, PresetData> = {
  harman: {
    id: 'harman',
    name: 'Harman IEM 2019',
    badge: '+6dB Sub-Bass Shelf',
    desc: 'Natural acoustic pinna gain with a controlled sub-bass shelf for universal musicality & spatial separation.',
    gains: [
      { hz: '60 Hz', db: '+5.2 dB', height: '75%' },
      { hz: '250 Hz', db: '+2.0 dB', height: '60%' },
      { hz: '1 kHz', db: '0.0 dB', height: '50%' },
      { hz: '4 kHz', db: '+4.1 dB', height: '70%' },
      { hz: '12 kHz', db: '+3.0 dB', height: '65%' },
    ],
  },
  moondrop: {
    id: 'moondrop',
    name: 'Moondrop VDSF Target',
    badge: 'Diffuse-Field Midrange',
    desc: 'Airy treble extension, clinical vocal resolution, and transparent spatial positioning for micro-details.',
    gains: [
      { hz: '60 Hz', db: '+1.5 dB', height: '50%' },
      { hz: '250 Hz', db: '0.0 dB', height: '45%' },
      { hz: '1 kHz', db: '+2.8 dB', height: '65%' },
      { hz: '4 kHz', db: '+6.2 dB', height: '80%' },
      { hz: '12 kHz', db: '+5.5 dB', height: '75%' },
    ],
  },
  waner: {
    id: 'waner',
    name: "Tangzu Wan'er Warm Curve",
    badge: 'Smooth Fatigue-Free',
    desc: 'Warm lower-midrange presence, velvety vocals, and smooth non-fatiguing high frequencies for long listening sessions.',
    gains: [
      { hz: '60 Hz', db: '+3.8 dB', height: '65%' },
      { hz: '250 Hz', db: '+3.5 dB', height: '70%' },
      { hz: '1 kHz', db: '+1.0 dB', height: '55%' },
      { hz: '4 kHz', db: '+2.4 dB', height: '60%' },
      { hz: '12 kHz', db: '0.0 dB', height: '50%' },
    ],
  },
};

export function AudiophileDSP() {
  const [activePreset, setActivePreset] = useState<EQPresetType>('harman');
  const current = PRESETS[activePreset];

  return (
    <section id="audiophile" className={styles.section}>
      <div className="section-header">
        <span className="section-tag">DSP EQUALIZATION</span>
        <h2 className="section-title">Hardware-Level Audiophile IEM Target Curves</h2>
        <p className="section-subtitle">
          Switch seamlessly between Harman IEM 2019, Moondrop VDSF, and Tangzu Wan'er target response curves via 5-band parametric DSP.
        </p>
      </div>

      <div className={styles.grid}>
        {/* Target Response Selector */}
        <div className={styles.selectorCard}>
          <h3 className={styles.cardTitle}>Target Response Selector</h3>
          <div className={styles.presetsList}>
            {(['harman', 'moondrop', 'waner'] as const).map((key) => {
              const p = PRESETS[key];
              const isSelected = activePreset === key;
              return (
                <button
                  key={key}
                  type="button"
                  className={`${styles.presetBtn} ${isSelected ? styles.presetBtnActive : ''}`}
                  onClick={() => setActivePreset(key)}
                >
                  <div className={styles.presetHeader}>
                    <span className={styles.presetName}>{p.name}</span>
                    <span className={styles.presetBadge}>{p.badge}</span>
                  </div>
                  <p className={styles.presetDesc}>{p.desc}</p>
                </button>
              );
            })}
          </div>
        </div>

        {/* 5-Band Parametric Hardware Gains */}
        <div className={styles.visualizerCard}>
          <div className={styles.visualizerHeader}>
            <Sliders size={18} />
            <span>5-Band Parametric Hardware Gains</span>
          </div>

          <div className={styles.fadersRow}>
            {current.gains.map((band, idx) => (
              <div key={idx} className={styles.faderCol}>
                <div className={styles.faderTrack}>
                  <div className={styles.faderThumb} style={{ height: band.height }} />
                </div>
                <span className={styles.faderHz}>{band.hz}</span>
                <span className={styles.faderDb}>{band.db}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
