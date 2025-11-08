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

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    apt-get update
    apt-get install -y \
    curl vim git unzip gnupg lsb-release ca-certificates dstat jq \
    apt-transport-https software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    groupadd docker || true
    usermod -aG docker ubuntu
    cd /home/ubuntu
    git clone https://github.com/cloudnativedaysjp/cnd-handson.git
    git clone https://github.com/cloudnativedaysjp/cnd-handson-app.git
    git clone https://github.com/cloudnativedaysjp/cnd-handson-infra.git
    chown -R ubuntu:ubuntu /home/ubuntu
    echo "ubuntu user groups after usermod:" >> /var/log/user_data_debug.log
    groups ubuntu >> /var/log/user_data_debug.log
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/usr/local
    mkdir -p /home/ubuntu/.config/code-server
    cat > /home/ubuntu/.config/code-server/config.yaml <<'CONFIG'
    bind-addr: 0.0.0.0:8080
    auth: password
    password: password
    cert: false
    CONFIG
    chown -R ubuntu:ubuntu /home/ubuntu/.config
    systemctl enable --now code-server@ubuntu
  EOF
  tags = {
     Name = "Ubuntu-EC2-student${count.index + 1}"
  }
}