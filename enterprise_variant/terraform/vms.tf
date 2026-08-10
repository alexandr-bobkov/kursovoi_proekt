data "yandex_compute_image" "debian" {
  family = "debian-13"
}

# ==============================================================================
# 1. ХОСТ-БАСТИОН (ЕДИНСТВЕННЫЙ ВНЕШНИЙ SSH ШЛЮЗ КОНТУРА)
# ==============================================================================
resource "yandex_compute_instance" "bastion" {
  name        = "enterprise-bastion"
  zone        = "ru-central1-a"
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian.id
      size     = 15
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.bastion_sg.id]
  }

  metadata = {
    user-data = <<EOT
#cloud-config
users:
  - name: debian
    groups: sudo
    shell: /bin/bash
    sudo: 'ALL=(ALL) NOPASSWD:ALL'
    ssh_authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILAoFf1G4TtCvUyjfoGYU9vzHj+/hM0jAKD830uCiqIW sanya8517@yandex.ru"
EOT
  }
}

# ==============================================================================
# 2. ВЫДЕЛЕННЫЙ СЕРВЕР ВЕБ-ПАНЕЛИ GRAFANA И PROMETHEUS (ВНЕШНИЙ IP ВКЛЮЧЕН)
# ==============================================================================
resource "yandex_compute_instance" "prometheus" {
  name        = "enterprise-grafana-server"
  zone        = "ru-central1-a"
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian.id
      size     = 15
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true # Разрешаем внешний IP для проверки преподавателем
    security_group_ids = [yandex_vpc_security_group.grafana_sg.id]
  }

  metadata = {
    user-data = <<EOT
#cloud-config
users:
  - name: debian
    groups: sudo
    shell: /bin/bash
    sudo: 'ALL=(ALL) NOPASSWD:ALL'
    ssh_authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILAoFf1G4TtCvUyjfoGYU9vzHj+/hM0jAKD830uCiqIW sanya8517@yandex.ru"
EOT
  }
}

# ==============================================================================
# 3. ВЫДЕЛЕННЫЙ СЕРВЕР ВЕБ-ПАНЕЛИ KIBANA (ВНЕШНИЙ IP ВКЛЮЧЕН)
# ==============================================================================
resource "yandex_compute_instance" "kibana_server" {
  name        = "enterprise-kibana-server"
  zone        = "ru-central1-a"
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian.id
      size     = 15
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true # Разрешаем внешний IP для проверки преподавателем
    security_group_ids = [yandex_vpc_security_group.kibana_sg.id]
  }

  metadata = {
    user-data = <<EOT
#cloud-config
users:
  - name: debian
    groups: sudo
    shell: /bin/bash
    sudo: 'ALL=(ALL) NOPASSWD:ALL'
    ssh_authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILAoFf1G4TtCvUyjfoGYU9vzHj+/hM0jAKD830uCiqIW sanya8517@yandex.ru"
EOT
  }
}

# ==============================================================================
# 4. ИЗОЛИРОВАННАЯ БАЗА ДАННЫХ ЛОГОВ (ELASTICSEARCH STORAGE - ИЗОЛИРОВАНА)
# ==============================================================================
resource "yandex_compute_instance" "elasticsearch_storage" {
  name        = "enterprise-elasticsearch-storage"
  zone        = "ru-central1-a"
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian.id
      size     = 20
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false # Оставляем строго приватным по Zero Trust
    security_group_ids = [yandex_vpc_security_group.internal_mgmt_sg.id]
  }

  metadata = {
    user-data = <<EOT
#cloud-config
users:
  - name: debian
    groups: sudo
    shell: /bin/bash
    sudo: 'ALL=(ALL) NOPASSWD:ALL'
    ssh_authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILAoFf1G4TtCvUyjfoGYU9vzHj+/hM0jAKD830uCiqIW sanya8517@yandex.ru"
EOT
  }
}

# ==============================================================================
# 5. ДИНАМИЧЕСКАЯ ГРУППА МАСШТАБИРОВАНИЯ ВЕБ-СЕРВЕРОВ (CORE_FRACTION = 100)
# ==============================================================================
resource "yandex_iam_service_account" "ig_sa" {
  name = "enterprise-ig-service-account"
}

resource "yandex_resourcemanager_folder_iam_member" "ig_editor" {
  folder_id = var.yandex_folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.ig_sa.id}"
}

