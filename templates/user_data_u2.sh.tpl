#!/bin/bash
# NexoAndes U2 - artefacto docente. Renderizar con Terraform templatefile().
# Linux con cloud-init y systemd. No contiene infraestructura ni credenciales.
set -euo pipefail
umask 022
export DEBIAN_FRONTEND=noninteractive
if ! command -v python3 >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y python3
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y python3
  elif command -v yum >/dev/null 2>&1; then
    yum install -y python3
  else
    echo 'ERROR: se requiere Python 3 y un gestor de paquetes compatible.' >&2
    exit 1
  fi
fi
if ! id nexoandes >/dev/null 2>&1; then
  useradd --system --no-create-home --shell /usr/sbin/nologin nexoandes
fi
install -d -m 0755 /opt/nexoandes /etc/nexoandes
# JSON -> base64 evita insertar valores de alumno como instrucciones de Bash.
printf '%s' '${base64encode(jsonencode({provider = provider, x = x, student = student, course = course, build_ref = build_ref, portal_version = portal_version}))}' | base64 --decode > /etc/nexoandes/config.json
cat > /opt/nexoandes/portal_base.py <<'PYTHON'
"""NexoAndes U2: metadata real, versiones y comprobacion funcional de laboratorio."""
import argparse
import hashlib
import html
import ipaddress
import json
import re
import socket
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.request import Request, ProxyHandler, build_opener

REFRESH_SECONDS = 30
MAX_AGE_SECONDS = 90

def utc_now():
    return datetime.now(timezone.utc).isoformat(timespec='seconds')

def validate_config(c):
    if c.get('provider') not in ('aws', 'azure'):
        raise ValueError('provider: aws o azure')
    x = c.get('x')
    if type(x) is not int or not 1 <= x <= 254:
        raise ValueError('x: entero entre 1 y 254')
    if c.get('student') != f'a{x:03d}':
        raise ValueError('student debe corresponder a x: aNNN')
    if not isinstance(c.get('course'), str) or not re.fullmatch(r'c[0-9]{2}', c['course']):
        raise ValueError('course: cNN')
    if not isinstance(c.get('build_ref'), str) or not re.fullmatch(r'[A-Za-z0-9._-]{4,80}', c['build_ref']):
        raise ValueError('build_ref: referencia real de 4 a 80 caracteres')
    if c.get('portal_version') not in ('v1', 'v2'):
        raise ValueError('portal_version: v1 o v2')
    if c['provider'] == 'azure' and c['portal_version'] != 'v1':
        raise ValueError('En este artefacto U2 Azure conserva v1')
    return {k: c[k] for k in ('provider', 'x', 'student', 'course', 'build_ref', 'portal_version')}

def cloud_metadata(provider, fetch=None):
    if fetch is None:
        opener = build_opener(ProxyHandler({}))
        def fetch(path, headers=None, method='GET'):
            request = Request('http://169.254.169.254' + path, headers=headers or {}, method=method)
            with opener.open(request, timeout=2) as response:
                return response.read(65536).decode('utf-8')
    if provider == 'aws':
        token = fetch('/latest/api/token', {'X-aws-ec2-metadata-token-ttl-seconds': '60'}, 'PUT')
        def get(path):
            return fetch('/latest/meta-data/' + path, {'X-aws-ec2-metadata-token': token}).strip()
        result = {'resource_id': get('instance-id'),
                  'location': get('placement/availability-zone'),
                  'private_ip': get('local-ipv4'), 'hostname': socket.gethostname()}
    else:
        data = json.loads(fetch('/metadata/instance?api-version=2021-02-01', {'Metadata': 'true'}))
        result = {'resource_id': data['compute']['vmId'], 'resource_name': data['compute']['name'],
                  'location': data['compute']['location'],
                  'private_ip': data['network']['interface'][0]['ipv4']['ipAddress'][0]['privateIpAddress'],
                  'hostname': socket.gethostname()}
    if not all(isinstance(result.get(k), str) and result[k].strip()
               for k in ('resource_id', 'location', 'private_ip', 'hostname')):
        raise ValueError('metadata incompleta')
    ipaddress.ip_address(result['private_ip'])
    return result

class MetadataState:
    def __init__(self):
        self.lock = threading.Lock()
        self.data = {}
        self.last_success = None
        self.last_success_mono = None
        self.last_attempt = None
        self.error = 'Pendiente de primera consulta'

    def refresh(self, provider, fetch=None):
        attempt = utc_now()
        try:
            data = cloud_metadata(provider, fetch)
        except Exception as exc:
            with self.lock:
                self.last_attempt = attempt
                self.error = type(exc).__name__
            return
        with self.lock:
            self.data = data
            self.last_attempt = attempt
            self.last_success = utc_now()
            self.last_success_mono = time.monotonic()
            self.error = None

    def snapshot(self):
        with self.lock:
            age = None if self.last_success_mono is None else max(0, time.monotonic() - self.last_success_mono)
            ok = bool(self.data) and self.error is None and age is not None and age <= MAX_AGE_SECONDS
            return {**self.data, 'metadata_ok': ok,
                    'metadata_cached': bool(self.data),
                    'metadata_stale': bool(self.data) and not ok,
                    'metadata_age_seconds': None if age is None else round(age, 2),
                    'metadata_last_success_utc': self.last_success,
                    'metadata_last_attempt_utc': self.last_attempt,
                    'metadata_error': self.error}

