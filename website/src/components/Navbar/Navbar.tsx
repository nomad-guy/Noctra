import { useEffect, useState } from 'react';
import styles from './Navbar.module.css';

const LINKS = [
  { href: '#features', label: 'Features' },
  { href: '#showcase', label: 'Showcase' },
  { href: '#downloads', label: 'Downloads' },
  { href: '#changelog', label: 'Changelog' },
  { href: '#faq', label: 'FAQ' },
];

type Theme = 'noir-black' | 'noir-white' | 'liquid-glass';

const THEME_META: Record<Theme, { label: string; icon: React.ReactElement }> = {
  'noir-black': {
    label: 'Noir Black',
    icon: (
      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path
          d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    ),
  },
  'noir-white': {
    label: 'Noir White',
    icon: (
      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <circle cx="12" cy="12" r="4.2" stroke="currentColor" strokeWidth="2" />
        <path
          d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.2 5.2l1.6 1.6M17.2 17.2l1.6 1.6M18.8 5.2l-1.6 1.6M6.8 17.2l-1.6 1.6"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
        />
      </svg>
    ),
  },
  'liquid-glass': {
    label: 'Liquid Glass',
    icon: (
      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path
          d="M12 2.5 21 12l-9 9.5L3 12l9-9.5Z"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinejoin="round"
        />
        <path d="M12 6.5 16.8 12 12 17.5 7.2 12 12 6.5Z" fill="currentColor" opacity="0.45" />
      </svg>
    ),
  },
};

function readStoredTheme(): Theme {
  try {
    const t = localStorage.getItem('noctra-theme');
    if (t === 'noir-white' || t === 'liquid-glass' || t === 'noir-black') return t;
  } catch {
    /* ignore */
  }
  return 'noir-black';
}

function applyTheme(theme: Theme) {
  document.documentElement.dataset.theme = theme;
  try {
    localStorage.setItem('noctra-theme', theme);
  } catch {
    /* ignore */
  }
}

export default function Navbar() {
  // Lazy initializer reads localStorage during first render — no setState
  // in an effect, and the first paint already has the stored theme.
  const [theme, setTheme] = useState<Theme>(() => {
    const stored = readStoredTheme();
    applyTheme(stored);
    return stored;
  });
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const pickTheme = (t: Theme) => {
    setTheme(t);
    applyTheme(t);
  };

  return (
    <header className={`${styles.navbar} ${scrolled ? styles.scrolled : ''}`}>
      <a className={styles.brand} href="#top" aria-label="Noctra home">
        <span className={styles.brandMark}>N</span>
        <span className={styles.brandName}>Noctra</span>
      </a>

      <nav className={styles.links} aria-label="Primary">
        {LINKS.map((l) => (
          <a key={l.href} className={styles.link} href={l.href}>
            {l.label}
          </a>
        ))}
      </nav>

      <div className={styles.right}>
        <div className={styles.themeSwitch} role="group" aria-label="Theme">
          {(Object.keys(THEME_META) as Theme[]).map((t) => (
            <button
              key={t}
              className={`${styles.themeBtn} ${theme === t ? styles.active : ''}`}
              onClick={() => pickTheme(t)}
              aria-label={`Switch to ${THEME_META[t].label}`}
              aria-pressed={theme === t}
              title={THEME_META[t].label}
            >
              {THEME_META[t].icon}
            </button>
          ))}
        </div>

        <a
          className={styles.githubBtn}
          href="https://github.com/nomad-guy/Noctra"
          target="_blank"
          rel="noreferrer"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M12 .5C5.65.5.5 5.65.5 12c0 5.08 3.29 9.39 7.86 10.91.58.11.79-.25.79-.55v-2.15c-3.2.7-3.87-1.36-3.87-1.36-.52-1.33-1.28-1.68-1.28-1.68-1.04-.71.08-.7.08-.7 1.15.08 1.76 1.18 1.76 1.18 1.03 1.76 2.69 1.25 3.35.96.1-.75.4-1.25.72-1.54-2.55-.29-5.23-1.28-5.23-5.68 0-1.26.45-2.28 1.18-3.09-.12-.29-.51-1.46.11-3.05 0 0 .96-.31 3.15 1.18a10.9 10.9 0 0 1 5.74 0c2.19-1.49 3.15-1.18 3.15-1.18.62 1.59.23 2.76.11 3.05.73.81 1.18 1.83 1.18 3.09 0 4.41-2.69 5.38-5.25 5.67.41.35.77 1.04.77 2.1v3.11c0 .3.21.67.8.55A11.51 11.51 0 0 0 23.5 12C23.5 5.65 18.35.5 12 .5Z" />
          </svg>
          GitHub
        </a>

        <a className={styles.downloadBtn} href="#downloads">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path
              d="M12 3v12m0 0 4.5-4.5M12 15l-4.5-4.5M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2"
              stroke="currentColor"
              strokeWidth="2.2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
          <span>Download</span>
        </a>

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
            <a
              key={l.href}
              className={styles.link}
              href={l.href}
              onClick={() => setMenuOpen(false)}
            >
              {l.label}
            </a>
          ))}
        </nav>
      )}
    </header>
  );
}
