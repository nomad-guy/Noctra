import { useState, useEffect, useMemo } from 'react';
import {
  Monitor,
  Smartphone,
  Terminal,
  Tablet,
  Download,
  Copy,
  Check,
  ShieldCheck,
  ExternalLink,
} from 'lucide-react';
import { detectUserPlatform } from '../../utils/detectPlatform';
import type { PlatformType, ReleaseData } from '../../types';
import { useRelease } from '../../context/ReleaseContext';
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

function buildGuides(release: ReleaseData): Record<PlatformType, PlatformGuide> {
  const { windows, linux, android, ios } = release.binaries;

  return {
    windows: {
      id: 'windows',
      name: 'Windows',
      badge: 'Standalone x64 Setup',
      fileName: windows.filename,
      fileSize: windows.size,
      downloadUrl: windows.downloadUrl,
      sha256: windows.sha256 || '47fe0543666fcf8ae676ff38a209930f7be522d0571fa088beba7f43ec8adce5',
      steps: [
        {
          title: 'Download the Official Installer',
          desc: `Click the download button above to get ${windows.filename}, pre-compiled with all audio engines and codecs bundled.`,
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
      fileName: android.filename,
      fileSize: android.size,
      downloadUrl: android.downloadUrl,
      sha256: android.sha256 || '79b47e8ebdb3cf0bf00f40d6c975a5933a364177d61eb1a4da605f63968ae2ad',
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
      fileName: linux.filename,
      fileSize: linux.size,
      downloadUrl: linux.downloadUrl,
      sha256: linux.sha256 || '9c5237895e6919dbb3fe27e462d159048a1b69828fa6b98668383f7e53f1da73',
      steps: [
        {
          title: 'Download the Debian Package',
          desc: `Download ${linux.filename} to your Downloads folder or fetch it directly via terminal.`,
        },
        {
          title: 'Install via DPKG',
          desc: 'Run the package installer using sudo dpkg in your terminal.',
          command: `sudo dpkg -i ${linux.filename}`,
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
      fileName: ios.filename,
      fileSize: ios.size,
      downloadUrl: ios.downloadUrl,
      sha256: ios.sha256 || 'b7faad7df8dfad86bc778bba9ae3298cb3d2a7c490a6e0df2e5b7b938f29ab0e',
      steps: [
        {
          title: 'Download the IPA Package',
          desc: `Download ${ios.filename}. Compatible with AltStore, SideStore, Sideloadly, and TrollStore on iOS 15.0+.`,
        },
        {
          title: '1-Click Install with AltStore (Optional)',
          desc: 'If AltStore is installed on your device, tap the deep-link below to start direct installation.',
          command: `altstore://install?url=${encodeURIComponent(ios.downloadUrl)}`,
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
}

export function InstallGuide() {
  const [selectedPlatform, setSelectedPlatform] =
    useState<PlatformType>('windows');
  const [userPlatform, setUserPlatform] =
    useState<PlatformType>('windows');
  const [copiedText, setCopiedText] = useState<string | null>(null);

  const { release } = useRelease();
  const guides = useMemo(() => buildGuides(release), [release]);

  useEffect(() => {
    const detected = detectUserPlatform();
    setUserPlatform(detected);
    setSelectedPlatform(detected);
  }, []);

  const guide = guides[selectedPlatform];

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
        <div className={styles.tabsWrapper}>
          {(['windows', 'android', 'linux', 'ios'] as PlatformType[]).map(
            (platformId) => {
              const p = guides[platformId];
              const isSelected = selectedPlatform === platformId;
              const isRecommended = userPlatform === platformId;

              return (
                <button
                  key={platformId}
                  className={`${styles.tabBtn} ${
                    isSelected ? styles.tabBtnActive : ''
                  }`}
                  onClick={() => setSelectedPlatform(platformId)}
                  type="button"
                >
                  {getPlatformIcon(platformId)}
                  <div className={styles.tabText}>
                    <span className={styles.tabName}>{p.name}</span>
                    {isRecommended && (
                      <span className={styles.recBadge}>Detected OS</span>
                    )}
                  </div>
                </button>
              );
            }
          )}
        </div>

        {/* Guide Content Card */}
        <div className={styles.guideCard}>
          {/* Card Top / Download Banner */}
          <div className={styles.cardHeader}>
            <div className={styles.fileMeta}>
              <span className={styles.osBadge}>{guide.badge}</span>
              <h3 className={styles.fileName}>{guide.fileName}</h3>
              <span className={styles.fileDetails}>
                {guide.fileSize} &bull; Release: {release.tag}
              </span>
            </div>

            <div className={styles.headerActions}>
              <a
                href={guide.downloadUrl}
                className={styles.downloadBtn}
                download
              >
                <Download size={18} />
                <span>Download {guide.name} Release</span>
              </a>
            </div>
          </div>

          {/* SHA-256 Box */}
          <div className={styles.shaBox}>
            <div className={styles.shaHeader}>
              <div className={styles.shaTitle}>
                <ShieldCheck size={16} />
                <span>Cryptographic SHA-256 Checksum</span>
              </div>
              <button
                className={styles.copyBtn}
                onClick={() => handleCopy(guide.sha256)}
                type="button"
              >
                {copiedText === guide.sha256 ? (
                  <>
                    <Check size={14} />
                    <span>Copied</span>
                  </>
                ) : (
                  <>
                    <Copy size={14} />
                    <span>Copy Hash</span>
                  </>
                )}
              </button>
            </div>
            <code className={styles.shaCode}>{guide.sha256}</code>
          </div>

          {/* Steps List */}
          <div className={styles.stepsList}>
            {guide.steps.map((step, index) => (
              <div key={index} className={styles.stepItem}>
                <div className={styles.stepNumber}>{index + 1}</div>
                <div className={styles.stepBody}>
                  <h4 className={styles.stepTitle}>{step.title}</h4>
                  <p className={styles.stepDesc}>{step.desc}</p>

                  {step.callout && (
                    <div className={styles.callout}>
                      <span className={styles.calloutLabel}>Note:</span>{' '}
                      {step.callout}
                    </div>
                  )}

                  {step.command && (
                    <div className={styles.commandBox}>
                      <code className={styles.commandCode}>{step.command}</code>
                      <button
                        className={styles.copyBtn}
                        onClick={() => handleCopy(step.command!)}
                        type="button"
                      >
                        {copiedText === step.command ? (
                          <>
                            <Check size={14} />
                            <span>Copied</span>
                          </>
                        ) : (
                          <>
                            <Copy size={14} />
                            <span>Copy</span>
                          </>
                        )}
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>

          {/* iOS AltStore Direct install helper */}
          {guide.id === 'ios' && (
            <div className={styles.iosAltstoreCallout}>
              <p>
                Have AltStore installed on your iPhone? Tap below to invoke
                the direct in-app install protocol:
              </p>
              <a
                href={guide.steps[1].command}
                className={styles.altstoreBtn}
              >
                <span>Open in AltStore</span>
                <ExternalLink size={14} />
              </a>
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
