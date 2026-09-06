import { useState } from 'react';
import { Monitor, Terminal, Smartphone, Sparkles, Download, Copy, Check } from 'lucide-react';
import type { PlatformType } from '../../types';
import styles from './AllDownloads.module.css';

interface PlatformDetails {
  platform: PlatformType;
  title: string;
  badge: string;
  desc: string;
  filename: string;
  size: string;
  arch: string;
  downloadUrl: string;
  sha256: string;
  commandLabel: string;
  command: string;
}

const PLATFORMS: Record<PlatformType, PlatformDetails> = {
  windows: {
    platform: 'windows',
    title: 'Windows 10 / 11 (64-bit)',
    badge: 'Inno Setup Standalone',
    desc: 'Bundles JustAudio C++ bitstream driver, taskbar audio preview, media keys, and lossless audio pipeline.',
    filename: 'Noctra-1.0.5-Setup-x64.exe',
    size: '24.5 MB',
    arch: 'x86_64',
    downloadUrl: 'https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-Setup-x64.exe',
    sha256: '9587f5f5e37b2587f43e9f55fa92f06068154cb9f905d3beb2edb1ca626b0577',
    commandLabel: 'Silent Inno Setup Installation (PowerShell)',
    command: 'Start-Process .\\Noctra-1.0.5-Setup-x64.exe -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES" -Wait',
  },
  linux: {
    platform: 'linux',
    title: 'Linux (Debian / Ubuntu / Mint / Arch)',
    badge: 'Native .deb Package',
    desc: 'Seamless pipewire/pulseaudio ALSA bitstream passthrough with desktop icons and native MPRIS controls.',
    filename: 'noctra_1.0.5_amd64.deb',
    size: '18.2 MB',
    arch: 'amd64 / x86_64',
    downloadUrl: 'https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/noctra_1.0.5_amd64.deb',
    sha256: 'e4c4a285325374a58cba0b8fb9d0913e82086ab09fe02f24110748565e2c7284',
    commandLabel: 'Terminal dpkg Installation',
    command: 'sudo dpkg -i noctra_1.0.5_amd64.deb && sudo apt-get install -f',
  },
  android: {
    platform: 'android',
    title: 'Android 8.0+ (ARM64 & Universal)',
    badge: 'Official Keystore Signed',
    desc: 'Hardware DAC bit-perfect output, in-app updates, notification bar controller, lockscreen artwork, and offline database.',
    filename: 'Noctra-1.0.5-arm64-v8a.apk',
    size: '22.9 MB',
    arch: 'arm64-v8a',
    downloadUrl: 'https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-arm64-v8a.apk',
    sha256: 'dcadce6ca90e6301b77061c36a4fd8b671a89cd124d3cd7b19187a16890df171',
    commandLabel: 'ADB Sideload Command',
    command: 'adb install -r Noctra-1.0.5-arm64-v8a.apk',
  },
  ios: {
    platform: 'ios',
    title: 'Apple iOS 14.0+ (iPhone & iPad)',
    badge: 'Sideloadable IPA Bundle',
    desc: 'Self-hosted and sideloadable with AltStore, SideStore, Sideloadly, or TrollStore. Zero jailbreak required.',
    filename: 'Noctra-1.0.5.ipa',
    size: '19.8 MB',
    arch: 'arm64',
    downloadUrl: 'https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5.ipa',
    sha256: '2138122f3f52a5e8ac62964509319f5aa44077add32c33d8c9f701ed3d9e269d',
    commandLabel: 'AltStore Sideload URL',
    command: 'altstore://install?url=https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5.ipa',
  },
};

export function AllDownloads() {
  const [activePlatform, setActivePlatform] = useState<PlatformType>('windows');
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  const current = PLATFORMS[activePlatform];

  const handleCopy = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  return (
    <section id="downloads" className={styles.section}>
      <div className="section-header">
        <span className="section-tag">NATIVE CROSS-PLATFORM HUB</span>
        <h2 className="section-title">Download Noctra v1.0.5</h2>
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
          <span>Android (APK)</span>
        </button>
        <button
          type="button"
          className={`${styles.platformTabBtn} ${activePlatform === 'ios' ? styles.platformTabActive : ''}`}
          onClick={() => setActivePlatform('ios')}
        >
          <Sparkles size={16} />
          <span>iOS (.ipa)</span>
        </button>
      </div>

      <div className={styles.card}>
        <div className={styles.cardHeader}>
          <div className={styles.titleArea}>
            <div className={styles.titleRow}>
              <h3 className={styles.osTitle}>{current.title}</h3>
              <span className={styles.badge}>{current.badge}</span>
            </div>
            <p className={styles.osDesc}>{current.desc}</p>
          </div>
        </div>

        <div className={styles.downloadCtaRow}>
          <div className={styles.fileInfo}>
            <span className={styles.fileName}>{current.filename}</span>
            <span className={styles.fileDetails}>
              {current.size} &bull; Architecture: {current.arch} &bull; Release: v1.0.5
            </span>
          </div>

          <a href={current.downloadUrl} className="btn btn-primary">
            <Download size={16} />
            <span>Download Package</span>
          </a>
        </div>

        {/* SHA256 Verification Hash Box */}
        <div className={styles.hashBox}>
          <div className={styles.hashHeader}>
            <span className={styles.hashLabel}>Cryptographic SHA-256 Checksum</span>
            <button
              type="button"
              className="btn btn-glass btn-sm"
              onClick={() => handleCopy(current.sha256, 'hash')}
            >
              {copiedKey === 'hash' ? <Check size={13} /> : <Copy size={13} />}
              <span>{copiedKey === 'hash' ? 'Copied' : 'Copy Hash'}</span>
            </button>
          </div>
          <code className={styles.hashVal}>{current.sha256}</code>
        </div>

        {/* Terminal Box */}
        <div className={styles.terminalBox}>
          <span className={styles.terminalLabel}>{current.commandLabel}</span>
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
        <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-Universal.apk" className={styles.linkTag}>Universal APK</a>
        <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-armeabi-v7a.apk" className={styles.linkTag}>armeabi-v7a APK</a>
        <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5-x86_64.apk" className={styles.linkTag}>x86_64 APK</a>
        <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/Noctra-1.0.5.aab" className={styles.linkTag}>Google Play .aab</a>
        <a href="https://github.com/nomad-guy/Noctra/releases/download/v1.0.5/SHA256SUMS.txt" className={styles.linkTag}>Official SHA256SUMS.txt</a>
        <a href="https://github.com/nomad-guy/Noctra/releases/tag/v1.0.5" target="_blank" rel="noopener noreferrer" className={styles.linkTag}>&rarr; GitHub Release v1.0.5</a>
      </div>
    </section>
  );
}
