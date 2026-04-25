const express = require('express');
const cors = require('cors');
require('dotenv').config();

const sequelize = require('./config/database');
const User = require('./models/User');
const authRoutes = require('./routes/auth.routes');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_, res) => res.json({ service: 'auth-service', status: 'OK' }));
app.use('/auth', authRoutes);

const PORT = process.env.PORT || 3001;
sequelize.sync({ alter: true }).then(() => {
  console.log('auth-service DB connected');
  app.listen(PORT, () => console.log(`auth-service running on :${PORT}`));
}).catch(err => { console.error(err); process.exit(1); });
