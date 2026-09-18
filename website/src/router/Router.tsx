import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';

export type RoutePath = '/' | '/features' | '/download' | '/architecture' | '/changelog';

interface RouterContextType {
  currentPath: string;
  navigate: (to: string) => void;
}

const RouterContext = createContext<RouterContextType>({
  currentPath: '/',
  navigate: () => {},
});

function getCleanPath(): string {
  // Support hash routing fallback for static hosts (e.g. /#/download)
  const hash = window.location.hash;
  if (hash.startsWith('#/')) {
    return hash.substring(1);
  }
  const path = window.location.pathname;
  // Normalize root path
  if (!path || path === '' || path === '/index.html') {
    return '/';
  }
  return path;
}

export function RouterProvider({ children }: { children: React.ReactNode }) {
  const [currentPath, setCurrentPath] = useState<string>(getCleanPath);

  useEffect(() => {
    const handlePopState = () => {
      setCurrentPath(getCleanPath());
    };
    window.addEventListener('popstate', handlePopState);
    window.addEventListener('hashchange', handlePopState);
    return () => {
      window.removeEventListener('popstate', handlePopState);
      window.removeEventListener('hashchange', handlePopState);
    };
  }, []);

  const navigate = useCallback((to: string) => {
    // If it's an external link or anchor on the same page
    if (to.startsWith('http') || to.startsWith('mailto:') || to.startsWith('tg:')) {
      window.open(to, '_blank', 'noopener,noreferrer');
      return;
    }

    if (to.startsWith('#') && !to.startsWith('#/')) {
      const el = document.querySelector(to);
      if (el) {
        el.scrollIntoView({ behavior: 'smooth' });
      }
      return;
    }

    const cleanTo = to.startsWith('#/') ? to.substring(1) : to;
    if (cleanTo === currentPath) {
      window.scrollTo({ top: 0, behavior: 'smooth' });
      return;
    }

    // Try HTML5 pushState; fallback to hash if on github.io or static file
    try {
      window.history.pushState({}, '', cleanTo);
      setCurrentPath(cleanTo);
    } catch {
      window.location.hash = `#${cleanTo}`;
      setCurrentPath(cleanTo);
    }
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }, [currentPath]);

  return (
    <RouterContext.Provider value={{ currentPath, navigate }}>
      {children}
    </RouterContext.Provider>
  );
}

export function useRouter() {
  return useContext(RouterContext);
}

export function Link({
  to,
  children,
  className,
  activeClassName,
  style,
  ...props
}: {
  to: string;
  children: React.ReactNode;
  className?: string;
  activeClassName?: string;
  style?: React.CSSProperties;
  [key: string]: any;
}) {
  const { currentPath, navigate } = useRouter();
  const isActive = currentPath === to || (to !== '/' && currentPath.startsWith(to));

  const handleClick = (e: React.MouseEvent<HTMLAnchorElement>) => {
    if (!to.startsWith('http') && !to.startsWith('mailto:') && !to.startsWith('tg:')) {
      e.preventDefault();
      navigate(to);
    }
  };

  const fullClassName = [
    className,
    isActive && activeClassName ? activeClassName : '',
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <a
      href={to}
      onClick={handleClick}
      className={fullClassName}
      style={style}
      {...props}
    >
      {children}
    </a>
  );
}
