# Plan de cambio v1 → v2 y recuperación (AWS)

Declarado antes de ejecutar el cambio. Contexto: cuenta AWS Academy, región us-east-1.

## Estado de partida
- Endpoint observado: http://na-u2-c50-a006-alb-1539241886.us-east-1.elb.amazonaws.com
- Controlador: ASG `na-u2-c50-a006-asg`, Launch Template `na-u2-c50-a006-lt` versión 1.
- Versión activa: v1 (perfil `basic`), build `0aef2c091431`, AMI `ami-0b17a6d8467be8c20`.
- Instancias v1: i-02b1c11dfeb5f79b6 (us-east-1b) e i-05816f5ad721138a2 (us-east-1a).

## Artefactos
v1 y v2 se instalan desde la misma plantilla del docente (`templates/user_data_u2.sh.tpl`); la versión la define `app_version` en `variables.tf`. El cambio de `app_version` modifica el user data, Terraform crea una versión nueva del Launch Template y el ASG reemplaza las instancias. No se modifica ninguna instancia existente. El Portal no guarda datos: reemplazar instancias no pierde información. El state vive en S3, fuera de las instancias.

## Estrategia elegida y alternativas
Se compararon dos estrategias con reemplazo:
- **Rolling con Instance Refresh (elegida).** Reemplaza las instancias de a una dentro del mismo ASG y del mismo target group. Solo necesita una instancia temporal (3 en total), cabe en la cuota del laboratorio y tiene un único controlador: el ASG.
- **Blue-green.** Crea un segundo ASG y target group con v2 y cambia el listener del ALB de una vez. Permite volver atrás cambiando el listener, sin reemplazar instancias, pero duplica la capacidad (4 instancias) y suma recursos y pasos.

Se elige rolling porque el Portal no necesita un corte instantáneo entre versiones y la cuota y el presupuesto del laboratorio favorecen menos capacidad temporal. Si se exigiera volver a v1 en segundos, sin lanzar instancias nuevas, la decisión cambiaría a blue-green.

## Capacidad
- Base: 2 instancias (min = deseada = 2).
- Temporal: 1 instancia (max = 3), solo durante el reemplazo.
- Instance Refresh: `min_healthy_percentage = 100` (nunca menos de 2 sanas) y `max_healthy_percentage = 150` (lanza la nueva antes de retirar la vieja), con `instance_warmup = 90` s.
- Salud: el target group comprueba `/api/check`, que solo responde 200 si la comprobación funcional del Portal pasa.

## Controlador único
El cambio lo inicia el pipeline (`terraform apply` del plan aprobado en el gate `produccion`) y lo ejecuta solo el Instance Refresh del ASG. No se detienen, reinician ni modifican instancias a mano durante la ventana.

## Observación
- Monitor HTTP (`scripts/monitor_http.sh`): `GET /api/check` al endpoint cada 2 s, timeout 5 s, sin reintentos. Registra hora UTC, código HTTP, versión, instancia y resultado.
- Monitor de controlador (`scripts/monitor_asg.sh`): cada 30 s registra el estado del Instance Refresh, las instancias del ASG con su versión de Launch Template y la salud de los destinos.
- Ventana: desde 60 s antes del inicio del apply hasta 120 s después de la estabilización.

## Criterios de aceptación
- Ventana completa, sin separaciones mayores a 7 s entre muestras HTTP.
- Cero fallos funcionales: ningún timeout, error, HTTP distinto de 200 ni respuesta con alumno, curso o versión incorrectos. Durante la transición se aceptan v1 y v2; después de estabilizar, solo v2.
- En cada consulta al controlador, al menos 2 destinos `healthy`.
- Estabilización: Instance Refresh `Successful`, 2 destinos `healthy` con la versión nueva del Launch Template y respuestas v2 (perfil `extended`) de ambas instancias nuevas.

## Señales de fallo y detención
Se detiene el cambio si ocurre cualquiera de estas condiciones: un fallo funcional repetido en el monitor HTTP, menos de 2 destinos `healthy`, Instance Refresh en `Failed`, o un refresh que no avanza en 15 minutos. La detención se hace sobre el mismo controlador con `aws autoscaling cancel-instance-refresh`, se conserva el registro completo y se pasa a la recuperación.

## Recuperación
Reversión planificada a v1 mediante otra operación, después de que termine la actualización: un commit que vuelve `app_version` a `"v1"`, revisado por PR y aplicado por el pipeline. Eso crea una versión nueva del Launch Template con el artefacto v1 y un Instance Refresh hacia instancias nuevas. No se configura `auto_rollback`, así que la recuperación no depende de un rollback automático dentro de la operación activa. Se observa con el mismo protocolo y la recuperación se acepta con los mismos criterios, con v1 como versión objetivo. Requisitos: credenciales vigentes del laboratorio, AMI fijada, plantilla versionada y código reconciliado con un plan posterior sin cambios.
