# --- ИДЕНТИФИКАТОРЫ ОКРУЖЕНИЯ (Значения автоматически подставятся из файла terraform.tfvars) ---

variable "yc_cloud_id" {
  type        = string
  description = "Идентификатор облака Yandex Cloud"
}

variable "yc_folder_id" {
  type        = string
  description = "Идентификатор  каталога (Folder) внутри облака"
}

# --- СЕТЕВЫЕ ПАРАМЕТРЫ И ЗОНЫ ДОСТУПНОСТИ ---

variable "yc_zone_default" {
  type        = string
  default     = "ru-central1-a"
  description = "Основная зона доступности (дата-центр А) для инфраструктуры"
}

variable "yc_zone_backup" {
  type        = string
  default     = "ru-central1-b"
  description = "Резервная зона доступности (дата-центр Б) для обеспечения отказоустойчивости сайта"
}

# --- ПАРАМЕТРЫ ОПЕРАЦИОННОЙ СИСТЕМЫ И ЖЕЛЕЗА ВМ ---

variable "vm_ubuntu_family" {
  type        = string
  default     = "debian-13" # Жестко фиксируем использование Debian 13 (Trixie)
  description = "Семейство операционной системы для поиска последнего актуального образа в зеркале"
}

variable "vm_platform_id" {
  type        = string
  default     = "standard-v3"
  description = "Тип архитектуры процессора виртуальных машин (Intel Ice Lake)"
}

variable "vm_core_fraction" {
  type        = number
  default     = 20
  description = "Гарантированная доля CPU в % для прерываемых ВМ (снижает стоимость хостинга на 70%)"
}

variable "vm_cores" {
  type        = number
  default     = 2
  description = "Количество ядер процессора, выделяемых на каждую виртуальную машину"
}

variable "vm_memory_default" {
  type        = number
  default     = 2
  description = "Объем оперативной памяти в ГБ для стандартных серверов (Бастион, Web-ноды, Prometheus)"
}

variable "vm_memory_large" {
  type        = number
  default     = 4
  description = "Объем оперативной памяти в ГБ для тяжелых систем (OpenSearch СУБД логов и Grafana)"
}

# --- ХРАНИЛИЩЕ И КЛЮЧИ ДОСТУПА ---

variable "disk_type" {
  type        = string
  default     = "network-hdd"
  description = "Тип сетевого диска ( HDD вместо SSD)"
}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/id_rsa.pub"
  description = "Путь к  публичному SSH-ключу на локальном ПК для организации ProxyJump сквозь Бастион"
}
