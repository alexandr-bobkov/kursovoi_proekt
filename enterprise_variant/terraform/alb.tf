# ==============================================================================
# L7 АРХИТЕКТУРА БАЛАНСИРОВКИ (APPLICATION LOAD BALANCER) С ТЕРMИНАЦИЕЙ SSL
# ==============================================================================

resource "yandex_alb_http_router" "web_router" {
  name = "enterprise-web-http-router"
}

resource "yandex_alb_virtual_host" "web_virtual_host" {
  name           = "web-virtual-host"
  http_router_id = yandex_alb_http_router.web_router.id
  route {
    name = "web-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_backend_group.id
        timeout          = "60s"
      }
    }
  }
}

resource "yandex_alb_backend_group" "web_backend_group" {
  name = "enterprise-web-backend-group"

  http_backend {
    name             = "web-http-backend"
    weight           = 1
    port             = 80
    target_group_ids = [yandex_compute_instance_group.web_group.application_load_balancer.0.target_group_id]
    
    load_balancing_config {
      panic_threshold = 50
    }    
    healthcheck {
      timeout             = "1s"
      interval            = "5s"
      healthy_threshold   = 2
      unhealthy_threshold = 3
      http_healthcheck {
        path = "/"
      }
    }
  }
}

# ==============================================================================
# КОНФИГУРАЦИЯ БАЛАНСИРОВЩИКА С СЕТЕВЫМИ ДОСТУПАМИ И СТАТИЧЕСКИМ IP
# ==============================================================================

resource "yandex_alb_load_balancer" "web_balancer" {
  name               = "enterprise-web-balancer-v2"
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

  # СЛУШАТЕЛЬ №1: Классический HTTP (Порт 80)
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

  # СЛУШАТЕЛЬ №2: Защищенный HTTPS (Порт 443) с терминацией SSL
  listener {
    name = "https-listener"
    endpoint {
      address {
        external_ipv4_address {
          address = yandex_vpc_address.alb_address.external_ipv4_address[0].address
        }
      }
      ports = [443]
    }
    tls {
      default_handler {
        certificate_ids = [yandex_cm_certificate.alb_yandex_cert_v2.id]
        http_handler {
          http_router_id = yandex_alb_http_router.web_router.id
        }
      }
    }
  }
}

# ==============================================================================
# АВТОМАТИЧЕСКАЯ ГЕНЕРАЦИЯ САМОПОДПИСАННОГО SSL-СЕРТИФИКАТА 
# ==============================================================================

resource "tls_private_key" "alb_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb_cert" {
  private_key_pem = tls_private_key.alb_key.private_key_pem

  subject {
    common_name  = "enterprise.local-sandbox.internal"
    organization = "Bobkov DevOps Sandbox Lab"
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "yandex_cm_certificate" "alb_yandex_cert_v2" {
  name = "enterprise-alb-ssl-cert-v2"
  self_managed {
    certificate = tls_self_signed_cert.alb_cert.cert_pem
    private_key = tls_private_key.alb_key.private_key_pem
  }
}
