#  Курсовая работа на профессии "DevOps-инженер с нуля"

Содержание
==========
* [Задача](#Задача)
* [Инфраструктура](#Инфраструктура)
    * [Сайт](#Сайт)
    * [Мониторинг](#Мониторинг)
    * [Логи](#Логи)
    * [Сеть](#Сеть)
    * [Резервное копирование](#Резервное-копирование)
    * [Дополнительно](#Дополнительно)
* [Выполнение работы](#Выполнение-работы)
* [Критерии сдачи](#Критерии-сдачи)
* [Как правильно задавать вопросы дипломному руководителю](#Как-правильно-задавать-вопросы-дипломному-руководителю) 

---------
## Задача
Ключевая задача — разработать отказоустойчивую инфраструктуру для сайта, включающую мониторинг, сбор логов и резервное копирование основных данных. Инфраструктура должна размещаться в [Yandex Cloud](https://cloud.yandex.com/).

**Примечание**: в курсовой работе используется система мониторинга Prometheus. Вместо Prometheus вы можете использовать Zabbix. Задание для курсовой работы с использованием Zabbix находится по [ссылке](https://github.com/netology-code/fops-sysadm-diplom/blob/diplom-zabbix/README.md).

**Перед началом работы над дипломным заданием изучите [Инструкция по экономии облачных ресурсов](https://github.com/netology-code/devops-materials/blob/master/cloudwork.MD).**   

## Инфраструктура
Для развёртки инфраструктуры используйте Terraform и Ansible. 

Параметры виртуальной машины (ВМ) подбирайте по потребностям сервисов, которые будут на ней работать. 

Ознакомьтесь со всеми пунктами из этой секции, не беритесь сразу выполнять задание, не дочитав до конца. Пункты взаимосвязаны и могут влиять друг на друга.

### Сайт
Создайте две ВМ в разных зонах, установите на них сервер nginx, если его там нет. ОС и содержимое ВМ должно быть идентичным, это будут наши веб-сервера.

Используйте набор статичных файлов для сайта. Можно переиспользовать сайт из домашнего задания.

Создайте [Target Group](https://cloud.yandex.com/docs/application-load-balancer/concepts/target-group), включите в неё две созданных ВМ.

Создайте [Backend Group](https://cloud.yandex.com/docs/application-load-balancer/concepts/backend-group), настройте backends на target group, ранее созданную. Настройте healthcheck на корень (/) и порт 80, протокол HTTP.

Создайте [HTTP router](https://cloud.yandex.com/docs/application-load-balancer/concepts/http-router). Путь укажите — /, backend group — созданную ранее.

Создайте [Application load balancer](https://cloud.yandex.com/en/docs/application-load-balancer/) для распределения трафика на веб-сервера, созданные ранее. Укажите HTTP router, созданный ранее, задайте listener тип auto, порт 80.

Протестируйте сайт
`curl -v <публичный IP балансера>:80` 

### Мониторинг
Создайте ВМ, разверните на ней Prometheus. На каждую ВМ из веб-серверов установите Node Exporter и [Nginx Log Exporter](https://github.com/martin-helmich/prometheus-nginxlog-exporter). Настройте Prometheus на сбор метрик с этих exporter.

Создайте ВМ, установите туда Grafana. Настройте её на взаимодействие с ранее развернутым Prometheus. Настройте дешборды с отображением метрик, минимальный набор — Utilization, Saturation, Errors для CPU, RAM, диски, сеть, http_response_count_total, http_response_size_bytes. Добавьте необходимые [tresholds](https://grafana.com/docs/grafana/latest/panels/thresholds/) на соответствующие графики.

### Логи
Cоздайте ВМ, разверните на ней Elasticsearch. Установите filebeat в ВМ к веб-серверам, настройте на отправку access.log, error.log nginx в Elasticsearch.

Создайте ВМ, разверните на ней Kibana, сконфигурируйте соединение с Elasticsearch.

### Сеть
Разверните один VPC. Сервера web, Prometheus, Elasticsearch поместите в приватные подсети. Сервера Grafana, Kibana, application load balancer определите в публичную подсеть.

Настройте [Security Groups](https://cloud.yandex.com/docs/vpc/concepts/security-groups) соответствующих сервисов на входящий трафик только к нужным портам.

Настройте ВМ с публичным адресом, в которой будет открыт только один порт — ssh. Настройте все security groups на разрешение входящего ssh из этой security group. Эта вм будет реализовывать концепцию bastion host. Потом можно будет подключаться по ssh ко всем хостам через этот хост.

### Резервное копирование
Создайте snapshot дисков всех ВМ. Ограничьте время жизни snaphot в неделю. Сами snaphot настройте на ежедневное копирование.

### Дополнительно
Не входит в минимальные требования. 

1. Для Prometheus можно реализовать альтернативный способ хранения данных — в базе данных PpostgreSQL. Используйте [Yandex Managed Service for PostgreSQL](https://cloud.yandex.com/en-ru/services/managed-postgresql). Разверните кластер из двух нод с автоматическим failover. Воспользуйтесь адаптером с https://github.com/CrunchyData/postgresql-prometheus-adapter для настройки отправки данных из Prometheus в новую БД.
2. Вместо конкретных ВМ, которые входят в target group, можно создать [Instance Group](https://cloud.yandex.com/en/docs/compute/concepts/instance-groups/), для которой настройте следующие правила автоматического горизонтального масштабирования: минимальное количество ВМ на зону — 1, максимальный размер группы — 3.
3. Можно добавить в Grafana оповещения с помощью Grafana alerts. Как вариант, можно также установить Alertmanager в ВМ к Prometheus, настроить оповещения через него.
4. В Elasticsearch добавьте мониторинг логов самого себя, Kibana, Prometheus, Grafana через filebeat. Можно использовать logstash тоже.
5. Воспользуйтесь Yandex Certificate Manager, выпустите сертификат для сайта, если есть доменное имя. Перенастройте работу балансера на HTTPS, при этом нацелен он будет на HTTP веб-серверов.

------
------

# ОТВЕТ:

## Base вариант


### Структура каталогов проекта:

# 1. Структура каталогов проекта

```text
~/kursovoi_proekt/             # Корень  GitHub-репозитория
├── .gitignore                 # Исключение секретных ключей, стейтов и hosts.ini из Git
└── base_variant/              # Базовая конфигурация инфраструктуры
    ├── README.md              # Главное описание проекта и инструкция по запуску
    ├── terraform/             # Декларативное описание ресурсов в Yandex Cloud
    │   ├── providers.tf       # Настройки провайдера и авторизация в облаке
    │   ├── variables.tf       # Объявление входных переменных и типов данных
    │   ├── terraform.tfvars   # Хранение реальных значений переменных (ID папок, зон)
    │   ├── authorized_key.json # Секретный JSON-ключ сервисного аккаунта Yandex Cloud
    │   ├── vms.tf             # Конфигурация виртуальных машин и автозапуска Ansible
    │   ├── run_ansible.sh     # Технический bash-скрипт автостарта плейбуков из Terraform
    │   ├── network.tf         # Топология сети (подсети public/private и NAT-шлюз)
    │   ├── security.tf        # Группы безопасности и правила фильтрации портов
    │   ├── alb.tf             # L7-балансировщик (Application LB) и целевые группы веб-нод
    │   ├── terraform.tfstate  # База данных текущего состояния развернутых ресурсов
    │   └── terraform.tfstate.backup # Резервная копия базы данных состояния Terraform
    └── ansible/               # Сценарии автоматизации развертывания сервисов
        ├── hosts.ini          # Динамически генерируемый инвентарь хостов с ProxyJump
        ├── update_site.sh     # Комплексный bash-скрипт последовательного наката конфигураций
        ├── playbook.yml       # Деплой Nginx, PHP-FPM и исходного кода веб-сайта
        ├── update_web.yml     # Установка агента Prometheus Node Exporter на веб-серверы
        ├── deploy_prometheus.yml # Развертывание сервера сбора метрик Prometheus
        ├── deploy_grafana.yml # Установка и настройка панелей визуализации Grafana Enterprise
        └── playbook_logging.yml # Развертывание Docker-стека логов Elasticsearch и Kibana

```




Красные линии — балансировка трафика.
Оранжевые линии — сбор метрик.
Фиолетовые линии — логирование.
Синяя и зеленая линии — вывод графиков и логов в админки.

📄 1. providers.tf (Настройка провайдера и авторизация)

Этот файл инициализирует и настраивает подключение к облаку Yandex Cloud с использованием твоего сервисного ключа.

```text
terraform {
  required_providers {
    yandex = {                                      # Объявляем, что используем провайдер Yandex Cloud
      source = "yandex-cloud/yandex"                # Указываем официальный источник провайдера в реестре
    }
  }
  required_version = ">= 0.13"                      # Требуем версию Terraform не ниже 0.13 для стабильности
}

provider "yandex" {
  service_account_key_file = "authorized_key.json" # Путь к секретному JSON-ключу  сервисного аккаунта
  cloud_id                 = var.cloud_id           # ID  глобального облака (берется из переменных)
  folder_id                = var.folder_id          # ID конкретной папки внутри облака, где создаются ВМ
  zone                     = var.zone               # Дефолтная зона доступности ( ru-central1-a)
}
```
