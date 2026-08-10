const express = require('express');
const cors = require('cors');
const env = require('./config/env');
const errorMiddleware = require('./middleware/error.middleware');

const app = express();

app.use(cors({ origin: env.CORS_ORIGIN }));
app.use(express.json());

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.use(errorMiddleware);

module.exports = app;
