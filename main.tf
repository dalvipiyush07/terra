# Configure the AWS Provider
provider "aws" {
  region = "us-west-2"
}

# Create a VPC
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production-vpc"
  }
}

# Create public subnets
resource "aws_subnet" "public" {
  count = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index)
  availability_zone = "us-west-2${count.index + 1}"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Create private subnets
resource "aws_subnet" "private" {
  count = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index + 2)
  availability_zone = "us-west-2${count.index + 1}"
  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "igw"
  }
}

# Create a NAT Gateway
resource "aws_nat_gateway" "this" {
  count = 2
  allocation_id = aws_eip.this[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    Name = "nat-gw-${count.index + 1}"
  }
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "this" {
  count = 2
  vpc = true
  tags = {
    Name = "eip-nat-gw-${count.index + 1}"
  }
}

# Create public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "public-rt"
  }
}

# Create private route table
resource "aws_route_table" "private" {
  count = 2
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "private-rt-${count.index + 1}"
  }
}

# Create public route
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# Create private route
resource "aws_route" "private" {
  count = 2
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id        = aws_nat_gateway.this[count.index].id
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  count = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}