resource "yandex_compute_instance_group" "web_group" {
  name               = "enterprise-dynamic-web-group"
  folder_id          = var.yandex_folder_id
  service_account_id = yandex_iam_service_account.ig_sa.id

  instance_template {
    name = "web-node-{instance.index}"
    platform_id = "standard-v3"
    resources {
      cores         = 2
      memory        = 2
      core_fraction = 100 # Гарантия процессора 100% для легитимного автоскейлинга по CPU
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = data.yandex_compute_image.debian.id
        size     = 15
      }
    }

    network_interface {
      network_id         = yandex_vpc_network.main_vpc.id
      subnet_ids         = [yandex_vpc_subnet.private_a.id, yandex_vpc_subnet.private_b.id]
      security_group_ids = [yandex_vpc_security_group.web_sg.id]
    }

    metadata = {
      user-data = <<EOT
#cloud-config
users:
  - name: debian
    groups: sudo
    shell: /bin/bash
    sudo: 'ALL=(ALL) NOPASSWD:ALL'
    ssh_authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILAoFf1G4TtCvUyjfoGYU9vzHj+/hM0jAKD830uCiqIW sanya8517@yandex.ru"
EOT
    }
  }

  scale_policy {
    auto_scale {
      initial_size           = 2
      min_zone_size          = 1
      max_size               = 3
      measurement_duration   = 60
      cpu_utilization_target = 70
    }
  }

  allocation_policy {
    zones = ["ru-central1-a", "ru-central1-b"]
  }

  deploy_policy {
    max_unavailable = 1
    max_creating    = 1
    max_expansion   = 1
    max_deleting    = 1
  }

  application_load_balancer {
    target_group_name = "dynamic-web-target-group"
  }

  depends_on = [yandex_resourcemanager_folder_iam_member.ig_editor]
}

# ==============================================================================
# 6. АВТОГЕНЕРАЦИЯ ИНВЕНТАРЯ ANSIBLE (ИТОГОВАЯ ИСПРАВЛЕННАЯ СБОРКА)
# ==============================================================================
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/hosts.ini"
  content  = <<EOT
[bastion]
bastion_host ansible_host=${yandex_compute_instance.bastion.network_interface.0.nat_ip_address} ansible_user=debian ansible_ssh_common_args=""

[kibana_host]
kibana_server ansible_host=${yandex_compute_instance.kibana_server.network_interface.0.ip_address} ansible_user=debian elastic_target_ip=${yandex_compute_instance.elasticsearch_storage.network_interface.0.ip_address}

[grafana_host]
grafana_server ansible_host=${yandex_compute_instance.prometheus.network_interface.0.ip_address} ansible_user=debian postgres_target_ip=${yandex_compute_instance.elasticsearch_storage.network_interface.0.ip_address}

[logging_storage]
elasticsearch_server ansible_host=${yandex_compute_instance.elasticsearch_storage.network_interface.0.ip_address} ansible_user=debian

[web_nodes]
%{ for index, instance in yandex_compute_instance_group.web_group.instances ~}
web-node-${index} ansible_host=${instance.network_interface.0.ip_address} ansible_user=debian
%{ endfor ~}

[all:vars]
# Фиксируем верный тип приватного ключа
ansible_ssh_private_key_file="~/.ssh/id_ed25519"

[internal:children]
kibana_host
grafana_host
logging_storage
web_nodes

[internal:vars]
# Явно передаем путь к ключу внутрь туннеля прыжка, чтобы local-exec в Terraform не зависел от агентов памяти
ansible_ssh_common_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p -l debian ${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}'"
EOT
}







# ==============================================================================
# 7. ИНФРАСТРУКТУРНЫЙ БЭКАП ВСЕХ ДИСКОВ КОНТУРА (SNAPSHOT SCHEDULE)
# ==============================================================================
resource "yandex_compute_snapshot_schedule" "enterprise_backup" {
  name = "enterprise-global-snapshot-schedule"

  schedule_policy {
    expression = "0 2 * * *"
  }

  snapshot_count = 7

  disk_ids = [
    yandex_compute_instance.bastion.boot_disk.0.disk_id,
    yandex_compute_instance.prometheus.boot_disk.0.disk_id,
    yandex_compute_instance.kibana_server.boot_disk.0.disk_id,
    yandex_compute_instance.elasticsearch_storage.boot_disk.0.disk_id # Бэкап Elasticsearch включен!
  ]
}

resource "null_resource" "null_ansible_trigger" {
  depends_on = [local_file.ansible_inventory, yandex_compute_instance_group.web_group]

  provisioner "local-exec" {
    command = "bash run_ansible.sh"
  }
}
