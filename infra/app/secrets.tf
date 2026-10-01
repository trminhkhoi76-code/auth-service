# Secrets are generated with *ephemeral* random_password and written through write-only
# attributes (password_wo / value_wo): the plaintext is never stored in the Terraform state.
# Within one apply the ephemeral value is opened once, so RDS and SSM receive the same password.

ephemeral "random_password" "db" {
  length = 32
  # RDS forbids / @ " and spaces
  override_special = "!#%^*-_=+"
}

ephemeral "random_password" "jwt" {
  length  = 64
  special = false
}

resource "aws_ssm_parameter" "db_password" {
  name             = "/${var.project_name}/${var.environment}/db-password"
  description      = "RDS master password, injected into ECS as DB_PASSWORD"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.db.result
  value_wo_version = var.db_password_version
}

resource "aws_ssm_parameter" "jwt_secret" {
  name             = "/${var.project_name}/${var.environment}/jwt-secret"
  description      = "HMAC key for signing JWTs, injected into ECS as JWT_SECRET"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.jwt.result
  value_wo_version = var.jwt_secret_version
}
