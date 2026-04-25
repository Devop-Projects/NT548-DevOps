const Task = require('../models/Task');

const getAllTasks = async (req, res) => {
  try {
    const tasks = await Task.findAll({ where: { userId: req.user.id } });
    res.json(tasks);
  } catch (error) {
    res.status(500).json({ message: 'Loi server', error: error.message });
  }
};

const createTask = async (req, res) => {
  try {
    const { title, description } = req.body;
    const task = await Task.create({ title, description, userId: req.user.id });
    res.status(201).json(task);
  } catch (error) {
    res.status(500).json({ message: 'Loi server', error: error.message });
  }
};

const updateTask = async (req, res) => {
  try {
    const task = await Task.findOne({ where: { id: req.params.id, userId: req.user.id } });
    if (!task) return res.status(404).json({ message: 'Khong tim thay task' });

    await task.update(req.body);
    res.json(task);
  } catch (error) {
    res.status(500).json({ message: 'Loi server', error: error.message });
  }
};

const deleteTask = async (req, res) => {
  try {
    const task = await Task.findOne({ where: { id: req.params.id, userId: req.user.id } });
    if (!task) return res.status(404).json({ message: 'Khong tim thay task' });

    await task.destroy();
    res.json({ message: 'Da xoa task' });
  } catch (error) {
    res.status(500).json({ message: 'Loi server', error: error.message });
  }
};

module.exports = { getAllTasks, createTask, updateTask, deleteTask };
