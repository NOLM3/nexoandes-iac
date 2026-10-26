#!/bin/bash
set -euo pipefail

# ============================================================
# NexoAndes Servicios Digitales SpA — Portal Operacional V1
# Artefacto docente de apoyo para IC106TICL / Unidad 1
#
# IMPORTANTE:
# - El estudiante NO debe modificar la lógica interna de este archivo.
# - Debe integrarlo y parametrizarlo desde Terraform mediante templatefile().
# - No contiene credenciales ni secretos.
# - Diseñado para una instancia Linux con systemd.
# ============================================================

# Parámetros entregados por Terraform.
STUDENT_NAME="${student_name}"
STUDENT_NUMBER="${student_number}"
ENVIRONMENT="${environment}"
PORTAL_VERSION="${portal_version}"
PROJECT_NAME="${project_name}"

log() {
  printf '[nexoandes-user-data] %s\n' "$*"
}

install_nginx() {
  if command -v nginx >/dev/null 2>&1; then
    log "nginx ya está instalado."
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    log "Instalando nginx con dnf..."
    dnf install -y nginx
  elif command -v yum >/dev/null 2>&1; then
    log "Instalando nginx con yum..."
    yum install -y nginx
  elif command -v apt-get >/dev/null 2>&1; then
    log "Instalando nginx con apt-get..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y nginx
  else
    log "ERROR: no se encontró un gestor de paquetes compatible."
    exit 1
  fi
}

imds_token() {
  curl -fsS --connect-timeout 2 --max-time 3 \
    -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null || true
}

imds_get() {
  local path="$1"
  local token="$2"

  if [ -z "$token" ]; then
    printf 'No disponible'
    return 0
  fi

  curl -fsS --connect-timeout 2 --max-time 3 \
    -H "X-aws-ec2-metadata-token: $token" \
    "http://169.254.169.254/latest/$${path}" 2>/dev/null || printf 'No disponible'
}

html_escape() {
  # Evita que valores mostrados como datos alteren el HTML.
  printf '%s' "$1" \
    | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g'
}

log "Iniciando configuración de Portal Operacional V1."
install_nginx

TOKEN="$(imds_token)"

INSTANCE_ID="$(imds_get 'meta-data/instance-id' "$TOKEN")"
INSTANCE_TYPE="$(imds_get 'meta-data/instance-type' "$TOKEN")"
AVAILABILITY_ZONE="$(imds_get 'meta-data/placement/availability-zone' "$TOKEN")"
PRIVATE_IP="$(imds_get 'meta-data/local-ipv4' "$TOKEN")"
PUBLIC_IP="$(imds_get 'meta-data/public-ipv4' "$TOKEN")"
HOSTNAME="$(imds_get 'meta-data/local-hostname' "$TOKEN")"

# Escapar solo para visualización en HTML.
E_STUDENT_NAME="$(html_escape "$STUDENT_NAME")"
E_STUDENT_NUMBER="$(html_escape "$STUDENT_NUMBER")"
E_ENVIRONMENT="$(html_escape "$ENVIRONMENT")"
E_PORTAL_VERSION="$(html_escape "$PORTAL_VERSION")"
E_PROJECT_NAME="$(html_escape "$PROJECT_NAME")"
E_INSTANCE_ID="$(html_escape "$INSTANCE_ID")"
E_INSTANCE_TYPE="$(html_escape "$INSTANCE_TYPE")"
E_AZ="$(html_escape "$AVAILABILITY_ZONE")"
E_PRIVATE_IP="$(html_escape "$PRIVATE_IP")"
E_PUBLIC_IP="$(html_escape "$PUBLIC_IP")"
E_HOSTNAME="$(html_escape "$HOSTNAME")"

