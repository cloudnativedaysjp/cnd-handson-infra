terraform {

  cloud {
    organization = "cloudnativedaysjp"

    workspaces {
      name = "cnd-handson-infra"
    }
  }
}
provider "aws" {
  region = "ap-northeast-1" # 適宜変更
}

locals {
  download_url_rows = [
    for i in range(var.num_students) : 
    join(",", [
      "student${i + 1}",
      "https://${aws_api_gateway_rest_api.download_url_api.id}.execute-api.${var.region}.amazonaws.com/${var.stage_name}/generate_url?key=keys/student${i + 1}.pem",
      "https://${aws_api_gateway_rest_api.download_url_api.id}.execute-api.${var.region}.amazonaws.com/${var.stage_name}/generate_url?key=student${i + 1}/hosts.txt"
    ])
  ]

  download_url_csv = join("\n", concat(
    ["student,pem_url,hosts_url"],
    local.download_url_rows
  ))
}

# ハンズオン用VPC
resource "aws_vpc" "handson_vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = { Name = "handson-vpc" }
}

data "aws_availability_zones" "available" {}

# サブネット
resource "aws_subnet" "handson_subnet" {
  vpc_id = aws_vpc.handson_vpc.id
  cidr_block = var.vpc_cidr_block
  map_public_ip_on_launch = true
  availability_zone = element(data.aws_availability_zones.available.names, var.az_index)
  tags = { Name = "handson-subnet" }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "handson_gw" {
  vpc_id = aws_vpc.handson_vpc.id
  tags = { Name = "handson-gw" }
}

# ルートテーブル
resource "aws_route_table" "handson_rt" {
  vpc_id = aws_vpc.handson_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.handson_gw.id
  }
}

# ルートテーブルの関連付け
resource "aws_route_table_association" "handson_rt_assoc" {
  subnet_id = aws_subnet.handson_subnet.id
  route_table_id = aws_route_table.handson_rt.id
}

# セキュリティグループ 
resource "aws_security_group" "handson_sg" {
  vpc_id = aws_vpc.handson_vpc.id
  name = "handson-sg"
}

locals {
  ingress_ports_map = {
    for port in var.handson_ingress_ports : tostring(port) => port
  }
}

resource "aws_security_group_rule" "handson_ingress" {
  for_each = local.ingress_ports_map

  type              = "ingress"
  from_port         = each.value
  to_port           = each.value
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.handson_sg.id
}

resource "aws_security_group_rule" "handson_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # all protocols
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.handson_sg.id
}

# 受講者ごとのSSHキーペアを作成
resource "tls_private_key" "handson_keys" {
  count     = var.num_students
  algorithm = "RSA"
  rsa_bits  = 2048
}

# AWSキーペアに登録
resource "aws_key_pair" "handson_keys" {
  count      = var.num_students
  key_name   = "handson-key-${count.index + 1}"
  public_key = tls_private_key.handson_keys[count.index].public_key_openssh
}

# 秘密鍵をローカルに保存
resource "null_resource" "create_keys_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ./keys"
  }
}

resource "local_file" "private_key" {
  count    = var.num_students
  content  = tls_private_key.handson_keys[count.index].private_key_pem
  filename = "${path.module}/keys/student${count.index + 1}.pem"
}

data "aws_ami" "latest_ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # UbuntuのAMIオーナーID
  filter {
    name   = "name"
    values = [var.ami_name]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# 受講者用 EC2 インスタンス
resource "aws_instance" "ubuntu_instance" {
  count                       = var.num_students
  ami                         = data.aws_ami.latest_ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.handson_keys[count.index].key_name
  subnet_id                   = aws_subnet.handson_subnet.id
  vpc_security_group_ids      = [aws_security_group.handson_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y curl vim git unzip gnupg lsb-release ca-certificates dstat jq
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=\\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \\$(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
  EOF

  tags = {
     Name = "Ubuntu-EC2-student${count.index + 1}"
  }
}

# hostsを生成
resource "null_resource" "generate_hosts" {
  count = length(aws_instance.ubuntu_instance)

  provisioner "local-exec" {
    command = <<EOT
      if [ ${count.index} -eq 0 ]; then mkdir -p ./generated_hosts; fi

      vm_ip="${aws_instance.ubuntu_instance[count.index].public_ip}"
      output_file="./generated_hosts/hosts_student${count.index + 1}.txt"

      > "$output_file"

      while IFS= read -r host; do
        echo "$vm_ip    $host" >> "$output_file"
      done < ./templates/hosts.template
    EOT
  }

  depends_on = [aws_instance.ubuntu_instance]
}

# Lambda関数コードをZIP化
resource "archive_file" "lambda_code_zip" {
  type        = "zip"
  source_file = "scripts/generate_download_url.py"  # ローカルのLambdaコード
  output_path = "${path.module}/generate_download_url.zip"  # ZIP化されたファイルの保存場所
}

# Lambda関数用のIAMロールを作成
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-exec-role"
  
  assume_role_policy = jsonencode({
    Version       = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect    = "Allow",
        Sid       = ""
      }
    ]
  })
}

