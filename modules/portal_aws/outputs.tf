output "alb_dns_name" {
  description = "DNS del ALB."
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "ARN del target group."
  value       = aws_lb_target_group.this.arn
}

output "asg_name" {
  description = "Nombre del ASG."
  value       = aws_autoscaling_group.this.name
}

output "launch_template_id" {
  description = "ID del Launch Template."
  value       = aws_launch_template.this.id
}

output "launch_template_version" {
  description = "Versión del Launch Template asignada al ASG."
  value       = aws_launch_template.this.latest_version
}
