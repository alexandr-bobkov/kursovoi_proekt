# ==============================================================================
# КОНФИГУРАЦИЯ ВИРТУАЛЬНЫХ МАШИН (BASE VARIANT - ФИНАЛ)
# ==============================================================================
data "yandex_compute_image" "debian_13" {
  family = "debian-13"
}

# --- 1. BASTION (SECURE JUMP HOST) ---
resource "yandex_compute_instance" "bastion" {
  name        = "bastion-host"
  hostname    = "bastion-host"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"
  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
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
    security_group_ids = [
      yandex_vpc_security_group.bastion_sg.id,
      yandex_vpc_security_group.internal_mgmt_sg.id
    ]
  }
  metadata = {
    ssh-keys = "debian:${file(var.ssh_public_key_path)}"
  }
}

# --- 2. GRAFANA (СВОЙ БЕЛЫЙ IP ДЛЯ ВЕБ-МОРДЫ) ---
resource "yandex_compute_instance" "grafana" {
  name        = "grafana-host"
  hostname    = "grafana"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"
  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian_13.id
      size     = 15
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true # Выдает белый IP для доступа снаружи
    security_group_ids = [yandex_vpc_security_group.grafana_sg.id]
  }
  metadata = {
    ssh-keys = "debian:${file(var.ssh_public_key_path)}"
  }
}

# --- 3. KIBANA (СВОЙ БЕЛЫЙ IP ДЛЯ ВЕБ-МОРДЫ) ---
resource "yandex_compute_instance" "kibana" {
  name        = "kibana-host"
  hostname    = "kibana"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"
  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian_13.id
      size     = 15
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true # Выдает белый IP для доступа снаружи
    security_group_ids = [yandex_vpc_security_group.kibana_sg.id]
  }
  metadata = {
    ssh-keys = "debian:${file(var.ssh_public_key_path)}"
  }
}

# --- 4. WEB-1 ---
resource "yandex_compute_instance" "web_1" {
  name        = "web-server-1"
  hostname    = "web1"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"
  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
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
    ssh-keys = "debian:${file(var.ssh_public_key_path)}"
  }
}

# --- 5. WEB-2 ---
resource "yandex_compute_instance" "web_2" {
  name        = "web-server-2"
  hostname    = "web2"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"
  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
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
    ssh-keys = "debian:${file(var.ssh_public_key_path)}"
  }
}

# --- 6. PROMETHEUS ---
resource "yandex_compute_instance" "prometheus" {
  name        = "prometheus-server"
  hostname    = "prometheus-server"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"
  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
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
    ssh-keys = "debian:${file(var.ssh_public_key_path)}"
  }
}

# --- 7. ELASTICSEARCH ---
resource "yandex_compute_instance" "opensearch" {
  name                      = "elasticsearch-storage"
  hostname                  = "elasticsearch-storage"
  platform_id               = "standard-v3"
  zone                      = "ru-central1-a"
  allow_stopping_for_update = true
  resources {
    cores         = 2
    memory        = 8
    core_fraction = 20
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
    ssh-keys = "debian:${file(var.ssh_public_key_path)}"
  }
}

# ==============================================================================
# ИНВЕНТАРЬ ANSIBLE И АВТОМАТИЗАЦИЯ (ИСПРАВЛЕННЫЙ ФИНАЛ)
# ==============================================================================
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/hosts.ini"
  content  = <<EOT
[bastion]
bastion_host ansible_host=${yandex_compute_instance.bastion.network_interface.0.nat_ip_address} ansible_user=debian

[webservers]
web1 ansible_host=${yandex_compute_instance.web_1.network_interface.0.ip_address} ansible_user=debian
web2 ansible_host=${yandex_compute_instance.web_2.network_interface.0.ip_address} ansible_user=debian

[logging_storage]
elasticsearch_server ansible_host=${yandex_compute_instance.opensearch.network_interface.0.ip_address} ansible_user=debian

[prometheus_host]
prometheus_server ansible_host=${yandex_compute_instance.prometheus.network_interface.0.ip_address} ansible_user=debian

[grafana_host]
grafana_server ansible_host=${yandex_compute_instance.grafana.network_interface.0.ip_address} ansible_user=debian

[kibana_host]
kibana_server ansible_host=${yandex_compute_instance.kibana.network_interface.0.ip_address} ansible_user=debian

[all:vars]
ansible_user=debian
ansible_ssh_private_key_file=${replace(var.ssh_public_key_path, ".pub", "")}
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

[internal:children]
webservers
logging_storage
prometheus_host
grafana_host
kibana_host

[internal:vars]
# Строка очищена от дублирования. ProxyCommand передаст чистый туннель без сетевого кэша.
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ControlMaster=no -o ControlPersist=no -o ProxyCommand="ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -i ${replace(var.ssh_public_key_path, ".pub", "")} -W %h:%p debian@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'
EOT
}


resource "null_resource" "ansible_auto_run" {
  triggers = {
    inventory_id = local_file.ansible_inventory.id
  }

  depends_on = [
    local_file.ansible_inventory,
    yandex_compute_instance.bastion,
    yandex_compute_instance.grafana,
    yandex_compute_instance.kibana,
    yandex_compute_instance.web_1,
    yandex_compute_instance.web_2,
    yandex_compute_instance.prometheus,
    yandex_compute_instance.opensearch,
    yandex_alb_load_balancer.web_alb
  ]

  provisioner "local-exec" {
    command = "bash ./run_ansible.sh"
  }
}