def make_info(config, release, profile, artifact_sha, state):
    return {'project': 'NexoAndes', 'phase': 'U2',
            **{k: config[k] for k in ('provider', 'x', 'student', 'course', 'build_ref')},
            'version': release, 'functional_profile': profile, 'artifact_sha256': artifact_sha,
            **state.snapshot(), 'observed_at_utc': utc_now()}

def functional_check(info, profile):
    checks = {'metadata_available': info['metadata_ok'],
              'resource_identified': bool(info.get('resource_id'))}
    if profile == 'extended':
        try:
            checks['ipv4_observed'] = ipaddress.ip_address(info.get('private_ip', '')).version == 4
        except ValueError:
            checks['ipv4_observed'] = False
        checks['location_observed'] = bool(info.get('location'))
        checks['metadata_fresh'] = info['metadata_ok'] and info['metadata_age_seconds'] <= MAX_AGE_SECONDS
    return {'operation': 'identity_check', 'profile': profile,
            'passed': all(checks.values()), 'checks': checks}

def render_page(info, check):
    esc = lambda value: html.escape('No disponible' if value is None else str(value), quote=True)
    identity = [('Alumno', info['student']), ('Curso', info['course']), ('X', info['x']),
                ('Proveedor', info['provider'].upper()), ('Build / commit', info['build_ref']),
                ('SHA-256 del artefacto instalado', info['artifact_sha256'])]
    resource = [('ID real', info.get('resource_id')), ('Nombre del recurso', info.get('resource_name')),
                ('Zona / ubicación', info.get('location')), ('IP privada real', info.get('private_ip')),
                ('Hostname', info.get('hostname'))]
    times = [('Respuesta HTTP (UTC)', info['observed_at_utc']),
             ('Última consulta correcta de metadata', info['metadata_last_success_utc']),
             ('Último intento de metadata', info['metadata_last_attempt_utc']),
             ('Antigüedad de metadata (segundos)', info['metadata_age_seconds'])]
    def rows(items):
        return ''.join('<dt>' + esc(k) + '</dt><dd>' + esc(v) + '</dd>' for k, v in items)
    valid = info['metadata_ok']
    status = 'Metadata disponible' if valid else 'Comprobación pendiente o degradada'
    cache_note = ('Datos de metadata conservados en memoria; no equivalen a una consulta nueva por cada HTTP.'
                  if valid else 'La metadata no está confirmada. Los últimos datos correctos, si existen, se conservan como antiguos.')
    version_note = ('v1: comprobación básica de identidad del recurso.' if info['version'] == 'v1'
                    else 'v2: comprobación ampliada de identidad, IPv4, ubicación y vigencia de metadata.')
    labels = {'metadata_available': 'Metadata disponible', 'resource_identified': 'Recurso identificado',
              'ipv4_observed': 'IPv4 observada', 'location_observed': 'Ubicación observada',
              'metadata_fresh': 'Metadata vigente'}
    check_rows = ''.join('<li>' + esc(labels[k]) + ': <strong>' + ('Correcto' if v else 'No confirmado') + '</strong></li>'
                         for k, v in check['checks'].items())
    page = '''<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>NexoAndes U2</title>
<style>*{box-sizing:border-box}body{margin:0;background:#f1f5f9;color:#203a4a;font:16px Arial,sans-serif}
header{background:#10334b;color:white;border-bottom:5px solid #c7a15a;padding:25px max(5vw,20px)}
h1{margin:0 0 8px;font-size:28px}.badge{background:#7250b5;border-radius:8px;padding:5px 12px;display:inline-block}
main{max-width:1120px;margin:24px auto;padding:0 20px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:18px}
section{background:white;border:1px solid #d6e0e8;border-radius:12px;padding:22px;margin-bottom:18px}
h2{font-size:19px;margin-top:0;color:#123b57}dl{margin:0}dt{font-size:14px;color:#526979;margin-top:14px}
dd{margin:4px 0;overflow-wrap:anywhere}a{color:#166ba0}li{margin:10px 0}.status{border-left:6px solid COLOR}
.muted{font-size:14px;color:#536b7a;line-height:1.5}footer{padding:12px 0 24px;font-size:14px}
@media(max-width:760px){.grid{grid-template-columns:1fr}}</style></head><body>
<header><h1>Portal Operacional NexoAndes <span class="badge">VERSION</span></h1>
Unidad 2 · Infraestructura reproducible · AWS / Azure</header><main>
<section class="status"><h2>STATUS</h2><p>CACHE</p><p class="muted">Recarga la página para obtener otra respuesta HTTP. La metadata se consulta cada 30 s.</p></section>
<div class="grid"><section><h2>Identificación del despliegue</h2><dl>IDENTITY</dl></section>
<section><h2>Recurso observado</h2><dl>RESOURCE</dl></section></div>
<section><h2>Comprobación funcional</h2><p>VERSION_NOTE</p><ul>CHECK_ROWS</ul>
<p class="muted">Estos resultados no acreditan por sí solos continuidad ni recuperación.</p></section>
<section><h2>Tiempo y procedencia de los datos</h2><dl>TIMES</dl>
<p class="muted">Contrasta con el proveedor, el repositorio y los registros del pipeline. El endpoint se registra desde el cliente.</p></section>
<footer><a href="/api/info">JSON de identidad</a> · <a href="/api/check">Comprobación funcional JSON</a> · <a href="/health">Salud del proceso</a></footer>
</main></body></html>'''
    values = {'COLOR': '#22866c' if valid else '#cb8a23', 'VERSION_NOTE': esc(version_note),
              'VERSION': esc(info['version']), 'STATUS': esc(status), 'CACHE': esc(cache_note),
              'IDENTITY': rows(identity), 'RESOURCE': rows(resource),
              'CHECK_ROWS': check_rows, 'TIMES': rows(times)}
    return re.sub(r'\b(?:VERSION_NOTE|CHECK_ROWS|IDENTITY|RESOURCE|VERSION|STATUS|CACHE|TIMES|COLOR)\b',
                  lambda match: values[match.group()], page)

