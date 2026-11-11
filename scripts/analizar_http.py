import csv, sys
from datetime import datetime
f = sys.argv[1]
filas = [r for r in csv.DictReader(open(f)) if r.get("hora_utc")]
t = lambda r: datetime.strptime(r["hora_utc"], "%Y-%m-%dT%H:%M:%S.%fZ")
fallos = [r for r in filas if r["http"] != "200" or r["passed"] != "True" or r["alumno"] != "a006" or r["curso"] != "c50" or r["version"] not in ("v1", "v2")]
saltos = [((t(b) - t(a)).total_seconds(), a["hora_utc"], b["hora_utc"]) for a, b in zip(filas, filas[1:])]
mayor = max(saltos)
v1 = [r for r in filas if r["version"] == "v1"]; v2 = [r for r in filas if r["version"] == "v2"]
print("Archivo:", f)
print("Muestras:", len(filas), "| desde", filas[0]["hora_utc"], "hasta", filas[-1]["hora_utc"])
print("Separación media: %.2f s | máxima: %.2f s (%s -> %s)" % (sum(s for s, _, _ in saltos) / len(saltos), *mayor))
print("Fallos funcionales:", len(fallos))
for r in fallos: print("  ", r["hora_utc"], r["http"], r["version"], r["instancia"], "curl", r["error_curl"])
if v1: print("v1:", len(v1), "| última", v1[-1]["hora_utc"], "| instancias", sorted({r["instancia"] for r in v1}))
if v2: print("v2:", len(v2), "| primera", v2[0]["hora_utc"], "| instancias", sorted({r["instancia"] for r in v2}), "| perfiles", sorted({r["perfil"] for r in v2}))
