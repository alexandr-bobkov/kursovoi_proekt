terraform {
  required_version = ">= 0.13"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.100.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
  }
}

variable "yandex_folder_id" {
  type        = string
  default     = "b1gfnin5k6cbrnbsamn0"
  description = "ID каталога в Yandex Cloud"
}

variable "yandex_service_account_key_file" {
  type        = string
  default     = "authorized_key.json"
  description = "Путь к JSON-ключу авторизации сервисного аккаунта"
}

variable "ssh_public_key" {
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILAoFf1G4TtCvUyjfoGYU9vzHj+/hM0jAKD830uCiqIW 8517@yandex.ru"
  description = "Публичный SSH-ключ для авторизации на нодах"
}

variable "ssh_private_key_path" {
  type        = string
  default     = "~/.ssh/id_ed25519"
  description = "Путь к приватному SSH-ключу для туннелей Ansible"
}

variable "my_home_ip" {
  type        = string
  default     = "0.0.0.0/0"
  description = "IP-адрес/CIDR для доступа к панелям Grafana и Kibana"
}

variable "ssl_certificate_name" {
  type        = string
  default     = "enterprise-alb-ssl-cert-v2"
  description = "Имя SSL-сертификата в Certificate Manager Yandex Cloud"
}

provider "yandex" {
  service_account_key_file = var.yandex_service_account_key_file
  folder_id                = var.yandex_folder_id
  zone                     = "ru-central1-a"
}
