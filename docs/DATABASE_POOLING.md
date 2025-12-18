# Database Connection Pooling Configuration Guide

This guide explains how to configure and optimize the ClientATS database connection pool for your deployment environment.

## Overview

ClientATS uses Ecto connection pooling to manage concurrent database connections efficiently. The pool settings are fully configurable via environment variables, allowing you to optimize for different deployment scenarios without code changes.

## Key Concepts

### Connection Pool
A pool of pre-established database connections that your application can use. Instead of creating a new connection for each request, connections are reused from the pool.

### Pool Size
The number of idle connections maintained in the pool. More connections allow more concurrent operations but consume more database resources.

### Pool Count
The number of independent connection pools. Multiple pools distribute load across separate connection groups.

### Max Overflow
Additional connections that can be created temporarily when the main pool is exhausted. These are released when no longer needed.

### Timeout
Maximum time (in milliseconds) to wait for an available connection from the pool.

## Environment Variables

Configure the connection pool using these environment variables:

### POOL_SIZE (default: 10)
The number of connections per pool.

```bash
export POOL_SIZE=20
```

### POOL_COUNT (default: 1)
The number of independent pools. Useful for distributing connections.

```bash
export POOL_COUNT=2  # Creates 2 independent pools of POOL_SIZE each
```

### MAX_OVERFLOW (default: 0)
Number of additional connections allowed when the pool is exhausted.

```bash
export MAX_OVERFLOW=5  # Allow 5 extra connections temporarily
```

### POOL_TIMEOUT (default: 5000)
Maximum wait time in milliseconds for an available connection.

```bash
export POOL_TIMEOUT=10000  # 10 second timeout
```

### DATABASE_SSL (default: false)
Enable SSL/TLS encryption for database connections.

```bash
export DATABASE_SSL=true
```

## Recommended Settings by Deployment Size

### Small Deployment (1-5 concurrent users)

For development or small staging environments:

```bash
export POOL_SIZE=5
export POOL_COUNT=1
export MAX_OVERFLOW=0
export POOL_TIMEOUT=5000
```

**Rationale:**
- Small POOL_SIZE sufficient for light traffic
- Single pool adequate
- No overflow needed (failures are acceptable in dev)

### Medium Deployment (5-100 concurrent users)

For typical production deployments:

```bash
export POOL_SIZE=10
export POOL_COUNT=1
export MAX_OVERFLOW=2
export POOL_TIMEOUT=5000
```

**Rationale:**
- POOL_SIZE=10 handles typical transaction volume
- Small MAX_OVERFLOW absorbs traffic spikes
- Single pool sufficient for most applications

### Large Deployment (100+ concurrent users)

For high-traffic production systems:

```bash
export POOL_SIZE=20
export POOL_COUNT=2
export MAX_OVERFLOW=10
export POOL_TIMEOUT=10000
```

**Rationale:**
- Larger POOL_SIZE for sustained traffic
- Multiple pools distribute connections
- Generous MAX_OVERFLOW handles peak loads
- Extended timeout accommodates temporary slowdowns

### Kubernetes Deployment

For containerized deployments with autoscaling:

```bash
export POOL_SIZE=10
export POOL_COUNT=2
export MAX_OVERFLOW=3
export POOL_TIMEOUT=8000
export DATABASE_SSL=true
```

**Rationale:**
- POOL_SIZE=10 per pod reasonable
- Multiple pools for redundancy
- SSL enabled for security across network
- Moderate overflow for pod churn scenarios

## Configuration Examples

### Docker Compose (Development)

```yaml
services:
  app:
    environment:
      - DATABASE_URL=ecto://postgres:postgres@db:5432/clientats_dev
      - POOL_SIZE=5
      - MAX_OVERFLOW=2
      - POOL_TIMEOUT=5000
```

### Docker Compose (Staging/Production)

```yaml
services:
  app:
    environment:
      - DATABASE_URL=ecto://postgres:secure_password@db:5432/clientats_prod
      - POOL_SIZE=15
      - POOL_COUNT=2
      - MAX_OVERFLOW=5
      - POOL_TIMEOUT=8000
      - DATABASE_SSL=true
```

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: clientats
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: app
        image: clientats:latest
        env:
        - name: POOL_SIZE
          value: "10"
        - name: POOL_COUNT
          value: "2"
        - name: MAX_OVERFLOW
          value: "3"
        - name: POOL_TIMEOUT
          value: "8000"
        - name: DATABASE_SSL
          value: "true"
```

### Heroku Deployment

Set config variables:

```bash
heroku config:set \
  POOL_SIZE=12 \
  POOL_COUNT=1 \
  MAX_OVERFLOW=4 \
  POOL_TIMEOUT=8000 \
  DATABASE_SSL=true \
  -a clientats-prod
```

## Performance Tuning

### Diagnosing Connection Pool Issues

Use the health endpoints to diagnose pool issues:

```bash
# Simple health check
curl http://localhost:4000/health

# Database readiness
curl http://localhost:4000/health/ready