cat > /usr/share/nginx/html/index.html <<EOF
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>NexoAndes — Portal Operacional</title>
  <style>
    :root {
      --navy: #17324d;
      --navy-2: #214f75;
      --gold: #c7a15a;
      --paper: #ffffff;
      --bg: #eef3f7;
      --ink: #263746;
      --muted: #667784;
      --ok: #287a45;
      --line: #d8e0e6;
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      font-family: Arial, Helvetica, sans-serif;
      background: linear-gradient(180deg, var(--bg), #f8fafc);
      color: var(--ink);
    }

    header {
      background: var(--navy);
      color: var(--paper);
      border-bottom: 6px solid var(--gold);
      padding: 28px 24px;
    }

    .wrap {
      max-width: 980px;
      margin: 0 auto;
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 14px;
    }

    .mark {
      width: 48px;
      height: 48px;
      border: 3px solid var(--gold);
      border-radius: 50%;
      display: grid;
      place-items: center;
      font-weight: 700;
      color: var(--gold);
      letter-spacing: .04em;
    }

    h1 {
      margin: 0;
      font-size: 1.8rem;
    }

    .subtitle {
      margin-top: 5px;
      color: #d9e5ee;
      font-size: .96rem;
    }

    main {
      padding: 34px 20px 52px;
    }

    .notice {
      background: #edf7ef;
      border: 1px solid #b9d9c1;
      border-left: 5px solid var(--ok);
      border-radius: 8px;
      padding: 14px 16px;
      margin-bottom: 22px;
    }

    .notice strong { color: var(--ok); }

    .grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 16px;
    }

    .card {
      background: var(--paper);
      border: 1px solid var(--line);
      border-radius: 10px;
      padding: 20px;
      box-shadow: 0 4px 14px rgba(23, 50, 77, .06);
    }

    .card h2 {
      color: var(--navy);
      font-size: 1rem;
      margin: 0 0 14px;
      padding-bottom: 9px;
      border-bottom: 2px solid var(--gold);
    }

    dl {
      display: grid;
      grid-template-columns: 150px 1fr;
      gap: 9px 12px;
      margin: 0;
    }

    dt {
      color: var(--muted);
      font-weight: 700;
    }

    dd {
      margin: 0;
      overflow-wrap: anywhere;
    }

    footer {
      margin-top: 24px;
      text-align: center;
      color: var(--muted);
      font-size: .82rem;
    }

    .tag {
      display: inline-block;
      background: var(--navy-2);
      color: white;
      border-radius: 999px;
      padding: 4px 9px;
      margin-left: 8px;
      font-size: .75rem;
    }

    @media (max-width: 720px) {
      .grid { grid-template-columns: 1fr; }
      dl { grid-template-columns: 1fr; }
      dt { margin-top: 7px; }
    }
  </style>
</head>
<body>
<header>
  <div class="wrap">
    <div class="brand">
      <div class="mark">NA</div>
      <div>
        <h1>NexoAndes — Portal Operacional <span class="tag">$${E_PORTAL_VERSION}</span></h1>
        <div class="subtitle">Simulación académica · Automatización de Infraestructura con IaC</div>
      </div>
    </div>
  </div>
</header>

<main class="wrap">
  <div class="notice">
    <strong>Estado: operativo.</strong>
    El servicio HTTP fue aprovisionado mediante user data e integrado desde Terraform.
  </div>

  <section class="grid">
    <article class="card">
      <h2>Identificación del despliegue</h2>
      <dl>
        <dt>Proyecto</dt><dd>$${E_PROJECT_NAME}</dd>
        <dt>Estudiante</dt><dd>$${E_STUDENT_NAME}</dd>
        <dt>N.º / identificador</dt><dd>$${E_STUDENT_NUMBER}</dd>
        <dt>Ambiente</dt><dd>$${E_ENVIRONMENT}</dd>
        <dt>Versión</dt><dd>$${E_PORTAL_VERSION}</dd>
      </dl>
    </article>

    <article class="card">
      <h2>Instancia AWS</h2>
      <dl>
        <dt>Instance ID</dt><dd>$${E_INSTANCE_ID}</dd>
        <dt>Instance type</dt><dd>$${E_INSTANCE_TYPE}</dd>
        <dt>Availability Zone</dt><dd>$${E_AZ}</dd>
        <dt>IP privada</dt><dd>$${E_PRIVATE_IP}</dd>
        <dt>IP pública</dt><dd>$${E_PUBLIC_IP}</dd>
        <dt>Hostname</dt><dd>$${E_HOSTNAME}</dd>
      </dl>
    </article>
  </section>

  <footer>
    NexoAndes Servicios Digitales SpA es un caso académico ficticio utilizado en IC106TICL.
  </footer>
</main>
</body>
</html>
EOF

# Dejar una ruta simple para health/automatización futura sin añadir lógica de U2/U3.
printf 'ok\n' > /usr/share/nginx/html/health.txt

systemctl enable nginx
systemctl restart nginx

log "Portal Operacional V1 configurado."
log "Verificación local: curl -I http://127.0.0.1/"
