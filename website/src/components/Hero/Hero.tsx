import { useEffect, useState } from 'react';
import { useRelease } from '../../context/ReleaseContext';
import { detectUserPlatform } from '../../utils/detectPlatform';
import type { PlatformType } from '../../types';
import styles from './Hero.module.css';

interface Metric {
  value: string;
  label: string;
}

const METRICS: Metric[] = [
  { value: '3 Themes', label: 'Noir Black · Noir White · Liquid Glass' },
  { value: 'Offline', label: 'Downloads & local playback' },
  { value: 'Real DSP', label: 'EQ · bass boost · reverb · visualizer' },
  { value: 'Free', label: 'Open source, forever' },
];

const OS_LABELS: Partial<Record<PlatformType, string>> = {
  android: 'Android',
  windows: 'Windows',
  linux: 'Linux',
  ios: 'iOS',
};

const OTHER_OS: PlatformType[] = ['android', 'windows', 'linux', 'ios'];

export default function Hero() {
  const { release, openChangelog } = useRelease();
  const [os, setOs] = useState<PlatformType>('windows');

  useEffect(() => {
    const id = requestAnimationFrame(() => setOs(detectUserPlatform()));
    return () => cancelAnimationFrame(id);
  }, []);

  return (
    <section className={styles.hero} id="top">
      <button
        type="button"
        className={styles.releasePill}
        onClick={openChangelog}
        aria-label="See what is new in the latest release"
      >
        <span className={styles.pulseDot} aria-hidden="true" />
        <span className={styles.tag}>{release.tag}</span>
        <span>is live</span>
        <span className={styles.whatsNewPill}>→ what's new</span>
      </button>

      <h1 className={styles.title}>
        Music, <span className={styles.gradientText}>the way it should</span> sound.
      </h1>

      <p className={styles.subtitle}>
        A free, open-source music player for Android, Windows, Linux, and iOS.
        Stream, download, and play offline — with a <strong>neural recommendation
        engine</strong>, real on-device DSP, synced lyrics, and Speaker Mesh that
        turns every phone in the room into a synced speaker.
      </p>

      <div className={styles.ctaGroup}>
        <a
          className={styles.btnPrimaryLarge}
          href={release.binaries[os]?.downloadUrl ?? release.releaseUrl}
        >
          <span className={styles.btnRow}>
            <svg width="17" height="17" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <path
                d="M12 3v12m0 0 4.5-4.5M12 15l-4.5-4.5M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2"
                stroke="currentColor"
                strokeWidth="2.2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            Download Noctra
          </span>
          <span className={styles.btnSubtext}>
            Free · No ads · No tracking · GitHub Releases
          </span>
        </a>
        <a
          className={styles.btnTgLarge}
          href="https://github.com/nomad-guy/Noctra"
          target="_blank"
          rel="noreferrer"
        >
          <span className={styles.btnRow}>
            <svg width="17" height="17" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M12 .5C5.65.5.5 5.65.5 12c0 5.08 3.29 9.39 7.86 10.91.58.11.79-.25.79-.55v-2.15c-3.2.7-3.87-1.36-3.87-1.36-.52-1.33-1.28-1.68-1.28-1.68-1.04-.71.08-.7.08-.7 1.15.08 1.76 1.18 1.76 1.18 1.03 1.76 2.69 1.25 3.35.96.1-.75.4-1.25.72-1.54-2.55-.29-5.23-1.28-5.23-5.68 0-1.26.45-2.28 1.18-3.09-.12-.29-.51-1.46.11-3.05 0 0 .96-.31 3.15 1.18a10.9 10.9 0 0 1 5.74 0c2.19-1.49 3.15-1.18 3.15-1.18.62 1.59.23 2.76.11 3.05.73.81 1.18 1.83 1.18 3.09 0 4.41-2.69 5.38-5.25 5.67.41.35.77 1.04.77 2.1v3.11c0 .3.21.67.8.55A11.51 11.51 0 0 0 23.5 12C23.5 5.65 18.35.5 12 .5Z" />
            </svg>
            View source
          </span>
          <span className={styles.btnSubtext}>GPL-3.0 · Star us on GitHub</span>
        </a>
      </div>

      <div className={styles.osPills}>
        <span className={styles.pillsLabel}>Detected</span>
        <a className={styles.osPill} href="#downloads">
          {OS_LABELS[os] ?? 'Your platform'}
        </a>
        <span className={styles.pillsLabel}>Also on</span>
        {OTHER_OS.filter((k) => k !== os).map((k) => (
          <a key={k} className={styles.osPill} href="#downloads">
            {OS_LABELS[k]}
          </a>
        ))}
      </div>

      <div className={styles.metricsStrip}>
        {METRICS.map((m) => (
          <div key={m.label} className={styles.metricCard}>
            <span className={styles.metricVal}>{m.value}</span>
            <span className={styles.metricLbl}>{m.label}</span>
          </div>
        ))}
      </div>
    </section>
  );
}
