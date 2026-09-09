import React, { createContext, useState, useEffect, useCallback, useMemo } from 'react';
import type { ReleaseData, ReleaseBinaryItem } from '../types';
export { useRelease } from '../hooks/useRelease';

export interface ReleaseContextValue {
  release: ReleaseData;
  isChangelogOpen: boolean;
  openChangelog: () => void;
  closeChangelog: () => void;
  refreshRelease: () => Promise<void>;
}

const CACHE_KEY = 'noctra_release_cache_v2';
const CACHE_TTL_MS = 15 * 60 * 1000; // 15 minutes

function formatBytes(bytes: number): string {
  if (!bytes || isNaN(bytes) || bytes <= 0) return '';
  const mb = bytes / (1024 * 1024);
  return `${mb.toFixed(1)} MB`;
}

function formatDate(isoString: string): string {
  if (!isoString) return 'Recent Release';
  try {
    const d = new Date(isoString);
    return d.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  } catch {
    return 'Recent Release';
  }
}

function getTimeAgo(isoString: string): string {
  if (!isoString) return 'recently';
  try {
    const msDiff = Date.now() - new Date(isoString).getTime();
    const hours = Math.floor(msDiff / (1000 * 60 * 60));
    if (hours < 1) return 'just now';
    if (hours < 24) return `${hours}h ago`;
    const days = Math.floor(hours / 24);
    if (days === 1) return 'yesterday';
    if (days < 30) return `${days}d ago`;
    return formatDate(isoString);
  } catch {
    return 'recently';
  }
}

