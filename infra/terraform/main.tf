data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "nexus_ci_sg" {
  name        = "tf-nexus-ci-sg"
  description = "Security Group para Jenkins, SonarQube y herramientas CI"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "SonarQube"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    description = "Salida a internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "tf-nexus-ci-sg"
    Plane = "ci"
  }
}

resource "aws_security_group" "nexus_app_sg" {
  name        = "tf-nexus-app-sg"
  description = "Security Group para NexusMicroservicios"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Frontend HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "API Gateway"
    from_port   = 9080
    to_port     = 9080
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Microservicios Nexus"
    from_port   = 8081
    to_port     = 8083
    protocol    = "tcp"
    security_groups = [
      aws_security_group.nexus_ci_sg.id
    ]
  }

  egress {
    description = "Salida a internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "tf-nexus-app-sg"
    Plane = "app"
  }
}

resource "aws_security_group" "nexus_secops_sg" {
  name        = "tf-nexus-secops-sg"
  description = "Security Group para Wazuh, Prometheus y Grafana"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Wazuh Dashboard"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Wazuh Agent"
    from_port   = 1514
    to_port     = 1515
    protocol    = "tcp"
    security_groups = [
      aws_security_group.nexus_app_sg.id
    ]
  }

  egress {
    description = "Salida a internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "tf-nexus-secops-sg"
    Plane = "secops"
  }
}

resource "aws_instance" "nexus_ci" {
  ami                    = var.ami_id
  instance_type          = "t3.large"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.nexus_ci_sg.id]

  root_block_device {
    volume_size = 60
    volume_type = "gp3"
  }

  tags = {
    Name  = "nexus-ci"
    Plane = "ci"
  }
}

resource "aws_instance" "nexus_app" {
  ami                    = var.ami_id
  instance_type          = "t3.large"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.nexus_app_sg.id]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = {
    Name  = "nexus-app"
    Plane = "app"
  }
}

resource "aws_instance" "nexus_secops" {
  ami                    = var.ami_id
  instance_type          = "t3.xlarge"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.nexus_secops_sg.id]

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  tags = {
    Name  = "nexus-secops"
    Plane = "secops"
  }
}
