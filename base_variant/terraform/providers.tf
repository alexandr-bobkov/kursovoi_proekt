terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.100.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "yandex" {
  service_account_key_file = file("authorized_key.json") 
  cloud_id                 = var.yc_cloud_id   
  folder_id                = var.yc_folder_id  
  zone                     = var.yc_zone_default  
}

