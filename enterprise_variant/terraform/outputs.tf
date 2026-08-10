# ==============================================================================
# ENTERPRISE VARIANT OUTPUTS — ССЫЛКИ И ПОРТЫ ИНФРАСТРУКТУРЫ СТЕНДА
# ==============================================================================

output "A_EXTERNAL_BALANCER_HTTPS_URL" {
  description = "Финальный защищенный адрес сайта на балансировщике Яндекса (Порт 443)"
  value       = "https://${yandex_alb_load_balancer.web_balancer.listener.1.endpoint.0.address.0.external_ipv4_address.0.address}/"
}

output "B_EXTERNAL_BALANCER_HTTP_URL" {
  description = "Резервный незащищенный адрес сайта на балансировщике Яндекса (Порт 80)"
  value       = "http://${yandex_alb_load_balancer.web_balancer.listener.0.endpoint.0.address.0.external_ipv4_address.0.address}/"
}

output "C_EXTERNAL_BASTION_SSH_COMMAND" {
  description = "Команда для прямого подключения к SSH шлюзу контура (Порт 22)"
  value       = "ssh debian@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"
}

output "D_EXTERNAL_GRAFANA_URL" {
  description = "Адрес панели Grafana (Порт 3000) — Доступен напрямую из интернета"
  value       = "http://${yandex_compute_instance.prometheus.network_interface.0.nat_ip_address}:3000"
}

output "E_INTERNAL_PROMETHEUS_URL" {
  description = "Адрес ядра мониторинга Prometheus (Порт 9090) — Доступ через SSH-туннель"
  value       = "http://${yandex_compute_instance.prometheus.network_interface.0.ip_address}:9090"
}

output "F_EXTERNAL_KIBANA_URL" {
  description = "Адрес веб-панели логов Kibana (Порт 5601) — Доступен напрямую из интернета"
  value       = "http://${yandex_compute_instance.kibana_server.network_interface.0.nat_ip_address}:5601"
}

output "G_INTERNAL_ELASTICSEARCH_URL" {
  description = "Адрес изолированной базы логов Elasticsearch (Порт 9200) в приватной подсети"
  value       = "http://${yandex_compute_instance.elasticsearch_storage.network_interface.0.ip_address}:9200"
}
