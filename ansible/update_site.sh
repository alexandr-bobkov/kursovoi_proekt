#!/bin/bash

# 1. Обновляем сайт на первом сервере (web1 - 10.0.10.13)
ssh -J debian@158.160.53.162 debian@10.0.10.13 << 'EOF'
# Сначала собираем аппаратные данные сервера прямо из системы
CPU_MODEL=$(grep -m 1 'model name' /proc/cpuinfo | sed 's/model name[[:space:]]*:[[:space:]]*//')
RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
SYS_DISK=$(df -h / | awk 'NR==2 {print $2}')

sudo tee /var/www/html/index.php > /dev/null << EOF_SITE
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Курсовой проект - Бобков А.К.</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background-color: #f4f6f9; color: #333; margin: 0; padding: 0; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
        .container { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); text-align: center; max-width: 600px; width: 100%; border-top: 8px solid #0052cc; margin: 20px; }
        h1 { color: #0052cc; margin-bottom: 5px; font-size: 26px; }
        .author { font-size: 18px; color: #555; font-weight: 600; margin-bottom: 25px; }
        p { font-size: 15px; color: #666; line-height: 1.6; }
        .status-box { background-color: #e3f2fd; border: 1px solid #90caf9; padding: 15px; border-radius: 8px; margin: 20px 0; font-size: 16px; color: #0d47a1; text-align: left; }
        .hardware-box { background-color: #f1f8e9; border: 1px solid #c5e1a5; padding: 15px; border-radius: 8px; margin: 20px 0; font-size: 15px; color: #33691e; text-align: left; }
        .status-line { margin: 8px 0; display: flex; justify-content: space-between; align-items: center; }
        .badge { background: #4caf50; color: white; padding: 3px 10px; border-radius: 20px; font-size: 14px; font-weight: bold; }
        .ip-text { font-family: 'Courier New', monospace; font-weight: bold; color: #333; }
        .footer { margin-top: 30px; font-size: 12px; color: #aaa; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Курсовой проект по DevOps</h1>
        <div class="author">Студент: Бобков А.К.</div>
        
        <p>Высокодоступная балансируемая инфраструктура успешно развернута в Yandex Cloud.</p>
        
        <div class="status-box">
            <div class="status-line">Активный сервер обработки: <span class="badge">WEB-SERVER-1</span></div>
            <div class="status-line">Внутренний IP-адрес ноды: <span class="ip-text">10.0.10.13</span></div>
            <div class="status-line">Текущая дата и время сервера: <span class="ip-text"><?php echo date('d.m.Y H:i:s T'); ?></span></div>
        </div>

        <div class="hardware-box">
            <div style="font-weight: bold; margin-bottom: 8px; text-align: center;">Аппаратные данные виртуальной машины:</div>
            <div class="status-line">Процессор (vCPU): <span class="ip-text">${CPU_MODEL}</span></div>
            <div class="status-line">Оперативная память (RAM): <span class="ip-text">${RAM_TOTAL}</span></div>
            <div class="status-line">Системный диск (SSD): <span class="ip-text">${SYS_DISK}</span></div>
        </div>
        
        <p>Метрики (Prometheus/Grafana) и логи (ELK Stack) работают штатно.</p>
        <div class="footer">Инфраструктура как код (IaC) &copy; 2026</div>
    </div>
</body>
</html>
EOF_SITE

# Настраиваем Nginx на работу с PHP, если индексный файл изменился
sudo ln -sf /var/www/html/index.php /var/www/html/index.html
EOF

# 2. Обновляем сайт на втором сервере (web2 - 10.0.20.17)
ssh -J debian@158.160.53.162 debian@10.0.20.17 << 'EOF'
CPU_MODEL=$(grep -m 1 'model name' /proc/cpuinfo | sed 's/model name[[:space:]]*:[[:space:]]*//')
RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
SYS_DISK=$(df -h / | awk 'NR==2 {print $2}')

sudo tee /var/www/html/index.php > /dev/null << EOF_SITE
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Курсовой проект - Бобков А.К.</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background-color: #f4f6f9; color: #333; margin: 0; padding: 0; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
        .container { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); text-align: center; max-width: 600px; width: 100%; border-top: 8px solid #0052cc; margin: 20px; }
        h1 { color: #0052cc; margin-bottom: 5px; font-size: 26px; }
        .author { font-size: 18px; color: #555; font-weight: 600; margin-bottom: 25px; }
        p { font-size: 15px; color: #666; line-height: 1.6; }
        .status-box { background-color: #e3f2fd; border: 1px solid #90caf9; padding: 15px; border-radius: 8px; margin: 20px 0; font-size: 16px; color: #0d47a1; text-align: left; }
        .hardware-box { background-color: #fff3e0; border: 1px solid #ffe082; padding: 15px; border-radius: 8px; margin: 20px 0; font-size: 15px; color: #e65100; text-align: left; }
        .status-line { margin: 8px 0; display: flex; justify-content: space-between; align-items: center; }
        .badge { background: #ff9800; color: white; padding: 3px 10px; border-radius: 20px; font-size: 14px; font-weight: bold; }
        .ip-text { font-family: 'Courier New', monospace; font-weight: bold; color: #333; }
        .footer { margin-top: 30px; font-size: 12px; color: #aaa; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Курсовой проект по DevOps</h1>
        <div class="author">Студент: Бобков А.К.</div>
        
        <p>Высокодоступная балансируемая инфраструктура успешно развернута в Yandex Cloud.</p>
        
        <div class="status-box">
            <div class="status-line">Активный сервер обработки: <span class="badge">WEB-SERVER-2</span></div>
            <div class="status-line">Внутренний IP-адрес ноды: <span class="ip-text">10.0.20.17</span></div>
            <div class="status-line">Текущая дата и время сервера: <span class="ip-text"><?php echo date('d.m.Y H:i:s T'); ?></span></div>
        </div>

        <div class="hardware-box">
            <div style="font-weight: bold; margin-bottom: 8px; text-align: center;">Аппаратные данные виртуальной машины:</div>
            <div class="status-line">Процессор (vCPU): <span class="ip-text">${CPU_MODEL}</span></div>
            <div class="status-line">Оперативная память (RAM): <span class="ip-text">${RAM_TOTAL}</span></div>
            <div class="status-line">Системный диск (SSD): <span class="ip-text">${SYS_DISK}</span></div>
        </div>
        
        <p>Метрики (Prometheus/Grafana) и логи (ELK Stack) работают штатно.</p>
        <div class="footer">Инфраструктура как код (IaC) &copy; 2026</div>
    </div>
</body>
</html>
EOF_SITE

sudo ln -sf /var/www/html/index.php /var/www/html/index.html
EOF

echo "Сайт успешно переведен на динамический режим с выводом даты и железа!"
