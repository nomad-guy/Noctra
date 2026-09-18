import { useEffect, useState } from 'react';
import { Download } from 'lucide-react';
import { Link, useRouter } from '../../router/Router';
import styles from './Navbar.module.css';

const LINKS = [
  { to: '/', label: 'Overview' },
  { to: '/features', label: 'Features' },
  { to: '/download', label: 'Download' },
  { to: '/architecture', label: 'Architecture' },
  { to: '/changelog', label: 'Changelog' },
];

export type Theme = 'noir-black' | 'noir-white' | 'liquid-glass' | 'material-u';

export interface ThemeMeta {
  id: Theme;
  label: string;
  appIcon: string;
  nextTheme: Theme;
  nextLabel: string;
}

export const THEME_DATA: Record<Theme, ThemeMeta> = {
  'noir-black': {
    id: 'noir-black',
    label: 'Noir Black',
    appIcon: '/images/logo_noctra_noir_black.png',
    nextTheme: 'noir-white',
    nextLabel: 'Noir White',
  },
  'noir-white': {
    id: 'noir-white',
    label: 'Noir White',
    appIcon: '/images/logo_noctra_noir_white.png',
    nextTheme: 'liquid-glass',
    nextLabel: 'Liquid Glass',
  },
  'liquid-glass': {
    id: 'liquid-glass',
    label: 'Liquid Glass',
    appIcon: '/images/logo_noctra_liquid_glass.png',
    nextTheme: 'material-u',
    nextLabel: 'Material U',
  },
  'material-u': {
    id: 'material-u',
    label: 'Material U',
    appIcon: '/images/logo_noctra_material_u.png',
    nextTheme: 'noir-black',
    nextLabel: 'Noir Black',
  },
};

function readStoredTheme(): Theme {
  try {
    const t = localStorage.getItem('noctra-theme');
    if (
      t === 'noir-white' ||
      t === 'liquid-glass' ||
      t === 'material-u' ||
      t === 'noir-black'
    ) {
      return t;
    }
  } catch {
    /* ignore */
  }
  return 'noir-black';
}

export function applyTheme(theme: Theme) {
  document.documentElement.setAttribute('data-theme', theme);
  document.documentElement.dataset.theme = theme;
  if (document.body) {
    document.body.setAttribute('data-theme', theme);
    document.body.dataset.theme = theme;
  }
  try {
    localStorage.setItem('noctra-theme', theme);
  } catch {
    /* ignore */
  }

  // Synchronize dynamic browser favicon with active theme app icon
  const favicon = document.querySelector<HTMLLinkElement>("link[rel~='icon']");
  if (favicon && THEME_DATA[theme]) {
    favicon.href = THEME_DATA[theme].appIcon;
  }
}

export default function Navbar() {
  const { currentPath } = useRouter();
  const [theme, setTheme] = useState<Theme>(() => {
    const stored = readStoredTheme();
    applyTheme(stored);
    return stored;
  });
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    applyTheme(theme);
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, [theme]);

  const cycleTheme = () => {
    const next = THEME_DATA[theme].nextTheme;
    setTheme(next);
    applyTheme(next);
  };

  const curr = THEME_DATA[theme] || THEME_DATA['noir-black'];

  return (
    <header className={`${styles.navbar} ${scrolled ? styles.scrolled : ''}`}>
      <Link to="/" className={styles.brand} aria-label="Noctra home">
        <div className={styles.brandMark}>
          <img
            src={curr.appIcon}
            alt="Noctra App Icon"
            className={styles.brandLogoImg}
          />
        </div>
        <span className={styles.brandName}>Noctra</span>
      </Link>

      <nav className={styles.links} aria-label="Primary">
        {LINKS.map((l) => {
          const isActive =
            l.to === '/'
              ? currentPath === '/'
              : currentPath.startsWith(l.to);
          return (
            <Link
              key={l.to}
              to={l.to}
              className={`${styles.link} ${isActive ? styles.linkActive : ''}`}
            >
              {l.label}
            </Link>
          );
        })}
      </nav>

      <div className={styles.right}>
        {/* Sleek Theme Tap Button */}
        <button
          type="button"
          className={styles.themeTapBtn}
          onClick={cycleTheme}
          title={`Active theme: ${curr.label}. Tap to switch to ${curr.nextLabel}`}
          aria-label={`Active theme: ${curr.label}. Tap to switch to ${curr.nextLabel}`}
        >
          <span className={styles.themeIconWrapper}>
            <img src={curr.appIcon} alt="" className={styles.themeIconImg} />
          </span>
          <span className={styles.themeName}>{curr.label}</span>
          <svg
            width="13"
            height="13"
            viewBox="0 0 24 24"
            fill="none"
            className={styles.cycleArrow}
            aria-hidden="true"
          >
            <path
              d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.19"
              stroke="currentColor"
              strokeWidth="2.2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </button>

        <a
          className={styles.githubBtn}
          href="https://github.com/nomad-guy/Noctra"
          target="_blank"
          rel="noreferrer"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M12 .5C5.65.5.5 5.65.5 12c0 5.08 3.29 9.39 7.86 10.91.58.11.79-.25.79-.55v-2.15c-3.2.7-3.87-1.36-3.87-1.36-.52-1.33-1.28-1.68-1.28-1.68-1.04-.71.08-.7.08-.7 1.15.08 1.76 1.18 1.76 1.18 1.03 1.76 2.69 1.25 3.35.96.1-.75.4-1.25.72-1.54-2.55-.29-5.23-1.28-5.23-5.68 0-1.26.45-2.28 1.18-3.09-.12-.29-.51-1.46.11-3.05 0 0 .96-.31 3.15 1.18a10.9 10.9 0 0 1 5.74 0c2.19-1.49 3.15-1.18 3.15-1.18.62 1.59.23 2.76.11 3.05.73.81 1.18 1.83 1.18 3.09 0 4.41-2.69 5.38-5.25 5.67.41.35.77 1.04.77 2.1v3.11c0 .3.21.67.8.55A11.51 11.51 0 0 0 23.5 12C23.5 5.65 18.35.5 12 .5Z" />
          </svg>
          <span>GitHub</span>
        </a>

        <Link to="/download" className={styles.downloadBtn}>
          <Download size={15} />
          <span>Download</span>
        </Link>

        <button
          className={styles.burger}
          onClick={() => setMenuOpen((v) => !v)}
          aria-label="Toggle menu"
          aria-expanded={menuOpen}
        >
          {menuOpen ? (
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <path d="M6 6l12 12M18 6 6 18" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" />
            </svg>
          ) : (
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <path d="M4 7h16M4 12h16M4 17h16" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" />
            </svg>
          )}
        </button>
      </div>

      {menuOpen && (
        <nav className={styles.mobileMenu} aria-label="Mobile">
          {LINKS.map((l) => (
            <Link
              key={l.to}
              to={l.to}
              className={styles.link}
              onClick={() => setMenuOpen(false)}
            >
              {l.label}
            </Link>
          ))}
          <button
            type="button"
            className={styles.themeTapBtn}
            onClick={cycleTheme}
            style={{ marginTop: 12, width: '100%', justifyContent: 'center' }}
          >
            <span className={styles.themeIconWrapper}>
              <img src={curr.appIcon} alt="" className={styles.themeIconImg} />
            </span>
            <span className={styles.themeName}>Theme: {curr.label} (Tap to Switch)</span>
          </button>
        </nav>
      )}
    </header>
  );
}
