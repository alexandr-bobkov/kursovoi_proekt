#  Курсовая работа на профессии "DevOps-инженер с нуля"

<details>
<summary>Задание</summary>
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

</details>
------
------



# ОТВЕТ:

<details>
<summary>Минимальная часть (base вариант)</summary>
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
📄 2. variables.tf (Объявление входных переменных)

```text
variable "cloud_id" {
  type        = string                              # Тип данных: строго текстовая строка
  description = "Идентификатор Yandex Cloud"         # Описание переменной для удобства чтения кода
}

variable "folder_id" {
  type        = string                              # Тип данных: строго текстовая строка
  description = "Идентификатор папки в облаке"     # Указывает, в какой каталог разворачивать ресурсы
}

variable "zone" {
  type        = string                              # Тип данных: строго текстовая строка
  default     = "ru-central1-a"                     # Значение по умолчанию, если не задано иное в .tfvars
  description = "Дефолтная зона доступности"        # Географическая зона Яндекса для размещения ресурсов
}
```

📄 3. network.tf (Топология сети и NAT-шлюз)Этот файл описывает создание изолированного виртуального облака (VPC), деление его на публичную и приватные подсети, а также настройку NAT-шлюза, чтобы изолированные серверы имели безопасный доступ в интернет за обновлениями.

```text
resource "yandex_vpc_network" "default" {
  name        = "kursovoi-network"                  # Имя нашей виртуальной сети (VPC) для группировки ресурсов
  description = "Глобальная сеть для курсового проекта" # Описание назначения сети для топологии
}

resource "yandex_vpc_gateway" "nat_gateway" {
  name = "egress-nat-gateway"                       # Создаем NAT-шлюз для безопасного исходящего трафика
  shared_egress_gateway {}                           # Включаем стандартный шлюз распределения адресов Яндекса
}

resource "yandex_vpc_route_table" "private_rt" {
  name       = "private-route-table"                # Таблица маршрутизации для внутренних изолированных серверов
  network_id = yandex_vpc_network.default.id        # Привязываем таблицу к нашей созданной глобальной сети

  static_route {
    destination_prefix = "0.0.0.0/0"                # Перенаправляем абсолютно весь исходящий интернет-трафик...
    gateway_id = yandex_vpc_gateway.nat_gateway.id  # ...строго через созданный выше NAT-шлюз Яндекса
  }
}

resource "yandex_vpc_subnet" "public_a" {
  name           = "public-subnet-a"                # Публичная подсеть для балансировщика и бастиона
  zone           = "ru-central1-a"                  # Географическая зона Яндекса (ru-central1-a)
  network_id     = yandex_vpc_network.default.id    # Идентификатор нашей глобальной виртуальной сети
  v4_cidr_blocks = ["10.0.1.0/24"]                  # Диапазон IP-адресов подсети (до 254 хостов)
}

resource "yandex_vpc_subnet" "private_a" {
  name           = "private-subnet-a"               # Приватная подсеть А для web-server-1 и prometheus
  zone           = "ru-central1-a"                  # Зона размещения (ru-central1-a)
  network_id     = yandex_vpc_network.default.id    # Связь с глобальной виртуальной сетью проекта
  v4_cidr_blocks = ["10.0.10.0/24"]                 # Изолированный диапазон внутренних IP-адресов
  route_table_id = yandex_vpc_route_table.private_rt.id # Принудительно подключаем NAT для выхода в интернет
}

resource "yandex_vpc_subnet" "private_b" {
  name           = "private-subnet-b"               # Приватная подсеть Б для резервного web-server-2 и Elasticsearch
  zone           = "ru-central1-b"                  # Зона размещения (ru-central1-b) для отказоустойчивости
  network_id     = yandex_vpc_network.default.id    # Идентификатор основной сети VPC
  v4_cidr_blocks = ["10.0.20.0/24"]                 # Выделенный изолированный сегмент адресов
  route_table_id = yandex_vpc_route_table.private_rt.id # Включаем маршрут в интернет через NAT-шлюз
}
```
📄 4. security.tf (Файрвол и группы безопасности)Здесь мы жестко регламентируем правила фильтрации портов (Network Security Groups), закрывая все лишние доступы снаружи.
```text
resource "yandex_vpc_security_group" "bastion_sg" {
  name        = "bastion-security-group"            # Группа безопасности для управляющего сервера (Бастиона)
  network_id  = yandex_vpc_network.default.id       # Привязка правил к сети нашего проекта

  ingress {
    protocol       = "TCP"                          # Протокол передачи данных
    description    = "Доступ администратора по SSH"  # Пояснение назначения правила для аудита
    v4_cidr_blocks = ["0.0.0.0/0"]                  # Разрешаем входящий SSH-подход с любого IP-адреса мира
    port           = 22                             # Стандартный порт защищенного туннеля SSH
  }

  ingress {
    protocol       = "TCP"                          # Протокол управления трафиком
    description    = "Доступ к панелям Grafana"     # Авторизованный вход в веб-интерфейс метрик
    v4_cidr_blocks = ["0.0.0.0/0"]                  # Открытый доступ для мониторинга извне
    port           = 3000                           # Порт веб-интерфейса Grafana
  }

  ingress {
    protocol       = "TCP"                          # Протокол управления трафиком
    description    = "Доступ к дашбордам Kibana"    # Авторизованный вход в веб-интерфейс логов
    v4_cidr_blocks = ["0.0.0.0/0"]                  # Внешний доступ к аналитике текстовых индексов
    port           = 5601                           # Порт веб-интерфейса Kibana
  }

  egress {
    protocol       = "ANY"                          # Разрешаем абсолютно любой исходящий трафик
    description    = "Свободный исход хоста"        # Бастиону нужно качать обновления и слать запросы базам
    v4_cidr_blocks = ["0.0.0.0/0"]                  # Направление: в любую сеть без ограничений
    from_port      = 0                              # Полный диапазон портов (старт)
    to_port        = 65535                          # Полный диапазон портов (конец)
  }
}
```

