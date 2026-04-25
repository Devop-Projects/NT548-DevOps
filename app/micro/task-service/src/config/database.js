const mongoose = require('mongoose');
require('dotenv').config();

const connect = async () => {
  await mongoose.connect(process.env.MONGODB_URL);
  console.log('task-service MongoDB connected');
};

module.exports = { connect };
