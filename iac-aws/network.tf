# VPC creation
resource "aws_vpc" "vpc_lambda" {
  cidr_block = "${var.vpc_cdir}"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# IGW for public subnets
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.vpc_lambda.id
}

resource "aws_eip" "ip" {
  vpc      = true
  depends_on = [aws_internet_gateway.default]
}

#NAT Gateway
resource "aws_nat_gateway" "nat_lambda" {
  allocation_id = aws_eip.ip.id
  subnet_id     = "${element(aws_subnet.public_lambda.*.id, 0)}"
  depends_on = [aws_internet_gateway.default,aws_eip.ip,aws_subnet.public_lambda]
}


# One private subnet per AZ
resource "aws_subnet" "private_lambda" {
  vpc_id            = "${aws_vpc.vpc_lambda.id}"
  count             = "${length(split(",", var.azs))}"
  availability_zone = "${element(split(",", var.azs), count.index)}"
  cidr_block        = "10.99.${count.index}.0/24"
}

# One public subnet per AZ
resource "aws_subnet" "public_lambda" {
  vpc_id            = "${aws_vpc.vpc_lambda.id}"
  count             = "${length(split(",", var.azs))}"
  availability_zone = "${element(split(",", var.azs), count.index)}"
  cidr_block        = "10.99.${count.index + 3}.0/24"
}


# Route the public subnets traffic through the IGW
resource "aws_route" "default" {
  route_table_id         = aws_vpc.vpc_lambda.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

# Routing table for private subnet
resource "aws_route_table" "privatert_lambda" {
  vpc_id = aws_vpc.vpc_lambda.id
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = "${aws_route_table.privatert_lambda.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.nat_lambda.id}"
}

resource "aws_route_table_association" "priv_table" {
  count = "${length(aws_subnet.private_lambda)}"
  subnet_id      = "${element(aws_subnet.private_lambda.*.id, count.index)}"
  route_table_id = "${aws_route_table.privatert_lambda.id}"
}

# Creating a security group for EFS:
resource "aws_security_group" "lamda-efs-sg" {
  name = "Lambda_EFS_SG"
  vpc_id = aws_vpc.vpc_lambda.id
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }

  egress {
    from_port   = 0 # Allowing any incoming port
    to_port     = 0 # Allowing any outgoing port
    protocol    = "-1" # Allowing any outgoing protocol
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}
