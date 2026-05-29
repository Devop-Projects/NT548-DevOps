import { useState } from 'react';
import { login, register } from '../services/api';

function Login({ onLogin }) {
  const [isRegister, setIsRegister] = useState(false);
  const [form, setForm] = useState({ username: '', email: '', password: '' });
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    try {
      const res = isRegister ? await register(form) : await login(form);
      onLogin(res.data.user, res.data.token);
    } catch (err) {
      setError(err.response?.data?.message || 'Co loi xay ra');
    }
  };

  return (
    <div style={{ maxWidth: 360, margin: '100px auto', padding: 24, border: '1px solid #eee', borderRadius: 12, fontFamily: 'sans-serif' }}>
      <h2 style={{ textAlign: 'center' }}>{isRegister ? 'Dang ky' : 'Dang nhap'}</h2>
      {error && <p style={{ color: 'red', textAlign: 'center' }}>{error}</p>}
      <form onSubmit={handleSubmit}>
        {isRegister && (
          <input placeholder="Username" value={form.username}
            onChange={e => setForm({...form, username: e.target.value})}
            style={{ width: '100%', padding: 8, marginBottom: 12, boxSizing: 'border-box' }} />
        )}
        <input type="email" placeholder="Email" value={form.email}
          onChange={e => setForm({...form, email: e.target.value})}
          style={{ width: '100%', padding: 8, marginBottom: 12, boxSizing: 'border-box' }} />
        <input type="password" placeholder="Mat khau" value={form.password}
          onChange={e => setForm({...form, password: e.target.value})}
          style={{ width: '100%', padding: 8, marginBottom: 16, boxSizing: 'border-box' }} />
        <button type="submit" style={{ width: '100%', padding: 10, background: '#5c6bc0', color: '#fff', border: 'none', borderRadius: 6, cursor: 'pointer' }}>
          {isRegister ? 'Dang ky' : 'Dang nhap'}
        </button>
      </form>
      <p style={{ textAlign: 'center', marginTop: 12 }}>
        <button onClick={() => setIsRegister(!isRegister)} style={{ background: 'none', border: 'none', color: '#5c6bc0', cursor: 'pointer' }}>
          {isRegister ? 'Da co tai khoan? Dang nhap' : 'Chua co tai khoan? Dang ky'}
        </button>
      </p>
    </div>
  );
}

export default Login;
