import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
  root: './src',
  // Look for svelte.config.js in the project root, not the vite root (./src).
  plugins: [svelte({ configFile: '../svelte.config.js' })],
  // Env files (.env with VITE_GOOGLE_MAPS_API_KEY) live in the project root too.
  envDir: '..',
  build: {
    outDir: '../dist',
    minify: false,
    emptyOutDir: true,
  },
});
