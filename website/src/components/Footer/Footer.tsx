import { useRelease } from '../../context/ReleaseContext';
import { Link } from '../../router/Router';
import styles from './Footer.module.css';

const EXPLORE_LINKS = [
  { to: '/', label: 'Overview' },
  { to: '/features', label: 'Features & DSP' },
  { to: '/download', label: 'Download Hub' },
  { to: '/architecture', label: 'Architecture & Security' },
  { to: '/changelog', label: 'Changelog' },
];

const PROJECT_LINKS = [
  {
    href: 'https://github.com/nomad-guy/Noctra',
    label: 'GitHub Repository',
  },
  {
    href: 'https://github.com/nomad-guy/Noctra/releases',
    label: 'All Releases',
  },
  {
    href: 'https://github.com/nomad-guy/Noctra/blob/main/CHANGELOG.md',
    label: 'Markdown Changelog',
  },
  {
    href: 'https://github.com/nomad-guy/Noctra/blob/main/CONTRIBUTING.md',
    label: 'Contributing Guide',
  },
  {
    href: 'https://github.com/nomad-guy/Noctra/blob/main/SECURITY.md',
    label: 'Security Policy',
  },
];

const COMMUNITY_LINKS = [
  { href: 'https://t.me/Noctra_app', label: 'Telegram Community (@Noctra_app)' },
  {
    href: 'https://github.com/nomad-guy/Noctra/issues',
    label: 'Issue Tracker',
  },
  {
    href: 'https://github.com/nomad-guy/Noctra/blob/main/LICENSE',
    label: 'GPL-3.0 License',
  },
];

export function Footer() {
  const { release } = useRelease();

  return (
    <footer className={styles.footer}>
      <div className={styles.container}>
        <div className={styles.topGrid}>
          <div className={styles.brandCol}>
            <Link className={styles.brand} to="/" aria-label="Noctra home">
              <span className={styles.brandMark}>N</span>
              <span className={styles.brandName}>Noctra</span>
            </Link>
            <p className={styles.motto}>
              Free, open-source audiophile music client for every device.
              Stream, reconstruct, and listen offline with zero ads, zero tracking, and zero accounts.
            </p>
            <div className={styles.releaseChip}>
              <span className={styles.releaseDot} aria-hidden="true" />
              <span>{release.tag}</span>
              <Link to="/changelog" className={styles.releaseLink}>
                view changelog →
              </Link>
            </div>
          </div>

          <nav className={styles.linkCol} aria-label="Site">
            <h3 className={styles.colTitle}>Explore</h3>
            {EXPLORE_LINKS.map((l) => (
              <Link key={l.label} className={styles.link} to={l.to}>
                {l.label}
              </Link>
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
            Noctra is not affiliated with, endorsed by, or connected to any commercial streaming provider.
            All trademarks belong to their respective owners.
          </p>
        </div>
      </div>
    </footer>
  );
}
