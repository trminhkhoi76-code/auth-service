# auth-service

Dịch vụ xác thực cấp JWT: Spring Boot 4.1, Java 21, MySQL 8.4, Flyway.

## API

| Method | Path | Auth | Mô tả |
| --- | --- | --- | --- |
| POST | `/api/auth/register` | — | `{email, password}` → `201` + token |
| POST | `/api/auth/login` | — | `{email, password}` → token |
| POST | `/api/auth/refresh` | — | `{refreshToken}` → cặp token mới |
| GET | `/api/users/me` | Bearer access token | Thông tin user hiện tại |
| GET | `/actuator/health/liveness`, `/actuator/health/readiness` | — | Probe cho ECS / ALB |

Response token: `{accessToken, refreshToken, tokenType: "Bearer", expiresIn}`. `expiresIn` tính bằng giây.

- Access token có claim `token_type=ACCESS`, `uid` và `role`. Refresh token có `token_type=REFRESH`.
  Hai loại không dùng thay cho nhau được.
- Email được chuẩn hoá (trim + lowercase).
- Mọi lỗi trả về dạng RFC 9457 `ProblemDetail` (`status`, `title`, `detail`, `instance`).

## Cấu hình (biến môi trường)

| Biến | Mặc định | Ghi chú |
| --- | --- | --- |
| `DB_HOST` / `DB_PORT` / `DB_NAME` | `localhost` / `3306` / `auth_service` | |
| `DB_USERNAME` / `DB_PASSWORD` | `root` / — | |
| `JWT_SECRET` | **bắt buộc** | ≥ 32 ký tự; thiếu thì app không khởi động |
| `JWT_ISSUER` | `auth-service` | |
| `JWT_ACCESS_TOKEN_TTL` / `JWT_REFRESH_TOKEN_TTL` | `15m` / `7d` | Định dạng `Duration` của Spring |

## Chạy local

```bash
# Chỉ chạy MySQL (port 3307), app chạy từ IDE/Maven với profile "local"
docker compose -f docker/docker-compose.yaml up -d mysql
./mvnw spring-boot:run -Dspring-boot.run.profiles=local

# Hoặc chạy cả stack bằng container
docker compose -f docker/docker-compose.yaml up --build
```

Chạy test bằng `./mvnw verify`. Cần Docker vì integration test chạy MySQL thật qua Testcontainers.

## Deploy

ECS Fargate + RDS được quản lý bằng Terraform; GitHub Actions build, push và `terraform apply` khi merge vào `main`.
Xem [infra/README.md](infra/README.md).
