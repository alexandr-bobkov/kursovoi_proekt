## 2.7 Файл `terraform/variables.tf`

variable "yc_cloud_id" {
  type        = string
  description = "Идентификатор облака Yandex Cloud"
}

variable "yc_folder_id" {
  type        = string
  description = "Идентификатор каталога внутри облака"
}

variable "yc_zone_default" {
  type        = string
  default     = "ru-central1-a"
  description = "Основная зона доступности для сервисов"
}

variable "yc_zone_backup" {
  type        = string
  default     = "ru-central1-b"
  description = "Резервная зона доступности для второго веб-сервера"
}

variable "vm_ubuntu_family" {
  type        = string
  default     = "ubuntu-2204-lts"
  description = "Семейство операционной системы для поиска актуального образа"
}

variable "vm_platform_id" {
  type        = string
  default     = "standard-v3"
  description = "Тип используемого процессора (Intel Ice Lake)"
}

variable "vm_core_fraction" {
  type        = number
  default     = 20
  description = "Гарантированная доля CPU в % для прерываемых ВМ (экономия бюджета)"
}

variable "vm_cores" {
  type        = number
  default     = 2
  description = "Количество ядер процессора для виртуальных машин"
}

variable "vm_memory_default" {
  type        = number
  default     = 2
  description = "Объем оперативной памяти в ГБ для стандартных ВМ"
}

variable "vm_memory_large" {
  type        = number
  default     = 4
  description = "Объем оперативной памяти в ГБ для тяжелых ВМ (OpenSearch/Grafana)"
}

variable "disk_type" {
  type        = string
  default     = "network-hdd"
  description = "Тип диска (HDD вместо SSD для экономии)"
}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/id_rsa.pub"
  description = "Путь к вашему публичному SSH-ключу на локальном компьютере"
}

