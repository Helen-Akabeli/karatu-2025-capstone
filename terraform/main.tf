provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "karatu-2025-capstone"
    }
  }
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "project-bedrock-vpc"
  cidr = "10.0.0.0/16"

  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  private_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  public_subnets = [
    "10.0.101.0/24",
    "10.0.102.0/24"
  ]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Project = "karatu-2025-capstone"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.17.2"

  cluster_name    = "project-bedrock-cluster"
  cluster_version = "1.33"

  cluster_endpoint_public_access = true
  enable_irsa = true


  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  vpc_id = module.vpc.vpc_id

  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
  bedrock_nodes = {
    instance_types = ["t3.small"]
    min_size       = 2
    desired_size   = 3
    max_size       = 4

      capacity_type = "ON_DEMAND"
    }
  }

  tags = {
    Project = "karatu-2025-capstone"
  }
}
# =============================================
# RDS Security Group
# =============================================
resource "aws_security_group" "rds" {
  name        = "project-bedrock-rds-sg"
  description = "Allow DB access from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "karatu-2025-capstone"
    Name    = "project-bedrock-rds-sg"
  }
}

# =============================================
# RDS Subnet Group
# =============================================
resource "aws_db_subnet_group" "main" {
  name       = "project-bedrock-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Project = "karatu-2025-capstone"
    Name    = "project-bedrock-db-subnet-group"
  }
}

# =============================================
# RDS MySQL
# =============================================
resource "aws_db_instance" "mysql" {
  identifier             = "bedrock-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "catalog"
  username               = var.mysql_username
  password               = var.mysql_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Project = "karatu-2025-capstone"
    Name    = "bedrock-mysql"
  }
}

# =============================================
# RDS PostgreSQL
# =============================================
resource "aws_db_instance" "postgres" {
  identifier             = "bedrock-postgres"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "orders"
  username               = var.pg_username
  password               = var.pg_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Project = "karatu-2025-capstone"
    Name    = "bedrock-postgres"
  }
}

# =============================================
# Secrets Manager
# =============================================
resource "aws_secretsmanager_secret" "mysql_creds" {
  name = "bedrock/mysql/credentials"
  tags = { Project = "karatu-2025-capstone" }
}

resource "aws_secretsmanager_secret_version" "mysql_creds" {
  secret_id = aws_secretsmanager_secret.mysql_creds.id
  secret_string = jsonencode({
    username = var.mysql_username
    password = var.mysql_password
    host     = aws_db_instance.mysql.address
    port     = 3306
    dbname   = "catalog"
  })
}

resource "aws_secretsmanager_secret" "pg_creds" {
  name = "bedrock/postgres/credentials"
  tags = { Project = "karatu-2025-capstone" }
}

resource "aws_secretsmanager_secret_version" "pg_creds" {
  secret_id = aws_secretsmanager_secret.pg_creds.id
  secret_string = jsonencode({
    username = var.pg_username
    password = var.pg_password
    host     = aws_db_instance.postgres.address
    port     = 5432
    dbname   = "orders"
  })
}

# =============================================
# DynamoDB
# =============================================
resource "aws_dynamodb_table" "carts" {
  name         = "bedrock-carts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Project = "karatu-2025-capstone"
    Name    = "bedrock-carts"
  }
}

# =============================================
# S3 Assets Bucket
# =============================================
resource "aws_s3_bucket" "assets" {
  bucket = "bedrock-assets-alt-soe-025-4174"
  tags = {
    Project = "karatu-2025-capstone"
    Name    = "bedrock-assets-alt-soe-025-4174"
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

# =============================================
# Lambda IAM Role
# =============================================
resource "aws_iam_role" "lambda" {
  name = "bedrock-asset-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = { Project = "karatu-2025-capstone" }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# =============================================
# Lambda Function
# =============================================
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/handler.py"
  output_path = "${path.module}/../lambda/handler.zip"
}

resource "aws_lambda_function" "asset_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "bedrock-asset-processor"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tags = { Project = "karatu-2025-capstone" }
}

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.asset_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.assets.arn
}

resource "aws_s3_bucket_notification" "asset_upload" {
  bucket = aws_s3_bucket.assets.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.asset_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

# =============================================
# Developer IAM User
# =============================================
resource "aws_iam_user" "dev_view" {
  name = "bedrock-dev-view"
  tags = { Project = "karatu-2025-capstone" }
}

resource "aws_iam_user_login_profile" "dev_view" {
  user                    = aws_iam_user.dev_view.name
  password_reset_required = false
}

resource "aws_iam_access_key" "dev_view" {
  user = aws_iam_user.dev_view.name
}

resource "aws_iam_user_policy_attachment" "readonly" {
  user       = aws_iam_user.dev_view.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_user_policy" "dev_s3" {
  name = "bedrock-dev-s3-put"
  user = aws_iam_user.dev_view.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "arn:aws:s3:::bedrock-assets-alt-soe-025-4174/*"
    }]
  })
}

# =============================================
# AWS Load Balancer Controller IAM Role
# =============================================
data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "eks" {
  url = module.eks.cluster_oidc_issuer_url
}

data "aws_iam_policy_document" "aws_lbc_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aws_lbc" {
  name               = "AmazonEKSLoadBalancerControllerRole"
  assume_role_policy = data.aws_iam_policy_document.aws_lbc_assume.json
  tags               = { Project = "karatu-2025-capstone" }
}

resource "aws_iam_role_policy_attachment" "aws_lbc" {
  role       = aws_iam_role.aws_lbc.name
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AWSLoadBalancerControllerIAMPolicyV2"
}
