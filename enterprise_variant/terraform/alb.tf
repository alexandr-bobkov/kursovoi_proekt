resource "tls_private_key" "auto_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "auto_cert" {
  private_key_pem = tls_private_key.auto_key.private_key_pem

  subject {
    common_name  = "bobkov-devops.ru"
    organization = "DevOps Enterprise"
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "yandex_cm_certificate" "site_cert" {
  name      = "site-ssl-certificate"
  folder_id = var.yandex_folder_id
  self_managed {
    certificate = tls_self_signed_cert.auto_cert.cert_pem
    private_key = tls_private_key.auto_key.private_key_pem
  }
}

resource "yandex_alb_backend_group" "web_backend_group" {
  name = "web-servers-backend-group"
  http_backend {
    name             = "web-http-backend"
    weight           = 1
    port             = 80
    target_group_ids = [yandex_compute_instance_group.web_group.application_load_balancer[0].target_group_id]
    healthcheck {
      timeout             = "2s"
      interval            = "5s"
      healthy_threshold   = 2
      unhealthy_threshold = 3
      http_healthcheck {
        path = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "web_router" {
  name = "web-servers-http-router"
}

resource "yandex_alb_virtual_host" "web_virtual_host" {
  name           = "web-virtual-host"
  http_router_id = yandex_alb_http_router.web_router.id
  authority      = ["*"]
  route {
    name = "main-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_backend_group.id
      }
    }
  }
}

resource "yandex_alb_load_balancer" "web_balancer" {
  name               = "site-application-load-balancer"
  network_id         = yandex_vpc_network.main_vpc.id
  security_group_ids = [yandex_vpc_security_group.web_sg.id]

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.public_a.id
    }
  }

  listener {
    name = "https-listener"
    endpoint {
      address {
        external_ipv4_address {}
      }
      ports = [443] # ИСПРАВЛЕНО: Четко задан массив с портом 443
    }
    tls {
      default_handler {
        http_handler {
          http_router_id = yandex_alb_http_router.web_router.id
        }
        certificate_ids = [yandex_cm_certificate.site_cert.id]
      }
    }
  }
}

resource "yandex_compute_snapshot_schedule" "daily_backup" {
  name = "daily-infrastructure-backups"
  schedule_policy {
    expression = "0 0 * * *"
  }
  retention_period = "168h" 
  
  disk_ids = [
    yandex_compute_instance.prometheus.boot_disk.0.disk_id,
    yandex_compute_instance.bastion.boot_disk.0.disk_id
  ]
}

output "IP_BALANCER_SITE_PUBLIC" {
  value = yandex_alb_load_balancer.web_balancer.listener.0.endpoint.0.address.0.external_ipv4_address.0.address
}

output "INTERNAL_IP_WEBSERVERS" {
  value = yandex_compute_instance_group.web_group.instances[*].network_interface.0.ip_address
}