📄 5. vms.tf (Конфигурация виртуальных машин и триггер автозапуска). Создаем все виртуальные машины в облаке, прописывает им ядра, память, диски, внедряет публичные SSH-ключи через metadata и запускает скрипт старта Ansible плейбуков, как только серверы станут доступны

```text
# Описываем конфигурацию машины Бастион-хоста
resource "yandex_compute_instance" "bastion" {
  name        = "bastion-host"                     # Уникальное сетевое имя виртуальной машины в облаке
  hostname    = "bastion-host"                     # Имя хоста внутри самой операционной системы Linux
  zone        = "ru-central1-a"                    # Размещаем в публичной зоне ru-central1-a
  platform_id = "standard-v3"                      # Архитектура процессора (Intel Ice Lake)

  resources {
    cores  = 2                                     # Выделяем 2 виртуальных ядра процессора (vCPU)
    memory = 2                                     # Выделяем 2 Гигабайта оперативной памяти (RAM)
  }

  boot_disk {
    initialize_params {
      image_id = "fd80le9bkv3lsgndf9qa"            # ID официального образа Ubuntu 22.04 LTS в репозитории Яндекса
      size     = 15                                # Объем системного диска: 15 Гигабайт (SSD)
      type     = "network-ssd"                     # Быстрый сетевой твердотельный накопитель
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public_a.id      # Подключаем к публичной подсети public-subnet-a
    nat       = true                               # Выделяем внешний публичный IP-адрес для доступа из интернета
  }

  metadata = {
    ssh-keys = "user:${file("~/.ssh/id_rsa.pub")}" # Пробрасываем твой публичный ключ для беспарольного входа по SSH
  }
}

# Шаблонная конфигурация для первого веб-сервера (Production Node)
resource "yandex_compute_instance" "web1" {
  name        = "web-server-1"
  hostname    = "web-server-1"
  zone        = "ru-central1-a"                    # Размещаем в приватной подсети зоны А
  platform_id = "standard-v3"

  resources {
    cores  = 2                                     # 2 ядра vCPU для обработки Nginx + PHP-FPM
    memory = 2                                     # 2 ГБ оперативной памяти
  }

  boot_disk {
    initialize_params {
      image_id = "fd80le9bkv3lsgndf9qa"            # Ubuntu 22.04 LTS
      size     = 15
      type     = "network-hdd"                     # Стандартный сетевой диск для экономии бюджета
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id # Изолированная приватная подсеть А
    nat                = false                     # Внешний IP отключен! Сервер полностью скрыт от интернета
    security_group_ids = [yandex_vpc_security_group.private_sg.id] # Подключаем внутренний файрвол
  }

  metadata = {
    ssh-keys = "user:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Конфигурация для второго веб-сервера (Backup Node)
resource "yandex_compute_instance" "web2" {
  name        = "web-server-2"
  hostname    = "web-server-2"
  zone        = "ru-central1-b"                    # Выносим в зону Б для обеспечения отказоустойчивости (High Availability)
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd80le9bkv3lsgndf9qa"
      size     = 15
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_b.id # Подключаем к приватной подсети Б
    nat                = false                     # Полная изоляция от внешнего мира
    security_group_ids = [yandex_vpc_security_group.private_sg.id]
  }

  metadata = {
    ssh-keys = "user:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Виртуальная машина для центрального сервера сбора метрик Prometheus
resource "yandex_compute_instance" "prometheus" {
  name        = "prometheus-server"
  hostname    = "prometheus-server"
  zone        = "ru-central1-a"
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 2                                     # Минимально необходимый объем для базы временных рядов TSDB
  }

  boot_disk {
    initialize_params {
      image_id = "fd80le9bkv3lsgndf9qa"
      size     = 20                                # Выделяем 20 ГБ для хранения истории метрик мониторинга
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id # Размещаем рядом с первым веб-сервером в приватной зоне А
    nat                = false
    security_group_ids = [yandex_vpc_security_group.private_sg.id]
  }

  metadata = {
    ssh-keys = "user:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Тяжелая виртуальная машина для базы данных и поискового движка логов Elasticsearch
resource "yandex_compute_instance" "elasticsearch" {
  name        = "elasticsearch-storage"
  hostname    = "elasticsearch-storage"
  zone        = "ru-central1-b"                    # Размещаем в приватной подсети зоны Б
  platform_id = "standard-v3"

  resources {
    cores  = 2                                     # 2 ядра vCPU
    memory = 4                                     # Выделяем повышенный объем (4 ГБ RAM) — Elasticsearch требователен к памяти Java VM
  }

  boot_disk {
    initialize_params {
      image_id = "fd80le9bkv3lsgndf9qa"
      size     = 30                                # Выделяем 30 ГБ под хранение индексов текстовых логов
      type     = "network-ssd"                     # Используем быстрый SSD, так как БД выполняет много операций чтения/записи
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.private_sg.id]
  }

  metadata = {
    ssh-keys = "user:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Автоматическая генерация файла инвентаря hosts.ini для Ansible сразу после создания инфраструктуры
resource "local_file" "ansible_inventory" {
  filename = "../ansible/hosts.ini"                # Путь, куда сохранить сгенерированный конфигурационный файл

  content = <<EOT
[bastion]
bastion-host ansible_host=${yandex_compute_instance.bastion.network_interface.0.nat_ip_address} ansible_user=user

[web]
web-server-1 ansible_host=${yandex_compute_instance.web1.network_interface.0.ip_address} ansible_user=user ansible_ssh_common_args='-o ProxyJump=user@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}'
web-server-2 ansible_host=${yandex_compute_instance.web2.network_interface.0.ip_address} ansible_user=user ansible_ssh_common_args='-o ProxyJump=user@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}'

[monitoring]
prometheus-server ansible_host=${yandex_compute_instance.prometheus.network_interface.0.ip_address} ansible_user=user ansible_ssh_common_args='-o ProxyJump=user@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}'

[logging]
elasticsearch-storage ansible_host=${yandex_compute_instance.elasticsearch.network_interface.0.ip_address} ansible_user=user ansible_ssh_common_args='-o ProxyJump=user@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}'
EOT
}

# Триггер local-exec, запускающий установку сервисов через автоматический bash-скрипт run_ansible.sh
resource "null_resource" "ansible_trigger" {
  depends_on = [
    yandex_compute_instance.bastion,               # Ждем, пока полностью создадутся все виртуальные хосты
    yandex_compute_instance.web1,
    yandex_compute_instance.web2,
    yandex_compute_instance.prometheus,
    yandex_compute_instance.elasticsearch,
    local_file.ansible_inventory                   # Ждем завершения генерации файла hosts.ini
  ]

  provisioner "local-exec" {
    command = "bash run_ansible.sh"               # Вызываем наш технический bash-скрипт автоматизации
  }
}
```

