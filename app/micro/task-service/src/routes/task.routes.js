const router = require('express').Router();
const auth = require('../middleware/auth.middleware');
const { getAll, create, update, remove } = require('../controllers/task.controller');

router.get('/', auth, getAll);
router.post('/', auth, create);
router.put('/:id', auth, update);
router.delete('/:id', auth, remove);

module.exports = router;
