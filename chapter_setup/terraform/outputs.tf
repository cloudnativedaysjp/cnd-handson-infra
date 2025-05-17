output "instance_ips" {
  value = aws_instance.ubuntu_instance[*].public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.handson_bucket.bucket
}

output "download_url_api_endpoint" {
  value = "https://${aws_api_gateway_rest_api.download_url_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.download_url_stage.stage_name}/generate_url"
}

output "ec2_instance_names" {
  value = aws_instance.ubuntu_instance[*].tags["Name"]
}

output "private_key_s3_urls" {
  value = [
    for i in range(var.num_students) :
    "s3://${aws_s3_bucket.handson_bucket.bucket}/keys/student${i + 1}.pem"
  ]
}

output "hosts_file_s3_urls" {
  value = [
    for i in range(var.num_students) :
    "s3://${aws_s3_bucket.handson_bucket.bucket}/student${i + 1}/hosts.txt"
  ]
}

output "lambda_function_name" {
  value = aws_lambda_function.generate_download_url_lambda.function_name
}

output "download_url_csv_raw" {
  value       = local.download_url_csv
  description = "Download URL CSV content (raw string, same as CSV file content)"
}