function buildReleaseData(tag: string, rawData?: any, isLive = false): ReleaseData {
  const cleanVersion = tag.replace(/^v/i, '');
  const publishedAt = rawData?.published_at ? formatDate(rawData.published_at) : 'Sep 7, 2026';
  const publishedTimeAgo = rawData?.published_at ? getTimeAgo(rawData.published_at) : 'recently';
  const releaseName = rawData?.name || `Noctra v${cleanVersion}`;
  const releaseUrl = rawData?.html_url || `https://github.com/nomad-guy/Noctra/releases/tag/${tag}`;
  const body = rawData?.body || '';

  const assets: any[] = Array.isArray(rawData?.assets) ? rawData.assets : [];
  let totalDownloads = 0;
  for (const a of assets) {
    if (typeof a.download_count === 'number') {
      totalDownloads += a.download_count;
    }
  }

  // Find asset matching helper
  const findAsset = (pattern: RegExp) => assets.find((a: any) => pattern.test(a.name));

  const winAsset = findAsset(/setup.*\.exe$/i) || findAsset(/\.exe$/i);
  const debAsset = findAsset(/\.deb$/i);
  const apkArm64Asset = findAsset(/arm64.*\.apk$/i);
  const apkUniversalAsset = findAsset(/universal.*\.apk$/i);
  const apkArmeabiAsset = findAsset(/armeabi.*\.apk$/i);
  const apkX86Asset = findAsset(/x86_64.*\.apk$/i);
  const aabAsset = findAsset(/\.aab$/i);
  const ipaAsset = findAsset(/\.ipa$/i);

  const baseReleaseUrl = `https://github.com/nomad-guy/Noctra/releases/download/${tag}`;

  const windows: ReleaseBinaryItem = {
    name: 'Windows 10 / 11 (64-bit)',
    badge: 'Inno Setup Standalone',
    filename: winAsset ? winAsset.name : `Noctra-${cleanVersion}-Setup-x64.exe`,
    downloadUrl: winAsset ? winAsset.browser_download_url : `${baseReleaseUrl}/Noctra-${cleanVersion}-Setup-x64.exe`,
    size: winAsset ? formatBytes(winAsset.size) : '24.5 MB',
    arch: 'x86_64',
    command: `Start-Process .\\Noctra-${cleanVersion}-Setup-x64.exe -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES" -Wait`,
    commandLabel: 'Silent Inno Setup Installation (PowerShell)',
    desc: 'Bundles JustAudio C++ bitstream driver, taskbar audio preview, media keys, and lossless audio pipeline.',
    sha256: '9587f5f5e37b2587f43e9f55fa92f06068154cb9f905d3beb2edb1ca626b0577',
  };

  const linux: ReleaseBinaryItem = {
    name: 'Linux (Debian / Ubuntu / Mint / Arch)',
    badge: 'Native .deb Package',
    filename: debAsset ? debAsset.name : `noctra_${cleanVersion}_amd64.deb`,
    downloadUrl: debAsset ? debAsset.browser_download_url : `${baseReleaseUrl}/noctra_${cleanVersion}_amd64.deb`,
    size: debAsset ? formatBytes(debAsset.size) : '18.2 MB',
    arch: 'amd64 / x86_64',
    command: `sudo dpkg -i noctra_${cleanVersion}_amd64.deb && sudo apt-get install -f`,
    commandLabel: 'Terminal dpkg Installation',
    desc: 'Seamless pipewire/pulseaudio ALSA bitstream passthrough with desktop icons and native MPRIS controls.',
    sha256: 'e4c4a285325374a58cba0b8fb9d0913e82086ab09fe02f24110748565e2c7284',
  };

  const androidArm64Url = apkArm64Asset
    ? apkArm64Asset.browser_download_url
    : `${baseReleaseUrl}/Noctra-${cleanVersion}-arm64-v8a.apk`;
  const androidUniversalUrl = apkUniversalAsset
    ? apkUniversalAsset.browser_download_url
    : `${baseReleaseUrl}/Noctra-${cleanVersion}-Universal.apk`;
  const androidArmeabiUrl = apkArmeabiAsset
    ? apkArmeabiAsset.browser_download_url
    : `${baseReleaseUrl}/Noctra-${cleanVersion}-armeabi-v7a.apk`;
  const androidX86Url = apkX86Asset
    ? apkX86Asset.browser_download_url
    : `${baseReleaseUrl}/Noctra-${cleanVersion}-x86_64.apk`;
  const androidAabUrl = aabAsset
    ? aabAsset.browser_download_url
    : `${baseReleaseUrl}/Noctra-${cleanVersion}.aab`;

  const android = {
    name: 'Android 8.0+ (ARM64 & Universal)',
    badge: 'Official Keystore Signed',
    filename: apkArm64Asset ? apkArm64Asset.name : `Noctra-${cleanVersion}-arm64-v8a.apk`,
    downloadUrl: androidArm64Url,
    size: apkArm64Asset ? formatBytes(apkArm64Asset.size) : '22.9 MB',
    arch: 'arm64-v8a',
    command: `adb install -r Noctra-${cleanVersion}-arm64-v8a.apk`,
    commandLabel: 'ADB Sideload Command',
    desc: 'Hardware DAC bit-perfect output, in-app updates, notification bar controller, lockscreen artwork, and offline database.',
    sha256: 'dcadce6ca90e6301b77061c36a4fd8b671a89cd124d3cd7b19187a16890df171',
    universalUrl: androidUniversalUrl,
    armeabiUrl: androidArmeabiUrl,
    x86_64Url: androidX86Url,
    aabUrl: androidAabUrl,
  };

  const iosDownloadUrl = ipaAsset
    ? ipaAsset.browser_download_url
    : `${baseReleaseUrl}/Noctra-${cleanVersion}.ipa`;

  const ios = {
    name: 'Apple iOS 14.0+ (iPhone & iPad)',
    badge: 'Sideloadable IPA Bundle',
    filename: ipaAsset ? ipaAsset.name : `Noctra-${cleanVersion}.ipa`,
    downloadUrl: iosDownloadUrl,
    size: ipaAsset ? formatBytes(ipaAsset.size) : '19.8 MB',
    arch: 'arm64',
    command: `altstore://install?url=${encodeURIComponent(iosDownloadUrl)}`,
    commandLabel: 'AltStore Sideload URL',
    desc: 'Self-hosted and sideloadable with AltStore, SideStore, Sideloadly, or TrollStore. Zero jailbreak required.',
    sha256: '2138122f3f52a5e8ac62964509319f5aa44077add32c33d8c9f701ed3d9e269d',
    altstoreUrl: `altstore://install?url=${encodeURIComponent(iosDownloadUrl)}`,
  };

  const sha256sumsUrl = `${baseReleaseUrl}/SHA256SUMS.txt`;

  return {
    tag,
    version: cleanVersion,
    name: releaseName,
    publishedAt,
    publishedTimeAgo,
    releaseUrl,
    body,
    isLive,
    isLoading: false,
    totalDownloads,
    binaries: {
      windows,
      linux,
      android,
      ios,
      sha256sumsUrl,
    },
  };
}

