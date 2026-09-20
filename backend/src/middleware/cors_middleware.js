const cors = require('cors');
const env = require('../config/env');

const corsOptions = {
  origin: (origin, callback) => {
    // In development or if allowedOrigins contains '*', allow all origins
    if (env.IS_DEVELOPMENT || env.ALLOWED_ORIGINS.includes('*') || !origin) {
      return callback(null, true);
    }

    if (env.ALLOWED_ORIGINS.includes(origin)) {
      return callback(null, true);
    }

    return callback(new Error('CORS policy: Not allowed by CORS.'));
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: false,
};

module.exports = cors(corsOptions);
