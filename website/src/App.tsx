import { useEffect } from 'react';
import { ReleaseProvider } from './context/ReleaseContext';
import { RouterProvider, useRouter } from './router/Router';
import { AmbientBackdrop } from './components/AmbientBackdrop/AmbientBackdrop';
import Navbar from './components/Navbar/Navbar';
import { Footer } from './components/Footer/Footer';
import { HomePage } from './pages/HomePage';
import { FeaturesPage } from './pages/FeaturesPage';
import { DownloadPage } from './pages/DownloadPage';
import { ArchitecturePage } from './pages/ArchitecturePage';
import { ChangelogPage } from './pages/ChangelogPage';
import './styles/base.css';

function PageSwitch() {
  const { currentPath } = useRouter();

  // Route matching
  if (currentPath.startsWith('/features')) {
    return <FeaturesPage />;
  }
  if (currentPath.startsWith('/download') || currentPath.startsWith('/install')) {
    return <DownloadPage />;
  }
  if (currentPath.startsWith('/architecture') || currentPath.startsWith('/docs')) {
    return <ArchitecturePage />;
  }
  if (currentPath.startsWith('/changelog')) {
    return <ChangelogPage />;
  }

  // Default to HomePage
  return <HomePage />;
}

export default function App() {
  useEffect(() => {
    if (!document.documentElement.dataset.theme) {
      document.documentElement.dataset.theme = 'noir-black';
    }
  }, []);

  return (
    <ReleaseProvider>
      <RouterProvider>
        <div className="noctra-root">
          {/* Lightweight Ambient Backdrop (Zero WebGL / Three.js overhead) */}
          <AmbientBackdrop />

          {/* Persistent Multi-Page Navigation */}
          <Navbar />

          {/* Active Page View */}
          <main style={{ position: 'relative', zIndex: 1, minHeight: 'calc(100vh - 200px)' }}>
            <PageSwitch />
          </main>

          {/* Persistent Footer */}
          <Footer />
        </div>
      </RouterProvider>
    </ReleaseProvider>
  );
}
