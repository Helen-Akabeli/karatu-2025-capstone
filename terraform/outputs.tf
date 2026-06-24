output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "region" {
  value = var.region
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "assets_bucket_name" {
  value = "bedrock-assets-alt-soe-025-4174"
}

output "mysql_endpoint" {
  value = aws_db_instance.mysql.address
}

output "postgres_endpoint" {
  value = aws_db_instance.postgres.address
}

output "dev_user_access_key" {
  value     = aws_iam_access_key.dev_view.id
  sensitive = true
}

output "dev_user_secret_key" {
  value     = aws_iam_access_key.dev_view.secret
  sensitive = true
}
