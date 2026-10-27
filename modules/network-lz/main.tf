# Istanbul Local Zone icin VPC. Uygulama, veritabani ve ALB subnet'leri Local
# Zone'da; VPC'nin kendisi ve (varsayilan olarak) NAT gateway parent region'da.
#
#   LZ public  -> IGW            (ALB)
#   LZ app     -> NAT            (ECS EC2 instance'lari ve task'lar)
#   LZ data    -> NAT            (MariaDB; paket kurulumu ve SSM icin cikis)
#
# NAT varsayilan olarak parent AZ'deki bir public subnet'te durur: Istanbul'da
# NAT gateway destegi teyit edilmedi ve bu her durumda calisir. Bedeli,
# Local Zone'dan internete ve AWS API'lerine giden trafigin Frankfurt
# uzerinden cikmasi. nat_in_local_zone = true bunu LZ'ye alir.

data "aws_availability_zone" "lz" {
  name = var.local_zone

  all_availability_zones = true
}

locals {
  nat_subnet_id = var.nat_in_local_zone ? aws_subnet.public.id : aws_subnet.nat_parent[0].id
}

# Local Zone'lar hesap bazinda acilir. Kapatma API ile yapilamadigi icin
# destroy bu kaynagi yalnizca state'ten cikarir.
resource "aws_ec2_availability_zone_group" "lz" {
  group_name    = data.aws_availability_zone.lz.group_name
  opt_in_status = "opted-in"
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
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = var.local_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-lz-public"
    Tier = "public"
    AZ   = var.local_zone
  }

  depends_on = [aws_ec2_availability_zone_group.lz]
}

resource "aws_subnet" "app" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10)
  availability_zone = var.local_zone

  tags = {
    Name = "${var.name}-lz-app-private"
    Tier = "app-private"
    AZ   = var.local_zone
  }

  depends_on = [aws_ec2_availability_zone_group.lz]
}

resource "aws_subnet" "data" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 20)
  availability_zone = var.local_zone

  tags = {
    Name = "${var.name}-lz-data-private"
    Tier = "data-private"
    AZ   = var.local_zone
  }

  depends_on = [aws_ec2_availability_zone_group.lz]
}

# NAT parent region'dayken onun durdugu subnet. Parent AZ secilir ki ileride
# bir Transit Gateway/VPN attachment'i da ayni AZ'yi kullanabilsin: LZ
# subnet'i attachment'a eklenemiyor, trafik parent AZ uzerinden geciyor.
resource "aws_subnet" "nat_parent" {
  count = var.nat_in_local_zone ? 0 : 1

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 100)
  availability_zone       = data.aws_availability_zone.lz.parent_zone_name
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-parent-public"
    Tier = "public"
    AZ   = data.aws_availability_zone.lz.parent_zone_name
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  # LZ'deki bir NAT'in EIP'si LZ'nin network border group'undan gelmek zorunda.
  network_border_group = var.nat_in_local_zone ? data.aws_availability_zone.lz.network_border_group : null

  tags = { Name = "${var.name}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = local.nat_subnet_id

  tags = { Name = "${var.name}-nat" }

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
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "nat_parent" {
  count = var.nat_in_local_zone ? 0 : 1

  subnet_id      = aws_subnet.nat_parent[0].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = { Name = "${var.name}-private-rt" }
}

resource "aws_route_table_association" "app" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "data" {
  subnet_id      = aws_subnet.data.id
  route_table_id = aws_route_table.private.id
}
