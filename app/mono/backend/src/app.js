const express = require('express');
const cors = require('cors');
require('dotenv').config();

const sequelize = require('./config/database');
const User = require('./models/User');
const Task = require('./models/Task');
const authRoutes = require('./routes/auth.routes');
const taskRoutes = require('./routes/task.routes');

const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.use('/api/auth', authRoutes);
app.use('/api/tasks', taskRoutes);

const PORT = process.env.PORT || 3000;

sequelize.sync({ alter: true })
  .then(() => {
    console.log('Ket noi database thanh cong');
    app.listen(PORT, () => {
      console.log(`Server dang chay tren port ${PORT}`);
    });
  })
  .catch(err => {
    console.error('Loi ket noi database:', err);
    process.exit(1);
  });

module.exports = app;
