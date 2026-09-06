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
