# Configure state file for our main tf script.
terraform {
  backend "s3" {
    bucket = "osquerystatebucket"
    key    = "osquerystatebucket/tfstate"
    region = "us-west-1"
  }
}

variable "region" {
  default = "us-west-1"
}

variable "bucket" {
  default = "s3uptycsosquery"
}

variable "binary_k3s" {
  default = "k3s"
}

variable "binary_osquery" {
  default = "osquery.deb"
}

variable "ami" {
  default = "ami-06397100adf427136" # ubuntu
  #default = "ami-04d9dff07d2aa02a3" # container Linux CoreOS
}

# Logging bucket to set up.
variable "logbucket" {
  default = "tfosquerylogbucket"
}

provider "aws" {
  region = "${var.region}"
}

resource "aws_iam_role" "s3osqueryRole" {
  name = "s3osqueryRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "template_file" "s3_public_policy" {
  template = "${file("s3policy.json")}"
  vars {
    bucket_name = "${var.bucket}"
    role = "${aws_iam_role.s3osqueryRole.arn}"
  }
}

resource "aws_s3_bucket" "s3_osquery" {
  bucket = "${var.bucket}"
  acl = "private"
  policy = "${data.template_file.s3_public_policy.rendered}"
  logging {
    target_bucket = "${var.logbucket}"
    target_prefix = "log/"
  }

}

resource "aws_s3_bucket_object" "object_k3s" {
  bucket = "${aws_s3_bucket.s3_osquery.id}"
  key    = "${var.binary_k3s}"
  source = "${var.binary_k3s}"
}

resource "aws_s3_bucket_object" "object_osquery" {
  bucket = "${aws_s3_bucket.s3_osquery.id}"
  key    = "${var.binary_osquery}"
  source = "${var.binary_osquery}"
}

locals {
  s3_url = "${aws_s3_bucket.s3_osquery.bucket}.s3-${var.region}.amazonaws.com"
}

data "template_file" "userdata" {
  template = "${file("userdata.sh")}"
  vars = {
    k3s = "${var.binary_k3s}"
    osquery = "${var.binary_osquery}"
    bucket_name = "${aws_s3_bucket.s3_osquery.bucket}"
    role = "${aws_iam_role.s3osqueryRole.arn}"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id = "vpc-0dd1ac922930e40b2"
  ingress {
    # TLS (change to whatever ports you need)
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    # TLS (change to whatever ports you need)
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    # Opens port 80 for the honey pot.
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

}

resource "aws_iam_instance_profile" "osquery_profile" {
  name = "osquery_profile"
  role = "${aws_iam_role.s3osqueryRole.name}"
}

# automatically deploys to default vpc - 172.31.0.0/16
resource "aws_spot_instance_request" "cheap_worker" {
  ami           = "${var.ami}"
  spot_price    = "0.01"
  instance_type = "t2.micro"
  key_name = "tewest"
  iam_instance_profile = "${aws_iam_instance_profile.osquery_profile.id}"
  associate_public_ip_address = true
  vpc_security_group_ids = ["${aws_security_group.allow_ssh.id}"]
  user_data = "${data.template_file.userdata.rendered}"
  tags = {
    Name = "CheapWorker"
  }
}

output "osquery_role" {
  value = "${aws_iam_role.s3osqueryRole.arn}"
}

output "s3_url" {
  value = "${local.s3_url}"
}
