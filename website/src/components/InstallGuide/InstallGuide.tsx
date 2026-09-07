import { useState, useEffect } from 'react';
import {
  Monitor,
  Smartphone,
  Terminal,
  Tablet,
  Download,
  Check,
  Copy,
  AlertCircle,
  ShieldCheck,
} from 'lucide-react';
import { detectUserPlatform } from '../../utils/detectPlatform';
import type { PlatformType } from '../../types';
import styles from './InstallGuide.module.css';

interface GuideStep {
  title: string;
  desc: string;
  callout?: string;
  command?: string;
}

interface PlatformGuide {
  id: PlatformType;
  name: string;
  badge: string;
  fileName: string;
  fileSize: string;
  downloadUrl: string;
  sha256: string;
  steps: GuideStep[];
}

const GUIDES: Record<PlatformType, PlatformGuide> = {
  windows: {
    id: 'windows',
    name: 'Windows',
    badge: 'Standalone x64 Setup',
    fileName: 'Noctra-1.0.6-Setup-x64.exe',
    fileSize: '54 MB',
    downloadUrl:
      'https://github.com/nomad-guy/Noctra/releases/download/v1.0.6/Noctra-1.0.6-Setup-x64.exe',
    sha256:
      '47fe0543666fcf8ae676ff38a209930f7be522d0571fa088beba7f43ec8adce5',
    steps: [
      {
        title: 'Download the Official Installer',
        desc: 'Click the download button above to get Noctra-1.0.6-Setup-x64.exe, pre-compiled with all audio engines and codecs bundled.',
      },
      {
        title: 'Run Setup & Security Confirmation',
        desc: 'Open the downloaded .exe file. Because Noctra is open source and community-built, Windows Defender SmartScreen may display a prompt.',
        callout:
          'If "Windows protected your PC" appears, click "More info" and then select "Run anyway" to proceed.',
      },
      {
        title: 'Complete 1-Click Installation',
        desc: 'The Inno Setup wizard installs Noctra directly to your local user AppData directory without requiring administrative elevation, creating clean Start Menu and Desktop shortcuts.',
      },
      {
        title: 'Launch & Keyboard Controls',
        desc: 'Launch Noctra. Use Space to Play/Pause, Left/Right arrows to scrub tracks, Up/Down arrows to adjust volume, and M to mute.',
      },
    ],
  },
  android: {
    id: 'android',
    name: 'Android',
    badge: 'Universal & Multi-ABI APK',
    fileName: 'Noctra-1.0.6-arm64-v8a.apk',
    fileSize: '36 MB',
    downloadUrl:
      'https://github.com/nomad-guy/Noctra/releases/download/v1.0.6/Noctra-1.0.6-arm64-v8a.apk',
    sha256:
      '79b47e8ebdb3cf0bf00f40d6c975a5933a364177d61eb1a4da605f63968ae2ad',
    steps: [
      {
        title: 'Select Package & Download',
        desc: 'For modern phones (2018+), download the arm64-v8a APK for the smallest footprint. For older devices or tablets, choose the Universal APK.',
      },
      {
        title: 'Enable "Install Unknown Apps"',
        desc: 'When opening the APK from your browser or file manager, Android security prompts for permission to install external applications.',
        callout:
          'Tap Settings on the security prompt and toggle "Allow from this source", then return to the installer.',
      },
      {
        title: 'Install & Grant Permissions',
        desc: 'Tap "Install". Once installed, open Noctra and allow audio and notification permissions so lockscreen controls and background streaming function smoothly.',
      },
      {
        title: 'Disable Battery Optimization (Optional)',
        desc: 'To prevent Android OEM task-killers from interrupting long gapless listening sessions, exclude Noctra from battery optimization in App Info -> Battery.',
      },
    ],
  },
  linux: {
    id: 'linux',
    name: 'Linux',
    badge: 'Debian / Ubuntu Package',
    fileName: 'noctra_1.0.6_amd64.deb',
    fileSize: '46 MB',
    downloadUrl:
      'https://github.com/nomad-guy/Noctra/releases/download/v1.0.6/noctra_1.0.6_amd64.deb',
    sha256:
      '9c5237895e6919dbb3fe27e462d159048a1b69828fa6b98668383f7e53f1da73',
    steps: [
      {
        title: 'Download the Debian Package',
        desc: 'Download noctra_1.0.6_amd64.deb to your Downloads folder or fetch it directly via terminal.',
      },
      {
        title: 'Install via DPKG',
        desc: 'Run the package installer using sudo dpkg in your terminal.',
        command: 'sudo dpkg -i noctra_1.0.6_amd64.deb',
      },
      {
        title: 'Resolve Dependencies (If Required)',
        desc: 'If any desktop or audio GTK dependencies are missing, resolve them with apt-get.',
        command: 'sudo apt-get install -f',
      },
      {
        title: 'Launch from Applications Menu',
        desc: 'Noctra installs with full system icon and desktop entry integration. Search for "Noctra" in your launcher or run "noctra" in your terminal.',
      },
    ],
  },
  ios: {
    id: 'ios',
    name: 'iOS',
    badge: 'Sideloadable IPA Bundle',
    fileName: 'Noctra-1.0.6.ipa',
    fileSize: '48 MB',
    downloadUrl:
      'https://github.com/nomad-guy/Noctra/releases/download/v1.0.6/Noctra-1.0.6.ipa',
    sha256:
      'b7faad7df8dfad86bc778bba9ae3298cb3d2a7c490a6e0df2e5b7b938f29ab0e',
    steps: [
      {
        title: 'Download the IPA Package',
        desc: 'Download Noctra-1.0.6.ipa. Compatible with AltStore, SideStore, Sideloadly, and TrollStore on iOS 15.0+.',
      },
      {
        title: '1-Click Install with AltStore (Optional)',
        desc: 'If AltStore is installed on your device, tap the deep-link below to start direct installation.',
        command:
          'altstore://install?url=https://github.com/nomad-guy/Noctra/releases/download/v1.0.6/Noctra-1.0.6.ipa',
      },
      {
        title: 'Trust Developer Certificate',
        desc: 'After installation, navigate to iOS Settings -> General -> VPN & Device Management.',
        callout:
          'Tap on your Apple ID certificate under "Developer App" and select "Trust".',
      },
      {
        title: 'Launch with Background Audio',
        desc: 'Open Noctra. Background audio sessions, Lock Screen playback controls, and Now Playing widgets are fully active.',
      },
    ],
  },
};