📄 6. alb.tf (L7-Балансировщик)
Этот файл настраивает Application Load Balancer. Он объединяет веб-серверы в целевую группу, следит за их работоспособностью (healthcheck) и распределяет входящий HTTP-трафик.

```text
resource "yandex_alb_target_group" "web_tg" {
  name = "web-target-group"                         # Создаем целевую группу, куда войдут наши веб-ноды

  target {
    subnet_id  = yandex_vpc_subnet.private_a.id      # Указываем подсеть первого веб-сервера
    ip_address = yandex_compute_instance.web1.network_interface.0.ip_address # Внутренний IP web-server-1
  }

  target {
    subnet_id  = yandex_vpc_subnet.private_b.id      # Указываем подсеть второго веб-сервера (зона B)
    ip_address = yandex_compute_instance.web2.network_interface.0.ip_address # Внутренний IP web-server-2
  }
}

resource "yandex_alb_backend_group" "web_bg" {
  name = "web-backend-group"                        # Группа бэкендов, управляющая логикой распределения

  http_backend {
    name             = "http-backend"                # Название HTTP-бэкенда
    weight           = 1                             # Вес ноды (равный распределяет трафик 50/50)
    target_group_ids = [yandex_alb_target_group.web_tg.id] # Привязываем созданную целевую группу
    port             = 80                            # На какой порт слать трафик (Nginx слушает 80)

    healthcheck {
      timeout          = "2s"                        # Время ожидания ответа от сервера (2 секунды)
      interval         = "5s"                        # Интервал между проверками доступности (5 секунд)
      healthy_threshold   = 2                        # Нужно 2 успешных ответа, чтобы считать ноду живой
      unhealthy_threshold = 3                        # После 3 ошибок нода вылетает из балансировки
      http_healthcheck {
        path = "/"                                  # Запрашиваем корень сайта для проверки его работы
      }
    }
  }
}

resource "yandex_alb_http_router" "web_router" {
  name = "web-http-router"                           # HTTP-роутер для маршрутизации трафика
}

resource "yandex_alb_virtual_host" "web_vh" {
  name           = "web-virtual-host"               # Виртуальный хост внутри роутера
  http_router_id = yandex_alb_http_router.web_router.id # Привязка к нашему роутеру

  route {
    name = "root-route"                             # Правило для обработки всех входящих путей
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_bg.id # Перенаправляем весь трафик на группу бэкендов
      }
    }
  }
}

resource "yandex_alb_load_balancer" "web_balancer" {
  name               = "web-load-balancer"          # Сам L7-балансировщик Яндекса
  network_id         = yandex_vpc_network.default.id # Привязываем к глобальной сети проекта
  security_group_ids = [yandex_vpc_security_group.public_sg.id] # Подключаем публичный файрвол

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"                   # Размещаем балансировщик в зоне A
      subnet_id = yandex_vpc_subnet.public_a.id      # ...и подключаем к публичной подсети
    }
  }

  listener {
    name = "http-listener"                          # Слушатель входящих запросов из интернета
    endpoint {
      address {
        external_ipv4_address {}                    # Выделяем внешний публичный IP-адрес для сайта
      }
      ports = [80]                                  # Слушаем стандартный 80-й порт HTTP
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.web_router.id # Связываем слушатель с роутером
      }
    }
  }
}
```

