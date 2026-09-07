import { useState } from 'react';
import { Monitor, Terminal, Smartphone, Sparkles, Download, Copy, Check } from 'lucide-react';
import type { PlatformType } from '../../types';
import { useRelease } from '../../context/ReleaseContext';
import styles from './AllDownloads.module.css';

export function AllDownloads() {
  const [activePlatform, setActivePlatform] = useState<PlatformType>('windows');
  const [copiedKey, setCopiedKey] = useState<string | null>(null);
  const { release } = useRelease();

  const current = release.binaries[activePlatform];

  const handleCopy = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  return (
    <section id="downloads" className={styles.section}>
      <div className="section-header">
        <span className="section-tag">NATIVE CROSS-PLATFORM HUB</span>
        <h2 className="section-title">Download Noctra {release.tag}</h2>
        <p className="section-subtitle">
          Single-file standalone native packages compiled directly from source with cryptographic SHA-256 integrity verification.
        </p>
      </div>

      <div className={styles.platformTabs}>
        <button
          type="button"
          className={`${styles.platformTabBtn} ${activePlatform === 'windows' ? styles.platformTabActive : ''}`}
          onClick={() => setActivePlatform('windows')}
        >
          <Monitor size={16} />
          <span>Windows (.exe)</span>
        </button>
        <button
          type="button"
          className={`${styles.platformTabBtn} ${activePlatform === 'linux' ? styles.platformTabActive : ''}`}
          onClick={() => setActivePlatform('linux')}
        >
          <Terminal size={16} />
          <span>Linux (.deb)</span>
        </button>
        <button
          type="button"
          className={`${styles.platformTabBtn} ${activePlatform === 'android' ? styles.platformTabActive : ''}`}
          onClick={() => setActivePlatform('android')}
        >
          <Smartphone size={16} />
          <span>Android (.apk)</span>
        </button>
        <button
          type="button"
          className={`${styles.platformTabBtn} ${activePlatform === 'ios' ? styles.platformTabActive : ''}`}
          onClick={() => setActivePlatform('ios')}
        >
          <Sparkles size={16} />
          <span>Apple iOS (.ipa)</span>
        </button>
      </div>

      <div className={styles.card}>
        <div className={styles.cardHeader}>
          <div className={styles.titleArea}>
            <div className={styles.titleRow}>
              <h3 className={styles.osTitle}>{current.name}</h3>
              <span className={styles.badge}>{current.badge}</span>
            </div>
            <p className={styles.osDesc}>{current.desc}</p>
          </div>
        </div>

        <div className={styles.downloadCtaRow}>
          <div className={styles.fileInfo}>
            <span className={styles.fileName}>{current.filename}</span>
            <span className={styles.fileDetails}>
              {current.size} &bull; Architecture: {current.arch} &bull; Release: {release.tag}
            </span>
          </div>

          <a href={current.downloadUrl} className="btn btn-primary">
            <Download size={16} />
            <span>Download Package</span>
          </a>
        </div>

        {/* SHA256 Verification Hash Box */}
        {current.sha256 && (
          <div className={styles.hashBox}>
            <div className={styles.hashHeader}>
              <span className={styles.hashLabel}>Cryptographic SHA-256 Checksum</span>
              <button
                type="button"
                className="btn btn-glass btn-sm"
                onClick={() => handleCopy(current.sha256 || '', 'hash')}
              >
                {copiedKey === 'hash' ? <Check size={13} /> : <Copy size={13} />}
                <span>{copiedKey === 'hash' ? 'Copied' : 'Copy Hash'}</span>
              </button>
            </div>
            <code className={styles.hashVal}>{current.sha256}</code>
          </div>
        )}

        {/* Terminal Box */}
        <div className={styles.terminalBox}>
          <span className={styles.terminalLabel}>{current.commandLabel || 'Installation Command'}</span>
          <div className={styles.terminalCode}>
            <code>{current.command}</code>
            <button
              type="button"
              className="btn btn-glass btn-sm"
              onClick={() => handleCopy(current.command, 'cmd')}
            >
              {copiedKey === 'cmd' ? <Check size={13} /> : <Copy size={13} />}
              <span>{copiedKey === 'cmd' ? 'Copied' : 'Copy Command'}</span>
            </button>
          </div>
        </div>
      </div>

      <div className={styles.moreLinks}>
        <a href={release.binaries.android.universalUrl} className={styles.linkTag}>Universal APK</a>
        <a href={release.binaries.android.armeabiUrl} className={styles.linkTag}>armeabi-v7a APK</a>
        <a href={release.binaries.android.x86_64Url} className={styles.linkTag}>x86_64 APK</a>
        <a href={release.binaries.android.aabUrl} className={styles.linkTag}>Google Play .aab</a>
        <a href={release.binaries.sha256sumsUrl} className={styles.linkTag}>Official SHA256SUMS.txt</a>
        <a href={release.releaseUrl} target="_blank" rel="noopener noreferrer" className={styles.linkTag}>&rarr; GitHub Release {release.tag}</a>
      </div>
    </section>
  );
}
