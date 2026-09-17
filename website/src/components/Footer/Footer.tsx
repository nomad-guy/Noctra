import { useRelease } from '../../context/ReleaseContext';
import styles from './Footer.module.css';

const RESOURCE_LINKS = [
  { href: '#features', label: 'Features' },
  { href: '#showcase', label: 'Showcase' },
  { href: '#downloads', label: 'Downloads' },
  { href: '#install', label: 'Install Guide' },
  { href: '#faq', label: 'FAQ' },
];

const PROJECT_LINKS = [
  {
    href: 'https://github.com/nomad-guy/Noctra',
    label: 'GitHub Repository',
    external: true,
  },
  {
    href: 'https://github.com/nomad-guy/Noctra/releases',
    label: 'All Releases',
    external: true,
  },
  {
    href: 'https://github.com/nomad-guy/Noctra/blob/main/CHANGELOG.md',
    label: 'Changelog',
    external: true,
  },
  {
    href: 'https://github.com/nomad-guy/Noctra/blob/main/CONTRIBUTING.md',
    label: 'Contributing',
    external: true,
  },
  {
    href: 'https://github.com/nomad-guy/Noctra/blob/main/SECURITY.md',
    label: 'Security Policy',
    external: true,
  },
];

const COMMUNITY_LINKS = [
  { href: 'https://t.me/Noctra_app', label: 'Telegram Channel', external: true },
  {
    href: 'https://github.com/nomad-guy/Noctra/issues',
    label: 'Issue Tracker',
    external: true,
  },
  {
    href: 'https://github.com/nomad-guy/Noctra/blob/main/LICENSE',
    label: 'GPL-3.0 License',
    external: true,
  },
];

export function Footer() {
  const { release, openChangelog } = useRelease();

  return (
    <footer className={styles.footer}>
      <div className={styles.container}>
        <div className={styles.topGrid}>
          <div className={styles.brandCol}>
            <a className={styles.brand} href="#top" aria-label="Noctra home">
              <span className={styles.brandMark}>N</span>
              <span className={styles.brandName}>Noctra</span>
            </a>
            <p className={styles.motto}>
              Free, open-source music for every device. Stream, download, and
              listen offline — with zero ads, zero tracking, and zero accounts.
            </p>
            <div className={styles.releaseChip}>
              <span className={styles.releaseDot} aria-hidden="true" />
              <span>{release.tag}</span>
              <button
                type="button"
                className={styles.releaseLink}
                onClick={openChangelog}
              >
                view changelog →
              </button>
            </div>
          </div>

          <nav className={styles.linkCol} aria-label="Site">
            <h3 className={styles.colTitle}>Explore</h3>
            {RESOURCE_LINKS.map((l) => (
              <a key={l.label} className={styles.link} href={l.href}>
                {l.label}
              </a>
            ))}
          </nav>

          <nav className={styles.linkCol} aria-label="Project">
            <h3 className={styles.colTitle}>Project</h3>
            {PROJECT_LINKS.map((l) => (
              <a
                key={l.label}
                className={styles.link}
                href={l.href}
                target="_blank"
                rel="noreferrer"
              >
                {l.label}
              </a>
            ))}
          </nav>

          <nav className={styles.linkCol} aria-label="Community">
            <h3 className={styles.colTitle}>Community</h3>
            {COMMUNITY_LINKS.map((l) => (
              <a
                key={l.label}
                className={styles.link}
                href={l.href}
                target="_blank"
                rel="noreferrer"
              >
                {l.label}
              </a>
            ))}
          </nav>
        </div>

        <div className={styles.bottomRow}>
          <p>
            &copy; 2026 Noctra · Built by the community, for the community.
            Distributed under the GPL-3.0 license.
          </p>
          <p className={styles.disclaimer}>
            Noctra is not affiliated with, endorsed by, or connected to any
            streaming provider. All trademarks belong to their respective owners.
          </p>
        </div>
      </div>
    </footer>
  );
}
