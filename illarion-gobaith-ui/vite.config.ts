import { fileURLToPath, URL } from 'node:url';
import vue from '@vitejs/plugin-vue';
import { defineConfig } from 'vite';

export default defineConfig({
  root: fileURLToPath(new URL('./ui', import.meta.url)),
  resolve: {
    alias: [
      {
        find: /^selene\/mock$/,
        replacement: fileURLToPath(new URL('../../../sdk/selene/src/mock.ts', import.meta.url)),
      },
      {
        find: /^selene$/,
        replacement: fileURLToPath(new URL('../../../sdk/selene/src/index.ts', import.meta.url)),
      },
      {
        find: 'illarion-client-core',
        replacement: fileURLToPath(new URL('../illarion-client-core/ui/src', import.meta.url)),
      },
      {
        find: 'moonlight-ui/styles',
        replacement: fileURLToPath(new URL('../../moonlight/moonlight-ui/ui/styles', import.meta.url)),
      },
      {
        find: 'moonlight-ui',
        replacement: fileURLToPath(new URL('../../moonlight/moonlight-ui/ui/src', import.meta.url)),
      },
    ],
    dedupe: ['vue'],
  },
  base: './',
  publicDir: 'public',
  server: {
    cors: { origin: 'https://cef.seleneworlds.com' },
  },
  plugins: [
    vue(),
    {
      name: 'bundle-ui-entrypoint',
      apply: 'build',
      generateBundle() {
        this.emitFile({
          type: 'asset',
          fileName: 'index.html',
          source:
            '<!doctype html>\n<html lang="en">\n<head>\n  <meta charset="UTF-8">\n  <meta name="viewport" content="width=device-width, initial-scale=1.0">\n  <title>Illarion Gobaith HUD</title>\n  <script type="module" src="./ui.js"></script>\n  <link rel="stylesheet" href="./ui.css">\n</head>\n<body>\n  <div id="illarion-ui"></div>\n</body>\n</html>\n',
        });
      },
    },
  ],
  build: {
    outDir: fileURLToPath(new URL('./client/ui/dist', import.meta.url)),
    emptyOutDir: true,
    assetsInlineLimit: Number.POSITIVE_INFINITY,
    rollupOptions: {
      input: fileURLToPath(new URL('./ui/src/main.ts', import.meta.url)),
      preserveEntrySignatures: 'strict',
      output: {
        entryFileNames: 'ui.js',
        assetFileNames: 'ui.[ext]',
      },
    },
  },
});
