import { useContext } from 'react';
import { ReleaseContext, type ReleaseContextValue } from '../context/ReleaseContext';

export function useRelease(): ReleaseContextValue {
  return useContext(ReleaseContext);
}
