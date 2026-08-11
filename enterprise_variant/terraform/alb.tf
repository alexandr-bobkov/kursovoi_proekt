# ==============================================================================
# КОНФИГУРАЦИЯ APPLICATION LOAD BALANCER (L7) —  HTTPS (ПОРТ 443)
# ==============================================================================

# 1. СТАТИЧЕСКИЙ ВНЕШНИЙ IP-АДРЕС ДЛЯ БАЛАНСИРОВЩИКА
resource "yandex_vpc_address" "web_balancer_ip" {
  name = "enterprise-web-balancer-ip"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

# 2. ЦЕЛЕВАЯ ГРУППА: Привязка динамической Instance Group веб-нод к балансировщику
resource "yandex_alb_target_group" "web_target_group" {
  name = "enterprise-web-target-group"

  dynamic "target" {
    for_each = yandex_compute_instance_group.web_group.instances
    content {
      subnet_id  = target.value.network_interface.0.subnet_id
      ip_address = target.value.network_interface.0.ip_address
    }
  }
}

# 3. БЭКЕНД-ГРУППА: Определение профиля балансировки и хелсчеков
resource "yandex_alb_backend_group" "web_backend_group" {
  name = "enterprise-web-backend-group"

  http_backend {
    name             = "web-http-backend"
    weight           = 1
    port             = 80
    target_group_ids = [yandex_alb_target_group.web_target_group.id]

    healthcheck {
      timeout            = "1s"
      interval           = "3s"
      healthy_threshold  = 2
      unhealthy_threshold = 3
      http_healthcheck {
        path = "/"
      }
    }
  }
}

# 4. HTTP-РОУТЕР: Маршрутизация входящего трафика
resource "yandex_alb_http_router" "web_router" {
  name = "enterprise-web-router"
}

resource "yandex_alb_virtual_host" "web_virtual_host" {
  name           = "web-virtual-host"
  http_router_id = yandex_alb_http_router.web_router.id

  # Единственный маршрут для пересылки HTTPS-трафика на бэкенд-группу
  route {
    name = "root-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_backend_group.id
        timeout          = "60s"
      }
    }
  }
}

# 5. СЛУШАТЕЛИ L7-БАЛАНСИРОВЩИКА (ТОЛЬКО ЗАЩИЩЕННЫЙ ПОРТ 443)
resource "yandex_alb_load_balancer" "web_balancer" {
  name               = "enterprise-web-balancer"
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

  # ЕДИНСТВЕННЫЙ СЛУШАТЕЛЬ (HTTPS): Защищенный пользовательский трафик с SSL Termination
  listener {
    name = "https-listener"
    endpoint {
      address {
        external_ipv4_address {
          address = yandex_vpc_address.web_balancer_ip.external_ipv4_address.0.address
        }
      }
      ports = [443]
    }
    tls {
      default_handler {
        http_handler {
          http_router_id = yandex_alb_http_router.web_router.id
        }
        certificate_ids = [
          data.yandex_cm_certificate.ssl_cert.id
        ]
      }
    }
  }
}

# ДАННЫЕ СЕРТИФИКАТА: Подтягиваем мой рабочий SSL-сертификат из Yandex Cloud
data "yandex_cm_certificate" "ssl_cert" {
  name = "enterprise-alb-ssl-cert-v2" # Имя из панели Yandex Cloud
}
