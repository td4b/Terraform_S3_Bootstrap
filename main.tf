# Configure state file for our main tf script.
terraform {
  backend "s3" {
    bucket = "osquery-statebucket"
    key    = "osquery-statebucket/tfstate"
    region = "us-west-1"
  }
}

variable "region" {
  default = "us-west-1"
}

variable "vpcid" {
  default = "vpc-0dd1ac922930e40b2"
}

variable "subnet" {
  default = "subnet-0603b49c9f38a102a"
}

variable "bucket" {
  default = "s3uptycs-osquery"
}

variable "binary" {
  default = "install.sh"
}

variable "ami" {
  default = "ami-06397100adf427136"
}

# Logging bucket to set up.
variable "logbucket" {
  default = "tfosquery-logbucket"
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

resource "aws_s3_bucket_object" "object" {
  bucket = "${aws_s3_bucket.s3_osquery.id}"
  key    = "${var.binary}"
  source = "${var.binary}"
  etag = "${filemd5("install.sh")}"
}

locals {
  s3_url = "${aws_s3_bucket.s3_osquery.bucket}.s3-${var.region}.amazonaws.com"
}

data "template_file" "userdata" {
  template = "${file("userdata.sh")}"
  vars = {
    key = "${var.binary}"
    bucket_name = "${aws_s3_bucket.s3_osquery.bucket}"
    role = "${aws_iam_role.s3osqueryRole.arn}"
  }
}

resource "aws_security_group" "cluster_comms" {
  name        = "cluster_comms"
  description = "Allow cluster traffic"
  vpc_id = "${var.vpcid}"
  ingress {
    # TLS (change to whatever ports you need)
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    self = true
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id = "${var.vpcid}"
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

resource "aws_spot_instance_request" "master" {
  ami           = "${var.ami}"
  spot_price    = "0.036"
  instance_type = "t2.large"
  subnet_id = "${var.subnet}"
  key_name = "tewest"
  iam_instance_profile = "${aws_iam_instance_profile.osquery_profile.id}"
  associate_public_ip_address = true
  vpc_security_group_ids = ["${aws_security_group.allow_ssh.id}","${aws_security_group.cluster_comms.id}"]
  #user_data = "${data.template_file.userdata.rendered}"
  tags = {
    Name = "k8s.master"
  }
}

# automatically deploys to default vpc - 172.31.0.0/16
resource "aws_spot_instance_request" "node" {
  count = 2
  ami           = "${var.ami}"
  spot_price    = "0.036"
  instance_type = "t2.large"
  subnet_id = "${var.subnet}"
  key_name = "tewest"
  iam_instance_profile = "${aws_iam_instance_profile.osquery_profile.id}"
  associate_public_ip_address = true
  vpc_security_group_ids = ["${aws_security_group.allow_ssh.id}","${aws_security_group.cluster_comms.id}"]
  #user_data = "${data.template_file.userdata.rendered}"
  tags = {
    Name = "k8s.node.${count.index}"
  }
}

output "osquery_role" {
  value = "${aws_iam_role.s3osqueryRole.arn}"
}

output "s3_url" {
  value = "${local.s3_url}"
}
