# Microservices Architecture Guide

This guide demonstrates a production-ready microservices architecture on EKS with service mesh, distributed tracing, and network policies.

## 📋 Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                     External Traffic                         │
└────────────────────────────┬─────────────────────────────────┘
                             ↓
                    AWS ALB (Ingress)
                             ↓
┌──────────────────────────────────────────────────────────────┐
│                   Linkerd Service Mesh                       │
│  (Traffic management, retries, load balancing)              │
└─────────┬──────────────────────┬──────────────────────┬──────┘
          ↓                      ↓                      ↓
    ┌─────────────┐        ┌──────────────┐      ┌──────────────┐
    │   Frontend  │        │ User Service │      │ Payment Svc  │
    │  (default)  │────────│ (user-svc)   │─────→│ (payment)    │
    └─────────────┘        └──────────────┘      └──────────────┘
          │                      ↑                      ↑
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 ↓
                     ┌──────────────────────┐
                     │  Order Service       │
                     │  (order-svc)         │
                     └──────────────────────┘
                                 ↓
                    ┌────────────────────────┐
                    │  Observability Stack   │
                    ├────────────────────────┤
                    │ • Prometheus (metrics) │
                    │ • Grafana (dashboards) │
                    │ • Loki (logs)          │
                    │ • Jaeger (traces)      │
                    └────────────────────────┘
```

## 🔒 Network Policies

Network policies enforce zero-trust communication between services.

### Service Communication Matrix

| From → To | Frontend | User | Payment | Order | DNS |
|-----------|----------|------|---------|-------|-----|
| Frontend | - | ✓ | ✓ | ✓ | ✓ |
| User | ✗ | - | ✗ | ✗ | ✓ |
| Payment | ✗ | ✓ | - | ✗ | ✓ |
| Order | ✗ | ✓ | ✓ | - | ✓ |

### How Network Policies Work

1. **Default Deny**: All ingress traffic blocked by default
2. **Explicit Allow**: Only specified traffic is allowed
3. **Cross-namespace**: Services can call other namespaces
4. **DNS**: All services can query DNS (for service discovery)

**Example: Payment Service Policy**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-payment-service
  namespace: payment-service
spec:
  podSelector:
    matchLabels:
      app: payment-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: order-service
    ports:
    - protocol: TCP
      port: 8080
```

## 🔗 Linkerd Service Mesh

Linkerd provides:
- **Automatic mTLS**: Encrypted service-to-service communication
- **Circuit Breaking**: Fail-fast on unhealthy services
- **Load Balancing**: Intelligent request distribution
- **Retry Logic**: Automatic retries on transient failures
- **Traffic Splitting**: Canary deployments

### Enabling Linkerd for a Service

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-service
  labels:
    linkerd.io/inject: enabled  # Enable Linkerd sidecar injection
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-service
  namespace: my-service
spec:
  template:
    metadata:
      annotations:
        linkerd.io/inject: enabled  # Also enable at pod level
    spec:
      containers:
      - name: my-app
        image: my-app:1.0
```

### Monitoring Linkerd

```bash
# View Linkerd topology
linkerd viz top

# Check mTLS status
linkerd viz edges namespaces

# View Linkerd dashboard
linkerd viz dashboard

# Port forward to dashboard
kubectl port-forward -n linkerd svc/web 8084:8084
# Access: http://localhost:8084
```

## 🔍 Distributed Tracing with Jaeger

Jaeger tracks requests across all microservices.

### Example: Tracing an Order Request

```
Client Request to Frontend
  ↓
frontend → [trace_id: xyz123]
  ├─ call: user-service/api/user (span: get-user)
  │   └─ returns user data
  ├─ call: order-service/api/create (span: create-order)
  │   └─ calls user-service again (span: validate-user)
  │   └─ calls payment-service (span: process-payment)
  │       └─ calls external payment gateway
  └─ returns order confirmation
```

### Access Jaeger UI

```bash
# Port forward to Jaeger
kubectl port-forward -n monitoring svc/jaeger-query 6831:16686

# Access: http://localhost:6831
```

### Instrumenting Your Application

**Node.js Example:**
```javascript
const jaeger = require('jaeger-client');

const initTracer = jaeger.initTracer({
  serviceName: 'user-service',
  sampler: { type: 'const', param: 1 },
  reporter: {
    agentHost: process.env.JAEGER_AGENT_HOST,
    agentPort: process.env.JAEGER_AGENT_PORT
  }
});

module.exports = initTracer;
```

**Java Example:**
```java
JaegerTracer tracer = new Configuration("payment-service")
    .withSampler(new ConstSampler(true))
    .withReporter(new Reporter() {...})
    .getTracer();
```

## 📊 Microservices Structure

### User Service

**Purpose**: User management and authentication

**Endpoints**:
- `GET /api/user/{id}` - Get user details
- `POST /api/user` - Create user
- `PUT /api/user/{id}` - Update user

**Database**: PostgreSQL (user_db)
**Dependencies**: None

**Example**:
```bash
curl http://user-service.user-service:8080/api/user/123
```

### Payment Service

**Purpose**: Payment processing

**Endpoints**:
- `POST /api/payment/process` - Process payment
- `GET /api/payment/status/{id}` - Check payment status

**Database**: Stripe (external)
**Dependencies**: user-service (verify user)

**Example**:
```bash
curl -X POST http://payment-service.payment-service:8080/api/payment/process \
  -d '{"user_id":"123","amount":99.99}'