📄 7. outputs.tf (Выходные переменные)Этот файл заставляет Terraform выводить критически важные IP-адреса в терминал сразу после успешного завершения развертывания.

```text
output "balancer_public_ip" {
  value       = yandex_alb_load_balancer.web_balancer.listener[0].endpoint[0].address[0].external_ipv4_address[0].address
  description = "Публичный IP-адрес балансировщика (адрес сайта)" # Сюда мы заходим браузером
}

output "bastion_public_ip" {
  value       = yandex_compute_instance.bastion.network_interface.0.nat_ip_address
  description = "Публичный IP-адрес Бастион-хоста для управления" # Нужен для SSH и Grafana/Kibana
}

output "web_servers_private_ips" {
  value       = [yandex_compute_instance.web1.network_interface.0.ip_address, yandex_compute_instance.web2.network_interface.0.ip_address]
  description = "Приватные IP-адреса веб-серверов"
}
```

📄 8. run_ansible.sh (Скрипт автозапуска из Terraform)
Этот локальный bash-скрипт вызывается ресурсом null_resource внутри vms.tf. Он координирует автоматический накат всех конфигураций.

```text
#!/bin/bash
# Выключаем строгую проверку SSH хост-ключей, чтобы Ansible не зависал на вопросах "Are you sure you want to continue connecting?"
export ANSIBLE_HOST_KEY_CHECKING=False

echo "Ожидание 15 секунд для окончательного старта SSH-демонов на виртуалках..."
sleep 15                                            # Задержка, чтобы ОС успели полностью загрузиться

cd ../ansible                                       # Переходим в директорию со сценариями Ansible

echo "Запуск базовой настройки веб-серверов (Nginx + PHP)..."
ansible-playbook -i hosts.ini playbook.yml          # Разворачиваем веб-сайт на нодах

echo "Установка агентов мониторинга Node Exporter..."
ansible-playbook -i hosts.ini update_web.yml        # Накатываем сборщики метрик железа

echo "Развертывание системы логирования (Elasticsearch + Kibana + Filebeat)..."
ansible-playbook -i hosts.ini playbook_logging.yml  # Поднимаем контейнеры логов и настраиваем агенты

echo "Инфраструктурный стенд полностью развернут и настроен!"
```


