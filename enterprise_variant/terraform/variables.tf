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
  description = "ID kataloga default v Yandex Cloud"
}

variable "yandex_service_account_key_file" {
  type        = string
  default     = "authorized_key.json"
  description = "Put k JSON klyuchu avtorizacii dlya kuruser"
}

variable "my_home_ip" {
  type        = string
  default     = "0.0.0.0/0"
  description = "IP-адрес с какого можно подключаться для портов 3000 и 5601, сейчас разрешено всем "
}

provider "yandex" {
  service_account_key_file = var.yandex_service_account_key_file
  folder_id                = var.yandex_folder_id
  zone                     = "ru-central1-a"
}
