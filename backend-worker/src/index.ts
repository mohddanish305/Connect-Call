import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { healthRoutes } from './routes/health';
import { agoraRoutes } from './routes/agora';
import type { Env, Variables } from './types';

const app = new Hono<{ Bindings: Env; Variables: Variables }>();

// 1. Centralized CORS Middleware (Safe for Mobile & Web, no wildcard credential sharing)
app.use('*', cors({
  origin: '*',
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
  credentials: false,
}));

// 2. Health routes mounted on root and /api
app.route('/', healthRoutes);
app.route('/api', healthRoutes);

// 3. Agora RTC Token routes mounted on /api/agora
app.route('/api/agora', agoraRoutes);

// 4. Fallback 404 handler
app.notFound((c) => {
  return c.json({ success: false, message: `Route not found: ${c.req.method} ${c.req.path}` }, 404);
});

// 5. Global Exception Handler
app.onError((err, c) => {
  console.error('[Worker Fatal Error]:', err.message);
  return c.json({ success: false, message: 'Internal server error.' }, 500);
});

export default app;
