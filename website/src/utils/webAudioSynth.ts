// Pure Web Audio API high-fidelity ambient synth engine for Noctra website demo
// Provides real-time playback, chord progression, and audio analyser node for waveforms.

class WebAudioSynthEngine {
  private ctx: AudioContext | null = null;
  private isPlaying = false;
  private intervalId: number | null = null;
  private analyser: AnalyserNode | null = null;
  private masterGain: GainNode | null = null;
  private chordIndex = 0;

  // Soothing Noctra ambient chords (Hz frequencies)
  // Progression: Dm9 -> BbMaj7 -> FMaj9 -> C6
  private chords: number[][] = [
    [146.83, 220.00, 261.63, 329.63, 392.00], // Dm9 (D3, A3, C4, E4, G4)
    [116.54, 233.08, 293.66, 349.23, 440.00], // BbMaj7 (Bb2, Bb3, D4, F4, A4)
    [174.61, 261.63, 329.63, 392.00, 523.25], // FMaj9 (F3, C4, E4, G4, C5)
    [130.81, 196.00, 261.63, 329.63, 440.00], // C6 (C3, G3, C4, E4, A4)
  ];

  public init() {
    if (this.ctx) return;
    const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    this.ctx = new AudioCtx();
    this.analyser = this.ctx.createAnalyser();
    this.analyser.fftSize = 64;
    this.analyser.smoothingTimeConstant = 0.8;

    this.masterGain = this.ctx.createGain();
    this.masterGain.gain.setValueAtTime(0.18, this.ctx.currentTime);
    this.masterGain.connect(this.analyser);
    this.analyser.connect(this.ctx.destination);
  }

  public getAnalyser(): AnalyserNode | null {
    return this.analyser;
  }

  public async play(): Promise<void> {
    this.init();
    if (!this.ctx) return;
    if (this.ctx.state === 'suspended') {
      await this.ctx.resume();
    }
    if (this.isPlaying) return;
    this.isPlaying = true;

    // Trigger initial chord immediately
    this.playChord(this.chords[this.chordIndex]);
    this.chordIndex = (this.chordIndex + 1) % this.chords.length;

    // Cycle chords every 3.6 seconds
    this.intervalId = window.setInterval(() => {
      if (!this.isPlaying) return;
      this.playChord(this.chords[this.chordIndex]);
      this.chordIndex = (this.chordIndex + 1) % this.chords.length;
    }, 3600);
  }

  public pause(): void {
    this.isPlaying = false;
    if (this.intervalId !== null) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }

  public toggle(): boolean {
    if (this.isPlaying) {
      this.pause();
      return false;
    } else {
      this.play();
      return true;
    }
  }

  public getIsPlaying(): boolean {
    return this.isPlaying;
  }

  public setVolume(val: number): void {
    if (this.masterGain && this.ctx) {
      const clamped = Math.max(0, Math.min(1, val));
      this.masterGain.gain.setTargetAtTime(clamped * 0.25, this.ctx.currentTime, 0.05);
    }
  }

  private playChord(freqs: number[]): void {
    if (!this.ctx || !this.masterGain) return;
    const now = this.ctx.currentTime;
    const chordDuration = 3.5;

    // Gentle lowpass filter for warm analog feel
    const filter = this.ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(650, now);
    filter.frequency.exponentialRampToValueAtTime(1400, now + 1.2);
    filter.frequency.exponentialRampToValueAtTime(500, now + chordDuration);
    filter.connect(this.masterGain);

    freqs.forEach((freq, idx) => {
      if (!this.ctx) return;
      const osc = this.ctx.createOscillator();
      const noteGain = this.ctx.createGain();

      osc.type = idx % 2 === 0 ? 'sine' : 'triangle';
      // Subtle organic detuning
      osc.frequency.setValueAtTime(freq + (Math.random() - 0.5) * 1.2, now);

      noteGain.gain.setValueAtTime(0.0001, now);
      noteGain.gain.linearRampToValueAtTime(0.12 / freqs.length, now + 0.4 + idx * 0.05);
      noteGain.gain.exponentialRampToValueAtTime(0.0001, now + chordDuration);

      osc.connect(noteGain);
      noteGain.connect(filter);

      osc.start(now);
      osc.stop(now + chordDuration + 0.1);
    });
  }
}

export const webAudioSynth = new WebAudioSynthEngine();
