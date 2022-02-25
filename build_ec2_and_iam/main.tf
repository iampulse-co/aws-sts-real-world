# Update these values for your environment
locals {
  # Name of an SSH key in your AWS console
  # If you don't have one, you can make it from the ec2 panel
  ssh_key_name = "KylerSSHKey"
  
  # Name of a subnet ID to put the host into
  # Make sure you can access this host somehow, probably over the internet
  # This means adding the host to a subnet with an Internet gateway
  subnet_id    = "subnet-04284bd0762e3a097"

  # The ID of the security group to assign to your host
  # Your host needs at least one to permit your public IP inbound to your host for SSH'ing in
  # If you don't have any, you can create it from the VPC panel in the console
  security_group_ids = [
    "sg-0235b624f342aba83",
  ]
}


terraform {
  required_version = "~> 1.1.2"

  required_providers {
    aws = {
      version = "~> 4.1.0"
      source  = "hashicorp/aws"
    }
  }
}

# Download AWS provider
provider "aws" {
  region = "us-east-2"
  default_tags {
    tags = {
      Owner = "Kyler"
    }
  }
}

# Identity the newest 
data "aws_ami" "amazon_linux2_5-10kernel-newest" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Build the AWS Instance
resource "aws_instance" "aws_instance" {
  ami                    = data.aws_ami.amazon_linux2_5-10kernel-newest.image_id
  instance_type          = "t2.micro"
  subnet_id              = local.subnet_id
  key_name               = local.ssh_key_name
  vpc_security_group_ids = local.security_group_ids
  iam_instance_profile   = aws_iam_instance_profile.default_iam_instance_profile.id

  tags = {
    Name = "OurEc2Host"
  }

  lifecycle {
    ignore_changes = [
      # Ignore AMI updates when AWS swaps out to newer AMI
      ami,
    ]
  }
}

output "instance_public_ip" {
  value = aws_instance.aws_instance.public_ip
}

resource "aws_iam_instance_profile" "default_iam_instance_profile" {
  name = "Assigned-IAM-Role"
  role = aws_iam_role.assigned_iam_role.id
}

resource "aws_iam_role" "assigned_iam_role" {
  name = "PulseSTS-Assigned-IAM-Role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2008-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "ec2.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
        }
      ]
    }
  )
}

output "assigned_role_name" {
  value = aws_iam_role.assigned_iam_role.name
}

resource "aws_iam_role_policy" "instance_assigned_permissions" {
  name = "Ec2-Instance-Assigned-Permissions"
  role = aws_iam_role.assigned_iam_role.id
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "sts:AssumeRole",
          "Resource" : "${aws_iam_role.assumed_role.arn}"
        }
      ]
    }
  )
}


# Create IAM role to assume
resource "aws_iam_role" "assumed_role" {
  name = "PulseSTS-Deity-AssumedRole"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : "${aws_iam_role.assigned_iam_role.arn}"
          },
          "Action" : "sts:AssumeRole"
        }
      ]
    }
  )
}

output "assumed_role_arn" {
  value = aws_iam_role.assumed_role.arn
}

# Create broad IAM policy with Deity rights
resource "aws_iam_policy" "assumed_role_policy" {
  name = "DeityRole"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "*"
          ],
          "Resource" : [
            "*"
          ],
          "Effect" : "Allow",
          "Sid" : "DeityPermissions",
        },
      ]
  })
}

# Attach IAM assume role to policy
resource "aws_iam_role_policy_attachment" "attach_assumed_role_to_permissions_policy" {
  role       = aws_iam_role.assumed_role.name
  policy_arn = aws_iam_policy.assumed_role_policy.arn
}
