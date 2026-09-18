import { Layers, Cpu, GitFork, CheckCircle2, Lock } from 'lucide-react';
import styles from './ArchitecturePage.module.css';

export function ArchitecturePage() {
  return (
    <div className={styles.container}>
      <header className={styles.header}>
        <span className={styles.tag}>TECHNICAL ARCHITECTURE</span>
        <h1 className={styles.title}>System Design & Layering</h1>
        <p className={styles.subtitle}>
          Noctra is engineered with strict unidirectional dependency boundaries, zero circular dependencies, on-device DSP isolates, and zero cloud tracking.
        </p>
      </header>

      {/* Layer Topology */}
      <section className={styles.cardSection}>
        <div className={styles.cardHeader}>
          <Layers size={22} className={styles.iconAccent} />
          <div>
            <h2>Unidirectional Layer Topology</h2>
            <p>Mechanically enforced by automated architecture boundary tests.</p>
          </div>
        </div>

        <div className={styles.codeDiagram}>
          <pre>{`core   ←   data   ←   services   ←   providers   ←   ui
  └────────────────────────── shared (importable anywhere)`}</pre>
        </div>

        <div className={styles.rulesGrid}>
          <div className={styles.ruleBox}>
            <span className={styles.ruleBadge}>RULE 1</span>
            <h4>Zero Cycles</h4>
            <p>No circular dependencies exist between any files in the codebase, preventing memory leaks and initialization deadlocks.</p>
          </div>
          <div className={styles.ruleBox}>
            <span className={styles.ruleBadge}>RULE 2</span>
            <h4>Unidirectional Flow</h4>
            <p>Core imports nothing internal. Services never import UI. UI reaches persistence exclusively via the provider layer.</p>
          </div>
        </div>
      </section>

      {/* 24-Bit Upscaler DSP Pipeline */}
      <section className={styles.cardSection}>
        <div className={styles.cardHeader}>
          <Cpu size={22} className={styles.iconAccent} />
          <div>
            <h2>On-Device 24-Bit Upscaler Pipeline</h2>
            <p>Harmonic reconstruction and dynamic high-shelf air filter running in a dedicated background isolate.</p>
          </div>
        </div>

        <div className={styles.flowDiagram}>
          <div className={styles.flowStep}>
            <span className={styles.stepNum}>01</span>
            <h4>Lossy Stream</h4>
            <p>Cached MP3 or AAC source</p>
          </div>
          <div className={styles.flowArrow}>→</div>
          <div className={styles.flowStep}>
            <span className={styles.stepNum}>02</span>
            <h4>Native Decode</h4>
            <p>Linear 24-bit PCM buffer</p>
          </div>
          <div className={styles.flowArrow}>→</div>
          <div className={styles.flowStep}>
            <span className={styles.stepNum}>03</span>
            <h4>DSP Isolate</h4>
            <p>Quadratic exciter & air filter</p>
          </div>
          <div className={styles.flowArrow}>→</div>
          <div className={styles.flowStep}>
            <span className={styles.stepNum}>04</span>
            <h4>Lossless WAV</h4>
            <p>True 24-bit PCM export</p>
          </div>
        </div>
      </section>

      {/* 6-Tier Composite Stream Resolver */}
      <section className={styles.cardSection}>
        <div className={styles.cardHeader}>
          <GitFork size={22} className={styles.iconAccent} />
          <div>
            <h2>6-Tier Composite Stream Fallback</h2>
            <p>Resilient multi-tier audio resolution with zero user configuration required.</p>
          </div>
        </div>

        <div className={styles.tierList}>
          <div className={styles.tierItem}>
            <span className={styles.tierPill}>Tier 1</span>
            <div className={styles.tierContent}>
              <h4>Cached 24-Bit Upscaled Master</h4>
              <p>Checks local disk for pre-rendered lossless 24-bit WAV file and plays bit-perfect audio immediately.</p>
            </div>
          </div>
          <div className={styles.tierItem}>
            <span className={styles.tierPill}>Tier 2</span>
            <div className={styles.tierContent}>
              <h4>Local Download Vault</h4>
              <p>Resolves downloaded songs from the offline storage vault with zero network usage.</p>
            </div>
          </div>
          <div className={styles.tierItem}>
            <span className={styles.tierPill}>Tier 3</span>
            <div className={styles.tierContent}>
              <h4>JioSaavn 320kbps CD Decryption</h4>
              <p>Directly decrypts high-fidelity 320kbps AAC/MP3 CDN streams with uncompressed album metadata.</p>
            </div>
          </div>
          <div className={styles.tierItem}>
            <span className={styles.tierPill}>Tier 4</span>
            <div className={styles.tierContent}>
              <h4>Native Android Kotlin Extractor</h4>
              <p>Hardware-optimized native audio extraction delegate for maximum throughput on Android.</p>
            </div>
          </div>
          <div className={styles.tierItem}>
            <span className={styles.tierPill}>Tier 5</span>
            <div className={styles.tierContent}>
              <h4>YouTube Music InnerTube REST JSON</h4>
              <p>Direct REST client extracting 160kbps Opus / 256kbps AAC audio streams with single-flight deduplication.</p>
            </div>
          </div>
          <div className={styles.tierItem}>
            <span className={styles.tierPill}>Tier 6</span>
            <div className={styles.tierContent}>
              <h4>Web Search Fallback Resolver</h4>
              <p>Graceful fallback search ensuring obscure or regional tracks resolve cleanly.</p>
            </div>
          </div>
        </div>
      </section>

      {/* Security Architecture */}
      <section id="security" className={styles.cardSection}>
        <div className={styles.cardHeader}>
          <Lock size={22} className={styles.iconAccent} />
          <div>
            <h2>Security & Anti-SSRF Perimeter</h2>
            <p>Military-grade network boundaries protecting local network integrity.</p>
          </div>
        </div>

        <div className={styles.securityGrid}>
          <div className={styles.securityBox}>
            <CheckCircle2 size={18} className={styles.checkIcon} />
            <div>
              <h4>Host Whitelisting</h4>
              <p>Audio playback is restricted exclusively to verified, cryptographic CDN endpoints.</p>
            </div>
          </div>
          <div className={styles.securityBox}>
            <CheckCircle2 size={18} className={styles.checkIcon} />
            <div>
              <h4>Anti-SSRF Protection</h4>
              <p>All private subnets (10.x, 192.168.x, 172.16.x), localhost (127.0.0.1), and link-local addresses are rejected.</p>
            </div>
          </div>
          <div className={styles.securityBox}>
            <CheckCircle2 size={18} className={styles.checkIcon} />
            <div>
              <h4>Hop-by-Hop Redirect Validation</h4>
              <p>Every HTTP redirect is inspected independently before following, preventing redirect poisoning.</p>
            </div>
          </div>
          <div className={styles.securityBox}>
            <CheckCircle2 size={18} className={styles.checkIcon} />
            <div>
              <h4>Zero Telemetry</h4>
              <p>No analytics SDKs, crash beacons, or user tracking tokens are linked into the release binary.</p>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
