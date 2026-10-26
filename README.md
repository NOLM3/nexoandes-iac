# NexoAndes — Portal Operacional V1 (Fase 1)

Infraestructura como código del Portal Operacional NexoAndes, desarrollada para la Evaluación Sumativa U1 de IC106TICL — Automatización de Infraestructura con IaC.

- **Autor:** Martín López Speer — N.° de lista 6
- **Repositorio:** https://github.com/NOLM3/nexoandes-iac

## Arquitectura

| Componente | Configuración |
|---|---|
| VPC | `172.16.0.0/16`, DNS habilitado |
| Subred pública | `172.16.6.0/24` en `us-east-1a`, IPv4 pública automática |
| Internet Gateway | Asociado a la VPC |
| Tabla de rutas | `0.0.0.0/0 → Internet Gateway`, asociada a la subred pública |
| Security group del portal | Ingreso solo HTTP/80; egreso hacia Internet para el bootstrap; sin SSH |
| Security group por defecto | Sin reglas (todo el tráfico bloqueado) |
| EC2 | `t2.micro`, Amazon Linux 2023, IMDSv2 obligatorio, volumen raíz cifrado |
| User data | Artefacto docente `user_data_v1.sh.tpl`: instala nginx, publica el Portal Operacional V1 con datos obtenidos vía IMDSv2 y expone `/health.txt` |
| Tags comunes | `StudentNumber = 6`, `Project = NexoAndes`, `Phase = Fase1` |

## Estructura del repositorio

```
.
├── .github/workflows/terraform.yml   # Pipeline CI/CD
├── modules/
│   ├── network/                      # VPC, subred, IGW, rutas y security groups
│   └── compute/                      # AMI (data source) e instancia EC2
├── templates/user_data_v1.sh.tpl     # Artefacto docente del Portal Operacional V1
├── tests/fase1.tftest.hcl            # Pruebas IaC con aserciones
├── backend.tf                        # State remoto en S3
├── locals.tf                         # Prefijo de nombres, subred, parámetros del portal y tags
├── main.tf                           # Root module: composición de módulos e integración del user data
├── outputs.tf                        # Valores para verificación
├── provider.tf                       # Provider AWS con default_tags
├── variables.tf                      # Entradas configurables
├── versions.tf                       # Restricciones de versión
├── .tflint.hcl                       # Configuración del linter
└── .terraform.lock.hcl               # Versiones exactas de providers
```

### Composición de módulos

El root module calcula la subred a partir de `student_number` y la entrega al módulo `network`. El módulo `compute` recibe la subred y el security group desde los outputs de `network`, lo que establece la dependencia: la red se crea antes que la instancia.

### Integración del Portal Operacional V1

El artefacto docente se conserva sin modificar su lógica, HTML ni CSS. El root module lo renderiza con `templatefile()` y entrega el resultado al módulo `compute` como `user_data`:

| Parámetro de la plantilla | Origen en Terraform | Valor |
|---|---|---|
| `student_name` | `var.student_name` | `Martín López Speer` |
| `student_number` | `var.student_number` | `6` |
| `environment` | `local.environment` | `fase1` |
| `portal_version` | `local.portal_version` | `v1` |
| `project_name` | `local.portal_project_name` | `NexoAndes Portal Operacional` |

Las secuencias `$${...}` de la plantilla son intencionales: Terraform las conserva como variables de Bash.

## Prerrequisitos

- Terraform >= 1.10
- AWS CLI v2
- Git
- TFLint y Checkov (solo para ejecutar los controles localmente)
- Sesión activa de AWS Academy Learner Lab
- Bucket S3 para el state (ver sección siguiente)

## Variables

| Variable | Descripción | Valor por defecto |
|---|---|---|
| `aws_region` | Región de AWS | `us-east-1` |
| `student_name` | Nombre mostrado en el portal | `Martín López Speer` |
| `student_number` | N.° de lista; define la subred `172.16.X.0/24` (rango válido 1–254) | `6` |
| `vpc_cidr` | Rango de la VPC | `172.16.0.0/16` |
| `availability_zone` | Zona de la subred pública | `us-east-1a` |
| `instance_type` | Tipo de instancia EC2 | `t2.micro` |

## State

El state se almacena en S3, fuera de Git:

- **Bucket:** `nexoandes-tfstate-s6-943830680153`
- **Key:** `fase1/terraform.tfstate`
- **Protecciones:** cifrado, versionado, bloqueo de acceso público y bloqueo de escritura concurrente (`use_lockfile`)

El