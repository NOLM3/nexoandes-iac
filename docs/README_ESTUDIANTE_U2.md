# Portal Operacional NexoAndes U2 — guía para estudiantes

## 1. Qué recibes y qué debes desarrollar

`user_data_u2.sh.tpl` es el artefacto docente para instalar el Portal en Linux. Una misma plantilla admite AWS y Azure. Instala un servicio Python y la versión seleccionada del Portal; no crea redes, máquinas, balanceadores, grupos, credenciales ni pipelines.

Tu trabajo consiste en integrarla y parametrizarla desde Terraform, desarrollar la infraestructura modular y el pipeline, ejecutar el despliegue, comprobar ambos proveedores y realizar en AWS la actualización por reemplazo y la recuperación solicitadas en la evaluación U2 vigente. Conserva la lógica interna de la plantilla. Su programación no se evalúa.

Este artefacto sustituye al bootstrap del Portal U1 para esta fase. No ejecutes ambos sobre la misma máquina: los dos servicios intentarían escuchar en el puerto 80. No contiene botones de carga, inyección de fallas, autoescalamiento ni remediación de U3.

La plantilla ofrece dos versiones de la aplicación:

| Versión | Comportamiento instalado |
|---|---|
| `v1` | Página de identidad y operación `/api/check` con comprobación básica de metadata e identificación del recurso. |
| `v2` | Página con descripción de la nueva versión y operación `/api/check` ampliada: añade comprobaciones de IPv4, ubicación y vigencia de metadata. |

El bootstrap instala un `portal_release.py` distinto para cada versión. El Portal expone el SHA-256 de sus archivos de aplicación instalados. Esta diferencia permite comprobar el artefacto efectivo; no demuestra por sí sola que hayas reemplazado infraestructura. Debes contrastar también IDs, plantilla de cómputo y operación del controlador. No cambies una etiqueta para simular una actualización o recuperación.

En el alcance de este artefacto, AWS admite `v1` y `v2`; Azure conserva `v1`. Una excepción al encargo requiere autorización del docente.

## 2. Requisitos del laboratorio

- Imagen Linux con cloud-init, Bash y systemd; Python 3.8 o superior y `useradd`. Referencia de diseño: Ubuntu Server LTS con cloud-init. La imagen concreta debe ser la autorizada y validada por el docente.
- Python 3 disponible en la imagen o salida autorizada a sus repositorios para instalarlo mediante apt, dnf o yum. No se descargan dependencias Python externas.
- Acceso al servicio de metadata local de la máquina. En AWS se utiliza exclusivamente IMDSv2; en Azure, IMDS con encabezado `Metadata: true`.
- Puerto HTTP 80 libre. No requiere Nginx ni Apache. El servicio Python es un servidor didáctico de laboratorio, no una plataforma de publicación para producción.
- Rutas, reglas de acceso y salida compatibles con el bootstrap. En AWS, los destinos del Portal deben recibir tráfico desde el SG del ALB según tu arquitectura; en Azure, aplica el NSG y acceso autorizados. No se requiere abrir SSH para usar este artefacto.

La plantilla se ejecuta con los privilegios del bootstrap. El servicio del Portal funciona después como usuario de sistema `nexoandes`, con capacidad limitada para escuchar en el puerto 80. No necesita access keys, tokens de Azure ni permisos para administrar recursos cloud: solo consulta metadata local.

## 3. Ubicación de la plantilla

Una organización posible es:

```text
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── templates/
│   └── user_data_u2.sh.tpl
└── modules/
    ├── portal_aws/
    └── portal_azure/
```

Adapta las rutas a tu estructura real. Conserva la plantilla con codificación UTF-8 y saltos de línea LF. Versiona la plantilla y este README junto con tu código, respetando las exclusiones de state, secretos y planes binarios.

## 4. Parámetros de `templatefile()`

Los seis valores son obligatorios. El proyecto `NexoAndes` y la fase `U2` están fijados dentro de la aplicación.

| Clave | Tipo y regla | Ejemplo ilustrativo |
|---|---|---|
| `provider` | String: `aws` o `azure`. | `aws` |
| `x` | Número entero entre 1 y 254, asignado por el docente. | `7` |
| `student` | String `aNNN`, correspondiente a X con tres dígitos. | `a007` |
| `course` | String `cNN`. | `c01` |
| `build_ref` | Referencia real del código/artefacto desplegado; 4–80 caracteres: letras, números, punto, guion o guion bajo. | SHA del commit preparado por el pipeline. |
| `portal_version` | String: `v1` o `v2`; en Azure, `v1`. | `v1` |

Los ejemplos de identidad no son datos de una ejecución. No incluyas nombres completos, credenciales ni información personal innecesaria. `build_ref` es un dato declarado por tu despliegue: debes contrastarlo con el repositorio y la ejecución; el Portal no lo certifica contra Git por sí solo.

La plantilla serializa los parámetros a JSON/base64 para que no sean interpretados como instrucciones de Bash. Base64 no cifra datos ni permite incluir secretos.

## 5. Renderizado desde Terraform

