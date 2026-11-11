#!/usr/bin/env bash
# Monitor HTTP del protocolo U2: GET /api/check cada 2 s, timeout 5 s, sin reintentos.
# Uso: bash scripts/monitor_http.sh <endpoint> <archivo.csv>    (Ctrl+C para terminar)
set -u
URL="$1"; LOG="$2"; BODY=$(mktemp)
echo "hora_utc,http,segundos,version,perfil,instancia,zona,alumno,curso,build,passed,error_curl" | tee -a "$LOG"
while true; do
  INICIO=$(date +%s.%N)
  HORA=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
  : > "$BODY"
  RES=$(curl -s --max-time 5 -o "$BODY" -w '%{http_code},%{time_total}' "$URL/api/check")
  ERR=$?
  CAMPOS=$(python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(",".join(str(d.get(k, "")) for k in ("version", "functional_profile", "resource_id", "location", "student", "course", "build_ref", "passed")))
except Exception:
    print(",,,,,,,")' "$BODY")
  echo "$HORA,$RES,$CAMPOS,$ERR" | tee -a "$LOG"
  # Mantiene la cadencia de 2 s descontando lo que tardó la petición.
  ESPERA=$(python3 -c 'import sys; print(max(0.0, 2 - (float(sys.argv[2]) - float(sys.argv[1]))))' "$INICIO" "$(date +%s.%N)")
  sleep "$ESPERA"
done
