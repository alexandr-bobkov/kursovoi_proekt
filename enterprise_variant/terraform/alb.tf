# ==============================================================================
# APPLICATION LOAD BALANCER (L7 HTTPS ПОРТ 443)
# ==============================================================================
resource "yandex_vpc_address" "web_balancer_ip" {
  name = "enterprise-web-balancer-ip"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

resource "yandex_alb_backend_group" "web_backend_group" {
  name = "enterprise-web-backend-group"

  http_backend {
    name             = "web-http-backend"
    weight           = 1
    port             = 80
    target_group_ids = [yandex_compute_instance_group.web_group.application_load_balancer.0.target_group_id]

    healthcheck {
      timeout             = "1s"
      interval            = "3s"
      healthy_threshold   = 2
      unhealthy_threshold = 3
      http_healthcheck {
        path = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "web_router" {
  name = "enterprise-web-router"
}

resource "yandex_alb_virtual_host" "web_virtual_host" {
  name           = "web-virtual-host"
  http_router_id = yandex_alb_http_router.web_router.id

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

data "yandex_cm_certificate" "ssl_cert" {
  name = var.ssl_certificate_name
}
