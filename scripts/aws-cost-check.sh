#!/bin/bash
# Daily AWS cost check - chạy mỗi sáng

echo "=== AWS Cost Last 7 Days ==="
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost \
  --output table

echo ""
echo "=== Top 5 Services This Month ==="
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[0].Groups[?Metrics.UnblendedCost.Amount>`0.01`] | sort_by(@, &Metrics.UnblendedCost.Amount) | reverse(@)[:5]' \
  --output table

echo ""
echo "=== ⚠️ Resources còn chạy (cần check để destroy) ==="
echo "EC2 instances:"
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,LaunchTime]' \
  --output table

echo "EKS clusters:"
aws eks list-clusters --output table

echo "RDS instances:"
aws rds describe-db-instances \
  --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus]' \
  --output table

echo "NAT Gateways (đắt nhất - $33/tháng/cái!):"
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[].[NatGatewayId,VpcId,State]' \
  --output table