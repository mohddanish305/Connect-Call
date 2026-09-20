import { Hono } from 'hono';
import type { Env, Variables } from '../types';

export const healthRoutes = new Hono<{ Bindings: Env; Variables: Variables }>();

healthRoutes.get('/health', (c) => {
  return c.json({
    success: true,
    service: c.env.SERVICE_NAME || 'ConnectCall Backend',
    status: 'healthy',
  });
});
