#!/usr/bin/env bash
# Monitor del controlador (protocolo U2): cada 30 s registra el Instance Refresh,
# las instancias del ASG con su versión de Launch Template y la salud de los destinos.
# Uso: bash scripts/monitor_asg.sh <asg> <target_group_arn> <archivo.log>    (Ctrl+C para terminar)
set -u
ASG="$1"; TG="$2"; LOG="$3"
while true; do
  T=$SECONDS
  {
    echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "-- Instance Refresh (estado, % completado):"
    aws autoscaling describe-instance-refreshes --auto-scaling-group-name "$ASG" --max-records 1 \
      --query 'InstanceRefreshes[0].[Status,PercentageComplete]' --output text
    echo "-- Instancias del ASG (id, zona, ciclo de vida, salud, versión LT):"
    aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
      --query 'AutoScalingGroups[0].Instances[].[InstanceId,AvailabilityZone,LifecycleState,HealthStatus,LaunchTemplate.Version]' --output text
    echo "-- Destinos del ALB (id, estado):"
    aws elbv2 describe-target-health --target-group-arn "$TG" \
      --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]' --output text
  } 2>&1 | tee -a "$LOG"
  RESTO=$(( 30 - (SECONDS - T) ))
  [ "$RESTO" -gt 0 ] && sleep "$RESTO"
done
