export type ThemeType = 'liquid-glass' | 'noir-black' | 'noir-white';
export type PlatformType = 'windows' | 'linux' | 'android' | 'ios';

export interface ThemeConfig {
  id: ThemeType;
  name: string;
  brandLogo: string;
  themeToggleIcon: string;
  fontBadge: string;
  nextTheme: ThemeType;
  nextThemeName: string;
}

export interface ShowcaseItem {
  id: string;
  title: string;
  desc: string;
  icon: string;
  screenshot: string;
  captionTitle: string;
  captionDesc: string;
  badges: string[];
}

export interface ReleaseBinary {
  platform: PlatformType;
  name: string;
  filename: string;
  size: string;
  sha256: string;
  downloadUrl: string;
  arch: string;
  primary: boolean;
  notes: string;
}

export interface ReleaseBinaryItem {
  name: string;
  badge: string;
  filename: string;
  downloadUrl: string;
  size: string;
  arch: string;
  command: string;
  commandLabel?: string;
  desc?: string;
  sha256?: string;
}

export interface ReleaseData {
  tag: string;
  version: string;
  name: string;
  publishedAt: string;
  publishedTimeAgo: string;
  releaseUrl: string;
  body: string;
  isLive: boolean;
  isLoading: boolean;
  totalDownloads: number;
  binaries: {
    windows: ReleaseBinaryItem;
    linux: ReleaseBinaryItem;
    android: ReleaseBinaryItem & {
      universalUrl: string;
      armeabiUrl: string;
      x86_64Url: string;
      aabUrl: string;
    };
    ios: ReleaseBinaryItem & {
      altstoreUrl: string;
    };
    sha256sumsUrl: string;
  };
}

