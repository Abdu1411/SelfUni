import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import {defineConfig} from 'vite';

import https from 'https';
import http from 'http';

const localProxyPlugin = () => ({
  name: 'local-proxy',
  configureServer(server: any) {
    server.middlewares.use('/api/proxy', (req: any, res: any) => {
      const urlParam = new URL(req.url, `http://${req.headers.host}`).searchParams.get('url');
      if (!urlParam) {
        res.statusCode = 400;
        res.end('Missing url parameter');
        return;
      }
      
      const client = urlParam.startsWith('https') ? https : http;
      client.get(urlParam, { 
        headers: { 
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9'
        } 
      }, (proxyRes) => {
        // Remove headers that might cause issues
        delete proxyRes.headers['content-security-policy'];
        delete proxyRes.headers['x-frame-options'];
        
        res.writeHead(proxyRes.statusCode || 200, proxyRes.headers);
        proxyRes.pipe(res);
      }).on('error', (err: Error) => {
        res.statusCode = 500;
        res.end(err.message);
      });
    });
  }
});

export default defineConfig(() => {
  return {
    plugins: [react(), tailwindcss(), localProxyPlugin()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, '.'),
      },
    },
    server: {
      // HMR is disabled in AI Studio via DISABLE_HMR env var.
      // Do not modifyâfile watching is disabled to prevent flickering during agent edits.
      hmr: process.env.DISABLE_HMR !== 'true',
      // Disable file watching when DISABLE_HMR is true to save CPU during agent edits.
      watch: process.env.DISABLE_HMR === 'true' ? null : {},
    },
  };
});
