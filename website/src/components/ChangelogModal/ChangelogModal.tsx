import { useEffect } from 'react';
import { X, ExternalLink, Sparkles, CheckCircle2, RefreshCw, Calendar, Tag, ShieldCheck } from 'lucide-react';
import { useRelease } from '../../context/ReleaseContext';
import styles from './ChangelogModal.module.css';

export function ChangelogModal() {
  const { release, isChangelogOpen, closeChangelog, refreshRelease } = useRelease();

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isChangelogOpen) {
        closeChangelog();
      }
    };
    if (isChangelogOpen) {
      document.body.style.overflow = 'hidden';
      window.addEventListener('keydown', handleKeyDown);
    } else {
      document.body.style.overflow = '';
    }
    return () => {
      document.body.style.overflow = '';
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [isChangelogOpen, closeChangelog]);

  if (!isChangelogOpen) return null;

  return (
    <div className={styles.overlay} onClick={closeChangelog}>
      <div className={styles.modal} onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className={styles.header}>
          <div className={styles.headerLeft}>
            <div className={styles.iconWrap}>
              <Sparkles size={20} />
            </div>
            <div>
              <div className={styles.tagRow}>
                <span className={styles.versionPill}>{release.tag}</span>
                {release.isLive && (
                  <span className={styles.liveBadge}>
                    <span className={styles.pulseDot} />
                    LIVE RELEASE
                  </span>
                )}
              </div>
              <h2 className={styles.title}>{release.name}</h2>
            </div>
          </div>

          <div className={styles.headerRight}>
            <button
              type="button"
              className={styles.refreshBtn}
              onClick={() => refreshRelease()}
              title="Check for newest updates"
            >
              <RefreshCw size={15} />
            </button>
            <button
              type="button"
              className={styles.closeBtn}
              onClick={closeChangelog}
              aria-label="Close modal"
            >
              <X size={18} />
            </button>
          </div>
        </div>

        {/* Meta Bar */}
        <div className={styles.metaBar}>
          <div className={styles.metaItem}>
            <Calendar size={14} />
            <span>Published: {release.publishedAt} ({release.publishedTimeAgo})</span>
          </div>
          <div className={styles.metaItem}>
            <Tag size={14} />
            <span>Version: {release.version}</span>
          </div>
          <div className={styles.metaItem}>
            <ShieldCheck size={14} />
            <span>Cryptographic SHA256 Verified</span>
          </div>
        </div>

        {/* Content Body */}
        <div className={styles.body}>
          {release.body ? (
            <div className={styles.markdownContent}>
              {release.body.split('\n\n').map((block: string, idx: number) => {
                const trimmed = block.trim();
                if (trimmed.startsWith('### ')) {
                  return (
                    <h3 key={idx} className={styles.sectionHeading}>
                      {trimmed.replace('### ', '')}
                    </h3>
                  );
                }
                if (trimmed.startsWith('## ')) {
                  return (
                    <h2 key={idx} className={styles.mainHeading}>
                      {trimmed.replace('## ', '')}
                    </h2>
                  );
                }
                if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
                  const items = trimmed.split('\n').filter((l: string) => l.trim().length > 0);
                  return (
                    <ul key={idx} className={styles.featureList}>
                      {items.map((item: string, itemIdx: number) => (
                        <li key={itemIdx} className={styles.featureItem}>
                          <CheckCircle2 size={15} className={styles.checkIcon} />
                          <span>{item.replace(/^[-*]\s+/, '').replace(/\*\*(.*?)\*\*/g, '$1')}</span>
                        </li>
                      ))}
                    </ul>
                  );
                }
                if (/^\d+\.\s+/.test(trimmed)) {
                  const items = trimmed.split('\n').filter((l: string) => l.trim().length > 0);
                  return (
                    <ol key={idx} className={styles.orderedList}>
                      {items.map((item: string, itemIdx: number) => (
                        <li key={itemIdx} className={styles.orderedItem}>
                          <span>{item.replace(/^\d+\.\s+/, '').replace(/\*\*(.*?)\*\*/g, '$1')}</span>
                        </li>
                      ))}
                    </ol>
                  );
                }
                return (
                  <p key={idx} className={styles.paragraph}>
                    {trimmed.replace(/\*\*(.*?)\*\*/g, '$1')}
                  </p>
                );
              })}
            </div>
          ) : (
            <div className={styles.emptyContent}>
              <p>Fetching full release notes from GitHub repository...</p>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className={styles.footer}>
          <a
            href={release.releaseUrl}
            target="_blank"
            rel="noopener noreferrer"
            className={styles.gitHubBtn}
          >
            <span>View Release on GitHub</span>
            <ExternalLink size={14} />
          </a>
          <button
            type="button"
            className={styles.dismissBtn}
            onClick={closeChangelog}
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
}