```

### Order Service

**Purpose**: Order management

**Endpoints**:
- `POST /api/order` - Create order
- `GET /api/order/{id}` - Get order details
- `PUT /api/order/{id}` - Update order

**Database**: PostgreSQL (order_db)
**Dependencies**: user-service, payment-service

**Example**:
```bash
curl -X POST http://order-service.order-service:8080/api/order \
  -d '{"user_id":"123","items":[...]}' \
  -H "Content-Type: application/json"
```

## 🚀 Deployment Workflow

### 1. Add New Microservice

Create directory structure:
```
kubernetes/microservices/new-service/
├── deployment.yaml
├── service.yaml
└── README.md
```

### 2. Apply Manifests

```bash
# Manual deployment
kubectl apply -f kubernetes/microservices/new-service/

# Or via ArgoCD (GitOps)
git push → ArgoCD auto-deploys
```

### 3. Enable Linkerd Injection

```bash
kubectl label namespace new-service linkerd.io/inject=enabled
kubectl rollout restart deployment/new-service -n new-service
```

### 4. Apply Network Policies

```bash
kubectl apply -f kubernetes/network-policies/network-policies.yaml
```

### 5. Verify Deployment

```bash
# Check pod status
kubectl get pods -n new-service

# View logs
kubectl logs -f deployment/new-service -n new-service

# Check service connectivity
kubectl run debug --image=busybox -it --rm -- sh
# Inside pod: wget http://new-service.new-service:8080/health
```

## 📈 Scaling Services

### Horizontal Pod Autoscaler (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: user-service-hpa
  namespace: user-service
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: user-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Apply HPA

```bash
kubectl apply -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: user-service-hpa
  namespace: user-service
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: user-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
EOF
```

## 🔐 Security Best Practices

### 1. Secrets Management

```bash
# Create secret from literal
kubectl create secret generic user-service-secrets \
  --from-literal=db.password=mypassword \
  -n user-service

# Create secret from file
kubectl create secret generic certs \
  --from-file=tls.crt \
  --from-file=tls.key \
  -n user-service
```

### 2. RBAC (Role-Based Access Control)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: user-service-role
  namespace: user-service
rules:
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: user-service-rolebinding
  namespace: user-service
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: user-service-role
subjects:
- kind: ServiceAccount
  name: user-service
  namespace: user-service
```

### 3. Pod Security Policies

All services include:
- Non-root user execution
- Read-only root filesystem
- No privilege escalation
- Dropped Linux capabilities

## 📊 Monitoring & Observability

### Prometheus Queries

```promql
# Request rate per service
rate(http_requests_total[5m])

# Error rate
rate(http_requests_failed_total[5m]) / rate(http_requests_total[5m])

# Service latency (p95)
histogram_quantile(0.95, http_request_duration_seconds)

# Pod memory usage
container_memory_usage_bytes
```

### Grafana Dashboards

Pre-built dashboards:
- Kubernetes cluster overview
- Pod resource usage
- Service latency and errors
- Linkerd service mesh metrics

### Loki Log Queries

```logql
# All logs from user-service
{namespace="user-service"}

# Error logs
{namespace="user-service"} | "error"

# Logs with specific trace ID
{trace_id="xyz123"}

# Performance logs (>100ms latency)
{namespace="user-service"} | "duration" | duration > 100
```

## 🛠️ Troubleshooting

### Service Communication Issues

```bash
# Check network policies
kubectl get networkpolicies -A

# Verify DNS resolution
kubectl run debug --image=busybox -it --rm -- nslookup user-service.user-service

# Test connectivity
kubectl run debug --image=busybox -it --rm -- wget -O - http://user-service.user-service:8080/health

# Check service endpoints
kubectl get endpoints -n user-service
```

### Linkerd Issues

```bash
# Check Linkerd status
linkerd check

# View Linkerd logs
kubectl logs -n linkerd deployment/linkerd-controller

# Check sidecar injection
kubectl get pods -n user-service -o jsonpath='{.items[0].spec.containers[*].name}'
# Should include 'linkerd-proxy' alongside your app container
```

### Jaeger/Tracing Issues

```bash
# Check Jaeger pods
kubectl get pods -n monitoring -l app=jaeger

# Verify Jaeger agent accessibility
kubectl port-forward -n monitoring svc/jaeger-agent 6831:6831

# Test connectivity from pod
kubectl exec -it deployment/user-service -n user-service -- \
  nc -zv jaeger-agent.monitoring 6831
```

## 📚 Additional Resources

- [Linkerd Documentation](https://linkerd.io/docs/)
- [Jaeger Tracing](https://www.jaegertracing.io/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Prometheus Queries](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboards](https://grafana.com/docs/grafana/latest/dashboards/)
- [Loki Queries](https://grafana.com/docs/loki/latest/query/)

## 🎯 Next Steps

1. Deploy base microservices: `kubectl apply -f kubernetes/microservices/*/`
2. Apply network policies: `kubectl apply -f kubernetes/network-policies/`
3. Access monitoring dashboards
4. Deploy your custom microservices using the templates
5. Monitor via Jaeger for distributed tracing

---

**Last Updated**: May 20, 2026
