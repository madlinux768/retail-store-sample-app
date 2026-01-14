# ECS Account Settings
# Sets default Container Insights mode for the AWS account

resource "aws_ecs_account_setting_default" "container_insights" {
  name  = "containerInsights"
  value = "enhanced"
}