📄 9. update_site.sh (Скрипт комплексного ручного перенаката)Этот скрипт лежит в папке ansible/. Он нужен тебе быстрой ручной отладки и обновления всего стенда одной командой, если  пришлось вносить правки в плейбуки.

```text
#!/bin/bash
# Скрипт для принудительного ручного обновления всех компонентов инфраструктуры

# Активируем SSH-агент на локальной машине, чтобы ключи автоматически пробрасывались через Бастион (ProxyJump)
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa                               # Добавляем твой закрытый ключ в память агента

echo "=== Шаг 1: Обновление конфигурации веб-серверов и сайта ==="
ansible-playbook -i hosts.ini playbook.yml

echo "=== Шаг 2: Пересборка метрик и мониторинга ==="
ansible-playbook -i hosts.ini update_web.yml

echo "=== Шаг 3: Перезапуск стека сбора логов ==="
ansible-playbook -i hosts.ini playbook_logging.yml

echo "=== Все конфигурации успешно обновлены! ==="
```

### Модулю 2: Разбор сценариев Ansible

📄 10. hosts.ini (Динамический инвентарь)
Этот файл генерируется автоматически через Terraform (vms.tf). Он делит серверы на группы и прописывает параметры ProxyJump для безопасного подключения в приватный контур через Бастион.

```text
[bastion]
# Описываем хост управления. Доступен напрямую по публичному IP
bastion-host ansible_host=93.77.185.215 ansible_user=user

[web]
# Веб-серверы находятся в приватной сети. Подключаемся к ним через Бастион (ProxyJump)
web-server-1 ansible_host=10.0.10.24 ansible_user=user ansible_ssh_common_args='-o ProxyJump=user@93.77.185.215'
web-server-2 ansible_host=10.0.20.11 ansible_user=user ansible_ssh_common_args='-o ProxyJump=user@93.77.185.215'

[monitoring]
# Сервер сбора метрик Prometheus. Также изолирован в приватной подсети
prometheus-server ansible_host=10.0.10.25 ansible_user=user ansible_ssh_common_args='-o ProxyJump=user@93.77.185.215'

[logging]
# Хранилище логов Elasticsearch. Доступ только через SSH-туннель Бастиона
elasticsearch-storage ansible_host=10.0.10.11 ansible_user=user ansible_ssh_common_args='-o ProxyJump=user@93.77.185.215'
```


📄 11. playbook.yml (Базовый деплой веб-нод)
Сценарий для группы [web]. Он устанавливает веб-сервер Nginx, интерпретатор PHP-FPM, настраивает виртуальный хост и копирует исходный код сайта.

