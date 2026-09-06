import { useEffect, useRef } from 'react';
import * as THREE from 'three';
import type { ThemeType } from '../../types';
import styles from './ThreeBackdrop.module.css';

interface Props {
  theme: ThemeType;
}

export function ThreeBackdrop({ theme }: Props) {
  const mountRef = useRef<HTMLDivElement>(null);
  const themeRef = useRef(theme);
  themeRef.current = theme;

  useEffect(() => {
    const container = mountRef.current;
    if (!container) return;

    // Setup Three.js scene
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.1, 1000);
    camera.position.z = 18;

    const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true, powerPreference: 'high-performance' });
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    container.appendChild(renderer.domElement);

    // Group for floating glass objects
    const mainGroup = new THREE.Group();
    scene.add(mainGroup);

    // Ambient light
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.4);
    scene.add(ambientLight);

    // Dynamic colored lights matching Noctra's 3 liquid glass aurora tones
    const light1 = new THREE.PointLight(0x68c8ff, 2.5, 50); // Aurora cyan
    light1.position.set(-10, 8, 5);
    scene.add(light1);

    const light2 = new THREE.PointLight(0x8070ff, 2.2, 50); // Violet
    light2.position.set(12, -8, 6);
    scene.add(light2);

    const light3 = new THREE.PointLight(0x68e8c0, 1.8, 50); // Mint
    light3.position.set(6, 10, -4);
    scene.add(light3);

    // Create 3D Glass Shards
    const shards: THREE.Mesh[] = [];
    const shardGeom = new THREE.OctahedronGeometry(1.6, 0);
    const icosaGeom = new THREE.IcosahedronGeometry(1.2, 0);

    const glassMaterial = new THREE.MeshPhysicalMaterial({
      color: 0x9edbff,
      roughness: 0.08,
      metalness: 0.1,
      transmission: 0.85,
      ior: 1.5,
      thickness: 1.4,
      specularIntensity: 1.0,
      transparent: true,
      opacity: 0.65,
    });

    // Monochromatic sleek wireframe material for Noir Black & White
    const wireMaterial = new THREE.MeshStandardMaterial({
      color: 0xffffff,
      roughness: 0.4,
      metalness: 0.8,
      wireframe: true,
    });

    const positions: [number, number, number][] = [
      [-7, 3, -2],
      [8, 4, -4],
      [-5, -4, -1],
      [7, -3, -3],
      [0, -6, -5],
    ];

    positions.forEach((pos, i) => {
      const geom = i % 2 === 0 ? shardGeom : icosaGeom;
      const mesh = new THREE.Mesh(geom, glassMaterial);
      mesh.position.set(...pos);
      mesh.rotation.set(Math.random() * Math.PI, Math.random() * Math.PI, 0);
      shards.push(mesh);
      mainGroup.add(mesh);
    });

    // Particle field for subtle floating dust/audio aura
    const particleCount = 140;
    const particleGeom = new THREE.BufferGeometry();
    const particlePositions = new Float32Array(particleCount * 3);

    for (let i = 0; i < particleCount * 3; i += 3) {
      particlePositions[i] = (Math.random() - 0.5) * 35;
      particlePositions[i + 1] = (Math.random() - 0.5) * 25;
      particlePositions[i + 2] = (Math.random() - 0.5) * 20;
    }

    particleGeom.setAttribute('position', new THREE.BufferAttribute(particlePositions, 3));
    const particleMat = new THREE.PointsMaterial({
      color: 0x7ec8ff,
      size: 0.08,
      transparent: true,
      opacity: 0.45,
    });
    const particles = new THREE.Points(particleGeom, particleMat);
    scene.add(particles);

    // Mouse tilt tracking
    let targetMouseX = 0;
    let targetMouseY = 0;
    let currentMouseX = 0;
    let currentMouseY = 0;

    const handleMouseMove = (e: MouseEvent) => {
      targetMouseX = (e.clientX / window.innerWidth) * 2 - 1;
      targetMouseY = -(e.clientY / window.innerHeight) * 2 + 1;
    };

    window.addEventListener('mousemove', handleMouseMove, { passive: true });

    // Handle Resize
    const handleResize = () => {
      camera.aspect = window.innerWidth / window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(window.innerWidth, window.innerHeight);
    };

    window.addEventListener('resize', handleResize);

    // Animation Loop
    let animationFrameId: number;
    let clock = new THREE.Clock();

    const animate = () => {
      animationFrameId = requestAnimationFrame(animate);
      const elapsedTime = clock.getElapsedTime();
      const currentTheme = themeRef.current;

      // Smooth mouse interpolation
      currentMouseX += (targetMouseX - currentMouseX) * 0.04;
      currentMouseY += (targetMouseY - currentMouseY) * 0.04;

      mainGroup.rotation.y = currentMouseX * 0.25;
      mainGroup.rotation.x = -currentMouseY * 0.2;

      // Update appearance based on active theme
      if (currentTheme === 'noir-black') {
        light1.color.setHex(0xffffff);
        light1.intensity = 0.8;
        light2.color.setHex(0xaaaaaa);
        light2.intensity = 0.6;
        light3.intensity = 0;
        particles.visible = true;
        particleMat.color.setHex(0xffffff);
        particleMat.opacity = 0.25;
        shards.forEach((s) => {
          s.material = wireMaterial;
          wireMaterial.color.setHex(0x44444c);
        });
      } else if (currentTheme === 'noir-white') {
        light1.color.setHex(0x222222);
        light1.intensity = 0.4;
        light2.intensity = 0;
        light3.intensity = 0;
        particles.visible = false;
        shards.forEach((s) => {
          s.material = wireMaterial;
          wireMaterial.color.setHex(0xcccccc);
        });
      } else {
        // Liquid Glass
        light1.color.setHex(0x68c8ff);
        light1.intensity = 2.5;
        light2.color.setHex(0x8070ff);
        light2.intensity = 2.0;
        light3.color.setHex(0x68e8c0);
        light3.intensity = 1.6;
        particles.visible = true;
        particleMat.color.setHex(0x7ec8ff);
        particleMat.opacity = 0.45;
        shards.forEach((s) => {
          s.material = glassMaterial;
        });
      }

      // Floating Shards gentle orbit & breathing
      shards.forEach((shard, idx) => {
        const speed = 0.3 + (idx % 3) * 0.15;
        shard.rotation.x += 0.003 * speed;
        shard.rotation.y += 0.005 * speed;
        shard.position.y += Math.sin(elapsedTime * speed + idx) * 0.003;
      });

      // Slowly rotate particle field
      particles.rotation.y = elapsedTime * 0.02;

      renderer.render(scene, camera);
    };

    animate();

    return () => {
      cancelAnimationFrame(animationFrameId);
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('resize', handleResize);
      if (container.contains(renderer.domElement)) {
        container.removeChild(renderer.domElement);
      }
      renderer.dispose();
      shardGeom.dispose();
      icosaGeom.dispose();
      glassMaterial.dispose();
      wireMaterial.dispose();
      particleGeom.dispose();
      particleMat.dispose();
    };
  }, []);

  return (
    <div className={styles.container} ref={mountRef}>
      <div className={styles.orbTopLeft} />
      <div className={styles.orbBottomRight} />
      <div className={styles.orbCenterRight} />
    </div>
  );
}