# Lambda関数を作成
resource "aws_lambda_function" "generate_download_url_lambda" {
  filename         = archive_file.lambda_code_zip.output_path
  function_name    = "GenerateSignedUrl"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "generate_download_url.lambda_handler"
  runtime          = "python3.8"

  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.handson_bucket.bucket
    }
  }
  depends_on = [
  archive_file.lambda_code_zip,
  aws_iam_role.lambda_exec_role
]

}

# s3アクセス用のIAMポリシーを作成
resource "aws_iam_policy" "lambda_s3_access_policy" {
  name        = "lambda-s3-access-policy"
  description = "Allow Lambda function to get objects from S3"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject"
        ],
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}"
        ]
      }
    ]
  })
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate_download_url_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.download_url_api.execution_arn}/*/*"
}

# IAMポリシーをLambda実行ロールにアタッチ
resource "aws_iam_role_policy_attachment" "lambda_s3_access_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_s3_access_policy.arn
}

# CloudWatch用のポリシーを作成
resource "aws_iam_policy" "lambda_cloudwatch_policy" {
  name        = "lambda-cloudwatch-logs-policy"
  description = "Allow Lambda function to write logs to CloudWatch"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_cloudwatch_policy.arn
}

# S3バケットを作成
resource "aws_s3_bucket" "handson_bucket" {
  bucket = var.s3_bucket_name
}

# S3バケットにSSH鍵をアップロード
resource "aws_s3_object" "ssh_key" {
  count    = var.num_students
  bucket   = aws_s3_bucket.handson_bucket.bucket
  key      = "keys/student${count.index + 1}.pem"
  content  = tls_private_key.handson_keys[count.index].private_key_pem
  acl      = "private"
}

# S3バケットにhostsをアップロード
resource "aws_s3_object" "hosts_file" {
  count   = var.num_students
  bucket  = aws_s3_bucket.handson_bucket.bucket
  key     = "student${count.index + 1}/hosts.txt"
  source  = "${path.module}/generated_hosts/hosts_student${count.index + 1}.txt"
  acl     = "private"
  depends_on = [null_resource.generate_hosts]
}


# API Gatewayを設定
resource "aws_api_gateway_rest_api" "download_url_api" {
  name        = "SignedUrlAPI"
  description = "API for generating download URLs"

  binary_media_types = [
    "application/octet-stream",
    "text/plain"
  ]
}

resource "aws_api_gateway_resource" "download_url_resource" {
  rest_api_id = aws_api_gateway_rest_api.download_url_api.id
  parent_id   = aws_api_gateway_rest_api.download_url_api.root_resource_id
  path_part   = "generate_url"
}

resource "aws_api_gateway_method" "get_download_url" {
  rest_api_id   = aws_api_gateway_rest_api.download_url_api.id
  resource_id   = aws_api_gateway_resource.download_url_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.download_url_api.id
  resource_id = aws_api_gateway_resource.download_url_resource.id
  http_method = aws_api_gateway_method.get_download_url.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.generate_download_url_lambda.arn}/invocations"
}

resource "aws_api_gateway_deployment" "download_url_deployment" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.download_url_api.id

  lifecycle {
    create_before_destroy = true
  }
  triggers = {
    redeployment = timestamp()
  }
}

resource "aws_api_gateway_stage" "download_url_stage" {
  rest_api_id   = aws_api_gateway_rest_api.download_url_api.id
  deployment_id = aws_api_gateway_deployment.download_url_deployment.id
  stage_name    = "default"
}

resource "local_file" "download_url_csv" {
  content  = local.download_url_csv
  filename = "${path.module}/download_urls.csv"
}
