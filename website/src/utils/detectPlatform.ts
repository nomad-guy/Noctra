import type { PlatformType } from '../types';

export function detectUserPlatform(): PlatformType {
  if (typeof window === 'undefined' || !navigator) return 'windows';

  const userAgent = navigator.userAgent || '';
  const platform =
    (navigator as unknown as { userAgentData?: { platform?: string } })
      .userAgentData?.platform ||
    navigator.platform ||
    '';

  if (/android/i.test(userAgent)) {
    return 'android';
  }

  if (
    /iPhone|iPad|iPod/i.test(userAgent) ||
    (/Macintosh/i.test(userAgent) && navigator.maxTouchPoints > 1)
  ) {
    return 'ios';
  }

  if (/Win/i.test(platform) || /windows/i.test(userAgent)) {
    return 'windows';
  }

  if (/Linux/i.test(platform) || /linux/i.test(userAgent)) {
    return 'linux';
  }

  return 'windows';
}
