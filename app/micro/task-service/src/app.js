const express = require('express');
const cors = require('cors');
require('dotenv').config();

const { connect } = require('./config/database');
const taskRoutes = require('./routes/task.routes');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_, res) => res.json({ service: 'task-service', status: 'OK' }));
app.use('/tasks', taskRoutes);

const PORT = process.env.PORT || 3002;
connect().then(() => {
  app.listen(PORT, () => console.log(`task-service running on :${PORT}`));
}).catch(err => { console.error(err); process.exit(1); });
