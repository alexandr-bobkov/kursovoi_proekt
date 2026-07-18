# ==============================================================================
# КОНФИГУРАЦИЯ ВИРТУАЛЬНЫХ МАШИН ДЛЯ КУРСОВОГО ПРОЕКТА
# Студент: Бобков А.К.
# ==============================================================================

# --- ДИНАМИЧЕСКИЙ СБОР САМОГО СВЕЖЕГО ОБРАЗА DEBIAN 13 ИЗ МАРКЕТПЛЕЙСА ---
data "yandex_compute_image" "debian_13" {
  family = "debian-13"
}

# --- 1. БАСТИОН-ХОСТ (SECURE JUMP HOST) ---
resource "yandex_compute_instance" "bastion" {
  name        = "bastion-host"
  hostname    = "bastion-host"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian_13.id
      size     = 10
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.bastion_sg.id]
  }
  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

# --- 2. ПЕРВЫЙ ОСНОВНОЙ ВЕБ-СЕРВЕР (WEB-1) ---
resource "yandex_compute_instance" "web_1" {
  name        = "web-server-1"
  hostname    = "web1"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian_13.id
      size     = 15
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }
  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

# --- 3. ВТОРОЙ РЕЗЕРВНЫЙ ВЕБ-СЕРВЕР (WEB-2) ---
resource "yandex_compute_instance" "web_2" {
  name        = "web-server-2"
  hostname    = "web2"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian_13.id
      size     = 15
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.private_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }
  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

# --- 4. СЕРВЕР МОНИТОРИНГА PROMETHEUS ---
resource "yandex_compute_instance" "prometheus" {
  name        = "prometheus-server"
  hostname    = "prometheus-server"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian_13.id
      size     = 20
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.internal_mgmt_sg.id]
  }
  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

# --- 5. БАЗА ДАННЫХ ЛОГОВ ELASTICSEARCH ---
resource "yandex_compute_instance" "opensearch" {
  name        = "elasticsearch-storage"
  hostname    = "elasticsearch-storage"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 4
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian_13.id
      size     = 25
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.internal_mgmt_sg.id]
  }
  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

# --- АВТОМАТИЧЕСКИЙ ДЕПЛОЙ ИНФРАСТРУКТУРЫ ANSIBLE НА АВТОПИЛОТЕ ---
resource "null_resource" "ansible_auto_run" {
  depends_on = [
    yandex_compute_instance.bastion,
    yandex_compute_instance.web_1,
    yandex_compute_instance.web_2,
    yandex_compute_instance.prometheus,
    yandex_compute_instance.opensearch
  ]

  # Шаг А: Автоматически создаем hosts.ini, прописывая IP Бастиона и как хост, и как сервер управления
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
grafana_kibana_server ansible_host=${yandex_compute_instance.bastion.network_interface[0].nat_ip_address} ansible_user=debian
EOF
EOT
  }

  # Шаг Б: Даем облаку 15 секунд прогреть SSH-порты серверов и запускаем автоустановку с отключением проверки ключей
  provisioner "local-exec" {
    command = "sleep 15 && export ANSIBLE_HOST_KEY_CHECKING=False && bash run_ansible.sh"
  }
}
