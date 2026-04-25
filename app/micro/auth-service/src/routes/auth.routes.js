const router = require('express').Router();
const { register, login, verifyToken } = require('../controllers/auth.controller');

router.post('/register', register);
router.post('/login', login);
router.get('/verify', verifyToken);

module.exports = router;
