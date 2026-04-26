# 🧊 [FROZEN] Microservices Version — NT548 Task Manager

> **Status:** ❄️ FROZEN — Reserved for Phase 9 refactoring
> **Last modified:** [Ngày bạn freeze]
> **Will be revisited:** Phase 9 — Microservices Migration

---

## ⚠️ DO NOT MODIFY

Phiên bản này hiện đang ở trạng thái **frozen** và sẽ không được sửa đổi cho đến khi đồ án tiến vào **Phase 9 — Microservices Migration**.

### Tại sao freeze?

Theo plan của đồ án, các phase 1-8 sẽ tập trung hoàn toàn vào **monolith version** (`app/mono/`) để:

1. **Giảm cognitive load** — Học DevOps practices trên 1 codebase đơn giản
2. **Đầu tư chiều sâu** — Hiểu kỹ Docker, K8s, CI/CD trên mono trước
3. **Tránh distributed monolith** — Microservices đòi hỏi kinh nghiệm về monolith trước
4. **Đúng path migration thực tế** — Netflix, Amazon, Uber đều đi từ monolith → microservices

Phiên bản này **được giữ trong repo** với mục đích:
- 📊 **Comparison study** — So sánh metrics monolith vs microservices ở Phase 9
- 📚 **Reference** — Tài liệu tham khảo về kiến trúc microservices
- 🎯 **Refactor target** — Sẽ được refactor và improve ở Phase 9

---

## 🔍 Known Issues (sẽ fix ở Phase 9)

Phiên bản hiện tại được tạo với sự hỗ trợ của AI và **chưa được audit kỹ thuật**. Các vấn đề đã được identify:

### Architecture Issues

| # | Issue | Severity | Phase 9 Action |
|---|-------|----------|----------------|
| 1 | Auth-service là SPOF — mỗi request task-service phải gọi HTTP đến auth-service để verify JWT | 🔴 High | Refactor: dùng JWT stateless verification, mỗi service tự verify với shared secret/public key |
| 2 | Không có circuit breaker giữa task-service và auth-service | 🔴 High | Implement circuit breaker pattern (e.g., opossum library) |
| 3 | API Gateway (Nginx) chỉ là reverse proxy, không có auth/rate-limit/logging | 🟡 Medium | Refactor sang Kong/Traefik hoặc enhance Nginx config |
| 4 | Frontend Dockerfile chạy `npm run dev` (Vite dev server) thay vì production build | 🔴 High | Multi-stage build với Nginx serve static files (như mono) |
| 5 | Không có health check cho task-service | 🟡 Medium | Add `/health/live` và `/health/ready` endpoints |
| 6 | Inconsistent database choice — Postgres cho user nhưng Mongo cho task | 🟢 Low | Justify hoặc migrate sang Postgres unified |

### Security Issues

| # | Issue | Severity | Phase 9 Action |
|---|-------|----------|----------------|
| 1 | JWT_SECRET hardcoded trong docker-compose | 🔴 Critical | Move to Secret management |
| 2 | DB passwords hardcoded | 🔴 Critical | Move to Secret management |
| 3 | Không có request validation | 🟡 Medium | Add express-validator hoặc zod |
| 4 | Không có rate limiting | 🟡 Medium | Add express-rate-limit middleware |

---

## 📋 Phase 9 Refactoring Plan (preview)

Khi tiến vào Phase 9, các bước sẽ là:

### Stage 1: Architecture Review
- [ ] Audit current architecture vs microservices best practices
- [ ] Document anti-patterns đã identify
- [ ] Design correct architecture (sequence diagrams, service boundaries)

### Stage 2: Refactor Core Issues
- [ ] Fix JWT verification (stateless, no inter-service calls)
- [ ] Implement circuit breaker pattern
- [ ] Add proper health checks per service
- [ ] Multi-stage Dockerfile cho frontend

### Stage 3: Production-Grade Microservices
- [ ] Service mesh exploration (Istio/Linkerd) — optional
- [ ] Distributed tracing (Jaeger/Zipkin)
- [ ] Centralized logging với correlation ID
- [ ] API Gateway upgrade (Kong/Traefik)

### Stage 4: Comparison Study
- [ ] Benchmark monolith vs microservices:
  - Image size (total)
  - Request latency (p50, p95, p99)
  - Resource usage (CPU, memory)
  - Deployment time
  - Operational complexity (số files, services, dependencies)
- [ ] Document findings trong thesis

---

## 🚫 Lock Status

```
File này đánh dấu app/micro/ ở trạng thái FROZEN.
Trong các Phase 1-8, KHÔNG có commit nào được sửa file trong thư mục này
(trừ file README.md này nếu cần update status).

Verification: Có thể check bằng `git log --oneline app/micro/` 
để confirm không có changes ngoài README.
```

---

## 📚 Reference

- **Strangler Fig Pattern** — Martin Fowler: https://martinfowler.com/bliki/StranglerFigApplication.html
- **Microservices Anti-Patterns** — O'Reilly book
- **Distributed Monolith** — Sam Newman blog post