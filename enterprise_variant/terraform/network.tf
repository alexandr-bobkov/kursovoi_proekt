# ==============================================================================
# СЕТЕВАЯ ТОПОЛОГИЯ CLOUD VPC И ПОДСЕТИ
# ==============================================================================
resource "yandex_vpc_network" "main_vpc" {
  name = "enterprise-main-vpc"
}

resource "yandex_vpc_subnet" "public_a" {
  name           = "enterprise-public-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main_vpc.id
  v4_cidr_blocks = ["10.100.10.0/24"]
}

resource "yandex_vpc_subnet" "public_b" {
  name           = "enterprise-public-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main_vpc.id
  v4_cidr_blocks = ["10.100.15.0/24"]
}

resource "yandex_vpc_subnet" "private_a" {
  name           = "enterprise-private-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main_vpc.id
  v4_cidr_blocks = ["10.100.20.0/24"]
  route_table_id = yandex_vpc_route_table.private_route_table.id
}

resource "yandex_vpc_subnet" "private_b" {
  name           = "enterprise-private-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main_vpc.id
  v4_cidr_blocks = ["10.100.30.0/24"]
  route_table_id = yandex_vpc_route_table.private_route_table.id
}

# ==============================================================================
# ГРУППЫ БЕЗОПАСНОСТИ (ZERO TRUST SECURITY GROUPS)
# ==============================================================================
resource "yandex_vpc_security_group" "alb_sg" {
  name       = "security-group-load-balancer"
  network_id = yandex_vpc_network.main_vpc.id

  # Входящий HTTP от клиентов
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }
  
  # Входящий HTTPS от клиентов
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }
  
  # Внутренние хелсчеки самого балансировщика ALB от Яндекс.Облака (БЕЗ ХАРДКОДА)
  ingress {
    protocol          = "TCP"
    description       = "Allow ALB health checks"
    predefined_target = "loadbalancer_healthchecks"
    port              = 30080
  }

  # Исходящий трафик (разрешаем балансировщику отвечать клиентам и общаться с бекендом)
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "bastion_sg" {
  name       = "bastion-security-group"
  network_id = yandex_vpc_network.main_vpc.id
  
  # Входящий SSH со всего интернета
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  # Исходящий трафик: разрешаем любые ответы клиентам и доступ к серверам внутри
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "grafana_sg" {
  name       = "grafana-security-group"
  network_id = yandex_vpc_network.main_vpc.id
  
  ingress {
    protocol       = "TCP"
    description    = "Разрешить доступ к веб-интерфейсу Grafana"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 3000
  }
  ingress {
    protocol          = "TCP"
    description       = "Разрешить SSH с Bastion"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "kibana_sg" {
  name       = "kibana-security-group"
  network_id = yandex_vpc_network.main_vpc.id
  
  ingress {
    protocol       = "TCP"
    description    = "Разрешить доступ к веб-интерфейсу Kibana"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
  }
  ingress {
    protocol          = "TCP"
    description       = "Разрешить SSH с Bastion"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }
  ingress {
    protocol       = "TCP"
    description    = "Разрешить сбор метрик Prometheus"
    v4_cidr_blocks = ["10.100.0.0/16"]
    port           = 9100
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "web_sg" {
  name       = "web-servers-security-group"
  network_id = yandex_vpc_network.main_vpc.id

  # --- ПРАВИЛА ДЛЯ ПОРТА 80 (HTTP) ---
  ingress {
    protocol          = "TCP"
    description       = "Разрешить HTTP от ALB"
    security_group_id = yandex_vpc_security_group.alb_sg.id
    port              = 80
  }
  ingress {
    protocol       = "TCP"
    description    = "Разрешить хелсчеки и трафик из публичных подсетей ALB (HTTP)"
    v4_cidr_blocks = concat(yandex_vpc_subnet.public_a.v4_cidr_blocks, yandex_vpc_subnet.public_b.v4_cidr_blocks)
    port           = 80
  }
  ingress {
    protocol          = "TCP"
    description       = "Разрешить внутренние хелсчеки Yandex ALB (HTTP)"
    predefined_target = "loadbalancer_healthchecks"
    port              = 80
  }

  # --- ПРАВИЛА ДЛЯ ПОРТА 443 (HTTPS) ---
  ingress {
    protocol          = "TCP"
    description       = "Разрешить HTTPS от ALB"
    security_group_id = yandex_vpc_security_group.alb_sg.id
    port              = 443
  }
  ingress {
    protocol       = "TCP"
    description    = "Разрешить хелсчеки и трафик из публичных подсетей ALB (HTTPS)"
    v4_cidr_blocks = concat(yandex_vpc_subnet.public_a.v4_cidr_blocks, yandex_vpc_subnet.public_b.v4_cidr_blocks)
    port           = 443
  }
  ingress {
    protocol          = "TCP"
    description       = "Разрешить внутренние хелсчеки Yandex ALB (HTTPS)"
    predefined_target = "loadbalancer_healthchecks"
    port              = 443
  }

  # --- ОСТАЛЬНЫЕ ПРАВИЛА ---
  ingress {
    protocol          = "TCP"
    description       = "Разрешить SSH с Bastion"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }
  ingress {
    protocol       = "TCP"
    description    = "Разрешить сбор метрик Node Exporter"
    v4_cidr_blocks = ["10.100.0.0/16"]
    port           = 9100
  }
  ingress {
    protocol       = "TCP"
    description    = "Разрешить сбор метрик Nginx Exporter"
    v4_cidr_blocks = ["10.100.0.0/16"]
    port           = 9113
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "internal_mgmt_sg" {
  name       = "internal-management-security-group"
  network_id = yandex_vpc_network.main_vpc.id

  ingress {
    protocol          = "TCP"
    description       = "Разрешить SSH с Bastion"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }
  ingress {
    protocol       = "TCP"
    description    = "Разрешить запросы Elasticsearch внутри VPC"
    v4_cidr_blocks = ["10.100.0.0/16"]
    port           = 9200
  }
  ingress {
    protocol       = "TCP"
    description    = "Разрешить подключения к PostgreSQL внутри VPC"
    v4_cidr_blocks = ["10.100.0.0/16"]
    port           = 5432
  }
  ingress {
    protocol       = "TCP"
    description    = "Разрешить сбор метрик Prometheus"
    v4_cidr_blocks = ["10.100.0.0/16"]
    port           = 9100
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==============================================================================
# NAT-ШЛЮЗ ДЛЯ ПРИВАТНЫХ ПОДСЕТЕЙ
# ==============================================================================
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "enterprise-nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "private_route_table" {
  name       = "enterprise-private-route-table"
  network_id = yandex_vpc_network.main_vpc.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}