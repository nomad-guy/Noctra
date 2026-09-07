import { useState, useEffect } from 'react';
import { Monitor, Terminal, Smartphone, Sparkles, Download } from 'lucide-react';
import { detectUserPlatform } from '../../utils/detectPlatform';
import type { PlatformType } from '../../types';
import styles from './QuickDownloads.module.css';

export function QuickDownloads() {
  const [userPlatform, setUserPlatform] = useState<PlatformType>('windows');

  useEffect(() => {
    setUserPlatform(detectUserPlatform());
  }, []);

  return (
    <section className={styles.section}>
      <div className={styles.grid}>
        {/* Windows */}
        <div className={`${styles.card} ${userPlatform === 'windows' ? styles.featuredCard : ''}`}>
          <div className={styles.badgeRow}>
            <span className={styles.platformTag}>WINDOWS</span>
            {userPlatform === 'windows' ? (
              <span className={`${styles.featuredBadge} ${styles.flashingBadge}`}>
                <span className={styles.pulseDot} />
                RECOMMENDED
              </span>
            ) : (
              <span className={styles.versionPill}>v1.0.5</span>
            )}
          </div>
          <div className={styles.iconTitleRow}>
            <div className={styles.osIcon}><Monitor size={22} /></div>
            <div>
              <h3 className={styles.platformTitle}>Windows</h3>
              <span className={styles.osSubtext}>Windows 10 / 11 (x64)</span>
            </div>
          </div>
          <p className={styles.desc}>
            Inno Setup standalone installer bundling JustAudio C++ bitstream engine, desktop shortcuts & file associations.
          </p>
          <div className={styles.fileMeta}>
            <code>Noctra-1.0.5-Setup-x64.exe</code>
            <span className={styles.metaSize}>24.5 MB</span>
          </div>
          <a
            href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-Setup-x64.exe"
            className={styles.downloadBtn}
          >
            <Download size={15} />
            <span>Download .exe</span>
          </a>
          <a href="#install" className={styles.guideLink}>Installation Guide &rarr;</a>
        </div>

        {/* Linux */}
        <div className={`${styles.card} ${userPlatform === 'linux' ? styles.featuredCard : ''}`}>
          <div className={styles.badgeRow}>
            <span className={styles.platformTag}>LINUX</span>
            {userPlatform === 'linux' ? (
              <span className={`${styles.featuredBadge} ${styles.flashingBadge}`}>
                <span className={styles.pulseDot} />
                RECOMMENDED
              </span>
            ) : (
              <span className={styles.versionPill}>v1.0.5</span>
            )}
          </div>
          <div className={styles.iconTitleRow}>
            <div className={styles.osIcon}><Terminal size={22} /></div>
            <div>
              <h3 className={styles.platformTitle}>Linux</h3>
              <span className={styles.osSubtext}>Ubuntu / Debian / Mint</span>
            </div>
          </div>
          <p className={styles.desc}>
            Native .deb package with ALSA & PulseAudio pipewire integration, app menu launcher, and low-latency audio.
          </p>
          <div className={styles.fileMeta}>
            <code>noctra_1.0.5_amd64.deb</code>
            <span className={styles.metaSize}>18.2 MB</span>
          </div>
          <a
            href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/noctra_1.0.5_amd64.deb"
            className={styles.downloadBtn}
          >
            <Download size={15} />
            <span>Download .deb</span>
          </a>
          <a href="#install" className={styles.guideLink}>Installation Guide &rarr;</a>
        </div>

        {/* Android */}
        <div className={`${styles.card} ${userPlatform === 'android' ? styles.featuredCard : ''}`}>
          <div className={styles.badgeRow}>
            <span className={styles.platformTag}>ANDROID</span>
            {userPlatform === 'android' ? (
              <span className={`${styles.featuredBadge} ${styles.flashingBadge}`}>
                <span className={styles.pulseDot} />
                RECOMMENDED
              </span>
            ) : (
              <span className={styles.versionPill}>v1.0.5</span>
            )}
          </div>
          <div className={styles.iconTitleRow}>
            <div className={styles.osIcon}><Smartphone size={22} /></div>
            <div>
              <h3 className={styles.platformTitle}>Android</h3>
              <span className={styles.osSubtext}>Phones, Tablets & DAP (8.0+)</span>
            </div>
          </div>
          <p className={styles.desc}>
            ARM64 & Universal APKs with media notification controls, lockscreen artwork, and verified release keystore.
          </p>
          <div className={styles.fileMeta}>
            <code>Noctra-1.0.5-arm64-v8a.apk</code>
            <span className={styles.metaSize}>22.9 MB</span>
          </div>
          <a
            href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-arm64-v8a.apk"
            className={styles.downloadBtn}
          >
            <Download size={15} />
            <span>Download APK</span>
          </a>
          <a href="#install" className={styles.guideLink}>Installation Guide &rarr;</a>
        </div>

        {/* iOS */}
        <div className={`${styles.card} ${userPlatform === 'ios' ? styles.featuredCard : ''}`}>
          <div className={styles.badgeRow}>
            <span className={styles.platformTag}>APPLE IOS</span>
            {userPlatform === 'ios' ? (
              <span className={`${styles.featuredBadge} ${styles.flashingBadge}`}>
                <span className={styles.pulseDot} />
                RECOMMENDED
              </span>
            ) : (
              <span className={styles.versionPill}>v1.0.5</span>
            )}
          </div>
          <div className={styles.iconTitleRow}>
            <div className={styles.osIcon}><Sparkles size={22} /></div>
            <div>
              <h3 className={styles.platformTitle}>iOS</h3>
              <span className={styles.osSubtext}>iPhone & iPad (iOS 14+)</span>
            </div>
          </div>
          <p className={styles.desc}>
            Sideloadable IPA bundle ready for AltStore, SideStore, and Sideloadly with zero jailbreaking required.
          </p>
          <div className={styles.fileMeta}>
            <code>Noctra-1.0.5.ipa</code>
            <span className={styles.metaSize}>19.8 MB</span>
          </div>
          <a
            href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5.ipa"
            className={styles.downloadBtn}
          >
            <Download size={15} />
            <span>Download .ipa</span>
          </a>
          <a href="#install" className={styles.guideLink}>Installation Guide &rarr;</a>
        </div>
      </div>
    </section>
  );
}
