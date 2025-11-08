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

resource "local_file" "download_url_csv" {
  content  = local.download_url_csv
  filename = "${path.module}/download_urls.csv"
}
