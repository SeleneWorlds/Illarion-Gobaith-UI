import { createServer } from 'vite';

const server = await createServer({
  configFile: false,
  server: { middlewareMode: true, hmr: false, ws: false },
  appType: 'custom',
});
try {
  await server.ssrLoadModule('/tests/client.test.ts');
} finally {
  await server.close();
}
