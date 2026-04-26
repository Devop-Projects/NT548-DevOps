import axios from 'axios';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000/api';

const api = axios.create({
  baseURL: API_URL,
  timeout: 10000,  // 10s timeout — fail fast on slow backend
});

/**
 * Request interceptor: attach JWT token to every request.
 */
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

/**
 * Response interceptor: handle 401 globally.
 *
 * Bug fixed (from Lesson 1.3 sequence diagram analysis):
 * - Token expires after 7 days
 * - Backend returns 401
 * - Old code: silent fail in console.error
 * - New code: redirect to login automatically
 *
 * Why this matters?
 * UX: user not stuck on broken page wondering why nothing loads.
 * Security: invalid token cleared from localStorage immediately.
 */
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      const code = error.response?.data?.code;

      // Token expired or invalid — force re-login
      if (code === 'TOKEN_EXPIRED' || code === 'INVALID_TOKEN' || code === 'NO_TOKEN') {
        localStorage.removeItem('token');
        localStorage.removeItem('user');

        // Don't redirect on the login/register page itself (would cause loop)
        const onAuthPage = window.location.pathname === '/login' ||
                           window.location.pathname === '/register';

        if (!onAuthPage) {
          // Use window.location instead of navigate (works without React Router context)
          window.location.href = '/';
        }
      }
    }
    return Promise.reject(error);
  }
);

export const register = (data) => api.post('/auth/register', data);
export const login = (data) => api.post('/auth/login', data);
export const getTasks = () => api.get('/tasks');
export const createTask = (data) => api.post('/tasks', data);
export const updateTask = (id, data) => api.put(`/tasks/${id}`, data);
export const deleteTask = (id) => api.delete(`/tasks/${id}`);