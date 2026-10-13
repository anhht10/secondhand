export default () => {
  const nodeEnv = process.env.NODE_ENV || 'development';
  const defaultMongoUri =
    nodeEnv === 'test'
      ? process.env.MONGODB_TEST_URI ||
        'mongodb://127.0.0.1:27017/remarket_test'
      : process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/remarket';

  const sharedJwtSecret = process.env.JWT_SECRET;

  return {
    nodeEnv,
    port: parseInt(process.env.PORT || '5000', 10),
    apiPrefix: process.env.API_PREFIX || 'api/v1',
    corsOrigin: process.env.CORS_ORIGIN || '*',
    database: {
      uri: defaultMongoUri,
    },
    jwt: {
      accessSecret:
        process.env.JWT_ACCESS_SECRET ||
        sharedJwtSecret ||
        'dev-access-secret-only-for-local-development',
      accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
      refreshSecret:
        process.env.JWT_REFRESH_SECRET ||
        sharedJwtSecret ||
        'dev-refresh-secret-only-for-local-development',
      refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
    },
    bcrypt: {
      saltRounds: parseInt(process.env.BCRYPT_SALT_ROUNDS || '10', 10),
    },
    throttle: {
      ttl: parseInt(process.env.THROTTLE_TTL || '60', 10),
      limit: parseInt(process.env.THROTTLE_LIMIT || '100', 10),
    },
    ai: {
      serviceUrl: (process.env.AI_SERVICE_URL || 'http://localhost:8000')
        .trim()
        .replace(/\/+$/, ''),
      serviceToken: (
        process.env.AI_SERVICE_TOKEN ||
        process.env.BACKEND_SERVICE_TOKEN ||
        ''
      ).trim(),
      timeoutMs: parseInt(process.env.AI_REQUEST_TIMEOUT_MS || '15000', 10),
    },
  };
};
