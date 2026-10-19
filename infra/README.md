# auth-service — hạ tầng AWS (Terraform)

```
infra/
├── bootstrap/   # chạy 1 lần, local, bằng quyền admin — state local
│                #   S3 state bucket · ECR · IAM role cho GitHub Actions (OIDC)
└── app/         # CI apply mỗi lần merge vào main — state trên S3
    │            #   VPC · ALB · ECS Fargate · RDS MySQL 8.4 · SSM secrets · CloudWatch Logs
    └── env/
        ├── dev.tfvars
        └── dev.s3.tfbackend
```

## Kiến trúc

```
Internet ──► ALB (public subnets, :80 / :443)
               │  health check: /actuator/health/readiness
               ▼
           ECS Fargate (public subnets + public IP, không NAT Gateway)
               │  SG: chỉ ALB vào được :8080
               ▼
           RDS MySQL 8.4 (private subnets, không có route ra internet)
               SG: chỉ ECS task vào được :3306
```

- **Không NAT Gateway**: task nằm ở public subnet có public IP để kéo image từ ECR, đọc SSM và ghi log
  (tiết kiệm khoảng $35/tháng). Inbound vẫn chỉ mở cho ALB.
- **Secrets**: DB password và JWT secret do Terraform sinh bằng `ephemeral "random_password"` rồi ghi qua
  thuộc tính write-only (`password_wo`, `value_wo`), nên **không nằm trong state**. ECS inject từ SSM
  SecureString thành `DB_PASSWORD` / `JWT_SECRET`.
- **Deploy an toàn**: mỗi image tag là git SHA, immutable. ECS bật deployment circuit breaker kèm rollback,
  `terraform apply` đợi service ổn định. Workflow còn kiểm tra lại task definition PRIMARY rồi gọi health check.

## Lần đầu: bootstrap

Cần AWS CLI đăng nhập vào account `151062089420` với quyền admin.

```bash
cd infra/bootstrap
# Sửa github_repository trong terraform.tfvars thành "<owner>/<repo>" thật
terraform init
terraform apply
```

Bước này tạo:

| Resource | Tên |
| --- | --- |
| State bucket | `auth-service-tfstate-151062089420` |
| ECR | `auth-service` (tag immutable, giữ 30 image) |
| Role cho PR (`terraform plan`) | `auth-service-github-plan`: ReadOnlyAccess, chỉ trust event `pull_request` |
| Role cho deploy | `auth-service-github-deploy`: PowerUserAccess + quyền IAM giới hạn ở role `auth-service-ecs-*`, chỉ trust branch `main` |

> `infra/bootstrap/terraform.tfstate` bị gitignore. Hãy giữ file này cẩn thận, hoặc chuyển nó lên bucket:
> thêm `backend "s3" { bucket = "auth-service-tfstate-151062089420", key = "bootstrap/terraform.tfstate", region = "ap-northeast-1", use_lockfile = true }`
> vào `versions.tf` rồi chạy `terraform init -migrate-state`.

Workflow đã hard-code account ID và tên role, nên **không cần cấu hình secret/variable nào trên GitHub**.

## Deploy

Push hoặc merge vào `main` sẽ chạy `.github/workflows/ci-cd.yml`:

1. `test`: `mvn verify` (integration test chạy với MySQL 8.4 qua Testcontainers)
2. `terraform-validate`: `fmt -check` + `validate` cả hai stack
3. `build-push`: build `linux/amd64` rồi push `auth-service:<git-sha>` lên ECR (bỏ qua nếu tag đã có, khi re-run)
4. `deploy`: `terraform apply -var image_tag=<git-sha>`, sau đó verify rollout và gọi `/actuator/health/readiness`

Với pull request: chạy `test`, `terraform-validate` và `terraform plan` bằng role read-only. Kết quả plan nằm ở job summary.

Lần apply đầu tiên tạo RDS nên mất khoảng 10–15 phút.

## Chạy Terraform từ máy local

```bash
cd infra/app
terraform init -backend-config=env/dev.s3.tfbackend
terraform plan -var-file=env/dev.tfvars -var "image_tag=$(terraform output -raw image_tag)"
```

## Vận hành

| Việc | Cách làm |
| --- | --- |
| Bật HTTPS | Tạo ACM certificate cùng region rồi điền `certificate_arn` trong `env/dev.tfvars`. HTTP sẽ redirect 301 sang HTTPS |
| Rotate DB password | Tăng `db_password_version`. RDS và SSM nhận password mới, ECS tự redeploy |
| Rotate JWT secret | Tăng `jwt_secret_version`. **Mọi token đã cấp đều mất hiệu lực** |
| Xem log | `aws logs tail /ecs/auth-service-dev --follow` |
| Vào container | Đặt `enable_execute_command = true`, apply, rồi `aws ecs execute-command --cluster auth-service-dev --task <id> --container auth-service --interactive --command sh` |
| Thêm môi trường | Tạo `env/<env>.tfvars` + `env/<env>.s3.tfbackend` (đổi `key`), sau đó thêm job deploy tương ứng |

## Chi phí ước tính (dev, Tokyo)

Khoảng **$50–60/tháng**: ALB (~$18) · RDS `db.t4g.micro` + 20 GB gp3 (~$20) ·
Fargate 0.5 vCPU / 1 GB trên Spot (~$6, On-Demand ~$18) · public IPv4 cho ALB và task (~$11).
Các biến chính ảnh hưởng chi phí: `task_cpu`, `task_memory`, `use_fargate_spot`, `db_instance_class`, `db_multi_az`.
