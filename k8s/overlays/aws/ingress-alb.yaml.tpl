# k8s/overlays/aws/ingress-alb.yaml.tpl
#
# Placeholders:
#   ${ACM_CERT_ARN} — từ dns output acm_certificate_arn
#   ${APP_FQDN}     — từ dns output full_fqdn (vd: task-manager.vantai.click)

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: task-manager-aws
  namespace: task-manager-dev
  annotations:
    # ALB Provisioning
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'

    # TLS / HTTPS
    alb.ingress.kubernetes.io/certificate-arn: ${ACM_CERT_ARN}
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06
    alb.ingress.kubernetes.io/ssl-redirect: '443'

    # Health Check
    alb.ingress.kubernetes.io/healthcheck-path: /health/ready
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '3'
    alb.ingress.kubernetes.io/success-codes: '200'

    # Tags
    alb.ingress.kubernetes.io/tags: Project=devops,Environment=dev,ManagedBy=kubernetes

spec:
  ingressClassName: alb
  rules:
  - host: ${APP_FQDN}
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 3000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
