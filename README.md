# Auth Service

Java 21 / Spring Boot authentication service with JWT access and refresh tokens, MySQL and Flyway. The repository also contains **AWS infrastructure-as-code** and a clearly isolated **verification laboratory**.

## What is real, tested and simulated?

| Path | Classification | Purpose |
| --- | --- | --- |
| `src/main/` | **APPLICATION** | Actual authentication API and business logic |
| `src/test/` | **AUTOMATED TEST** | Spring Boot/MySQL integration tests via Testcontainers |
| `infra/` | **INFRASTRUCTURE** | Terraform configuration for AWS resources |
| `.github/workflows/ci-cd.yml` | **LIVE DEPLOYMENT PATH (DEV)** | CI and, on `main`, AWS-capable ECR/Terraform deployment |
| `.github/workflows/policy-validation.yml` | **REAL REPOSITORY CHECK** | Required Terraform and repository-boundary validation |
| `verification/` | **VERIFY / DEMO** | Historical simulations and GitHub/OIDC evidence, manual-only |

**Important:** The current CI/CD targets `dev`, **not a documented production environment**. A green demo is not proof of AWS authorization. A merge to `main` can trigger a real AWS dev deployment. Review [evidence levels](docs/verification-matrix.md) before interpreting a result.

## API

| Method | Path | Authentication | Result |
| --- | --- | --- | --- |
| POST | `/api/auth/register` | Public | Register user; token pair |
| POST | `/api/auth/login` | Public | Token pair |
| POST | `/api/auth/refresh` | Public (refresh token) | New token pair |
| GET | `/api/users/me` | Bearer access token | Current user |
| GET | `/actuator/health/liveness` | Public | Liveness |
| GET | `/actuator/health/readiness` | Public | Readiness |

Responses include `{accessToken, refreshToken, tokenType: "Bearer", expiresIn}`. `expiresIn` is in seconds. Refresh tokens are not accepted as API access tokens. Errors use RFC 9457 `ProblemDetail`.

## Configuration

| Variable | Default | Notes |
| --- | --- | --- |
| `DB_HOST`, `DB_PORT`, `DB_NAME` | `localhost`, `3306`, `auth_service` | MySQL connection |
| `DB_USERNAME`, `DB_PASSWORD` | `root`, empty | Use a secure secret outside local development |
| `JWT_SECRET` | None | Required; at least 32 characters |
| `JWT_ISSUER` | `auth-service` | Token issuer |
| `JWT_ACCESS_TOKEN_TTL` | `15m` | Spring duration format |
| `JWT_REFRESH_TOKEN_TTL` | `7d` | Spring duration format |

## Local development

Prerequisites: JDK 21, Docker, MySQL (via Docker Compose) and Maven wrapper.

```bash
# Start local database and run the app with the local profile
docker compose -f docker/docker-compose.yaml up -d mysql
./mvnw spring-boot:run -Dspring-boot.run.profiles=local

# Alternative: start the whole stack as containers
docker compose -f docker/docker-compose.yaml up --build
```

## Tests and verification

```bash
./mvnw verify                   # Real auth integration tests; requires Docker
terraform fmt -check -recursive infra
python3 -m unittest discover -s verification/ac7 -v  # Simulator model only
```

GitHub Actions `VERIFY ONLY` workflows are manual-only. They do not execute AWS IAM writes. Do not confuse them with the real CI/CD deploy workflow.

## Documentation

- [Architecture](docs/architecture.md)
- [Evidence and verification matrix](docs/verification-matrix.md)
- [Infrastructure and deployment](infra/README.md)
- [Manual verification laboratory](verification/README.md)
- [Contribution and review guidelines](CONTRIBUTING.md)

**Known deployment caveat:** the live workflow's assumed role name differs from the roles defined by Terraform bootstrap, and the bootstrap tfvars still has a repository placeholder. These require a separate AWS-backed verification/fix; see [verification matrix](docs/verification-matrix.md). No claim is made here that a production AWS environment has been checked.
