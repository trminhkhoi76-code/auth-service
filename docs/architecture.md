# Auth Service architecture

## Application (real implementation)

Java 21 / Spring Boot REST API provides registration, login, refresh and current-user lookup. Spring Security guards authenticated endpoints; signed JWT access and refresh tokens are distinct. Users are stored in MySQL, and schema versioning is managed by Flyway.

```text
Client --> /api/auth/* --> AuthController --> AuthService --> UserRepository --> MySQL
            |                     |
            +---- SecurityConfig / JwtAuthenticationFilter / JwtService
```

The integration suite under `src/test/` uses MySQL through Testcontainers. This is a test implementation, not a separate production service.

## Infrastructure (declarative, AWS-capable)

- `infra/bootstrap/`: state bucket, ECR and GitHub OIDC IAM roles.
- `infra/app/`: VPC, ALB, ECS Fargate, RDS and secrets.
- `.github/workflows/ci-cd.yml`: PR tests and plan; `main` push can build and deploy to `dev`.
- `.github/workflows/policy-validation.yml`: required repository-side validation.
- `verification/`: manual experiments, **not** application code or deploy configuration.

Do not confuse the configured `dev` deploy path with a separately configured production environment. Production deployment is not represented here.

## Security and operational boundaries

The infrastructure documentation describes intended AWS roles, not observed effective permissions. A role-name mismatch between Terraform bootstrap and CI/CD needs separate remediation before security claims are made. See [verification matrix](verification-matrix.md) and [infrastructure operations](../infra/README.md).
