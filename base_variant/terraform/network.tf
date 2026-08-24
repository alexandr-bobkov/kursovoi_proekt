# ==============================================================================
# СЕТЕВАЯ ТОПОЛОГИЯ (ZERO TRUST SECURITY GROUPS)
# ==============================================================================

# --- 1. VPC ---
resource "yandex_vpc_network" "main_vpc" {
  name = "coursework-main-network"
}

resource "yandex_vpc_address" "alb_address" {
  name = "static-balancer-address"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

# --- 2. SUBNETS ---
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

# --- 3. NAT-ШЛЮЗ ---
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
# 4. ГРУППЫ БЕЗОПАСНОСТИ
# ==============================================================================

# 1. ALB
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
    description    = "Allow ALB health checks"
    v4_cidr_blocks = ["198.18.235.0/24", "198.18.248.0/24"]
    port           = 30080
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. Bastion
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

# 3. Grafana
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

# 4. Kibana
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
    v4_cidr_blocks = ["10.0.0.0/16"]
    port           = 22
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5. Web-серверы
resource "yandex_vpc_security_group" "web_sg" {
  name       = "web-servers-security-group"
  network_id = yandex_vpc_network.main_vpc.id

  ingress {
    protocol          = "TCP"
    description       = "HTTP от ALB"
    security_group_id = yandex_vpc_security_group.alb_sg.id
    port              = 80
  }
  ingress {
    protocol          = "TCP"
    description       = "SSH от Bastion"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }
  ingress {
    protocol       = "TCP"
    description    = "Node Exporter"
    v4_cidr_blocks = ["10.0.0.0/16"]
    port           = 9100
  }
  ingress {
    protocol       = "TCP"
    description    = "Nginx Exporter"
    v4_cidr_blocks = ["10.0.0.0/16"]
    port           = 9113
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# 6. Внутреннее управление
resource "yandex_vpc_security_group" "internal_mgmt_sg" {
  name       = "internal-management-security-group"
  network_id = yandex_vpc_network.main_vpc.id

  ingress {
    protocol          = "TCP"
    description       = "Allow SSH management from Bastion"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }
  ingress {
    protocol       = "ICMP"
    description    = "Allow ICMP ping"
    v4_cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    protocol       = "TCP"
    description    = "Prometheus metrics"
    v4_cidr_blocks = ["10.0.0.0/16"]
    port           = 9090
  }
  ingress {
    protocol       = "TCP"
    description    = "Elasticsearch"
    v4_cidr_blocks = ["10.0.0.0/16"]
    port           = 9200
  }
  egress {
    protocol       = "ANY"
    description    = "Allow outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 5. БЭКАПЫ ---
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