const FALLBACK_RELEASE = buildReleaseData('v1.0.7', {
  name: 'Noctra v1.0.7',
  published_at: '2026-09-09T12:00:00Z',
  body: `### Android Predictive Back & System Navigation Architecture
- Fixed touch freeze and animation desynchronization when backing out of artist profiles and playlists with system back gestures.
- RouteAware lifecycle integration with ahead-of-time canPop evaluation.
- Native Android 14+ predictive back slide gestures enabled.

### Seamless 120 FPS UI Transitions & Repaint Boundary Isolation
- Hardware-accelerated Cupertino page transitions on mobile and FadeUpwards on desktop.
- Repaint isolation on IndexedStack, MiniPlayerDock, and heavy sliver sections.
- O(1) set lookup for downloaded track status.

### Player Download Spiral Progress Indicator
- Reactive circular progress indicator during song downloads in the full player sheet.

### Website Theme Port
- Synchronized mobile app top-bar theme icons with the website header navigation.`,
}, false);

export const ReleaseContext = createContext<ReleaseContextValue>({
  release: FALLBACK_RELEASE,
  isChangelogOpen: false,
  openChangelog: () => {},
  closeChangelog: () => {},
  refreshRelease: async () => {},
});

export const ReleaseProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [release, setRelease] = useState<ReleaseData>(() => {
    try {
      const cached = localStorage.getItem(CACHE_KEY);
      if (cached) {
        const { data, timestamp } = JSON.parse(cached);
        if (Date.now() - timestamp < CACHE_TTL_MS && data?.tag_name) {
          return buildReleaseData(data.tag_name, data, true);
        }
      }
    } catch {
      // Ignore cache parse error
    }
    return FALLBACK_RELEASE;
  });

  const [isChangelogOpen, setIsChangelogOpen] = useState(false);

  const fetchRelease = useCallback(async () => {
    try {
      // 1. Fetch latest release from GitHub API
      const res = await fetch('https://api.github.com/repos/nomad-guy/Noctra/releases/latest', {
        headers: { Accept: 'application/vnd.github.v3+json' },
      });

      if (!res.ok) {
        // If /latest fails (e.g. 404 or draft), try list endpoint
        const listRes = await fetch('https://api.github.com/repos/nomad-guy/Noctra/releases?per_page=1', {
          headers: { Accept: 'application/vnd.github.v3+json' },
        });
        if (listRes.ok) {
          const list = await listRes.json();
          if (Array.isArray(list) && list.length > 0 && list[0].tag_name) {
            const rawData = list[0];
            const updated = buildReleaseData(rawData.tag_name, rawData, true);
            setRelease(updated);
            try {
              localStorage.setItem(CACHE_KEY, JSON.stringify({ data: rawData, timestamp: Date.now() }));
            } catch {
              // Ignore storage errors
            }
            return;
          }
        }
        return;
      }

      const rawData = await res.json();
      if (rawData && rawData.tag_name) {
        const updated = buildReleaseData(rawData.tag_name, rawData, true);
        setRelease(updated);
        try {
          localStorage.setItem(CACHE_KEY, JSON.stringify({ data: rawData, timestamp: Date.now() }));
        } catch {
          // Ignore storage errors
        }
      }
    } catch (err) {
      console.warn('Could not fetch latest release from GitHub, using cached/fallback:', err);
    }
  }, []);

  useEffect(() => {
    let active = true;
    const load = async () => {
      if (active) {
        await fetchRelease();
      }
    };
    load();
    return () => {
      active = false;
    };
  }, [fetchRelease]);

  const openChangelog = useCallback(() => setIsChangelogOpen(true), []);
  const closeChangelog = useCallback(() => setIsChangelogOpen(false), []);

  const value = useMemo<ReleaseContextValue>(() => ({
    release,
    isChangelogOpen,
    openChangelog,
    closeChangelog,
    refreshRelease: fetchRelease,
  }), [release, isChangelogOpen, openChangelog, closeChangelog, fetchRelease]);

  return (
    <ReleaseContext.Provider value={value}>
      {children}
    </ReleaseContext.Provider>
  );
};
