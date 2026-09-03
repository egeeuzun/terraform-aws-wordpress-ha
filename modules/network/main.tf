locals {
  nat_gateway_id_by_az = {
    for idx, subnet in var.public_subnet_map : subnet.az => aws_nat_gateway.this[idx].id
  }

  public_azs = [for subnet in var.public_subnet_map : subnet.az]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-igw" }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_map)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_map[count.index].cidr
  availability_zone       = var.public_subnet_map[count.index].az
  map_public_ip_on_launch = true

  tags = {
    Name = var.public_subnet_map[count.index].name
    Tier = "public"
    AZ   = var.public_subnet_map[count.index].az
  }
}

resource "aws_subnet" "app" {
  count             = length(var.app_subnet_map)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.app_subnet_map[count.index].cidr
  availability_zone = var.app_subnet_map[count.index].az

  tags = {
    Name = var.app_subnet_map[count.index].name
    Tier = "app-private"
    AZ   = var.app_subnet_map[count.index].az
  }
}

resource "aws_subnet" "data" {
  count             = length(var.data_subnet_map)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.data_subnet_map[count.index].cidr
  availability_zone = var.data_subnet_map[count.index].az

  tags = {
    Name = var.data_subnet_map[count.index].name
    Tier = "data-private"
    AZ   = var.data_subnet_map[count.index].az
  }
}

resource "aws_eip" "nat" {
  count  = length(var.public_subnet_map)
  domain = "vpc"

  tags = { Name = "${var.name}-nat-eip-${var.public_subnet_map[count.index].az}" }
}

resource "aws_nat_gateway" "this" {
  count         = length(var.public_subnet_map)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = { Name = "${var.name}-nat-${var.public_subnet_map[count.index].az}" }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${var.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app" {
  count  = length(var.app_subnet_map)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = local.nat_gateway_id_by_az[var.app_subnet_map[count.index].az]
  }

  tags = { Name = "${var.name}-app-rt-${var.app_subnet_map[count.index].az}" }

  lifecycle {
    precondition {
      condition     = contains(local.public_azs, var.app_subnet_map[count.index].az)
      error_message = "App subnet'in bulundugu AZ'de public subnet (dolayisiyla NAT gateway) yok. Her app AZ'si icin public_subnet_map'e ayni AZ'de bir kayit ekleyin."
    }
  }
}

resource "aws_route_table_association" "app" {
  count          = length(aws_subnet.app)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-data-rt" }
}

resource "aws_route_table_association" "data" {
  count          = length(aws_subnet.data)
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}
