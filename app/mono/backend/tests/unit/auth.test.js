// tests/unit/auth.test.js
//
// Unit test cho auth.controller.js
// Triết lý: mock User model — KHÔNG chạy DB thật
// → test nhanh, deterministic, có thể chạy offline

// Mock các module trước khi require controller
jest.mock('../../src/models/User');
jest.mock('../../src/config/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  debug: jest.fn(),
}));

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../../src/models/User');
const { register, login } = require('../../src/controllers/auth.controller');

// Set env var cho JWT
process.env.JWT_SECRET = 'test-secret-for-jest';
process.env.JWT_EXPIRES_IN = '1h';

// Helper: tạo mock req/res
const mockReq = (body = {}) => ({ body });
const mockRes = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
};

describe('Auth Controller — register', () => {
  beforeEach(() => {
    jest.clearAllMocks();   // reset mock giữa các test
  });

  it('returns 400 when missing required fields', async () => {
    const req = mockReq({ email: 'test@example.com' });   // thiếu username, password
    const res = mockRes();

    await register(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ message: expect.stringContaining('Missing') })
    );
  });

  it('returns 400 when password too short', async () => {
    const req = mockReq({
      username: 'alice',
      email: 'alice@example.com',
      password: '123',   // < 6 ký tự
    });
    const res = mockRes();

    await register(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 when email already exists', async () => {
    User.findOne.mockResolvedValue({ id: 'existing-uuid', email: 'alice@example.com' });

    const req = mockReq({
      username: 'alice',
      email: 'alice@example.com',
      password: 'validpassword',
    });
    const res = mockRes();

    await register(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ message: 'Email already in use' });
  });

  it('creates user and returns token on valid input', async () => {
    User.findOne.mockResolvedValue(null);   // email chưa tồn tại
    User.create.mockResolvedValue({
      id: 'new-uuid',
      username: 'alice',
      email: 'alice@example.com',
    });

    const req = mockReq({
      username: 'alice',
      email: 'alice@example.com',
      password: 'validpassword',
    });
    const res = mockRes();

    await register(req, res);

    expect(User.create).toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        token: expect.any(String),
        user: expect.objectContaining({ email: 'alice@example.com' }),
      })
    );
  });
});

describe('Auth Controller — login', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns 401 for non-existent email', async () => {
    User.findOne.mockResolvedValue(null);

    const req = mockReq({ email: 'nobody@example.com', password: 'whatever' });
    const res = mockRes();

    await login(req, res);

    expect(res.status).toHaveBeenCalledWith(401);
  });

  it('returns 401 for wrong password', async () => {
    const hashedPassword = await bcrypt.hash('correct-password', 10);
    User.findOne.mockResolvedValue({
      id: 'user-uuid',
      email: 'alice@example.com',
      password: hashedPassword,
    });

    const req = mockReq({ email: 'alice@example.com', password: 'wrong-password' });
    const res = mockRes();

    await login(req, res);

    expect(res.status).toHaveBeenCalledWith(401);
  });

  it('returns token for valid credentials', async () => {
    const hashedPassword = await bcrypt.hash('correct-password', 10);
    User.findOne.mockResolvedValue({
      id: 'user-uuid',
      username: 'alice',
      email: 'alice@example.com',
      password: hashedPassword,
    });

    const req = mockReq({ email: 'alice@example.com', password: 'correct-password' });
    const res = mockRes();

    await login(req, res);

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ token: expect.any(String) })
    );
  });
});