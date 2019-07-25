
// this tells terraform that we are going to be using AWS as the provider
provider "aws" {
  region                  = "eu-west-1"
  shared_credentials_file = "~/.aws/credentials"
  profile                 =  "own"
}

// The first step in creating a webserver cluster, is to create a Launch Configuration.
// This specifies how each EC2 instance in the Autoscaling Group (ASG) will be setup.
resource "aws_launch_configuration" "webserver_launch_config" {
  image_id        = "ami-0220a3a426e69bb5f"
  instance_type   =   "t2.nano"
  security_groups = [aws_security_group.webserver.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World!" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  // this tells terraform the order of creation/deletion
  lifecycle {
    create_before_destroy = true
  }
}

// After creating the Launch Configuration above, we can go ahead and create the
// Autoscaling Group (ASG):
resource "aws_autoscaling_group" "webserver_asg" {
  launch_configuration  = aws_launch_configuration.webserver_launch_config.id
  availability_zones    = data.aws_availability_zones.all.names

  min_size              = 1
  max_size              = 10

  load_balancers        = [aws_elb.webserver_loadbalancer.name] // tells the ASG to register each instance to the CLB
  health_check_type     = "ELB" // changes the default 'EC2' health-check to the more robust load-balancer health-check

  // each EC2 instance will be tagged with the following name tag
  tag {
    propagate_at_launch = true
    key                 = "Name"
    value               = "webserver-asg"
  }
}

// A data source does not create anything new but rather it fetches some readonly information
// from the provider and makes it available to the rest of the Terraform code
data "aws_availability_zones" "all" { }


// What remains is to create a load-balancer that will manage the traffic between the EC2 webserver
// instances in our ASG cluster. (NOTE: this is the "legacy Classic Load Balancer (CLB) and is used here
// for demonstration purposes. Using the newer Application Load Balancer (ALB) is advised.
resource "aws_elb" "webserver_loadbalancer" {
  name                = "webserver-asg-alb"
  availability_zones  = data.aws_availability_zones.all.names
  security_groups     = [aws_security_group.elb-secgroup.id]

  // we specify a listener to tell the load balancer what port to listen on to what port to
  // route traffic to:
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }

  // the health-check is used by the CLB to monitor the health of each instance. If an instance
  // is unhealthy, it automatically stops to route traffic towards it
  health_check {
    unhealthy_threshold = 2
    healthy_threshold   = 2
    timeout             = 3
    interval            = 30
    target              = "HTTP:${var.server_port}/"
  }
}


// the following creates an AWS Security Group that allows TCP traffic from all IP addresses
// on port 8080
resource "aws_security_group" "webserver" {
  name = "ec2_webserver"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


// Because CLBs do not allow any traffic by default, we need to create a security group that allows traffic:
resource "aws_security_group" "elb-secgroup" {

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow incoming traffic on port 80 from everywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}






/*
// reources are created using the command:
// resource "<PROVIDER>_<TYPE> "<NAME>" { [CONFIG] }
resource "aws_instance" "terraform_vm" {
  ami                     = "ami-0220a3a426e69bb5f"
  instance_type           = "t2.nano"
  vpc_security_group_ids  = [aws_security_group.webserver.id]

  tags = {
    Name  = "terraform_vm"
  }

  // user_data is used to tell the instance commands to run after it is instantiated
  // <<-EOF ... EOF is TF's syntax to allow for multiline comments without adding \n to each line
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello World!" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF
}


// outputs can be used to print certain information to the screen after running `terraform apply`
output "public_ip" {
  value       = aws_instance.terraform_vm.public_ip
  description = "Webserver instance public IP"
}



*/
