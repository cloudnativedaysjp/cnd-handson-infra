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

# hostsを生成
resource "null_resource" "generate_hosts" {
  count = length(aws_instance.ubuntu_instance)

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      mkdir -p ./generated_hosts

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