```text
- name: Развертывание веб-серверов Nginx + PHP-FPM
  hosts: web                                        # Сценарий выполняется только на хостах из группы [web]
  become: true                                      # Запускаем все задачи с правами суперпользователя (root)

  tasks:
    # Шаг 1: Обновление кэша пакетов и установка ПО
    - name: Установка системных пакетов Nginx и PHP
      apt:
        name:
          - nginx                                   # Устанавливаем веб-сервер Nginx для приема HTTP
          - php-fpm                                 # Менеджер процессов PHP для обработки скриптов
          - php-curl                                # Дополнительный модуль для работы с сетевыми запросами
        state: present                              # Убеждаемся, что пакеты установлены
        update_cache: yes                           # Аналог команды apt-get update перед установкой

    # Шаг 2: Настройка конфигурации веб-сервера
    - name: Создание конфигурации виртуального хоста Nginx
      copy:
        dest: /etc/nginx/sites-available/default    # Путь к главному дефолтному конфигу Nginx
        content: |
          server {
              listen 80 default_server;             # Слушаем входящий трафик на 80-м порту
              root /var/www/html;                   # Корневая директория, где лежит код нашего сайта
              index index.php index.html;           # Приоритет индексных файлов при запросе к корню
              server_name _;                        # Обрабатываем любые доменные имена и IP-адреса

              location / {
                  try_files $uri $uri/ =404;        # Если файл не найден, отдаем стандартную ошибку 404
              }

              location ~ \.php$ {
                  include snippets/fastcgi-php.conf; # Подключаем базовые правила fastcgi для PHP
                  fastcgi_pass unix:/run/php/php8.4-fpm.sock; # Перенаправляем PHP-запросы в сокет PHP-FPM
              }
          }
      notify: Restart Nginx                         # Если конфиг изменился, дергаем обработчик перезапуска

    # Шаг 3: Размещение исходного кода сайта
    - name: Копирование исходного кода PHP-приложения
      copy:
        dest: /var/www/html/index.php               # Создаем главный файл нашего сайта
        content: |
          <?php
          echo "<h1>Инфраструктурный стенд Base работает стабильно!</h1>";
          echo "<p>Хост обработки: " . gethostname() . "</p>"; # Показывает, какая именно нода ответила (проверка ALB)
          ?>
        owner: www-data                             # Владельцем файла делаем системного пользователя веб-сервера
        group: www-data                             # Группа пользователя для корректных прав доступа

  handlers:
    # Обработчики вызываются только при успешном изменении конфигурационных файлов
    - name: Restart Nginx
      service:
        name: nginx
        state: restarted                            # Перезапускаем веб-сервер для применения новых настроек
```


📄 12. update_web.yml (Установка Node Exporter на веб-серверы)Этот сценарий разворачивает агент Prometheus Node Exporter на всех веб-нодах, чтобы собирать метрики загрузки процессора, памяти и дисков.

```text

- name: Установка и настройка Prometheus Node Exporter
  hosts: web                                        # Выполняется на целевых веб-серверах
  become: true                                      # Требуются права суперпользователя

  tasks:
    - name: Скачивание архива Node Exporter
      get_url:
        url: "https://github.com"
        dest: "/tmp/node_exporter.tar.gz"           # Скачиваем бинарный файл во временную директорию

    - name: Распаковка архива
      unarchive:
        src: "/tmp/node_exporter.tar.gz"            # Распаковываем скачанный архив
        dest: "/opt/"                               # Директория размещения исполняемых файлов
        remote_src: yes                             # Указываем, что архив уже находится на удаленном хосте

    - name: Создание systemd сервиса
      copy:
        dest: /etc/systemd/system/node_exporter.service # Регистрируем демон в системном менеджере процессов
        content: |
          [Unit]
          Description=Node Exporter                 # Описание службы
          After=network.target                      # Запуск строго после поднятия сетевых интерфейсов

          [Service]
          User=root                                 # Запуск от имени root для доступа к метрикам ядра
          ExecStart=/opt/node_exporter-1.8.1.linux-amd64/node_exporter # Путь к бинарнику

          [Install]
          WantedBy=multi-user.target                # Автозапуск при обычной загрузке системы
      notify: Restart Node Exporter                 # Перезапуск службы при изменении юнита

  handlers:
    - name: Restart Node Exporter
      systemd:
        name: node_exporter
        state: restarted                            # Перезапуск демона
        enabled: yes                                # Включение службы в автозагрузку ОС

```
📄 13. deploy_prometheus.yml (Развертывание Prometheus Server)Сценарий настраивает выделенный сервер мониторинга, который по протоколу HTTP забирает метрики с Node Exporter на веб-нодах.

```text
- name: Развертывание Prometheus Server
  hosts: monitoring                                 # Выполняется на prometheus-server
  become: true                                      # Требуются root-права

  tasks:
    - name: Установка Prometheus из репозитория
      apt:
        name: prometheus                            # Устанавливаем официальный пакет Prometheus
        state: present
        update_cache: yes

    - name: Настройка конфигурации сбора метрик
      copy:
        dest: /etc/prometheus/prometheus.yml        # Главный файл конфигурации сбора данных
        content: |
          global:
            scrape_interval: 15s                    # Интервал опроса хостов по умолчанию

          scrape_configs:
            - job_name: 'node_metrics'              # Задача для сбора системных метрик серверов
              static_configs:
                - targets: ['10.0.10.24:9100', '10.0.20.11:9100'] # IP-адреса веб-серверов и порт Node Exporter
      notify: Restart Prometheus

  handlers:
    - name: Restart Prometheus
      service:
        name: prometheus
        state: restarted                            # Перезапуск для применения новой конфигурации таргетов
        enabled: yes

```

