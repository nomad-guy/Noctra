import { useState, useEffect } from 'react';
import { Download, Shield, Sparkles, Sliders, Mic2, ArrowRight } from 'lucide-react';
import { useRelease } from '../context/ReleaseContext';
import { detectUserPlatform } from '../utils/detectPlatform';
import type { PlatformType } from '../types';
import { ShowcaseGallery } from '../components/ShowcaseGallery/ShowcaseGallery';
import { Link } from '../router/Router';
import styles from './HomePage.module.css';

const PILLARS = [
  {
    icon: <Sparkles size={22} className={styles.pillarIcon} />,
    title: 'On-Device 24-Bit Upscaler',
    desc: 'Harmonic reconstruction, dynamic Nyquist bounds, and 24-bit headroom restoration export true lossless WAVs directly on-device.',
    tag: 'Pure DSP Engine',
    link: '/features#upscaler',
  },
  {
    icon: <Sliders size={22} className={styles.pillarIcon} />,
    title: 'Hardware DSP & IEM Target Curves',
    desc: '5-band parametric equalizer with zero cloud latency. Includes Harman 2019, Moondrop VDSF, and Tangzu Wan\u2019er audiophile IEM targets.',
    tag: 'Studio Master',
    link: '/features#equalizer',
  },
  {
    icon: <Mic2 size={22} className={styles.pillarIcon} />,
    title: 'Universal Synced Lyrics',
    desc: 'Apple Music-style dual subtitles. Offline Brahmic matrix, Hanzi Pinyin, Romaji, and persistent transliteration across continuous listening.',
    tag: 'Multi-Script',
    link: '/features#lyrics',
  },
  {
    icon: <Shield size={22} className={styles.pillarIcon} />,
    title: 'Privacy Sovereign & Zero Telemetry',
    desc: 'No accounts, no phone numbers, no tracking, and no ads. Anti-SSRF host whitelisting and 100% open source under GPL-3.0.',
    tag: '100% Private',
    link: '/architecture#security',
  },
];

export function HomePage() {
  const { release } = useRelease();
  const [os, setOs] = useState<PlatformType>('windows');

  useEffect(() => {
    setOs(detectUserPlatform());
  }, []);

  const currentBinary = release.binaries[os];
  const downloadUrl = currentBinary?.downloadUrl ?? release.releaseUrl;
  const osLabel = os.charAt(0).toUpperCase() + os.slice(1);

  return (
    <div className={styles.homeContainer}>
      {/* Minimal Audiophile Hero */}
      <section className={styles.heroSection}>
        <div className={styles.heroBadgeWrapper}>
          <Link to="/changelog" className={styles.releasePill}>
            <span className={styles.pulseDot} />
            <span className={styles.releaseTag}>{release.tag}</span>
            <span className={styles.releaseStatus}>is live</span>
            <span className={styles.arrowIcon}>→</span>
          </Link>
        </div>

        <h1 className={styles.heroTitle}>
          Music, <span className={styles.gradientTitle}>the way it should</span> sound.
        </h1>

        <p className={styles.heroSubtitle}>
          The privacy-sovereign audiophile music client for Windows, Android, Linux, and iOS.
          Features on-device 24-bit audio upscaling, universal bilingual lyrics, hardware DSP,
          and quad signature themes. Zero accounts, zero ads, zero telemetry.
        </p>

        <div className={styles.ctaRow}>
          <a href={downloadUrl} className={styles.btnPrimary}>
            <Download size={18} />
            <span>Download for {osLabel}</span>
          </a>

          <Link to="/download" className={styles.btnSecondary}>
            <span>All Platforms</span>
          </Link>

          <a
            href="https://github.com/nomad-guy/Noctra"
            target="_blank"
            rel="noopener noreferrer"
            className={styles.btnGhost}
          >
            <svg width="17" height="17" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M12 .5C5.65.5.5 5.65.5 12c0 5.08 3.29 9.39 7.86 10.91.58.11.79-.25.79-.55v-2.15c-3.2.7-3.87-1.36-3.87-1.36-.52-1.33-1.28-1.68-1.28-1.68-1.04-.71.08-.7.08-.7 1.15.08 1.76 1.18 1.76 1.18 1.03 1.76 2.69 1.25 3.35.96.1-.75.4-1.25.72-1.54-2.55-.29-5.23-1.28-5.23-5.68 0-1.26.45-2.28 1.18-3.09-.12-.29-.51-1.46.11-3.05 0 0 .96-.31 3.15 1.18a10.9 10.9 0 0 1 5.74 0c2.19-1.49 3.15-1.18 3.15-1.18.62 1.59.23 2.76.11 3.05.73.81 1.18 1.83 1.18 3.09 0 4.41-2.69 5.38-5.25 5.67.41.35.77 1.04.77 2.1v3.11c0 .3.21.67.8.55A11.51 11.51 0 0 0 23.5 12C23.5 5.65 18.35.5 12 .5Z" />
            </svg>
            <span>GitHub</span>
          </a>
        </div>

        <div className={styles.specChips}>
          <span className={styles.specChip}>24-Bit / 192kHz Lossless</span>
          <span className={styles.specChip}>On-Device DSP</span>
          <span className={styles.specChip}>4 Themes</span>
          <span className={styles.specChip}>GPL-3.0 Open Source</span>
        </div>
      </section>

      {/* Real Screenshot Showcase */}
      <ShowcaseGallery />

      {/* Core Engineering Pillars */}
      <section className={styles.pillarsSection}>
        <div className={styles.sectionHeader}>
          <span className={styles.sectionTag}>BUILT DIFFERENT</span>
          <h2 className={styles.sectionTitle}>Engineered for Acoustic Purity</h2>
          <p className={styles.sectionSubtitle}>
            Noctra doesn't compromise between audiophile fidelity, privacy, and visual elegance.
          </p>
        </div>

        <div className={styles.pillarsGrid}>
          {PILLARS.map((pillar) => (
            <div key={pillar.title} className={styles.pillarCard}>
              <div className={styles.pillarTop}>
                {pillar.icon}
                <span className={styles.pillarTag}>{pillar.tag}</span>
              </div>
              <h3 className={styles.pillarTitle}>{pillar.title}</h3>
              <p className={styles.pillarDesc}>{pillar.desc}</p>
              <Link to={pillar.link} className={styles.pillarLink}>
                <span>Learn more</span>
                <ArrowRight size={14} />
              </Link>
            </div>
          ))}
        </div>
      </section>

      {/* Quick Download CTA Card */}
      <section className={styles.downloadCtaSection}>
        <div className={styles.ctaBox}>
          <div className={styles.ctaContent}>
            <h2 className={styles.ctaTitle}>Ready for Pure Sound?</h2>
            <p className={styles.ctaDesc}>
              Single-file standalone native packages compiled directly with cryptographic SHA-256 integrity verification.
            </p>
            <div className={styles.ctaActions}>
              <Link to="/download" className={styles.btnPrimary}>
                <Download size={18} />
                <span>Go to Downloads Center</span>
              </Link>
              <Link to="/features" className={styles.btnSecondary}>
                <span>Explore All Features</span>
              </Link>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
