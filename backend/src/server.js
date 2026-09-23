import 'dotenv/config';import app from './app.js';import {connectDatabase} from './config/db.js';
const port = process.env.PORT || 5000;
const host = process.env.HOST || '0.0.0.0';

connectDatabase()
  .then(() => {
    app.listen(port, host, () => console.log(`API listening on http://${host}:${port}`));
  })
  .catch(error => {
    console.error(`MongoDB connection failed: ${error.message}`);
    process.exitCode = 1;
  });

process.on('unhandledRejection', error => console.error('Unhandled rejection:', error));
