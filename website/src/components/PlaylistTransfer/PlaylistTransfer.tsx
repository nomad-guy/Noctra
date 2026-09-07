import { useState } from 'react';
import { Music, FileJson, FileSpreadsheet, Copy, Check, Shuffle, Sparkles } from 'lucide-react';
import styles from './PlaylistTransfer.module.css';

const SAMPLE_MANIFEST_JSON = `{
  "format": "noctra_playlist_v1",
  "version": "1.0.6",
  "exportedAt": "2026-09-06T21:30:00Z",
  "playlist": {
    "name": "Midnight Audiophile Studio",
    "trackCount": 3,
    "songs": [
      {
        "title": "Tum Se Hi",
        "artist": "Mohit Chauhan, Pritam",
        "durationMs": 321000,
        "format": "FLAC 24-bit/192kHz",
        "artwork": "https://images.noctra.app/covers/rockstar.jpg"
      },
      {
        "title": "Midnight City",
        "artist": "M83",
        "durationMs": 243000,
        "format": "FLAC 16-bit/44.1kHz",
        "artwork": "https://images.noctra.app/covers/m83.jpg"
      },
      {
        "title": "Starboy",
        "artist": "The Weeknd, Daft Punk",
        "durationMs": 230000,
        "format": "Opus 48kHz Master",
        "artwork": "https://images.noctra.app/covers/starboy.jpg"
      }
    ]
  }
}`;

const SAMPLE_CSV = `Title,Artist,Duration (sec),Format,Tags
"Tum Se Hi","Mohit Chauhan, Pritam",321,"FLAC 24/192","Audiophile, Acoustic"
"Midnight City","M83",243,"FLAC 16/44.1","Synthwave, Electronic"
"Starboy","The Weeknd, Daft Punk",230,"Opus 48k","Pop, R&B"`;

export function PlaylistTransfer() {
  const [tab, setTab] = useState<'preview' | 'json' | 'csv'>('preview');
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  const handleCopy = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  return (
    <section id="transfer" className={styles.section}>
      <div className="section-header">
        <span className="section-tag">NEW IN V1.0.6</span>
        <h2 className="section-title">Universal Playlist Transfer & Algorithmic Remix</h2>
        <p className="section-subtitle">
          Export and transfer playlists across devices via lossless JSON manifest (<code>.noctra.json</code>) or spreadsheet CSV (<code>.csv</code>). 100% on-device with zero account lock-in.
        </p>
      </div>

      <div className={styles.transferCard}>
        <div className={styles.headerRow}>
          <div className={styles.tabs}>
            <button
              type="button"
              className={`${styles.tabBtn} ${tab === 'preview' ? styles.tabBtnActive : ''}`}
              onClick={() => setTab('preview')}
            >
              <Music size={16} />
              <span>Visual Playlist</span>
            </button>
            <button
              type="button"
              className={`${styles.tabBtn} ${tab === 'json' ? styles.tabBtnActive : ''}`}
              onClick={() => setTab('json')}
            >
              <FileJson size={16} />
              <span>JSON Manifest (.noctra.json)</span>
            </button>
            <button
              type="button"
              className={`${styles.tabBtn} ${tab === 'csv' ? styles.tabBtnActive : ''}`}
              onClick={() => setTab('csv')}
            >
              <FileSpreadsheet size={16} />
              <span>Universal CSV (.csv)</span>
            </button>
          </div>

          <div>
            {tab === 'json' && (
              <button
                type="button"
                className="btn btn-glass btn-sm"
                onClick={() => handleCopy(SAMPLE_MANIFEST_JSON, 'json')}
              >
                {copiedKey === 'json' ? <Check size={14} /> : <Copy size={14} />}
                <span>{copiedKey === 'json' ? 'Copied Manifest!' : 'Copy JSON'}</span>
              </button>
            )}
            {tab === 'csv' && (
              <button
                type="button"
                className="btn btn-glass btn-sm"
                onClick={() => handleCopy(SAMPLE_CSV, 'csv')}
              >
                {copiedKey === 'csv' ? <Check size={14} /> : <Copy size={14} />}
                <span>{copiedKey === 'csv' ? 'Copied CSV!' : 'Copy CSV'}</span>
              </button>
            )}
          </div>
        </div>

        {tab === 'preview' && (
          <div className={styles.previewGrid}>
            <div className={styles.metaPanel}>
              <div className={styles.artBadge}>
                <Sparkles size={28} />
              </div>
              <h4 className={styles.panelTitle}>Midnight Audiophile Studio</h4>
              <span className={styles.panelTag}>v1.0.6 SQLite Folder</span>
              <p className={styles.panelDesc}>
                Preserves track order, high-res cover art links, and sample rate telemetry.
              </p>
              <div className={styles.btnGroup}>
                <button
                  type="button"
                  className="btn btn-primary btn-sm"
                  onClick={() => alert('Simulated 1-tap Shuffle activated!')}
                >
                  <Shuffle size={14} />
                  <span>1-Tap Shuffle</span>
                </button>
                <button
                  type="button"
                  className="btn btn-glass btn-sm"
                  onClick={() => alert('Simulated Algorithmic Remix Reorder!')}
                >
                  <Sparkles size={14} />
                  <span>Remix Reorder</span>
                </button>
              </div>
            </div>

            <div className={styles.trackList}>
              <div className={styles.trackItem}>
                <span className={styles.trackNum}>01</span>
                <div className={styles.trackDetails}>
                  <span className={styles.trackName}>Tum Se Hi</span>
                  <span className={styles.trackSub}>Mohit Chauhan &bull; Pritam</span>
                </div>
                <span className={styles.trackTag}>24/192 FLAC</span>
              </div>
              <div className={styles.trackItem}>
                <span className={styles.trackNum}>02</span>
                <div className={styles.trackDetails}>
                  <span className={styles.trackName}>Midnight City</span>
                  <span className={styles.trackSub}>M83</span>
                </div>
                <span className={styles.trackTag}>16/44.1 FLAC</span>
              </div>
              <div className={styles.trackItem}>
                <span className={styles.trackNum}>03</span>
                <div className={styles.trackDetails}>
                  <span className={styles.trackName}>Starboy</span>
                  <span className={styles.trackSub}>The Weeknd &bull; Daft Punk</span>
                </div>
                <span className={styles.trackTag}>Opus 320k</span>
              </div>
            </div>
          </div>
        )}

        {tab === 'json' && (
          <pre className={styles.codeBlock}>
            <code>{SAMPLE_MANIFEST_JSON}</code>
          </pre>
        )}

        {tab === 'csv' && (
          <pre className={styles.codeBlock}>
            <code>{SAMPLE_CSV}</code>
          </pre>
        )}
      </div>
    </section>
  );
}
