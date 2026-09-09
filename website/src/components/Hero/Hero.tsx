import { useEffect, useRef } from 'react';
import { animate, stagger } from 'animejs';
import { Download, Send, Monitor, Terminal, Smartphone, Sparkles } from 'lucide-react';
import { useRelease } from '../../context/ReleaseContext';
import styles from './Hero.module.css';

export function Hero() {
  const heroRef = useRef<HTMLElement>(null);
  const { release, openChangelog } = useRelease();

  useEffect(() => {
    if (!heroRef.current) return;
    // Users who prefer reduced motion get the fully-rendered page with no
    // entrance animation.
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    animate(
      [
        `.${styles.releasePill}`,
        `.${styles.title}`,
        `.${styles.subtitle}`,
        `.${styles.ctaGroup}`,
        `.${styles.osPills}`,
        `.${styles.metricsStrip}`,
      ],
      {
        opacity: [0, 1],
        translateY: [24, 0],
        delay: stagger(100, { start: 150 }),
        ease: 'outCubic',
        duration: 800,
      }
    );
  }, []);

  return (
    <section id="hero" className={styles.hero} ref={heroRef}>
      <div
        className={styles.releasePill}
        onClick={openChangelog}
        role="button"
        tabIndex={0}
        onKeyDown={(e) => e.key === 'Enter' && openChangelog()}
        title="Click to view release highlights"
      >
        <span className={styles.pulseDot} />
        <span>{release.tag} Production Release &bull; Windows &bull; Linux &bull; Android &bull; iOS</span>
        <span className={styles.whatsNewPill}>What's New &rarr;</span>
      </div>

      <h1 className={styles.title}>
        Autonomous Music.<br />
        <span className={styles.gradientText}>Pure Acoustic Sovereignty.</span>
      </h1>

      <p className={styles.subtitle}>
        Bit-perfect lossless FLAC up to <strong>24-bit / 192 kHz</strong>, consolidated bilingual subtitles, on-device taste neural vectors, playlist remixing, and cross-device transfer manifests. Single-file native packages for <strong>Windows, Linux, Android, and iOS</strong>.
      </p>

      <div className={styles.ctaGroup}>
        <a href="#downloads" className={styles.btnPrimaryLarge}>
          <div className={styles.btnRow}>
            <Download size={18} />
            <span>Download Native Packages</span>
          </div>
          <span className={styles.btnSubtext}>Windows • Linux • Android • iOS</span>
        </a>

        <a
          href="https://t.me/Noctra_app"
          target="_blank"
          rel="noopener noreferrer"
          className={styles.btnTgLarge}
        >
          <div className={styles.btnRow}>
            <Send size={18} />
            <span>Join Telegram Channel</span>
          </div>
          <span className={styles.btnSubtext}>@Noctra_app • Official Updates</span>
        </a>
      </div>

      <div className={styles.osPills}>
        <span className={styles.pillsLabel}>Direct 1-Click:</span>
        <a href={release.binaries.windows.downloadUrl} className={styles.osPill}>
          <Monitor size={13} /> Windows (.exe)
        </a>
        <a href={release.binaries.linux.downloadUrl} className={styles.osPill}>
          <Terminal size={13} /> Linux (.deb)
        </a>
        <a href={release.binaries.android.downloadUrl} className={styles.osPill}>
          <Smartphone size={13} /> Android (.apk)
        </a>
        <a href={release.binaries.ios.downloadUrl} className={styles.osPill}>
          <Sparkles size={13} /> iOS (.ipa)
        </a>
      </div>

      <div className={styles.metricsStrip}>
        <div className={styles.metricCard}>
          <span className={styles.metricVal}>24-bit / 192k</span>
          <span className={styles.metricLbl}>Lossless Master FLAC</span>
        </div>
        <div className={styles.metricCard}>
          <span className={styles.metricVal}>4 Platforms</span>
          <span className={styles.metricLbl}>Win • Linux • Android • iOS</span>
        </div>
        <div className={styles.metricCard}>
          <span className={styles.metricVal}>0% Telemetry</span>
          <span className={styles.metricLbl}>Strict Local Sandbox</span>
        </div>
        <div className={styles.metricCard}>
          <span className={styles.metricVal}>Harman & Moondrop</span>
          <span className={styles.metricLbl}>Audiophile IEM Curves</span>
        </div>
      </div>
    </section>
  );
}
