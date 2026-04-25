# NT548 - DevOps Task Manager App

## Yeu cau cai dat
- Node.js >= 18
- PostgreSQL >= 15

## Cach chay (thu cong)

### Backend
```bash
cd app/mono/backend
cp .env.example .env   # dien thong tin database
npm install
npm run dev
```

### Frontend
```bash
cd app/mono/frontend
npm install
npm run dev
```

## API Endpoints
| Method | URL | Mo ta | Auth |
|--------|-----|--------|------|
| POST | /api/auth/register | Dang ky | Khong |
| POST | /api/auth/login | Dang nhap | Khong |
| GET | /api/tasks | Lay danh sach tasks | Can token |
| POST | /api/tasks | Tao task moi | Can token |
| PUT | /api/tasks/:id | Cap nhat task | Can token |
| DELETE | /api/tasks/:id | Xoa task | Can token |
