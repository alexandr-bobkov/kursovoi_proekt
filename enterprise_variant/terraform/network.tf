resource "yandex_vpc_network" "main_vpc" {
  name = "enterprise-main-vpc"
}

resource "yandex_vpc_subnet" "public_a" {
  name           = "enterprise-public-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main_vpc.id
  v4_cidr_blocks = ["10.100.10.0/24"]
}

resource "yandex_vpc_subnet" "private_a" {
  name           = "enterprise-private-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main_vpc.id
  v4_cidr_blocks = ["10.100.20.0/24"]
  route_table_id = yandex_vpc_route_table.nat_route_table.id
}

resource "yandex_vpc_subnet" "private_b" {
  name           = "enterprise-private-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main_vpc.id
  v4_cidr_blocks = ["10.100.30.0/24"]
  route_table_id = yandex_vpc_route_table.nat_route_table.id
}

resource "yandex_vpc_gateway" "nat_gateway" {
  name = "enterprise-nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "nat_route_table" {
  name       = "enterprise-nat-route-table"
  network_id = yandex_vpc_network.main_vpc.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

resource "yandex_vpc_security_group" "bastion_sg" {
  name       = "enterprise-bastion-sg"
  network_id = yandex_vpc_network.main_vpc.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol       = "TCP"
    port           = 5601
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol       = "TCP"
    port           = 3000
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "web_sg" {
  name       = "enterprise-web-sg"
  network_id = yandex_vpc_network.main_vpc.id

  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "internal_mgmt_sg" {
  name       = "enterprise-internal-mgmt-sg"
  network_id = yandex_vpc_network.main_vpc.id

  ingress {
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
