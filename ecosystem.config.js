module.exports = {
  apps: [
    {
      name: 'hestia',
      script: 'server.js',
      env: {
        PORT: 3000,
      },
      env_production: {
        PORT: 3000,
      },
    },
  ],
};