El siguiente fragmento muestra únicamente la integración del artefacto. No es una solución de infraestructura ni un pipeline completo. Declara y valida las variables de tu proyecto: `x` (number), `course`, `build_ref` y `app_version` (string).

```hcl
locals {
  portal_identity = {
    x         = var.x
    student   = format("a%03d", var.x)
    course    = var.course
    build_ref = var.build_ref
  }

  portal_aws_bootstrap = templatefile(
    "${path.module}/templates/user_data_u2.sh.tpl",
    merge(local.portal_identity, {
      provider       = "aws"
      portal_version = var.app_version
    })
  )

  portal_azure_bootstrap = templatefile(
    "${path.module}/templates/user_data_u2.sh.tpl",
    merge(local.portal_identity, {
      provider       = "azure"
      portal_version = "v1"
    })
  )
}
```

Entrega el contenido renderizado a tus módulos mediante sus inputs. Si `templatefile()` se llama dentro de un módulo hijo, `path.module` apunta a ese módulo: ajusta la ubicación de la plantilla o pasa el contenido desde el root.

### AWS: Launch Template

El argumento `user_data` de `aws_launch_template` recibe el script codificado en base64:

```hcl
# Fragmento dentro de tu aws_launch_template:
user_data = base64encode(local.portal_aws_bootstrap)

metadata_options {
  http_endpoint = "enabled"
  http_tokens   = "required"
}
```

En tu composición modular, reemplaza la referencia local por el input correspondiente. El ASG debe usar la versión de Launch Template prevista por tu estrategia. Crear otra versión de la plantilla no prueba que los componentes activos hayan sido reemplazados ni que ya sirvan el Portal nuevo.

Si tu estrategia autorizada usa `aws_instance`, su argumento `user_data` recibe el script sin codificar, mientras que `user_data_base64` recibe base64. No confundas los argumentos ni codifiques dos veces. Revisa en el plan si el cambio propone actualización o reemplazo.

### Azure: VM Linux

El argumento `custom_data` de `azurerm_linux_virtual_machine` recibe base64:

```hcl
# Fragmento dentro de tu azurerm_linux_virtual_machine:
custom_data = base64encode(local.portal_azure_bootstrap)
```

Utiliza una imagen con cloud-init y conserva `portal_version = "v1"`. Completa red, NIC, IP pública, disco, configuración de acceso y demás requisitos en tu propio módulo. Si la plataforma exige una clave pública administrativa, usa el mecanismo autorizado sin publicar su clave privada. La plantilla no exige ingresar por SSH.

En AWS, el script renderizado debe caber en el límite de user data de 16 KiB antes de su codificación exterior. No agregues imágenes o librerías dentro del script. Usa el archivo suministrado sin ampliar su lógica.

## 6. Qué publica el Portal

| Ruta | Uso y resultado |
|---|---|
| `/` | Página HTML con identidad, recurso, versión, comprobación funcional y tiempos. HTTP 200 si la comprobación pasa; 503 si no puede confirmarse. |
| `/health` | Salud básica del proceso HTTP. Devuelve 200 si el servidor atiende, incluso cuando la metadata está pendiente o degradada. No acredita la función completa. |
| `/api/info` | JSON con identidad, versión, perfil funcional, hash de aplicación y metadata. Devuelve 503 si no puede confirmar los datos requeridos. |
| `/api/check` | JSON anterior más `operation`, `profile`, `checks` y `passed`; comportamiento básico en v1 y ampliado en v2. HTTP 200 cuando pasa; 503 cuando falla. |

Selecciona y justifica la ruta del health check según tu diseño. Si eliges `/health`, complementa la salud con `/api/info` y `/api/check`: un destino saludable no garantiza identidad, versión ni función correctas.

Los endpoints admiten GET. Para comprobar, usa `curl` sin `-I`; no se implementa HEAD. No hay endpoint que provoque carga, falle instancias o administre infraestructura.

### Metadata y tiempos

La aplicación consulta metadata cada 30 segundos y mantiene la última lectura correcta en memoria. No hace una consulta nueva por cada petición HTTP.

- `observed_at_utc`: hora de la respuesta HTTP actual.
- `metadata_last_success_utc`: hora de la última lectura correcta al servicio de metadata.
- `metadata_last_attempt_utc`: hora de inicio del último intento de consulta.
- `metadata_age_seconds`: antigüedad de la lectura correcta, medida con reloj monotónico.
- `metadata_cached`: hay una lectura previa conservada en memoria; puede ser válida o antigua.
- `metadata_stale`: esa lectura no se puede considerar vigente por error de consulta o antigüedad.
- `metadata_ok`: última consulta sin error, datos requeridos disponibles y antigüedad no superior a 90 s.

Tras un error se conservan los últimos datos correctos, pero se muestran como antiguos y las rutas funcionales devuelven 503. Si nunca hubo lectura correcta, los campos no se inventan. Al reiniciar el proceso, la caché desaparece y se consulta de nuevo. Los tokens IMDSv2 y las respuestas completas de metadata no se publican.

