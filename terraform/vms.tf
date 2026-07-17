# Динамический поиск образа операционной системы Debian 13
data "yandex_compute_image" "debian_base" {
  family = var.vm_ubuntu_family # Берет значение "debian-13" из переменных
}

# 4.1 БАСТИОН ХОСТ (Точка входа для SSH Jump)
resource "yandex_compute_instance" "bastion" {
  name        = "bastion-host"
  zone        = var.yc_zone_default
  platform_id = var.vm_platform_id

  resources { 
    cores         = var.vm_cores
    memory        = var.vm_memory_default
    core_fraction = var.vm_core_fraction 
  }

  boot_disk { 
    initialize_params { 
      image_id = data.yandex_compute_image.debian_base.id
      type     = var.disk_type
      size     = 15 
    } 
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true # Включаем внешний IP
    security_group_ids = [yandex_vpc_security_group.bastion_sg.id]
  }

  scheduling_policy { preemptible = true }
  metadata = { ssh-keys = "debian:${file(var.ssh_public_key_path)}" }
}

# 4.2 ВЕБ-СЕРВЕР 1 (В приватной подсети А)
resource "yandex_compute_instance" "web_1" {
  name        = "web-server-1"
  zone        = var.yc_zone_default
  platform_id = var.vm_platform_id

  resources { 
    cores         = var.vm_cores
    memory        = var.vm_memory_default
    core_fraction = var.vm_core_fraction 
  }

  boot_disk { 
    initialize_params { 
      image_id = data.yandex_compute_image.debian_base.id
      type     = var.disk_type
      size     = 15 
    } 
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false # Внешнего IP нет ради безопасности
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }

  scheduling_policy { preemptible = true }
  metadata = { ssh-keys = "debian:${file(var.ssh_public_key_path)}" }
}

# 4.3 ВЕБ-СЕРВЕР 2 (В приватной подсети Б для отказоустойчивости)
resource "yandex_compute_instance" "web_2" {
  name        = "web-server-2"
  zone        = var.yc_zone_backup
  platform_id = var.vm_platform_id

  resources { 
    cores         = var.vm_cores
    memory        = var.vm_memory_default
    core_fraction = var.vm_core_fraction 
  }

  boot_disk { 
    initialize_params { 
      image_id = data.yandex_compute_image.debian_base.id
      type     = var.disk_type
      size     = 15 
    } 
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_b.id
    nat                = false # Внешнего IP нет
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }

  scheduling_policy { preemptible = true }
  metadata = { ssh-keys = "debian:${file(var.ssh_public_key_path)}" }
}

# 4.4 СЕРВЕР МОНИТОРИНГА (PROMETHEUS)
resource "yandex_compute_instance" "prometheus" {
  name        = "prometheus-server"
  zone        = var.yc_zone_default
  platform_id = var.vm_platform_id

  resources { 
    cores         = var.vm_cores
    memory        = var.vm_memory_default
    core_fraction = var.vm_core_fraction 
  }

  boot_disk { 
    initialize_params { 
      image_id = data.yandex_compute_image.debian_base.id
      type     = var.disk_type
      size     = 15 
    } 
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.internal_mgmt_sg.id]
  }

  scheduling_policy { preemptible = true }
  metadata = { ssh-keys = "debian:${file(var.ssh_public_key_path)}" }
}

# 4.5 БАЗА ДАННЫХ ЛОГОВ (ELASTICSEARCH)
resource "yandex_compute_instance" "opensearch" {
  name        = "elasticsearch-logs-server"
  zone        = var.yc_zone_default
  platform_id = var.vm_platform_id

  resources { 
    cores         = var.vm_cores
    memory        = var.vm_memory_large # 4 ГБ ОЗУ под требования базы Elasticsearch
    core_fraction = var.vm_core_fraction 
  }

  boot_disk { 
    initialize_params { 
      image_id = data.yandex_compute_image.debian_base.id
      type     = var.disk_type
      size     = 20 
    } 
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.internal_mgmt_sg.id]
  }

  scheduling_policy { preemptible = true }
  metadata = { ssh-keys = "debian:${file(var.ssh_public_key_path)}" }
}

# 4.6 СЕРВЕР С ВЕБ-ПАНЕЛЯМИ (GRAFANA И KIBANA)
resource "yandex_compute_instance" "grafana_kibana" {
  name        = "grafana-kibana-server"
  zone        = var.yc_zone_default
  platform_id = var.vm_platform_id

  resources { 
    cores         = var.vm_cores
    memory        = var.vm_memory_large # 4 ГБ ОЗУ, чтобы держать два тяжелых веб-интерфейса
    core_fraction = var.vm_core_fraction 
  }

  boot_disk { 
    initialize_params { 
      image_id = data.yandex_compute_image.debian_base.id
      type     = var.disk_type
      size     = 20 
    } 
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true # Включаем внешний IP, чтобы админ мог зайти в панели через браузер
    security_group_ids = [yandex_vpc_security_group.public_ui_sg.id]
  }

  scheduling_policy { preemptible = true }
  metadata = { ssh-keys = "debian:${file(var.ssh_public_key_path)}" }
}

# --- АВТОМАТИЧЕСКИЙ ДЕПЛОЙ ИНФРАСТРУКТУРЫ ANSIBLE НА АВТОПИЛОТЕ ---
resource "null_resource" "ansible_auto_run" {
  # Ждем, пока все 6 виртуальных машин будут физически созданы в облаке Яндекса
  depends_on = [
    yandex_compute_instance.bastion,
    yandex_compute_instance.web_1,
    yandex_compute_instance.web_2,
    yandex_compute_instance.prometheus,
    yandex_compute_instance.opensearch,
    yandex_compute_instance.grafana_kibana
  ]

  # Шаг А: Автоматически создаем и перезаписываем файл hosts.ini актуальными IP-адресами
  provisioner "local-exec" {
    command = <<EOT
cat <<EOF > ../ansible/hosts.ini
[bastion]
bastion_host ansible_host=${yandex_compute_instance.bastion.network_interface[0].nat_ip_address} ansible_user=debian

[webservers]
web1 ansible_host=${yandex_compute_instance.web_1.network_interface[0].ip_address} ansible_user=debian
web2 ansible_host=${yandex_compute_instance.web_2.network_interface[0].ip_address} ansible_user=debian

[logging_storage]
elasticsearch_server ansible_host=${yandex_compute_instance.opensearch.network_interface[0].ip_address} ansible_user=debian

[prometheus_host]
prometheus_server ansible_host=${yandex_compute_instance.prometheus.network_interface[0].ip_address} ansible_user=debian

[public_mgmt]
grafana_kibana_server ansible_host=${yandex_compute_instance.grafana_kibana.network_interface[0].ip_address} ansible_user=debian
EOF
EOT
  }

  # Шаг Б: Даем облаку 15 секунд прогреть SSH-порты серверов и запускаем автоустановку
  provisioner "local-exec" {
    command = "sleep 15 && bash run_ansible.sh"
  }
}
