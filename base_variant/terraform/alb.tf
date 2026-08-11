# ==============================================================================
# БАЛАНСИРОВЩИК ТРАФИКА (APPLICATION LOAD BALANCER)
# ==============================================================================

resource "yandex_alb_target_group" "web_tg" {
  name = "site-target-group"
  target {
    subnet_id  = yandex_vpc_subnet.private_a.id
    ip_address = yandex_compute_instance.web_1.network_interface.0.ip_address
  }
  target {
    subnet_id  = yandex_vpc_subnet.private_b.id
    ip_address = yandex_compute_instance.web_2.network_interface.0.ip_address
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
          address = yandex_vpc_address.alb_address.external_ipv4_address.0.address
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

# ==============================================================================
# ВЫВОД IP АДРЕСОВ В ТЕРМИНАЛ 
# ==============================================================================

output "IP_BASTION_HOST_PUBLIC" {
  value       = yandex_compute_instance.bastion.network_interface.0.nat_ip_address
  description = "Public IP address for SSH ProxyJump connections"
}

output "IP_BALANCER_SITE_PUBLIC" {
  value       = yandex_vpc_address.alb_address.external_ipv4_address.0.address
  description = "Public IP address of the main website"
}

output "IP_GRAFANA_PUBLIC" {
  value       = yandex_compute_instance.grafana.network_interface.0.nat_ip_address
  description = "Public IP address for accessing Grafana dashboards (Port 3000)"
}

output "IP_KIBANA_PUBLIC" {
  value       = yandex_compute_instance.kibana.network_interface.0.nat_ip_address
  description = "Public IP address for accessing Kibana web interface (Port 5601)"
}

output "IP_INTERNAL_WEB_SERVER_1" {
  value       = yandex_compute_instance.web_1.network_interface.0.ip_address
  description = "Internal private IP of web-node-1"
}

output "IP_INTERNAL_WEB_SERVER_2" {
  value       = yandex_compute_instance.web_2.network_interface.0.ip_address
  description = "Internal private IP of web-node-2"
}

output "IP_INTERNAL_PROMETHEUS" {
  value       = yandex_compute_instance.prometheus.network_interface.0.ip_address
  description = "Internal private IP of Prometheus monitoring core"
}

output "IP_INTERNAL_ELASTICSEARCH_STORAGE" {
  value       = yandex_compute_instance.opensearch.network_interface.0.ip_address
  description = "Internal private IP of Elasticsearch storage host"
}
