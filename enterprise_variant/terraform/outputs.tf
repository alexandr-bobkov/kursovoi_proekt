# ==============================================================================
# ВЫХОДНЫЕ ПЕРЕМЕННЫЕ ИНФРАСТРУКТУРЫ КУРСОВОГО ПРОЕКТА С УКАЗАНИЕМ ПОРТОВ
# ==============================================================================

output "A_PRODUCTION_SECURE_URL" {
  description = "Защищенный веб-ресурс (HTTPS / Порт 443)"
  value       = "https://${yandex_vpc_address.web_balancer_ip.external_ipv4_address.0.address}/"
}

output "B_BASTION_PUBLIC_IP" {
  description = "Команда подключения к Бастион-хосту для SSH (Порт 22)"
  value       = "ssh debian@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"
}

# ------------------------------------------------------------------------------
# ВНЕШНИЕ ССЫЛКИ НА ПАНЕЛИ УПРАВЛЕНИЯ (С ПОРТАМИ СЛУЖБ)
# ------------------------------------------------------------------------------

output "C_ENTERPRISE_GRAFANA_URL" {
  description = "Веб-интерфейс мониторинга Grafana (Порт 3000)"
  value       = "http://${yandex_compute_instance.prometheus.network_interface.0.nat_ip_address}:3000/"
}

output "D_ENTERPRISE_KIBANA_URL" {
  description = "Веб-интерфейс визуализации логов Kibana (Порт 5601)"
  value       = "http://${yandex_compute_instance.kibana_server.network_interface.0.nat_ip_address}:5601/"
}

# ------------------------------------------------------------------------------
# ВНУТРЕННИЕ ПРИВАТНЫЕ IP-АДРЕСА СЕТИ VPC (ДЛЯ ПРОВЕРКИ ТУННЕЛЕЙ АНСИБЛА)
# ------------------------------------------------------------------------------

output "E_INTERNAL_ELASTICSEARCH_STORAGE_IP" {
  description = "Внутренний IP сервера хранения логов Elasticsearch"
  value       = yandex_compute_instance.elasticsearch_storage.network_interface.0.ip_address
}

output "F_INTERNAL_KIBANA_SERVER_IP" {
  description = "Внутренний IP сервера визуализации Kibana"
  value       = yandex_compute_instance.kibana_server.network_interface.0.ip_address
}

output "G_INTERNAL_GRAFANA_SERVER_IP" {
  description = "Внутренний IP сервера мониторинга Grafana + Prometheus"
  value       = yandex_compute_instance.prometheus.network_interface.0.ip_address
}

output "H_INTERNAL_WEB_NODES_IPS" {
  description = "Список внутренних IP-адресов динамической группы веб-серверов"
  value       = [for instance in yandex_compute_instance_group.web_group.instances : instance.network_interface.0.ip_address]
}
