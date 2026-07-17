# --- БАЛАНСИРОВЩИК ТРАФИКА (ALB) ---

resource "yandex_alb_target_group" "web_tg" {
  name = "site-target-group"
  target {
    subnet_id  = yandex_vpc_subnet.private_a.id
    ip_address = yandex_compute_instance.web_1.network_interface[0].ip_address
  }
  target {
    subnet_id  = yandex_vpc_subnet.private_b.id
    ip_address = yandex_compute_instance.web_2.network_interface[0].ip_address
  }
}

resource "yandex_alb_backend_group" "web_bg" {
  name = "site-backend-group"
  http_backend {
    name             = "http-backend"
    weight           = 1
    port             = 80
    target_group_ids = [yandex_alb_target_group.web_tg.id]
    load_balancing_config {
      panic_threshold = 50
    }    
    healthcheck {
      timeout             = "1s"
      interval            = "3s"
      healthy_threshold   = 2
      unhealthy_threshold = 2
      http_healthcheck {
        path = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "web_router" {
  name = "site-http-router"
}

resource "yandex_alb_virtual_host" "web_vhost" {
  name           = "site-virtual-host"
  http_router_id = yandex_alb_http_router.web_router.id
  route {
    name = "root-path-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_bg.id
        timeout          = "60s"
      }
    }
  }
}

resource "yandex_alb_load_balancer" "web_alb" {
  name               = "site-application-load-balancer"
  network_id         = yandex_vpc_network.main_vpc.id
  security_group_ids = [yandex_vpc_security_group.alb_sg.id]
  
  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.public_a.id
    }
    location {
      zone_id   = "ru-central1-b"
      subnet_id = yandex_vpc_subnet.public_b.id
    }
  }
  
  listener {
    name = "http-listener"
    endpoint {
      address {
        external_ipv4_address {
          address = yandex_vpc_address.alb_address.external_ipv4_address[0].address
        }
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.web_router.id
      }
    }
  }
}

# --- ПЛАНЫ РЕЗЕРВНОГО КОПИРОВАНИЯ (БЭКАПЫ) ---

resource "yandex_compute_snapshot_schedule" "daily_backup" {
  name = "infrastructure-daily-backup-plan"
  schedule_policy {
    expression = "0 2 * * *"
  }
  retention_period = "168h"
  snapshot_spec {
    description = "Daily automatic backup snapshot"
  }
  disk_ids = [
    yandex_compute_instance.bastion.boot_disk[0].disk_id,
    yandex_compute_instance.web_1.boot_disk[0].disk_id,
    yandex_compute_instance.web_2.boot_disk[0].disk_id,
    yandex_compute_instance.prometheus.boot_disk[0].disk_id,
    yandex_compute_instance.opensearch.boot_disk[0].disk_id,
    yandex_compute_instance.grafana_kibana.boot_disk[0].disk_id
  ]
}

# --- ВЫВОД IP АДРЕСОВ В ТЕРМИНАЛ (ОУТПУТЫ) ---

output "IP_BASTION_HOST_PUBLIC" {
  value = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
}
output "IP_BALANCER_SITE_PUBLIC" {
  value = yandex_vpc_address.alb_address.external_ipv4_address[0].address
}
output "IP_GRAFANA_AND_LOGS_PUBLIC" {
  value = yandex_compute_instance.grafana_kibana.network_interface[0].nat_ip_address
}
output "IP_INTERNAL_WEB_SERVER_1" {
  value = yandex_compute_instance.web_1.network_interface[0].ip_address
}
output "IP_INTERNAL_WEB_SERVER_2" {
  value = yandex_compute_instance.web_2.network_interface[0].ip_address
}
output "IP_INTERNAL_PROMETHEUS" {
  value = yandex_compute_instance.prometheus.network_interface[0].ip_address
}
output "IP_INTERNAL_OPENSEARCH_STORAGE" {
  value = yandex_compute_instance.opensearch.network_interface[0].ip_address
}

# --- АВТОМАТИЧЕСКАЯ ГЕНЕРАЦИЯ ИНВЕНТАРЯ ANSIBLE (ФИНАЛЬНЫЙ ЭТАЛОН) ---
resource "local_file" "ansible_inventory" {
  filename = "../ansible/hosts.ini"
  content  = <<EOT
[webservers]
web1 ansible_host=${yandex_compute_instance.web_1.network_interface[0].ip_address}
web2 ansible_host=${yandex_compute_instance.web_2.network_interface[0].ip_address}

[prometheus_host]
prometheus_server ansible_host=${yandex_compute_instance.prometheus.network_interface[0].ip_address}

[logging_storage]
elasticsearch_server ansible_host=${yandex_compute_instance.opensearch.network_interface[0].ip_address}

[public_mgmt]
# ИСПРАВЛЕНО: Обращаемся по внутреннему IP сквозь защищенный туннель Бастиона
grafana_kibana_server ansible_host=${yandex_compute_instance.grafana_kibana.network_interface[0].ip_address}

[all:vars]
ansible_user=debian
ansible_ssh_private_key_file=/home/user/.ssh/id_rsa
ansible_ssh_common_args="-o StrictHostKeyChecking=no -o ProxyJump=debian@${yandex_compute_instance.bastion.network_interface[0].nat_ip_address}"
EOT
}


