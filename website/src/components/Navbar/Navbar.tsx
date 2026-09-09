import { useEffect, useState } from 'react';
import { Download, Menu, Moon, Sun, X } from 'lucide-react';
import type { ThemeType } from '../../types';
import { useRelease } from '../../context/ReleaseContext';
import styles from './Navbar.module.css';

const NAV_LINKS = [
  { href: '#hero', label: 'Home' },
  { href: '#showcase', label: 'App Demo' },
  { href: '#lyrics', label: 'Lyrics' },
  { href: '#audiophile', label: 'DSP Curves' },
  { href: '#transfer', label: 'Transfer' },
  { href: '#telemetry', label: 'Telemetry' },
  { href: '#downloads', label: 'Downloads' },
  { href: '#install', label: 'Install Guide' },
];

interface Props {
  theme: ThemeType;
  onCycleTheme: () => void;
}

export function Navbar({ theme, onCycleTheme }: Props) {
  const { release } = useRelease();
  const [mobileOpen, setMobileOpen] = useState(false);

  // Close the mobile panel once the viewport is desktop-sized again.
  useEffect(() => {
    if (!mobileOpen) return;
    const onResize = () => {
      if (window.innerWidth > 820) setMobileOpen(false);
    };
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, [mobileOpen]);

  // Scroll lock + Escape while the mobile panel is open.
  useEffect(() => {
    if (!mobileOpen) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setMobileOpen(false);
    };
    document.body.style.overflow = 'hidden';
    window.addEventListener('keydown', handleKeyDown);
    return () => {
      document.body.style.overflow = '';
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [mobileOpen]);

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

  const renderThemeIcon = () => {
    switch (theme) {
      case 'liquid-glass':
        return (
          <img
            src="./images/liquid_glass_shard.png"
            alt="Liquid Glass"
            className={`${styles.themeIconImg} ${styles.shardGlow}`}
          />
        );
      case 'noir-white':
        return <Sun size={18} className={styles.themeIcon} />;
      case 'noir-black':
      default:
        return <Moon size={18} className={styles.themeIcon} />;
    }
  };

  const getThemeTooltip = () => {
    switch (theme) {
      case 'liquid-glass':
        return 'Active: Liquid Glass. Tap to switch to Noir Black.';
      case 'noir-black':
        return 'Active: Noir Black. Tap to switch to Noir White.';
      case 'noir-white':
        return 'Active: Noir White. Tap to switch to Liquid Glass.';
    }
  };

  return (
    <header className={styles.header}>
      <div className={styles.container}>
        <a href="#hero" className={styles.brand}>
          <img src={getBrandLogo()} alt="Noctra" className={styles.brandLogo} />
          <span className={styles.brandName}>NOCTRA</span>
        </a>

        <nav className={styles.navLinks} aria-label="Primary">
          {NAV_LINKS.map((link) => (
            <a key={link.href} href={link.href} className={styles.navLink}>
              {link.label}
            </a>
          ))}
        </nav>

        <div className={styles.actions}>
          {/* Minimal Theme Switcher showing the app's theme logo */}
          <button
            className={styles.themeBtn}
            onClick={onCycleTheme}
            title={getThemeTooltip()}
            type="button"
            aria-label="Toggle App Theme"
          >
            {renderThemeIcon()}
          </button>

          {/* Telegram Logo Only */}
          <a
            href="https://t.me/Noctra_app"
            target="_blank"
            rel="noopener noreferrer"
            className={styles.tgBtn}
            title="Noctra Official Telegram Channel (@Noctra_app)"
            aria-label="Noctra Official Telegram Channel"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M12 2C6.48 2 2 6.48 2 12C2 17.52 6.48 22 12 22C17.52 22 22 17.52 22 12C22 6.48 17.52 2 12 2ZM16.64 8.8C16.49 10.38 15.84 14.22 15.51 15.99C15.37 16.74 15.09 16.99 14.83 17.02C14.25 17.07 13.81 16.64 13.25 16.27C12.37 15.69 11.87 15.33 11.02 14.77C10.03 14.12 10.67 13.76 11.24 13.18C11.39 13.03 13.95 10.7 14 10.49C14.01 10.45 14.01 10.33 13.94 10.27C13.87 10.21 13.77 10.23 13.7 10.25C13.6 10.27 12.01 11.32 8.94 13.38C8.5 13.68 8.1 13.83 7.74 13.82C7.34 13.81 6.57 13.59 6 13.4C5.3 13.17 4.75 13.05 4.8 12.67C4.83 12.47 5.11 12.27 5.64 12.06C8.88 10.65 11.04 9.72 12.12 9.27C15.2 7.98 15.84 7.76 16.26 7.76C16.35 7.76 16.56 7.78 16.69 7.89C16.8 7.98 16.83 8.11 16.84 8.2C16.83 8.27 16.85 8.48 16.64 8.8Z" fill="currentColor"/>
            </svg>
          </a>

          {/* Quick CTA */}
          <a href="#downloads" className={styles.downloadCta}>
            <Download size={14} />
            <span>Get {release.tag}</span>
          </a>

          {/* Mobile hamburger */}
          <button
            type="button"
            className={styles.hamburgerBtn}
            onClick={() => setMobileOpen((open) => !open)}
            aria-expanded={mobileOpen}
            aria-controls="mobile-nav-panel"
            aria-label={mobileOpen ? 'Close menu' : 'Open menu'}
          >
            {mobileOpen ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>
      </div>

      {/* Mobile slide-down panel */}
      <nav
        id="mobile-nav-panel"
        className={`${styles.mobilePanel} ${mobileOpen ? styles.mobilePanelOpen : ''}`}
        aria-label="Mobile"
        aria-hidden={!mobileOpen}
      >
        {NAV_LINKS.map((link) => (
          <a
            key={link.href}
            href={link.href}
            className={styles.mobileLink}
            onClick={() => setMobileOpen(false)}
            tabIndex={mobileOpen ? 0 : -1}
          >
            {link.label}
          </a>
        ))}
        <a
          href="#downloads"
          className={styles.mobileDownload}
          onClick={() => setMobileOpen(false)}
          tabIndex={mobileOpen ? 0 : -1}
        >
          <Download size={15} />
          <span>Download {release.tag}</span>
        </a>
      </nav>
    </header>
  );
}
