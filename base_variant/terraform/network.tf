# ==============================================================================
# СЕТЕВАЯ ИНФРАСТРУКТУРА И МЕЖСЕТЕВОЙ ЭКРАН (ZERO TRUST SECURITY GROUPS)
# ==============================================================================

# --- 1. ВИРТУАЛЬНАЯ ЧАСТНАЯ СЕТЬ (VPC) ---
resource "yandex_vpc_network" "main_vpc" {
  name = "coursework-main-network"
}

# Резервирование внешнего статического IP-адреса для балансировщика трафика (ALB)
resource "yandex_vpc_address" "alb_address" {
  name = "static-balancer-address"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

# --- 2. СЕТЕВЫЕ ПОДСЕТИ (SUBNETS) ---
resource "yandex_vpc_subnet" "public_a" {
  name           = "public-subnet-zone-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main_vpc.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}

resource "yandex_vpc_subnet" "public_b" {
  name           = "public-subnet-zone-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main_vpc.id
  v4_cidr_blocks = ["10.0.2.0/24"]
}

resource "yandex_vpc_subnet" "private_a" {
  name           = "private-subnet-zone-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main_vpc.id
  v4_cidr_blocks = ["10.0.10.0/24"]
  route_table_id = yandex_vpc_route_table.nat_route_table.id
}

resource "yandex_vpc_subnet" "private_b" {
  name           = "private-subnet-zone-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main_vpc.id
  v4_cidr_blocks = ["10.0.20.0/24"]
  route_table_id = yandex_vpc_route_table.nat_route_table.id
}

# --- 3. NAT-ШЛЮЗ ДЛЯ ВЫХОДА В ИНТЕРНЕТ И МАРШРУТИЗАЦИЯ ---
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "secure-nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "nat_route_table" {
  name       = "internal-nat-route-table"
  network_id = yandex_vpc_network.main_vpc.id
  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

# ==============================================================================
# 4. СТРОГИЕ ГРУППЫ БЕЗОПАСНОСТИ (КАРКАСЫ ZERO TRUST)
# ==============================================================================

# 1. Группа балансировщика трафика (ALB)
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
  }
}

# 2. Группа Бастион-хоста
resource "yandex_vpc_security_group" "bastion_sg" {
  name       = "bastion-security-group"
  network_id = yandex_vpc_network.main_vpc.id
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Группа сервера Grafana
resource "yandex_vpc_security_group" "grafana_sg" {
  name       = "grafana-security-group"
  network_id = yandex_vpc_network.main_vpc.id
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 3000
  }
  ingress {
    protocol          = "TCP"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. Группа интерфейса логов Kibana
resource "yandex_vpc_security_group" "kibana_sg" {
  name       = "kibana-security-group"
  network_id = yandex_vpc_network.main_vpc.id
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
  }
  ingress {
    protocol       = "TCP"
    description    = "Allow SSH management from local cloud network"
    v4_cidr_blocks = ["10.0.0.0/16"] # ОТКРЫЛ СКВОЗНОЙ ТУННЕЛЬ ВНУТРИ ОБЛАКА
    port           = 22
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5. Группа Веб-серверов бэкенда 
resource "yandex_vpc_security_group" "web_sg" {
  name       = "web-servers-security-group"
  network_id = yandex_vpc_network.main_vpc.id
  
  ingress {
    protocol          = "TCP"
    description       = "Разрешаем HTTP трафик строго от группы балансировщика ALB"
    security_group_id = yandex_vpc_security_group.alb_sg.id
    port              = 80
  }
  ingress {
    protocol          = "TCP"
    description       = "Разрешаем SSH-управление строго от группы Бастион-хоста"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }
  ingress {
    protocol          = "TCP"
    description       = "Разрешаем сбор метрик Node Exporter внутри всей подсети проекта"
    v4_cidr_blocks    = ["10.0.0.0/16"]
    port              = 9100
  }
  ingress {
    protocol          = "TCP"
    description       = "Разрешаем сбор метрик Nginx Exporter внутри всей подсети проекта"
    v4_cidr_blocks    = ["10.0.0.0/16"]
    port              = 9113
  }
  
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# 6. Группа Внутренней Инфраструктуры Управления 
resource "yandex_vpc_security_group" "internal_mgmt_sg" {
  name       = "internal-management-security-group"
  network_id = yandex_vpc_network.main_vpc.id

  # Разрешаем входящий SSH-доступ строго от группы Бастиона
  ingress {
    protocol          = "TCP"
    description       = "Allow SSH management from Bastion security group"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }

  # ЭТАЛОН ИБ: Разрешаем диагностический ICMP-пинг со всей внутренней подсети проекта
  ingress {
    protocol       = "ICMP"
    description    = "Allow ICMP ping diagnostics from local subnet"
    v4_cidr_blocks = ["10.0.0.0/16"]
  }

    # Разрешаем Grafana и Ansible-хелсчекам забирать метрики из Prometheus по внутренней сети
  ingress {
    protocol       = "TCP"
    description    = "Allow internal cloud network to query Prometheus metrics port"
    v4_cidr_blocks = ["10.0.0.0/16"] # сквозное внутреннее доверие
    port           = 9090
  }

  # Разрешаем Kibana, Filebeat-агентам и Ansible слать логи и запросы в Elasticsearch со всей подсети
  ingress {
    protocol       = "TCP"
    description    = "Allow internal cloud network to query Elasticsearch storage port"
    v4_cidr_blocks = ["10.0.0.0/16"] # Объединили правила в один надежный внутренний проход
    port           = 9200
  }

  
  # Разрешаем машинам отвечать на запросы и ходить за пакетами
  egress {
    protocol       = "ANY"
    description    = "Allow outbound traffic to anywhere for package downloads"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}


# --- 5. АВТОМАТИЧЕСКОЕ РЕЗЕРВНОЕ КОПИРОВАНИЕ ДИСКОВ ВСЕХ 7 МАШИН ---
resource "yandex_compute_snapshot_schedule" "infrastructure_backup" {
  name = "daily-infrastructure-snapshots"
  schedule_policy {
    expression = "0 2 * * *"
  }
  snapshot_spec {
    description = "Automated daily backup of full coursework stack"
  }
  retention_period = "168h"
  disk_ids = [
    yandex_compute_instance.bastion.boot_disk.0.disk_id,
    yandex_compute_instance.web_1.boot_disk.0.disk_id,
    yandex_compute_instance.web_2.boot_disk.0.disk_id,
    yandex_compute_instance.prometheus.boot_disk.0.disk_id,
    yandex_compute_instance.opensearch.boot_disk.0.disk_id,
    yandex_compute_instance.grafana.boot_disk.0.disk_id,
    yandex_compute_instance.kibana.boot_disk.0.disk_id
  ]
}
