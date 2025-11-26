# for master
variable "subnet_id" {
	default = "SUBNET_ID_XXX"
}
# for slave
variable "subnet_id_1" {
	default = "SUBNET_ID_XXX"
}

variable "vpc_security_group_ids" {
	default = ["SG_ID_XXX"]
}

variable "placement_group_name" {
	default = "PG_NAME_XXX"
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
	default = "40"
}
variable "root_block_iops" {
	default = "3000"
}
variable "root_block_throughput" {
	default = "125"
}

## 
variable "region_name" {
	description = "Name of the region"
	default = "REGION_NAME_XXX"
}

variable "number_of_instances" {
	description = "number of instances to be created"
	default = 3
}