# Detailed diagnostics (requires token)
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:4000/health/diagnostics
```

The diagnostics endpoint returns:

```json
{
  "status": "healthy",
  "database": {
    "status": "healthy",
    "latency_ms": 2
  },
  "pool": {
    "pool_size": 10,
    "pool_count": 1,
    "max_overflow": 2,
    "timeout_ms": 5000,
    "database_version": "PostgreSQL 15.2"
  },
  "activity": {
    "total_connections": 8,
    "active_connections": 3,
    "idle_connections": 5,
    "longest_transaction_minutes": 0.5
  },
  "performance_insights": [
    "Connection pool at 75% capacity - consider increasing POOL_SIZE"
  ]
}
```

### Signs You Need to Adjust Settings

**Pool Exhaustion (frequent errors about no available connections):**
- Increase POOL_SIZE
- Increase MAX_OVERFLOW
- Add POOL_COUNT for multiple pools

**High Connection Latency:**
- Check database performance (run slow query logs)
- Increase POOL_TIMEOUT if database is occasionally slow
- Check POOL_TIMEOUT isn't too high (creates bottleneck)

**Database Connection Limit Exceeded:**
- Reduce POOL_SIZE × POOL_COUNT (too many connections total)
- Add connection pooling at database level (pgBouncer)
- Implement application-level connection pooling

**Idle Connections Timing Out:**
- Reduce POOL_SIZE
- Increase connection timeout at database level

## Kubernetes-Specific Considerations

### Scaling and Connection Limits

Each pod gets its own connection pool:

```
3 pods × (POOL_SIZE=10 + MAX_OVERFLOW=3) = 39 connections
```

PostgreSQL connection limit is typically 100-200, so plan accordingly:

```bash
# For 10 pods with reasonable settings
export POOL_SIZE=8
export POOL_COUNT=1
export MAX_OVERFLOW=2
# Total: 10 pods × (8 + 2) = 100 connections
```

### Readiness Probes

Configure Kubernetes readiness probes to use the health endpoint:

```yaml
readinessProbe:
  httpGet:
    path: /health/ready
    port: 4000
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

The `/health/ready` endpoint returns:
- 200 OK if database is accessible (ready)
- 503 Service Unavailable if database is down (not ready)

This ensures pods are only routed traffic when database is accessible.

### Liveness Probes

Configure Kubernetes liveness probes for basic application health:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 4000
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

The `/health` endpoint returns 200 if the application is running.

## Monitoring and Observability

### Application Logs

Check logs for connection pool issues:

```bash
# Docker Compose
docker-compose logs app | grep -i "pool\|connection"

# Kubernetes
kubectl logs -l app=clientats | grep -i "pool\|connection"
```

### Metrics Endpoint

Access Prometheus-format metrics:

```bash
curl http://localhost:4000/metrics | grep -i "database\|pool\|connection"
```

Key metrics to monitor:
- `db_connections_active` - Active database connections
- `db_connections_idle` - Idle connections
- `db_connection_wait_time_ms` - Time waiting for available connection
- `db_query_duration_ms` - Query execution time

### Database-Level Monitoring

Check PostgreSQL connection usage:

```sql
-- Connect to PostgreSQL
psql -U postgres -d clientats_prod

-- View current connections
SELECT usename, count(*) FROM pg_stat_activity GROUP BY usename;

-- View connection limits
SELECT datname, client_addr, count(*) FROM pg_stat_activity
GROUP BY datname, client_addr;
```

## Troubleshooting

### "Connection refused" errors

**Symptom:** Application cannot connect to database

**Solutions:**
1. Verify DATABASE_URL is correct
2. Check database is running: `ping <db_host>`
3. Verify database credentials
4. Check database firewall rules
5. Enable DATABASE_SSL if using SSL

### "Pool timeout" errors

**Symptom:** Request fails waiting for available connection

**Solutions:**
1. Check POOL_TIMEOUT value (may be too short)
2. Increase POOL_SIZE
3. Increase MAX_OVERFLOW
4. Check for connection leaks in application code
5. Verify database isn't experiencing issues

### High memory usage

**Symptom:** Application memory grows with pool configuration

**Solutions:**
1. Reduce POOL_SIZE
2. Reduce POOL_COUNT
3. Reduce MAX_OVERFLOW
4. Monitor actual connection usage via diagnostics endpoint

### Database connection limit exceeded

**Symptom:** "Sorry, too many clients already" from PostgreSQL

**Solutions:**
1. Reduce total connections: POOL_SIZE × POOL_COUNT
2. Implement connection pooling at database level (pgBouncer)
3. Increase PostgreSQL max_connections setting
4. Reduce replica count (fewer pods = fewer connections)

## Best Practices

1. **Start Conservative:** Begin with recommended values for your deployment size
2. **Monitor Early:** Enable monitoring from day one
3. **Tune Gradually:** Make small adjustments based on metrics
4. **Test Under Load:** Simulate expected traffic before production
5. **Document Changes:** Record why you changed each setting
6. **Scale Horizontally:** Add pods rather than just increasing pool size
7. **Use Diagnostics:** Regularly check `/health/diagnostics` endpoint
8. **Database Pooling:** Consider pgBouncer for very high concurrency
9. **SSL in Production:** Always enable DATABASE_SSL in production
10. **Regular Reviews:** Check pool metrics weekly in production

## Related Documentation

- [Ecto Connection Pooling](https://hexdocs.pm/ecto/Ecto.Adapters.Postgres.html#module-pool-configuration)
- [PostgreSQL Connection Limits](https://www.postgresql.org/docs/current/runtime-config-connection.html)
- [Kubernetes Health Checks](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [CI/CD Setup Guide](./CI_CD_SETUP.md)

## Support

For issues or questions:
1. Check application logs for connection-related errors
2. Review diagnostics endpoint output
3. Consult troubleshooting section above
4. Contact DevOps team with diagnostics data