export function InstallGuide() {
  const [selectedPlatform, setSelectedPlatform] =
    useState<PlatformType>('windows');
  const [userPlatform, setUserPlatform] =
    useState<PlatformType>('windows');
  const [copiedText, setCopiedText] = useState<string | null>(null);

  useEffect(() => {
    const detected = detectUserPlatform();
    setUserPlatform(detected);
    setSelectedPlatform(detected);
  }, []);

  const guide = GUIDES[selectedPlatform];

  const handleCopy = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedText(text);
    setTimeout(() => setCopiedText(null), 2000);
  };

  const getPlatformIcon = (id: PlatformType) => {
    switch (id) {
      case 'windows':
        return <Monitor className={styles.tabIcon} size={24} />;
      case 'android':
        return <Smartphone className={styles.tabIcon} size={24} />;
      case 'linux':
        return <Terminal className={styles.tabIcon} size={24} />;
      case 'ios':
        return <Tablet className={styles.tabIcon} size={24} />;
    }
  };

  return (
    <section id="install" className={styles.section}>
      <div className={styles.container}>
        <div className={styles.header}>
          <span className={styles.tag}>Installation Hub</span>
          <h2 className={styles.title}>Download & Setup Guide</h2>
          <p className={styles.subtitle}>
            Step-by-step installation instructions and security verification for
            all supported platforms.
          </p>
        </div>

        {/* Platform Tabs */}
        <div className={styles.tabs} role="tablist">
          {(Object.keys(GUIDES) as PlatformType[]).map((platform) => {
            const isActive = platform === selectedPlatform;
            const isUserPlatform = platform === userPlatform;
            const item = GUIDES[platform];
            return (
              <button
                key={platform}
                type="button"
                className={`${styles.tabBtn} ${
                  isActive ? styles.tabBtnActive : ''
                }`}
                onClick={() => setSelectedPlatform(platform)}
              >
                {getPlatformIcon(platform)}
                <span className={styles.tabName}>
                  {item.name}
                  {isUserPlatform && (
                    <span className={styles.yourOsTag}>YOUR OS</span>
                  )}
                </span>
                <span className={styles.tabBadge}>{item.badge}</span>
              </button>
            );
          })}
        </div>

        {/* Detailed Guide Card */}
        <div className={styles.card}>
          <div className={styles.cardHeader}>
            <div className={styles.cardMeta}>
              <h3 className={styles.platformTitle}>
                Installing Noctra on {guide.name}
              </h3>
              <span className={styles.packageSubtitle}>
                {guide.fileName} ({guide.fileSize})
              </span>
            </div>
            <a
              href={guide.downloadUrl}
              className={styles.primaryDownloadBtn}
              download
            >
              <Download size={18} />
              Download for {guide.name}
            </a>
          </div>

          <div className={styles.stepsList}>
            {guide.steps.map((step, idx) => (
              <div key={step.title} className={styles.stepItem}>
                <div className={styles.stepNumber}>0{idx + 1}</div>
                <div className={styles.stepContent}>
                  <h4 className={styles.stepTitle}>{step.title}</h4>
                  <p className={styles.stepDesc}>{step.desc}</p>
                  {step.callout && (
                    <div className={styles.calloutBox}>
                      <AlertCircle className={styles.calloutIcon} size={16} />
                      <span>{step.callout}</span>
                    </div>
                  )}
                  {step.command && (
                    <div className={styles.codeBox}>
                      <code className={styles.codeText}>{step.command}</code>
                      <button
                        type="button"
                        className={styles.copyBtn}
                        onClick={() => handleCopy(step.command!)}
                        title="Copy command"
                      >
                        {copiedText === step.command ? (
                          <Check size={16} />
                        ) : (
                          <Copy size={16} />
                        )}
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>

          <div className={styles.checksumBox}>
            <div className={styles.checksumHeader}>
              <ShieldCheck size={18} />
              <span>SHA-256 Cryptographic Integrity Checksum</span>
            </div>
            <code className={styles.checksumValue}>{guide.sha256}</code>
          </div>
        </div>
      </div>
    </section>
  );
}
