import { Send, ExternalLink, ShieldCheck } from 'lucide-react';
import styles from './PrivacyAudit.module.css';

export function PrivacyAudit() {
  return (
    <section id="privacy" className={styles.section}>
      <div className="section-header">
        <span className="section-tag">UNCOMPROMISING DATA SOVEREIGNTY</span>
        <h2 className="section-title">Why Noctra is Architecturally Private</h2>
        <p className="section-subtitle">
          Commercial music platforms collect millions of telemetry metrics every day. Noctra collects exactly zero bytes.
        </p>
      </div>

      <div className={styles.tableContainer}>
        <div className={`${styles.row} ${styles.headerRow}`}>
          <div>Privacy Dimension</div>
          <div>Commercial Music Apps</div>
          <div className={styles.safe}>Noctra Sovereign Model</div>
        </div>
        <div className={styles.row}>
          <div>Account & Identity Tracking</div>
          <div className={styles.danger}>Mandatory Email, Phone & Google Sign-In</div>
          <div className={styles.safe}>
            <ShieldCheck size={16} /> 0 Accounts &bull; 100% Instant Play
          </div>
        </div>
        <div className={styles.row}>
          <div>Background Telemetry & Ad Logs</div>
          <div className={styles.danger}>Diagnostic Trackers, Device Fingerprinting</div>
          <div className={styles.safe}>
            <ShieldCheck size={16} /> 0% Remote Telemetry &bull; Strict Sandbox
          </div>
        </div>
        <div className={styles.row}>
          <div>Taste & Listening Vectors</div>
          <div className={styles.danger}>Monetized for Cloud Ad Targeting</div>
          <div className={styles.safe}>
            <ShieldCheck size={16} /> On-Device Encrypted SQLite Vault
          </div>
        </div>
        <div className={styles.row}>
          <div>Playlist & Library Portability</div>
          <div className={styles.danger}>Locked Behind Proprietary Walls</div>
          <div className={styles.safe}>
            <ShieldCheck size={16} /> Open JSON (.noctra.json) & Universal CSV
          </div>
        </div>
      </div>

      {/* Official Telegram Channel Banner Card */}
      <div className={styles.communityCard}>
        <div className={styles.communityContent}>
          <div className={styles.tgIconBox}>
            <Send size={28} />
          </div>
          <div>
            <span className={styles.communityPill}>OFFICIAL TELEGRAM COMMUNITY</span>
            <h3 className={styles.communityTitle}>Join the Noctra Channel on Telegram</h3>
            <p className={styles.communityDesc}>
              Get real-time release announcements, early test builds, discuss audiophile IEM target curves, and connect with fellow music sovereignty enthusiasts.
            </p>
          </div>
        </div>

        <a
          href="https://t.me/Noctra_app"
          target="_blank"
          rel="noopener noreferrer"
          className={styles.tgJoinBtn}
        >
          <Send size={16} />
          <span>Join @Noctra_app</span>
          <ExternalLink size={14} />
        </a>
      </div>
    </section>
  );
}
