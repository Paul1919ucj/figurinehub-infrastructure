terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

# REGIUNEA AWS
provider "aws" {
  region = "eu-central-1"
}

# DETECTAREA AUTOMATA A IP-ULUI PUBLIC
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

# CHEIA SSH
resource "aws_key_pair" "figurinehub" {
  key_name   = "figurinehub-key"
  public_key = file(pathexpand("~/.ssh/figurinehub.pub"))
}

# SECURITY GROUP
resource "aws_security_group" "figurinehub" {
  name        = "figurinehub-web-sg"
  description = "HTTP and SSH access for FigurineHub"

  # HTTP - ACCES PUBLIC
  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH - DOAR DE PE IP-UL TAU
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${trimspace(data.http.my_ip.response_body)}/32"]
  }

  # TRAFIC DE IESIRE
  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "FigurineHub-SecurityGroup"
    Project = "FigurineHub"
  }
}

# CELE DOUA SERVERE EC2
resource "aws_instance" "figurinehub" {
  count = 2

  ami                    = "ami-0e872aee57663ae2d"
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.figurinehub.key_name
  vpc_security_group_ids = [aws_security_group.figurinehub.id]

  root_block_device {
    volume_size = 12
    volume_type = "gp3"
  }

  tags = {
    Name        = count.index == 0 ? "FigurineHub-STAGE" : "FigurineHub-PROD"
    Environment = count.index == 0 ? "stage" : "prod"
    Project     = "FigurineHub"
  }
}

# AFISAREA IP-URILOR DUPA DEPLOYMENT
output "stage_public_ip" {
  value = aws_instance.figurinehub[0].public_ip
}

output "prod_public_ip" {
  value = aws_instance.figurinehub[1].public_ip
}