El Portal no inventa ni determina su endpoint público. Registra desde el cliente el DNS del ALB en AWS y la URL/IP pública real en Azure. Contrasta la IP privada, el ID y la ubicación con las consultas al proveedor.

## 7. Despliegue inicial y comprobaciones

Despliega v1 en ambos proveedores mediante el pipeline exigido, con controles, plan y autorización. Espera a que termine el bootstrap; un recurso creado o un `apply` exitoso no prueban que el servicio esté listo.

Los comandos siguientes usan Bash. En Windows puedes ejecutarlos en el entorno Bash autorizado; si trabajas en PowerShell, adapta la asignación de variables y utiliza `curl.exe` para evitar confundirlo con otros comandos.

```bash
ENDPOINT="http://<endpoint-real>"
curl -sS --max-time 5 "$ENDPOINT/"
curl -sS --max-time 5 "$ENDPOINT/health"
curl -sS --max-time 5 -w '\nHTTP %{http_code}\n' "$ENDPOINT/api/info"
curl -sS --max-time 5 -w '\nHTTP %{http_code}\n' "$ENDPOINT/api/check"
```

Reemplaza `<endpoint-real>` y evita la barra final en `ENDPOINT`. No interpretes solo el código de salida de curl: con estas opciones un HTTP 503 puede dejar salida de proceso 0. Comprueba código HTTP y cuerpo.

Contrasta tres fuentes: outputs Terraform, consulta independiente AWS/Azure y respuesta HTTP. Comprueba alumno/curso/X, fase U2, proveedor, versión, build, recurso y ubicación. Conserva la hora y el contexto. Una respuesta aislada detrás del ALB identifica al backend que la atendió; no certifica todos los destinos activos.

## 8. Actualización y recuperación AWS

Conserva una referencia reproducible de v1, configura v2 en el código y ejecuta la estrategia autorizada mediante pipeline. Verifica reemplazo real, versión efectiva, salud y capacidad, además de esperar el resultado final del controlador. En `/api/check`, v1 tiene perfil `basic` y v2 `extended`; los artefactos de aplicación instalados también tienen hashes distintos.

La plantilla no coordina tráfico, drenaje, actualización ni rollback. Esas responsabilidades corresponden a tu infraestructura, estrategia y controlador. Mantén un único controlador del cambio.

Para recuperar, utiliza la configuración y el artefacto recuperables definidos en tu plan. Conserva la versión de Launch Template, referencia de imagen y build necesarias. Al volver a v1 pueden existir nuevos IDs e IP privadas. Actualiza el código según la decisión adoptada y revisa un plan posterior. No edites state ni archivos dentro de una instancia para simular el resultado.

Mantén Azure en v1 y verifícalo por separado. Aplica el protocolo de observación completo de la evaluación V6: inicio −60 s a estabilización +120 s; peticiones programadas cada 2 s, timeout 5 s, sin reintentos que oculten fallos; cobertura con separación máxima de 7 s y consultas de capacidad/controlador cada 30 s como máximo. Conserva errores e intentos anteriores. Unos pocos comandos curl no sustituyen esta observación ni la comprobación funcional del contenido.

## 9. Diagnóstico y cierre

Si el Portal no responde, revisa contexto, rutas, reglas de acceso, bootstrap y servicio mediante los mecanismos autorizados. No abras acceso administrativo público solo para diagnosticar.

Comandos de diagnóstico dentro de la VM, únicamente cuando dispongas de un mecanismo autorizado:

```bash
cloud-init status --long
systemctl status nexoandes.service --no-pager
journalctl -u nexoandes.service --no-pager -n 80
```

- Error en parámetros: comprueba tipos, relación X/alumno, curso, build y versión.
- Puerto ocupado: utiliza una imagen limpia; no superpongas este Portal al servidor de U1.
- HTTP 503: consulta el error y los tiempos de metadata; comprueba IMDS y el proveedor configurado. No sustituyas los datos reales por constantes.
- Página v1 cuando esperabas v2: revisa qué destinos atienden, la versión de plantilla y el estado del controlador. Cambiar user data no prueba ejecución nueva del bootstrap.
- Datos que no coinciden: revisa contexto y momento de cada consulta; no mezcles sesiones.

Antes de limpiar, registra la verificación final de ambos proveedores. Retira los recursos evaluados y la capacidad temporal, comprueba la eliminación independientemente y conserva los registros sin secretos. Entrega repositorio, ZIP limpio y ficha PDF según V6. No incluyas state, credenciales, tokens, claves privadas ni planes binarios. Incluye `.terraform.lock.hcl`.

## 10. Referencias técnicas

- AWS, user data y límite de tamaño: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html
- AWS, IMDSv2: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html
- Azure, Instance Metadata Service: https://learn.microsoft.com/azure/virtual-machines/instance-metadata-service
- Terraform, Launch Template: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template
- Terraform, VM Linux Azure: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
- Terraform, templatefile: https://developer.hashicorp.com/terraform/language/functions/templatefile

La validación local del paquete no sustituye el despliegue en las imágenes y cuentas autorizadas. Comunica restricciones reales al docente y documenta las alternativas aprobadas.
