import styles from './AmbientBackdrop.module.css';

export function AmbientBackdrop() {
  return (
    <div className={styles.backdrop} aria-hidden="true">
      <div className={styles.gradientOrb1} />
      <div className={styles.gradientOrb2} />
      <div className={styles.gradientOrb3} />
      <div className={styles.gridOverlay} />
    </div>
  );
}
