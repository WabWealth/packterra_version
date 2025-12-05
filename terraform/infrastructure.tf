terraform {
  backend "local" {
    path = "/tmp/terraform.tfstate"
  }

  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# ===================================================================
#              SUBNETS & VPC
# ===================================================================
locals {
  subnet_az1 = "subnet-0863d2dc6fd9f284e" # eu-west-1c
  subnet_az2 = "subnet-0e8bdaf0ff5b69fa8" # eu-west-1a
  vpc_id     = "vpc-07e1180f0c948096c"
}

# ===================================================================
#                     NGINX INSTANCE
# ===================================================================
resource "aws_instance" "nginx-node" {
  ami                    = "ami-01936304bea4b25ae"
  instance_type          = "t3.micro"
  subnet_id              = local.subnet_az2
  vpc_security_group_ids = ["sg-08d9b35ca9022bd30"]
  key_name               = "MasterClass2025"

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx git

    systemctl enable nginx
    systemctl start nginx

    cd /tmp
    git clone https://github.com/WabWealth/fruits-veg_market.git
    cp -r /tmp/fruits-veg_market/frontend/* /usr/share/nginx/html/
  EOF

  tags = { Name = "terraform-nginx-node" }
}

# ===================================================================
#                     PYTHON INSTANCES (2)
# ===================================================================
resource "aws_instance" "python-node" {
  count                  = 2
  ami                    = "ami-0fd3ab0418fa90a1c"
  instance_type          = "t3.micro"
  subnet_id              = local.subnet_az1
  vpc_security_group_ids = ["sg-08d9b35ca9022bd30"]
  key_name               = "MasterClass2025"

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y python3 python3-pip git

    cd /home/ec2-user
    git clone https://github.com/WabWealth/fruits-veg_market.git
    cd fruits-veg_market/python_app

    pip3 install -r requirements.txt
    nohup python3 main.py --port 8080 &
  EOF

  tags = { Name = "terraform-python-node-${count.index + 1}" }
}

# ===================================================================
#                     JAVA INSTANCES (2)
# ===================================================================
resource "aws_instance" "java-node" {
  count                  = 2
  ami                    = "ami-043f483fe0bce59d1"
  instance_type          = "t3.micro"
  subnet_id              = local.subnet_az2
  vpc_security_group_ids = ["sg-08d9b35ca9022bd30"]
  key_name               = "MasterClass2025"

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y java-17-amazon-corretto git

    cd /home/ec2-user
    git clone https://github.com/WabWealth/fruits-veg_market.git
    cd fruits-veg_market/java_app

    chmod +x ./mvnw
    ./mvnw clean package

    nohup java -jar target/*.jar --server.port=9090 &
  EOF

  tags = { Name = "terraform-java-node-${count.index + 1}" }
}

# ===================================================================
#                     APPLICATION LOAD BALANCER
# ===================================================================
resource "aws_lb" "alb" {
  name               = "devops-alb"
  load_balancer_type = "application"
  subnets            = [local.subnet_az1, local.subnet_az2]
  security_groups    = ["sg-08d9b35ca9022bd30"]

  tags = { Name = "devops-alb" }
}

# ===================================================================
#                     TARGET GROUPS + HEALTH CHECKS
# ===================================================================

resource "aws_lb_target_group" "nginx_tg" {
  name     = "nginx-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = local.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "python_tg" {
  name     = "python-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = local.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "java_tg" {
  name     = "java-tg"
  port     = 9090
  protocol = "HTTP"
  vpc_id   = local.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# ===================================================================
#                     TARGET GROUP ATTACHMENTS
# ===================================================================

resource "aws_lb_target_group_attachment" "nginx_attach" {
  target_group_arn = aws_lb_target_group.nginx_tg.arn
  target_id        = aws_instance.nginx-node.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "python_attach" {
  count            = 2
  target_group_arn = aws_lb_target_group.python_tg.arn
  target_id        = aws_instance.python-node[count.index].id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "java_attach" {
  count            = 2
  target_group_arn = aws_lb_target_group.java_tg.arn
  target_id        = aws_instance.java-node[count.index].id
  port             = 9090
}

# ===================================================================
#                     LISTENER (PORT 80)
# ===================================================================
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_tg.arn
  }
}

# ===================================================================
#                     PATH ROUTING RULES
# ===================================================================

resource "aws_lb_listener_rule" "python_rule" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.python_tg.arn
  }

  condition {
    path_pattern {
      values = ["/python/*"]
    }
  }
}

resource "aws_lb_listener_rule" "java_rule" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.java_tg.arn
  }

  condition {
    path_pattern {
      values = ["/java/*"]
    }
  }
}