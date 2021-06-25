###############################################################################
# AWS VPC
###############################################################################

variable "aws_region" {
  default = "eu-west-1"
}


variable "azs" {
  default = "eu-west-1a,eu-west-1b,eu-west-1c"
}


variable "vpc_name" {
  default = "vpc_lambda"
}

variable "vpc_cdir" {
  default = "10.99.0.0/16"
}

#data "aws_subnet_ids" "vpc_subnet_ids" {
#  vpc_id = aws_vpc.vpc_lambda.id
#}

#data "aws_subnet" "get_sub_ids" {
#  count = "${length(data.aws_subnet_ids.vpc_subnet_ids.ids)}"
#  id    = "${tolist(data.aws_subnet_ids.vpc_subnet_ids.ids)[count.index]}"
#}

###############################################################################
# EFS
###############################################################################


variable "uid" {
  default = 1000
}

variable "permissions" {
  default = 755
}

###############################################################################
# IAM
###############################################################################


variable "iam_policy_arn" {
  description = "IAM Policy to be attached to role"
  type = list(string)
  default = ["arn:aws:iam::aws:policy/AWSLambdaExecute", "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole","arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess"]
}
