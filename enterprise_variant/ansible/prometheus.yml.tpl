global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter_metrics'
    static_configs:
      - targets:
        - '${web_node_1}:9100'
        - '${web_node_2}:9100'
        - '${prometheus_server}:9100'
        - '${elasticsearch_server}:9100'
        - '${bastion_host}:9100'

  - job_name: 'nginx_exporter_metrics'
    static_configs:
      - targets:
        - '${web_node_1}:9113'
        - '${web_node_2}:9113'
