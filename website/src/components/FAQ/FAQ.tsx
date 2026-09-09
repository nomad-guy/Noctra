import { useRelease } from '../../context/ReleaseContext';
import styles from './FAQ.module.css';

export function FAQ() {
  const { release, openChangelog } = useRelease();

  const faqJsonLd = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: [
      {
        '@type': 'Question',
        name: `What is new in Noctra ${release.tag}?`,
        acceptedAnswer: {
          '@type': 'Answer',
          text: 'On-device stem separation with real-time multi-band DSP isolation, AI Radio repeat prevention with a 60-track sliding LRU window, on-device neural recommendation optimizations, sleep timer End of Track mode, in-playlist search and multi-criteria sorting, full artist discography sections, and complete song credits with liner notes.',
        },
      },
      {
        '@type': 'Question',
        name: 'Do I need an account or subscription to use Noctra?',
        acceptedAnswer: {
          '@type': 'Answer',
          text: 'No. Noctra is completely authentication-less. All playlists, favorites, and listening records are saved on your local device in an encrypted SQLite database.',
        },
      },
      {
        '@type': 'Question',
        name: 'Is the audio stream bit-perfect lossless?',
        acceptedAnswer: {
          '@type': 'Answer',
          text: 'Yes. Noctra resolves pure FLAC bitstreams up to 24-bit / 192 kHz from uncompressed streaming repositories. Live codec, sample rate, and bit depth are displayed in the player.',
        },
      },
      {
        '@type': 'Question',
        name: 'How do I install Noctra on iOS?',
        acceptedAnswer: {
          '@type': 'Answer',
          text: 'Download the IPA from the downloads section, then install it with AltStore, SideStore, Sideloadly, or TrollStore. No jailbreak required.',
        },
      },
      {
        '@type': 'Question',
        name: 'How do bilingual synchronized lyrics work?',
        acceptedAnswer: {
          '@type': 'Answer',
          text: 'Where synchronized dual-language transcripts exist, Noctra consolidates identical timestamps (150ms or less) so the translated line displays as a subtle italic subtitle beneath the active vocal line.',
        },
      },
    ],
  };

  return (
    <section id="faq" className={styles.section}>
      <div className="section-header">
        <span className="section-tag">FREQUENTLY ASKED QUESTIONS</span>
        <h2 className="section-title">Answers to Common Inquiries</h2>
      </div>

      <div className={styles.accordion}>
        <details className={styles.item} open>
          <summary className={styles.question}>
            <span>What is new in Noctra {release.tag}?</span>
            <span className={styles.arrow}>+</span>
          </summary>
          <div className={styles.answer}>
            <p>
              {release.tag} introduces on-device stem separation with real-time multi-band DSP isolation (vocals, drums, bass, instruments), intelligent AI Radio repeat prevention with a 60-track sliding LRU window, on-device neural recommendation optimizations, sleep timer &quot;End of Track&quot; mode, in-playlist search and multi-criteria sorting, full artist discography sections (Singles, EPs, Albums), and complete song credits with liner notes.
            </p>
            <div style={{ marginTop: '0.85rem' }}>
              <button
                type="button"
                onClick={openChangelog}
                className="btn btn-glass btn-sm"
                style={{ cursor: 'pointer' }}
              >
                Inspect Live Changelog &rarr;
              </button>
            </div>
          </div>
        </details>

        <details className={styles.item}>
          <summary className={styles.question}>
            <span>Do I need an account or subscription to use Noctra?</span>
            <span className={styles.arrow}>+</span>
          </summary>
          <div className={styles.answer}>
            <p>
              No. Noctra is completely authentication-less. You do not need an email, phone number, or password. All playlists, favorites, and listening records are saved on your local device in an encrypted SQLite database.
            </p>
          </div>
        </details>

        <details className={styles.item}>
          <summary className={styles.question}>
            <span>Is the audio stream bit-perfect lossless?</span>
            <span className={styles.arrow}>+</span>
          </summary>
          <div className={styles.answer}>
            <p>
              Yes. Noctra resolves pure FLAC bitstreams up to 24-bit / 192 kHz from uncompressed streaming repositories. Real-time audio telemetry in the player displays live codec, sample rate, and bit depth.
            </p>
          </div>
        </details>

        <details className={styles.item}>
          <summary className={styles.question}>
            <span>How do I install Noctra on iOS?</span>
            <span className={styles.arrow}>+</span>
          </summary>
          <div className={styles.answer}>
            <p>
              Download <code>{release.binaries.ios.filename}</code> from the downloads section. Open AltStore, SideStore, Sideloadly, or TrollStore, select the IPA, and install it to your iPhone or iPad with zero jailbreaking required.
            </p>
          </div>
        </details>

        <details className={styles.item}>
          <summary className={styles.question}>
            <span>How do bilingual synchronized lyrics work?</span>
            <span className={styles.arrow}>+</span>
          </summary>
          <div className={styles.answer}>
            <p>
              In songs where synchronized dual-language transcripts are present (e.g. Hindi in Romanized English alongside an English translation), Noctra consolidates identical timestamps (&le; 150ms) so the translated line displays as a subtle italic subtitle beneath the active vocal line.
            </p>
          </div>
        </details>
      </div>

      {/* FAQ structured data for search-engine rich results */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd) }}
      />
    </section>
  );
}
