terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.0.0-beta1"
    }
  }
}

provider aws {
  region = "ap-south-2"
}

resource aws_default_vpc default {}

resource aws_security_group flask_sg {
  name        = "flask_sg"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Website"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource aws_instance flask_app {
  ami           = "ami-053a0835435bf4f45"
  instance_type = "t3.micro"
  key_name      = "devops_project"
  security_groups = [aws_security_group.flask_sg.name]

  tags = {
    Name = "FlaskAppServer"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Setting up the Flask app server...'",
      "sudo apt-get update -y",
      "sudo apt-get install -y docker.io",
      "sudo usermod -aG docker $USER",
      "newgrp docker", 
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "docker pull sanders003/flask-auth-app:latest",
      "docker run -d -p 8000:8000 sanders003/flask-auth-app:latest"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./devops_project.pem")
      host        = aws_instance.flask_app.public_dns
    }
  }
}