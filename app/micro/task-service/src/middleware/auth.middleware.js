const axios = require('axios');

const authMiddleware = async (req, res, next) => {
  const token = req.headers['authorization'];
  if (!token) return res.status(401).json({ message: 'Khong co token' });

  try {
    const response = await axios.get(`${process.env.AUTH_SERVICE_URL}/auth/verify`, {
      headers: { authorization: token },
    });

    if (!response.data.valid)
      return res.status(401).json({ message: 'Token khong hop le' });

    req.user = response.data.user;
    next();
  } catch {
    res.status(401).json({ message: 'Loi xac thuc' });
  }
};

module.exports = authMiddleware;