📄 14. deploy_grafana.yml (Развертывание Grafana Enterprise)Этот плейбук разворачивает Grafana Enterprise на Бастионе для визуализации собранных метрик.


```text
- name: Установка Grafana Enterprise на Бастион
  hosts: bastion                                    # Выполняется на bastion-host
  become: true

  tasks:
    - name: Добавление GPG-ключа репозитория Grafana
      apt_key:
        url: https://grafana.com        # Ключ проверки подлинности пакетов
        state: present

    - name: Добавление официального репозитория
      apt_repository:
        repo: deb https://grafana.com stable main # Подключаем стабильную ветку пакетов
        state: present

    - name: Установка Grafana Enterprise
      apt:
        name: grafana-enterprise                    # Устанавливаем сам пакет визуализации
        state: present
        update_cache: yes
      notify: Start Grafana

  handlers:
    - name: Start Grafana
      service:
        name: grafana-server
        state: restarted                            # Запуск веб-интерфейса Grafana (:3000)
        enabled: yes                                # Включение в автозагрузку

```

📄 15. playbook_logging.yml (Стек логов Elasticsearch + Kibana + Filebeat) Плейбук, который поднимает Docker-контейнеры для логирования и настраивает сборщики Filebeat на веб-серверах.

```text
- name: Развертывание Docker-стека Elasticsearch и Kibana
  hosts: logging                                    # Выполняется на elasticsearch-storage
  become: true

  tasks:
    - name: Установка Docker и Docker Compose
      apt:
        name:
          - docker.io                               # Системный движок контейнеризации
          - docker-compose                          # Утилита оркестрации мультиконтейнерных сред
        state: present
        update_cache: yes

    - name: Создание конфигурации Docker Compose
      copy:
        dest: /root/docker-compose.yml              # Манифест запуска инфраструктуры логов
        content: |
          version: '7.17.9'
          services:
            elasticsearch:
              image: docker.elastic.co/elasticsearch/elasticsearch:7.17.9 # Версия хранилища индексов
              container_name: elasticsearch
              environment:
                - discovery.type=single-node        # Запуск в режиме одиночной ноды (без кластеризации)
                - "ES_JAVA_OPTS=-Xms2g -Xmx2g"      # Ограничение памяти Java кучи (2 ГБ)
              ports:
                - "9200:9200"                       # Проброс порта REST API базы данных логов
              restart: always

            kibana:
              image: docker.elastic.co/kibana/kibana:7.17.9 # Аналитическая панель логов
              container_name: kibana
              ports:
                - "5601:5601"                       # Порт веб-интерфейса Kibana
              environment:
                - ELASTICSEARCH_HOSTS=http://elasticsearch:9200 # Связь Кибаны с Эластиком по внутренней сети Docker
              restart: always
      notify: Start Containers

  handlers:
    - name: Start Containers
      shell: "docker-compose -f /root/docker-compose.yml up -d" # Запуск контейнеров в бэкграунде (detached)

- name: Установка и настройка Filebeat на веб-нодах
  hosts: web                                        # Переключаемся на группу веб-серверов
  become: true

  tasks:
    - name: Скачивание и установка агента Filebeat
      apt:
        deb: "https://elastic.co" # Скачиваем пакет напрямую

    - name: Конфигурация Filebeat
      copy:
        dest: /etc/filebeat/filebeat.yml            # Настройки путей сбора логов и отправки
        content: |
          filebeat.inputs:
            - type: log
              enabled: true
              paths:
                - /var/www/html/error.log           # Сбор ошибок приложения
                - /var/www/html/access.log          # Сбор логов посещений

          output.elasticsearch:
            hosts: ["10.0.10.11:9200"]              # Отправка логов напрямую на приватный IP Elasticsearch
      notify: Restart Filebeat

  handlers:
    - name: Restart Filebeat
      service:
        name: filebeat
        state: restarted                            # Перезапуск агента сбора логов
        enabled: yes

```





</details>
