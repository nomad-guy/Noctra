import type { ThemeType } from '../../types';
import { useRelease } from '../../context/ReleaseContext';
import styles from './Footer.module.css';

interface Props {
  theme: ThemeType;
}

export function Footer({ theme }: Props) {
  const { release, openChangelog } = useRelease();
  const getBrandLogo = () => {
    switch (theme) {
      case 'noir-black':
        return './images/logo_noctra_noir_black.png';
      case 'noir-white':
        return './images/logo_noctra_noir_white.png';
      case 'liquid-glass':
      default:
        return './images/logo_noctra_liquid_glass.png';
    }
  };

  return (
    <footer className={styles.footer}>
      <div className={styles.container}>
        <div className={styles.topRow}>
          <div className={styles.brand}>
            <img src={getBrandLogo()} alt="Noctra" className={styles.brandLogo} />
            <div>
              <span className={styles.brandName}>NOCTRA</span>
              <p className={styles.motto}>Autonomous, Privacy-Sovereign Music Intelligence.</p>
            </div>
          </div>

          <div className={styles.links}>
            <a href="https://t.me/Noctra_app" target="_blank" rel="noopener noreferrer" className={styles.link}>
              Telegram Channel (@Noctra_app)
            </a>
            <a href="https://github.com/nomad-guy/Noctra" target="_blank" rel="noopener noreferrer" className={styles.link}>
              GitHub Repository
            </a>
            <a href={release.releaseUrl} target="_blank" rel="noopener noreferrer" className={styles.link}>
              Release {release.tag}
            </a>
            <button type="button" onClick={openChangelog} className={styles.link} style={{ background: 'none', border: 'none', padding: 0, cursor: 'pointer', textAlign: 'left', font: 'inherit' }}>
              Changelog & Notes
            </button>
            <a href="https://github.com/nomad-guy/Noctra/blob/main/LICENSE" target="_blank" rel="noopener noreferrer" className={styles.link}>
              GPL-3.0 License
            </a>
          </div>
        </div>

        <div className={styles.bottomRow}>
          <p>
            &copy; 2026 Noctra. Built with precision for pure acoustic freedom. Distributed strictly for personal, educational, and research purposes under the GPL-3.0 license.
          </p>
        </div>
      </div>
    </footer>
  );
}