def handler_factory(config, release, profile, artifact_sha, state):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            path = self.path.split('?', 1)[0]
            if path not in ('/', '/health', '/api/info', '/api/check'):
                self.send_error(404)
                return
            info = make_info(config, release, profile, artifact_sha, state)
            check = functional_check(info, profile)
            if path == '/health':
                data = {'process': 'running', 'version': release, 'provider': config['provider'],
                        'observed_at_utc': info['observed_at_utc']}
                status, mime = 200, 'application/json; charset=utf-8'
            elif path == '/':
                data = render_page(info, check)
                status, mime = (200 if check['passed'] else 503), 'text/html; charset=utf-8'
            else:
                data = info if path == '/api/info' else {**info, **check}
                status, mime = (200 if check['passed'] else 503), 'application/json; charset=utf-8'
            body = data.encode('utf-8') if isinstance(data, str) else json.dumps(data, ensure_ascii=False).encode('utf-8')
            self.send_response(status)
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, fmt, *args):
            pass
    return Handler

def main(release, profile):
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', required=True)
    parser.add_argument('--port', type=int, default=80)
    args = parser.parse_args()
    config = validate_config(json.loads(Path(args.config).read_text(encoding='utf-8')))
    if config['portal_version'] != release:
        raise ValueError('Version de configuracion distinta del artefacto instalado')
    root = Path(__file__).resolve().parent
    artifact_sha = hashlib.sha256((root / 'portal_base.py').read_bytes() + b'\0' + (root / 'portal_release.py').read_bytes()).hexdigest()
    state = MetadataState()
    def refresh_loop():
        while True:
            state.refresh(config['provider'])
            time.sleep(REFRESH_SECONDS)
    threading.Thread(target=refresh_loop, daemon=True).start()
    ThreadingHTTPServer(('0.0.0.0', args.port), handler_factory(config, release, profile, artifact_sha, state)).serve_forever()
PYTHON
# Se instala un archivo de version diferente; no se cambia solamente una etiqueta.
python3 - <<'INSTALL_RELEASE'
import json, pathlib, sys
sys.path.insert(0, '/opt/nexoandes')
from portal_base import validate_config
c = validate_config(json.loads(pathlib.Path('/etc/nexoandes/config.json').read_text()))
releases = {
    'v1': "from portal_base import main\nif __name__ == '__main__':\n    main('v1', 'basic')\n",
    'v2': "from portal_base import main\nif __name__ == '__main__':\n    main('v2', 'extended')\n",
}
pathlib.Path('/opt/nexoandes/portal_release.py').write_text(releases[c['portal_version']], encoding='utf-8')
INSTALL_RELEASE
chmod 0644 /etc/nexoandes/config.json /opt/nexoandes/*.py
PYTHON_BIN=$(command -v python3)
cat > /etc/systemd/system/nexoandes.service <<UNIT
[Unit]
Description=Portal Operacional NexoAndes U2
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=nexoandes
Group=nexoandes
WorkingDirectory=/opt/nexoandes
ExecStart=$PYTHON_BIN -B /opt/nexoandes/portal_release.py --config /etc/nexoandes/config.json --port 80
Restart=on-failure
RestartSec=5
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable nexoandes.service
systemctl restart nexoandes.service
systemctl is-active --quiet nexoandes.service
echo 'Bootstrap NexoAndes U2 terminado. Verificar metadata, proveedor y respuesta HTTP.'
