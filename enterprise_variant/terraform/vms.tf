terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.80"
    }
  }
}

provider "yandex" {
  folder_id                = var.yandex_folder_id
  service_account_key_file = var.yandex_service_account_key_file
}

data "yandex_iam_service_account" "ig_sa" {
  name      = "kuruser"
  folder_id = var.yandex_folder_id
}

data "yandex_compute_image" "debian_13" {
  family = "debian-13"
}

resource "yandex_compute_instance" "bastion" {
  name        = "bastion-host-enterprise"
  hostname    = "bastion-host-enterprise"
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
    security_group_ids = [yandex_vpc_security_group.bastion_sg.id]
    nat                = true
  }
  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "prometheus" {
  name        = "prometheus-server-ent"
  hostname    = "prometheus-server-ent"
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
    security_group_ids = [yandex_vpc_security_group.internal_mgmt_sg.id]
  }
  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "opensearch" {
  name        = "elasticsearch-storage-ent"
  hostname    = "elasticsearch-storage-ent"
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
    subnet_id          = yandex_vpc_subnet.private_a.id # FIXED: Теперь железно в правильной приватной сети!
    security_group_ids = [yandex_vpc_security_group.internal_mgmt_sg.id]
  }
  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance_group" "web_group" {
  name               = "web-servers-instance-group"
  folder_id          = var.yandex_folder_id
  service_account_id = data.yandex_iam_service_account.ig_sa.id

  instance_template {
    name        = "web-node-{instance.index}"
    platform_id = "standard-v3"
    resources {
      cores  = 2
      memory = 2
    }
    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = data.yandex_compute_image.debian_13.id
        size     = 15
      }
    }
    network_interface {
      network_id         = yandex_vpc_network.main_vpc.id
      subnet_ids         = [yandex_vpc_subnet.private_a.id, yandex_vpc_subnet.private_b.id]
      security_group_ids = [yandex_vpc_security_group.web_sg.id, yandex_vpc_security_group.internal_mgmt_sg.id]
    }
    metadata = {
      ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
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
    max_unavailable = 2
    max_expansion   = 1
  }

  application_load_balancer {
    target_group_name = "web-servers-target-group"
  }
}

resource "null_resource" "ansible_auto_run" {
  depends_on = [
    yandex_compute_instance.bastion,
    yandex_compute_instance_group.web_group,
    yandex_compute_instance.prometheus,
    yandex_compute_instance.opensearch
  ]

  triggers = {
    web_nodes_changed = join(",", yandex_compute_instance_group.web_group.instances[*].name)
  }

  provisioner "local-exec" {
    command = <<EOT
cat <<EOF > ../ansible/hosts.ini
[bastion]
bastion_host ansible_host=${yandex_compute_instance.bastion.network_interface.0.nat_ip_address} ansible_user=debian

[webservers]
%{ for instance in yandex_compute_instance_group.web_group.instances ~}
${instance.name} ansible_host=${instance.network_interface.0.ip_address} ansible_user=debian
%{ endfor ~}

[logging_storage]
elasticsearch_server ansible_host=${yandex_compute_instance.opensearch.network_interface.0.ip_address} ansible_user=debian

[prometheus_host]
prometheus_server ansible_host=${yandex_compute_instance.prometheus.network_interface.0.ip_address} ansible_user=debian

[public_mgmt]
grafana_kibana_server ansible_host=${yandex_compute_instance.bastion.network_interface.0.nat_ip_address} ansible_user=debian

[all:vars]
ansible_user=debian
ansible_ssh_private_key_file=/home/user/.ssh/id_rsa
ansible_ssh_common_args="-o StrictHostKeyChecking=no -o ProxyJump=debian@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"

[bastion:vars]
ansible_ssh_common_args="-o StrictHostKeyChecking=no"

[public_mgmt:vars]
ansible_ssh_common_args="-o StrictHostKeyChecking=no"
EOF
EOT
  }

  provisioner "local-exec" {
    command = "sleep 15 && export ANSIBLE_HOST_KEY_CHECKING=False && bash run_ansible.sh"
  }
}
