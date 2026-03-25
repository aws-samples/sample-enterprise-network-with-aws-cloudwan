resource "aws_subnet" "subnets" {
  for_each = merge([
    for subnet_key, azs in local.subnet_configs_by_type_and_az : {
      for az, config in azs : "${subnet_key}-${az}" => {
        cidr_block        = config.cidr_block
        availability_zone = az
        public_ip         = config.public_ip
        type              = config.type
        tags              = config.tags
      }
    }
  ]...)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.public_ip

  depends_on = [aws_vpc.main]

  tags = each.value.tags
}

