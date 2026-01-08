terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.60"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "${var.region_name}"
  shared_credentials_files   = [ "~/.aws/credentials" ]
}

resource "aws_instance" "sut_server" {
  instance_type 			= var.instance_type
  count 					= var.number_of_instances
  ami 						= var.ami_id
  subnet_id					= var.subnet_id
  vpc_security_group_ids 	= var.vpc_security_group_ids
  placement_group           = var.placement_group_name
  key_name 					= var.ami_key_pair_name
  user_data 				= file(var.userdata_file)

  root_block_device {
    volume_type           	= var.root_block_volume_type
    volume_size           	= var.root_block_volume_size
    iops                  	= var.root_block_iops
    throughput            	= var.root_block_throughput
  }
  
  tags = {
    Name = "${var.instance_name}"
  }
}

resource "aws_instance" "sut_server_1" {
  instance_type 			= var.instance_type
  count 					= var.number_of_instances
  ami 						= var.ami_id
  subnet_id					= var.subnet_id_1
  vpc_security_group_ids 	= var.vpc_security_group_ids
  key_name 					= var.ami_key_pair_name
  user_data 				= file(var.userdata_file)

  root_block_device {
    volume_type           	= var.root_block_volume_type
    volume_size           	= var.root_block_volume_size
    iops                  	= var.root_block_iops
    throughput            	= var.root_block_throughput
  }
  
  tags = {
    Name = "${var.instance_name}"
  }
}

resource "aws_instance" "sut_server_2" {
  instance_type 			= var.instance_type
  count 					= var.number_of_instances
  ami 						= var.ami_id
  subnet_id					= var.subnet_id_2
  vpc_security_group_ids 	= var.vpc_security_group_ids
  key_name 					= var.ami_key_pair_name
  user_data 				= file(var.userdata_file)

  root_block_device {
    volume_type           	= var.root_block_volume_type
    volume_size           	= var.root_block_volume_size
    iops                  	= var.root_block_iops
    throughput            	= var.root_block_throughput
  }
  
  tags = {
    Name = "${var.instance_name}"
  }
}
