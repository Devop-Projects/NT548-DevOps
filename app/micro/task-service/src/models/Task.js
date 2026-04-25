const mongoose = require('mongoose');

const taskSchema = new mongoose.Schema({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  status: { type: String, enum: ['todo', 'in_progress', 'done'], default: 'todo' },
  userId: { type: String, required: true },
}, { timestamps: true });

module.exports = mongoose.model('Task', taskSchema);
