import { useState } from 'react';
import {
  Monitor,
  Smartphone,
  Terminal,
  Sparkles,
  Download,
  Copy,
  Check,
  ShieldCheck,
  ExternalLink,
} from 'lucide-react';
import { useRelease } from '../context/ReleaseContext';
import type { PlatformType } from '../types';
import styles from './DownloadPage.module.css';

export function DownloadPage() {
  const { release } = useRelease();
  const [selectedPlatform, setSelectedPlatform] = useState<PlatformType>('windows');
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  const binaries = release.binaries;
  const current = binaries[selectedPlatform];

  const handleCopy = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  return (
    <div className={styles.container}>
      <header className={styles.header}>
        <span className={styles.tag}>OFFICIAL RELEASES</span>
        <h1 className={styles.title}>Download Noctra {release.tag}</h1>
        <p className={styles.subtitle}>
          Single-file standalone native packages compiled directly from source with cryptographic SHA-256 integrity verification.
        </p>
      </header>

      {/* Platform Selector Tabs */}
      <div className={styles.platformTabs}>
        <button
          type="button"
          className={`${styles.tabBtn} ${selectedPlatform === 'windows' ? styles.tabBtnActive : ''}`}
          onClick={() => setSelectedPlatform('windows')}
        >
          <Monitor size={18} />
          <span>Windows</span>
        </button>

        <button
          type="button"
          className={`${styles.tabBtn} ${selectedPlatform === 'android' ? styles.tabBtnActive : ''}`}
          onClick={() => setSelectedPlatform('android')}
        >
          <Smartphone size={18} />
          <span>Android</span>
        </button>

        <button
          type="button"
          className={`${styles.tabBtn} ${selectedPlatform === 'linux' ? styles.tabBtnActive : ''}`}
          onClick={() => setSelectedPlatform('linux')}
        >
          <Terminal size={18} />
          <span>Linux</span>
        </button>

        <button
          type="button"
          className={`${styles.tabBtn} ${selectedPlatform === 'ios' ? styles.tabBtnActive : ''}`}
          onClick={() => setSelectedPlatform('ios')}
        >
          <Sparkles size={18} />
          <span>iOS</span>
        </button>
      </div>

      {/* Primary Download Card */}
      <div className={styles.downloadCard}>
        <div className={styles.cardHeader}>
          <div>
            <span className={styles.cardBadge}>{current.badge}</span>
            <h2 className={styles.cardTitle}>{current.name}</h2>
            <p className={styles.cardDesc}>{current.desc}</p>
          </div>
          <div className={styles.actionCol}>
            <a href={current.downloadUrl} className={styles.btnDownloadPrimary}>
              <Download size={18} />
              <span>Download {current.filename}</span>
            </a>
            {current.size && <span className={styles.fileSizeText}>File size: {current.size}</span>}
          </div>
        </div>

        {/* Alternative Architectures (for Android) */}
        {selectedPlatform === 'android' && release.binaries.android && (
          <div className={styles.androidVariants}>
            <h3 className={styles.variantHeading}>Architecture-Specific APKs & Bundles</h3>
            <div className={styles.variantGrid}>
              {release.binaries.android.universalUrl && (
                <a href={release.binaries.android.universalUrl} className={styles.variantChip}>
                  <Download size={14} />
                  <span>Universal APK (All Devices)</span>
                </a>
              )}
              {release.binaries.android.downloadUrl && (
                <a href={release.binaries.android.downloadUrl} className={styles.variantChip}>
                  <Download size={14} />
                  <span>ARM64-v8a (Modern 64-bit Phones)</span>
                </a>
              )}
              {release.binaries.android.armeabiUrl && (
                <a href={release.binaries.android.armeabiUrl} className={styles.variantChip}>
                  <Download size={14} />
                  <span>ARMeabi-v7a (Older 32-bit Phones)</span>
                </a>
              )}
              {release.binaries.android.x86_64Url && (
                <a href={release.binaries.android.x86_64Url} className={styles.variantChip}>
                  <Download size={14} />
                  <span>x86_64 (Emulators & ChromeOS)</span>
                </a>
              )}
              {release.binaries.android.aabUrl && (
                <a href={release.binaries.android.aabUrl} className={styles.variantChip}>
                  <Download size={14} />
                  <span>Google Play App Bundle (.aab)</span>
                </a>
              )}
            </div>
          </div>
        )}

        {/* Command Line / Install Instruction */}
        {current.command && (
          <div className={styles.commandBox}>
            <div className={styles.commandHeader}>
              <span className={styles.commandLabel}>{current.commandLabel}</span>
              <button
                type="button"
                className={styles.copyBtn}
                onClick={() => handleCopy(current.command!, 'cmd')}
              >
                {copiedKey === 'cmd' ? <Check size={14} /> : <Copy size={14} />}
                <span>{copiedKey === 'cmd' ? 'Copied!' : 'Copy'}</span>
              </button>
            </div>
            <code className={styles.codeSnippet}>{current.command}</code>
          </div>
        )}

        {/* SHA-256 Integrity Verification */}
        <div className={styles.checksumBox}>
          <div className={styles.checksumHeader}>
            <div className={styles.checksumLeft}>
              <ShieldCheck size={16} className={styles.shieldIcon} />
              <span className={styles.checksumLabel}>Cryptographic SHA-256 Verification</span>
            </div>
            <button
              type="button"
              className={styles.copyBtn}
              onClick={() => handleCopy(current.sha256 || '', 'sha')}
            >
              {copiedKey === 'sha' ? <Check size={14} /> : <Copy size={14} />}
              <span>{copiedKey === 'sha' ? 'Hash Copied!' : 'Copy SHA-256'}</span>
            </button>
          </div>
          <code className={styles.shaCode}>{current.sha256}</code>
        </div>
      </div>

      {/* GitHub Releases & Source Code Banner */}
      <div className={styles.releaseBanner}>
        <div>
          <h3>Verify All Binary Checksums</h3>
          <p>
            Download the official cryptographic manifest directly from GitHub Actions to verify all release packages.
          </p>
        </div>
        <div className={styles.bannerActions}>
          <a
            href={binaries.sha256sumsUrl}
            target="_blank"
            rel="noopener noreferrer"
            className={styles.bannerBtn}
          >
            <span>SHA256SUMS.txt</span>
            <ExternalLink size={14} />
          </a>
          <a
            href={release.releaseUrl}
            target="_blank"
            rel="noopener noreferrer"
            className={styles.bannerBtnSecondary}
          >
            <span>GitHub Release Notes</span>
            <ExternalLink size={14} />
          </a>
        </div>
      </div>
    </div>
  );
}
