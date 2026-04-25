import { useState, useEffect } from 'react';
import { getTasks, createTask, updateTask, deleteTask } from './services/api';
import Login from './pages/Login';

function App() {
  const [user, setUser] = useState(() => {
    const stored = localStorage.getItem('user');
    return stored ? JSON.parse(stored) : null;
  });
  const [tasks, setTasks] = useState([]);
  const [newTitle, setNewTitle] = useState('');

  useEffect(() => {
    if (user) loadTasks();
  }, [user]);

  const loadTasks = async () => {
    try {
      const res = await getTasks();
      setTasks(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  const handleLogin = (userData, token) => {
    localStorage.setItem('token', token);
    localStorage.setItem('user', JSON.stringify(userData));
    setUser(userData);
  };

  const handleLogout = () => {
    localStorage.clear();
    setUser(null);
    setTasks([]);
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    if (!newTitle.trim()) return;
    await createTask({ title: newTitle });
    setNewTitle('');
    loadTasks();
  };

  const handleStatusChange = async (id, status) => {
    await updateTask(id, { status });
    loadTasks();
  };

  const handleDelete = async (id) => {
    await deleteTask(id);
    loadTasks();
  };

  if (!user) return <Login onLogin={handleLogin} />;

  return (
    <div style={{ maxWidth: 600, margin: '40px auto', padding: '0 20px', fontFamily: 'sans-serif' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h1>Task Manager</h1>
        <div>
          <span>Xin chao, {user.username}</span>
          <button onClick={handleLogout} style={{ marginLeft: 12 }}>Dang xuat</button>
        </div>
      </div>

      <form onSubmit={handleCreate} style={{ display: 'flex', gap: 8, marginBottom: 24 }}>
        <input
          value={newTitle}
          onChange={e => setNewTitle(e.target.value)}
          placeholder="Them task moi..."
          style={{ flex: 1, padding: '8px 12px', borderRadius: 6, border: '1px solid #ddd' }}
        />
        <button type="submit" style={{ padding: '8px 16px', borderRadius: 6, background: '#5c6bc0', color: '#fff', border: 'none' }}>
          Them
        </button>
      </form>

      {tasks.map(task => (
        <div key={task.id} style={{ padding: 12, border: '1px solid #eee', borderRadius: 8, marginBottom: 8, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <strong>{task.title}</strong>
            <span style={{ marginLeft: 8, fontSize: 12, background: '#eee', padding: '2px 8px', borderRadius: 12 }}>
              {task.status}
            </span>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <select value={task.status} onChange={e => handleStatusChange(task.id, e.target.value)} style={{ fontSize: 12 }}>
              <option value="todo">Todo</option>
              <option value="in_progress">In Progress</option>
              <option value="done">Done</option>
            </select>
            <button onClick={() => handleDelete(task.id)} style={{ color: 'red', border: 'none', background: 'none', cursor: 'pointer' }}>X</button>
          </div>
        </div>
      ))}
    </div>
  );
}

export default App;
