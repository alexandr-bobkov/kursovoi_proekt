# ==============================================================================
# СЕТЕВАЯ ТОПОЛОГИЯ CLOUD VPC И КОНФИГУРАЦИЯ ПОДСЕТЕЙ С ТАБЛИЦЕЙ МАРШРУТОВ
# ==============================================================================

resource "yandex_vpc_network" "main_vpc" {
  name = "enterprise-main-vpc"
}

# Резервирование внешнего статического IP-адреса для балансировщика трафика (ALB)
resource "yandex_vpc_address" "alb_address" {
  name = "static-balancer-address"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

# --- КОНФИГУРАЦИЯ ПОДСЕТЕЙ КОНТУРА ---
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
# МЕЖСЕТЕВОЙ ЭКРАН СТРОГОГО РЕЖИМА ENTERPRISE (ZERO TRUST SECURITY GROUPS)
# ==============================================================================

# 1. Группа Балансировщика (ALB) - Открыт только внешнему миру на веб-порты
resource "yandex_vpc_security_group" "alb_sg" {
  name       = "security-group-load-balancer"
  network_id = yandex_vpc_network.main_vpc.id
  
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }
  
  # Балансировщик может слать трафик только в приватные подсети веб-нод бэкенда
  egress {
    protocol       = "TCP"
    v4_cidr_blocks = concat(yandex_vpc_subnet.private_a.v4_cidr_blocks, yandex_vpc_subnet.private_b.v4_cidr_blocks)
    port           = 80
  }
}

# 2. Группа Бастион-хоста - Внешний доступ по SSH для администратора
resource "yandex_vpc_security_group" "bastion_sg" {
  name       = "bastion-security-group"
  network_id = yandex_vpc_network.main_vpc.id
  
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }
  # Разрешаем Бастиону SSH-доступ ко всему внутреннему VPC пространства
  egress {
    protocol       = "TCP"
    v4_cidr_blocks = ["10.100.0.0/16"]
    port           = 22
  }
}

# 3. Группа сервера Grafana & Prometheus (Внешний доступ открыт для проверки)
resource "yandex_vpc_security_group" "grafana_sg" {
  name       = "grafana-security-group"
  network_id = yandex_vpc_network.main_vpc.id
  
  ingress {
    protocol       = "TCP"
    description    = "Allow Grafana Web UI for global inspection"
    v4_cidr_blocks = ["0.0.0.0/0"] 
    port           = 3000
  }
  ingress {
    protocol          = "TCP"
    description       = "Allow management SSH from Bastion ONLY"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
# 4. Группа интерфейса логов Kibana (Внешний доступ открыт для проверки)
resource "yandex_vpc_security_group" "kibana_sg" {
  name       = "kibana-security-group"
  network_id = yandex_vpc_network.main_vpc.id
  
  ingress {
    protocol       = "TCP"
    description    = "Allow Kibana Web UI for global inspection"
    v4_cidr_blocks = ["0.0.0.0/0"] # разрешаем подключение с любого внешнего ip можно указать конкретный адрес
    port           = 5601
  }
  ingress {
    protocol          = "TCP"
    description       = "Allow management SSH from Bastion ONLY"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }
  
  # Разрешаем Prometheus собирать метрики железа с ноды Кибаны
  ingress {
    protocol       = "TCP"
    description    = "Allow Prometheus to scrape internal Kibana node metrics"
    v4_cidr_blocks = ["10.100.0.0/16"]
    port           = 9100
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5. Группа Веб-серверов бэкенда (Dynamic Instance Group)
resource "yandex_vpc_security_group" "web_sg" {
  name       = "web-servers-security-group"
  network_id = yandex_vpc_network.main_vpc.id

  ingress {
    protocol          = "TCP"
    description       = "Allow HTTP traffic from ALB SG ONLY"
    security_group_id = yandex_vpc_security_group.alb_sg.id
    port              = 80
  }
  
  ingress {
    protocol       = "TCP"
    description    = "Allow Healthchecks and Traffic from ALB Public Subnets"
    v4_cidr_blocks = concat(yandex_vpc_subnet.public_a.v4_cidr_blocks, yandex_vpc_subnet.public_b.v4_cidr_blocks)
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow Yandex ALB Internal Healthchecks via Service IPs"
    v4_cidr_blocks = ["198.18.235.0/24", "198.18.248.0/24"]
    port           = 80
  }
  ingress {
    protocol          = "TCP"
    description       = "Allow management SSH from Bastion SG ONLY"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }
  
  # Сбор метрик Node Exporter разрешен для всего интранета
  ingress {
    protocol       = "TCP"
    description    = "Allow Node Exporter metrics scraping from VPC"
    v4_cidr_blocks = ["10.100.0.0/16"]
    port           = 9100
  }
  # Сбор метрик Nginx Exporter разрешен для всего интранета
  ingress {
    protocol       = "TCP"
    description    = "Allow Nginx Exporter metrics scraping from VPC"
    v4_cidr_blocks = ["10.100.0.0/16"]
    port           = 9113
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# 6. Группа Изолированной базы логов и данных (Elasticsearch & СУБД Стенда)
resource "yandex_vpc_security_group" "internal_mgmt_sg" {
  name       = "internal-management-security-group"
  network_id = yandex_vpc_network.main_vpc.id

  ingress {
    protocol          = "TCP"
    description       = "Allow SSH from Bastion ONLY"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }

  # ИСПРАВЛЕНО: Открыт интранет-доступ к Elasticsearch для Filebeat со всех подсетей
  ingress {
    protocol       = "TCP"
    description    = "Allow Elasticsearch queries from Kibana and Filebeat via VPC"
    v4_cidr_blocks = ["10.100.0.0/16"]
    port           = 9200
  }
  
  ingress {
    protocol       = "TCP"
    description    = "Allow Managed PostgreSQL cluster connections from internal VPC"
    v4_cidr_blocks = ["10.100.0.0/16"]
    port           = 5432
  }

  # Разрешаем Prometheus собирать метрики железа с ноды баз данных и логов
  ingress {
    protocol       = "TCP"
    description    = "Allow Prometheus to scrape internal database node metrics"
    v4_cidr_blocks = ["10.100.0.0/16"]
    port           = 9100
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==============================================================================
# NAT-ШЛЮЗ ДЛЯ ВЫХОДА ПРИВАТНЫХ НОД В ИНТЕРНЕТ И ТАБЛИЦА МАРШРУТИЗАЦИИ
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
