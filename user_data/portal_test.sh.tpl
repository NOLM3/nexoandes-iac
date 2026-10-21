#!/bin/bash
# Portal de prueba provisorio. Se reemplaza por user_data_v1.sh.tpl entregado por el docente.
set -euo pipefail

dnf install -y httpd

# IMDSv2: toda consulta a la metadata requiere un token de sesión previo.
TOKEN=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

md() {
  curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" \
    "http://169.254.169.254/latest/meta-data/$1"
}

INSTANCE_ID=$(md instance-id)
AZ=$(md placement/availability-zone)
PRIVATE_IP=$(md local-ipv4)
PUBLIC_IP=$(md public-ipv4)
HOST=$(md local-hostname)

cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><title>NexoAndes - Portal Operacional</title></head>
<body>
<pre>
NexoAndes - Portal Operacional (prueba)
Estado: operativo
StudentNumber: ${student_number}

Instance ID       : $INSTANCE_ID
Availability Zone : $AZ
Private IP        : $PRIVATE_IP
Public IP         : $PUBLIC_IP
Hostname          : $HOST
</pre>
</body>
</html>
EOF

systemctl enable --now httpd