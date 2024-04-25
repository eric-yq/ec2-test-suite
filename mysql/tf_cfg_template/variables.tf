## 手工设置下面几个变量
variable "subnet_id" {
	default = "subnet-046de201cd71d1cde"
}

variable "vpc_security_group_ids" {
	default = ["sg-0d75ecd997cb2a4b4"]
}

variable "ami_key_pair_name" {
	default = "ericyq-global"
}

## 不要手工修改。
variable "instance_name" {
	default = "INSTANCE_NAME_XXX"
}

variable "instance_type" {
	default = "INSTANCE_TYPE_XXX"
}

variable "ami_id" {
	default = "AMI_ID_XXX"
}

variable "userdata_file" {
	default = "USERDATA_FILE_XXX"
}

## 根卷配置
variable "root_block_volume_type" {
	default = "gp3"
}
variable "root_block_volume_size" {
	default = "200"
}
variable "root_block_iops" {
	default = "15000"
}
variable "root_block_throughput" {
	default = "1000"
}

## 
variable "region_name" {
	description = "Name of the region"
	default = "us-west-2"
}

variable "number_of_instances" {
	description = "number of instances to be created"
	default = 1
}
