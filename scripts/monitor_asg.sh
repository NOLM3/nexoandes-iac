#!/usr/bin/env bash
# Monitor del controlador (protocolo U2): cada 30 s registra los ASG del Portal (anterior y nuevo),
# sus instancias con la versión de Launch Template y la salud de los destinos del ALB.
# Uso: bash scripts/monitor_asg.sh <prefijo_asg> <target_group_arn> <archivo.log>    (Ctrl+C para terminar)
set -u
PREFIJO="$1"; TG="$2"; LOG="$3"
while true; do
  T=$SECONDS
  {
    echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "-- Grupos e instancias (asg, id, zona, ciclo de vida, salud, versión LT):"
    aws autoscaling describe-auto-scaling-groups \
      --query "AutoScalingGroups[?starts_with(AutoScalingGroupName, '$PREFIJO')].Instances[].[AutoScalingGroupName,InstanceId,AvailabilityZone,LifecycleState,HealthStatus,LaunchTemplate.Version]" \
      --output text
    echo "-- Destinos del ALB (id, estado):"
    aws elbv2 describe-target-health --target-group-arn "$TG" \
      --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]' --output text
  } 2>&1 | tee -a "$LOG"
  RESTO=$(( 30 - (SECONDS - T) ))
  [ "$RESTO" -gt 0 ] && sleep "$RESTO"
done
