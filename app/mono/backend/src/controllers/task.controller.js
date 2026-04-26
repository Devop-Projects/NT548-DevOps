const Task = require('../models/Task');
const logger = require('../config/logger');

const getAllTasks = async (req, res) => {
  try {
    const tasks = await Task.findAll({ where: { userId: req.user.id } });
    res.json(tasks);
  } catch (error) {
    logger.error({ err: error, userId: req.user.id }, 'Failed to get tasks');
    res.status(500).json({ message: 'Internal server error' });
  }
};

const createTask = async (req, res) => {
  try {
    const { title, description } = req.body;

    if (!title || title.trim() === '') {
      return res.status(400).json({ message: 'Title is required' });
    }

    const task = await Task.create({
      title: title.trim(),
      description: description?.trim() || '',
      userId: req.user.id
    });

    logger.info({ taskId: task.id, userId: req.user.id }, 'Task created');
    res.status(201).json(task);
  } catch (error) {
    logger.error({ err: error, userId: req.user.id }, 'Failed to create task');
    res.status(500).json({ message: 'Internal server error' });
  }
};

const updateTask = async (req, res) => {
  try {
    const task = await Task.findOne({
      where: { id: req.params.id, userId: req.user.id }
    });

    if (!task) {
      return res.status(404).json({ message: 'Task not found' });
    }

    await task.update(req.body);
    logger.debug({ taskId: task.id }, 'Task updated');
    res.json(task);
  } catch (error) {
    logger.error({ err: error, taskId: req.params.id }, 'Failed to update task');
    res.status(500).json({ message: 'Internal server error' });
  }
};

const deleteTask = async (req, res) => {
  try {
    const task = await Task.findOne({
      where: { id: req.params.id, userId: req.user.id }
    });

    if (!task) {
      return res.status(404).json({ message: 'Task not found' });
    }

    await task.destroy();
    logger.info({ taskId: req.params.id, userId: req.user.id }, 'Task deleted');
    res.json({ message: 'Task deleted' });
  } catch (error) {
    logger.error({ err: error, taskId: req.params.id }, 'Failed to delete task');
    res.status(500).json({ message: 'Internal server error' });
  }
};

module.exports = { getAllTasks, createTask, updateTask, deleteTask };