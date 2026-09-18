import { ArrowUpRight } from 'lucide-react';
import styles from './ChangelogPage.module.css';

interface ReleaseItem {
  version: string;
  date: string;
  isLatest?: boolean;
  tagline: string;
  sections: {
    title: string;
    items: string[];
  }[];
}

const RELEASES: ReleaseItem[] = [
  {
    version: 'v1.1.2',
    date: 'September 18, 2026',
    isLatest: true,
    tagline: 'Lossless Upscaling Auto-Play, Transliteration Persistence & High-Contrast Visual Refinement',
    sections: [
      {
        title: 'Audio Upscaler & Playback',
        items: [
          'Automatic lossless upscaled playback: Cached 24-bit upscaled WAVs are automatically resolved and prioritized over lossy network streams without requiring manual file picker steps.',
          '24-BIT UPSCALED gold badge: Now playing bar displays live resolution telemetry; tapping navigates directly to the upscaler sheet.',
          'Immediate upscale playback: Completion view in the upscale sheet now features a 1-tap "Play Upscaled Track" primary action.',
          'Stereo isolation: Independent left/right DSP state machines eliminate channel crosstalk during harmonic reconstruction.',
        ],
      },
      {
        title: 'Universal Lyrics & Transliteration',
        items: [
          'Persistent transliteration script: User-selected reading scripts (Romanized, Devanagari, Pinyin) remain active across continuous track changes.',
          'Expanded Chinese & Japanese vocabulary: Hanzi detection threshold and Pinyin transliteration engine updated with preserved word-level timestamps.',
        ],
      },
      {
        title: 'Visual Contrast & Theme Refinement',
        items: [
          'Elevated secondary and tertiary text contrast across Noir Black, Noir White, Liquid Glass, and Material U themes.',
          'Eliminated hardcoded low-opacity whites across carousels, charts, search results, and cast sheets.',
        ],
      },
      {
        title: 'Engine Architecture & Stability',
        items: [
          'Startup hydration race condition resolved: Persisted playback settings are guaranteed to be loaded before audio handler registration.',
          'Multi-output structured reporting: Native Android audio router upgraded with per-route active flags and normal audio routing mode.',
          'Unicode track matching guard: Diacritic and accent folding prevents false rejections of international titles.',
          'Automated CI release signing enforced in GitHub Actions.',
        ],
      },
    ],
  },
  {
    version: 'v1.1.1',
    date: 'September 18, 2026',
    tagline: 'On-Device Audio Upscaler, Material U Theme & Slow-Network Adaptations',
    sections: [
      {
        title: 'Headline Features',
        items: [
          'On-device audio upscaler: Harmonic reconstruction, dynamic band extension, and soft limiting in a background isolate exporting true 24-bit studio WAVs.',
          'Material U theme: Palette derives from OS dynamic wallpaper colors (Android 12+) with branded seed fallback.',
          'Slow-network mode: Adaptive request timeouts scaling with measured network quality; search returns as soon as the first good provider responds.',
          'RAM and battery guardrails: Image cache clamped to 400 images / 48 MiB.',
        ],
      },
    ],
  },
  {
    version: 'v1.1.0',
    date: 'September 16, 2026',
    tagline: 'Online Taste Learning & Recommendation Engine Convergence',
    sections: [
      {
        title: 'Key Upgrades',
        items: [
          'Online taste vector training: Likes, skips, replays, full plays, and playlist additions train the on-device 120-dim MLP.',
          'Maximal Marginal Relevance (MMR) diversity reranking balances exploration and listener affinity.',
          'Sliding LRU window prevents repetitive artist clusters in continuous autoplay radio.',
        ],
      },
    ],
  },
];

export function ChangelogPage() {
  return (
    <div className={styles.container}>
      <header className={styles.header}>
        <span className={styles.tag}>RELEASE TIMELINE</span>
        <h1 className={styles.title}>Changelog & Updates</h1>
        <p className={styles.subtitle}>
          Track every release, technical improvement, and audiophile DSP upgrade made to Noctra.
        </p>
      </header>

      <div className={styles.timeline}>
        {RELEASES.map((rel) => (
          <article key={rel.version} className={styles.releaseCard}>
            <div className={styles.releaseHeader}>
              <div className={styles.versionBadgeRow}>
                <span className={styles.versionTag}>{rel.version}</span>
                {rel.isLatest && <span className={styles.latestPill}>Latest Release</span>}
                <time className={styles.releaseDate}>{rel.date}</time>
              </div>
              <h2 className={styles.releaseTagline}>{rel.tagline}</h2>
            </div>

            <div className={styles.sectionsList}>
              {rel.sections.map((sec) => (
                <div key={sec.title} className={styles.sectionBlock}>
                  <h3 className={styles.sectionTitle}>{sec.title}</h3>
                  <ul className={styles.itemList}>
                    {sec.items.map((item, idx) => (
                      <li key={idx} className={styles.itemText}>
                        <span className={styles.bullet}>•</span>
                        <span>{item}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>

            <div className={styles.releaseFooter}>
              <a
                href={`https://github.com/nomad-guy/Noctra/releases/tag/${rel.version}`}
                target="_blank"
                rel="noopener noreferrer"
                className={styles.githubLink}
              >
                <span>View on GitHub Releases</span>
                <ArrowUpRight size={14} />
              </a>
            </div>
          </article>
        ))}
      </div>
    </div>
  );
}
