environment = "dev"

# Cost levers for a personal dev environment
task_cpu         = 512
task_memory      = 1024
desired_count    = 1
use_fargate_spot = true

db_instance_class      = "db.t4g.micro"
db_multi_az            = false
db_deletion_protection = false
db_skip_final_snapshot = true

# ACM certificate ARN to enable HTTPS (strongly recommended: the API carries passwords)
certificate_arn = ""

enable_execute_command = true
