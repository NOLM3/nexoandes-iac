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

El bucket se crea una sola vez, antes del primer `terraform init`:

```bash
BUCKET="nexoandes-tfstate-s6-$(aws sts get-caller-identity --query Account --output text)"
aws s3api create-bucket --bucket "$BUCKET" --region us-east-1
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

## Pipeline CI/CD

Definido en `.github/workflows/terraform.yml` (GitHub Actions).

| Evento | Jobs que se ejecutan |
|---|---|
| Pull request hacia `main` | Controles previos → Plan |
| Push a `main` (merge) | Controles previos → Plan → **Gate** → Apply |
| Manual: `plan` | Controles previos → Plan |
| Manual: `apply` | Controles previos → Plan → **Gate** → Apply |
| Manual: `destroy` | Controles previos → **Gate** → Destroy |

### Controles previos

| Control | Herramienta | Propósito |
|---|---|---|
| (a) Formato | `terraform fmt -check` | Estilo uniforme del código |
| (b) Validación | `terraform validate` | Sintaxis y coherencia de la configuración |
| (c) Prueba IaC | `terraform test` | Aserciones sobre el cálculo de la subred, reutilización del módulo y validación de entradas |
| (d) Lint | TFLint | Buenas prácticas: declaraciones sin uso, versiones y tipos |
| (e) Seguridad | Checkov | Configuraciones riesgosas en los recursos |

### Criterio de despliegue

- Si cualquier control falla, el plan no se ejecuta.
- Si el plan falla, el apply no se ejecuta.
- El apply y el destroy usan el environment `produccion`, que exige aprobación manual (gate).
- El apply aplica el plan guardado como artefacto, es decir, exactamente el plan revisado.
- `concurrency` impide ejecuciones simultáneas sobre el mismo state.

### Autenticación

Las credenciales temporales del Learner Lab se cargan como secrets del repositorio (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`). No se escriben en el código y aparecen enmascaradas en los logs. El job de controles no recibe credenciales.

## Flujo de despliegue y limpieza

1. Desarrollar los cambios en una rama de trabajo.
2. Abrir un pull request hacia `main`: el pipeline ejecuta los controles y el plan.
3. Revisar el plan y hacer el merge.
4. El pipeline se detiene en el gate; revisar el plan y aprobar el despliegue.
5. Verificar el resultado (sección siguiente).
6. Ejecutar manualmente el workflow con `plan`: debe indicar `No changes`.
7. Ejecutar manualmente el workflow con `destroy` y aprobar el gate.
8. Comprobar que no quedan recursos.

## Verificación

```bash
terraform output
aws ec2 describe-instances --instance-ids <instance_id> --region us-east-1 \
  --query "Reservations[].Instances[].[InstanceId,State.Name,PrivateIpAddress,PublicIpAddress,Placement.AvailabilityZone]" --output table
curl -I http://<public_ip>/
curl http://<public_ip>/health.txt
```

Las tres fuentes deben coincidir en el Instance ID: el output identifica, el proveedor confirma el recurso y HTTP confirma el servicio. `health.txt` debe responder `ok`.

Comprobación posterior al destroy:

```bash
aws ec2 describe-instances --region us-east-1 --filters "Name=tag:Project,Values=NexoAndes" \
  --query "Reservations[].Instances[].[InstanceId,State.Name]" --output table
aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Project,Values=NexoAndes" --query "Vpcs[].VpcId" --output text
```

## Ejecución local (diagnóstico)

Los controles pueden ejecutarse localmente antes de abrir un pull request. El despliegue evaluado se realiza solo desde el pipeline.

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform test
tflint --init && tflint --recursive
checkov -d . --framework terraform --compact --quiet
terraform plan
```

## Convención de commits

Formato `tipo: descripción`, en minúsculas y en presente:

| Tipo | Uso |
|---|---|
| `feat` | Nueva funcionalidad o recurso |
| `fix` | Corrección de un error |
| `docs` | Documentación |
| `test` | Pruebas |
| `ci` | Pipeline |
| `chore` | Configuración y tareas de mantenimiento |

## Seguridad

- `.gitignore` excluye `.terraform/`, archivos de state, planes, `*.tfvars`, claves y credenciales.
- `.terraform.lock.hcl` sí se versiona.
- Excepciones de Checkov documentadas en el código con su justificación:

| Regla | Justificación |
|---|---|
| CKV_AWS_130 | El diagrama exige IPv4 pública automática en la subred |
| CKV_AWS_260 | El portal debe responder HTTP público en el puerto 80 |
| CKV2_AWS_5 | Falso positivo: el SG se asocia en el módulo `compute` |
| CKV2_AWS_11 | Flow logs corresponden a monitoreo avanzado, fuera de alcance |
| CKV_AWS_126 | Monitoreo detallado fuera de alcance |
| CKV_AWS_135 | `t2.micro` no admite EBS optimizado |
| CKV2_AWS_41 | El portal no consume APIs de AWS; sin rol IAM se aplica mínimo privilegio |

## Restricciones del entorno

- Las credenciales del Learner Lab son temporales y se renuevan en cada sesión; los secrets del repositorio deben actualizarse antes de ejecutar el pipeline.
- El artefacto `user_data_v1.sh.tpl` se publicó después del primer despliegue completo. Mientras no estuvo disponible se utilizó una plantilla equivalente; al recibirlo se integró sin modificaciones y se repitió el despliegue.

## Referencias

- Amazon Web Services. (2026). *Use the Instance Metadata Service to access instance metadata*. https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html
- Bridgecrew. (2026). *Checkov documentation*. https://www.checkov.io/
- GitHub. (2026). *GitHub Actions documentation*. https://docs.github.com/actions
- HashiCorp. (2026). *Terraform documentation*. https://developer.hashicorp.com/terraform/docs
- TFLint. (2026). *TFLint* [Software]. https://github.com/terraform-linters/tflint
