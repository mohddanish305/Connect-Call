/**
 * Safe development request logger.
 * Never logs authorization headers, tokens, passwords, or secrets.
 */
function requestLogger(req, res, next) {
  const startTime = Date.now();
  console.log(`[HTTP INCOMING] ${req.method} ${req.originalUrl}`);

  res.on('finish', () => {
    const elapsed = Date.now() - startTime;
    // Log only method, path, status, and duration
    console.log(`[HTTP] ${req.method} ${req.originalUrl} -> ${res.statusCode} (${elapsed}ms)`);
  });

  next();
}

module.exports = requestLogger;
