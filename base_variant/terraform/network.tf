# --- 1. ВИРТУАЛЬНАЯ СЕТЬ (VPC) ---
resource "yandex_vpc_network" "main_vpc" {
  name = "coursework-main-network"
}

# --- 2. СТАТИЧЕСКИЙ АДРЕС БАЛАНСИРОВЩИКА (Требуется для alb.tf) ---
resource "yandex_vpc_address" "alb_address" {
  name = "static-balancer-address"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

# --- 3. СЕТЕВЫЕ ПОДСЕТИ (SUBNETS) ---

# Публичная подсеть А (Зона А)
resource "yandex_vpc_subnet" "public_a" {
  name           = "public-subnet-zone-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main_vpc.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}

# Публичная подсеть Б (Зона Б - Требуется для alb.tf)
resource "yandex_vpc_subnet" "public_b" {
  name           = "public-subnet-zone-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main_vpc.id
  v4_cidr_blocks = ["10.0.2.0/24"]
}

# Приватная подсеть А (Зона А)
resource "yandex_vpc_subnet" "private_a" {
  name           = "private-subnet-zone-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main_vpc.id
  v4_cidr_blocks = ["10.0.10.0/24"]
  route_table_id = yandex_vpc_route_table.nat_route_table.id
}

# Приватная подсеть Б (Зона Б)
resource "yandex_vpc_subnet" "private_b" {
  name           = "private-subnet-zone-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main_vpc.id
  v4_cidr_blocks = ["10.0.20.0/24"]
  route_table_id = yandex_vpc_route_table.nat_route_table.id
}

# --- 4. NAT-ШЛЮЗ ДЛЯ ВЫХОДА В ИНТЕРНЕТ (ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ) ---
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "secure-nat-gateway" # ВЕРНУЛИ ОРИГИНАЛЬНОЕ ИМЯ ОБЛАКА
  shared_egress_gateway {}    # Добавили обязательный блок шлюза Яндекса
}

resource "yandex_vpc_route_table" "nat_route_table" {
  name       = "internal-nat-route-table"
  network_id = yandex_vpc_network.main_vpc.id
  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

# Группа балансировщика трафика
resource "yandex_vpc_security_group" "alb_sg" {
  name       = "security-group-load-balancer"
  network_id = yandex_vpc_network.main_vpc.id
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

# Сквозное правило для приватной сети (Решает проблему связи ELK и Prometheus)
resource "yandex_vpc_security_group" "internal_shared_rule" {
  name       = "internal-shared-rule"
  network_id = yandex_vpc_network.main_vpc.id
  ingress {
    protocol       = "ANY"
    v4_cidr_blocks = ["10.0.0.0/16"]
    from_port      = 0
    to_port        = 65535
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}


# Группа безопасности для Веб-серверов Nginx (Требуется для vms.tf)
resource "yandex_vpc_security_group" "web_sg" {
  name       = "web-servers-security-group"
  network_id = yandex_vpc_network.main_vpc.id
  ingress {
    protocol          = "TCP"
    security_group_id = yandex_vpc_security_group.alb_sg.id
    port              = 80
  }
  ingress {
    protocol       = "ANY"
    v4_cidr_blocks = ["10.0.0.0/16"]
    from_port      = 0
    to_port        = 65535
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

# Группа безопасности для внутренних серверов управления (Prometheus и Elastic)
resource "yandex_vpc_security_group" "internal_mgmt_sg" {
  name       = "internal-management-security-group"
  network_id = yandex_vpc_network.main_vpc.id
  ingress {
    protocol       = "ANY"
    v4_cidr_blocks = ["10.0.0.0/16"]
    from_port      = 0
    to_port        = 65535
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "bastion_sg" {
  name       = "bastion-security-group"
  network_id = yandex_vpc_network.main_vpc.id

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH from anywhere"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  # Открываю порт 5601 для Kibana внутри ресурса
  ingress {
    protocol       = "TCP"
    description    = "Allow Kibana UI for online-commission"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
  }

  # Открываю порт 3000 для Grafana внутри ресурса
  ingress {
    protocol       = "TCP"
    description    = "Allow Grafana UI for online-commission"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 3000
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

