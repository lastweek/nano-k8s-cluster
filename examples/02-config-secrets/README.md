# ConfigMaps and Secrets Examples

This section covers Kubernetes ConfigMaps and Secrets - mechanisms for managing configuration and sensitive data.

## Prerequisites

- Kubernetes cluster running (minikube, kind, or k3s)
- kubectl configured and working
- Basic understanding of Pods

## Learning Objectives

After completing these examples, you will understand:

1. **ConfigMaps**: Storing and consuming non-sensitive configuration
2. **Secrets**: Storing and consuming sensitive data
3. **Consumption patterns**: Environment variables, volume mounts
4. **Security considerations**: Encryption, RBAC, external secret stores

## Examples

### 01: ConfigMap (Environment Variables)

**File**: [01-configmap.yaml](01-configmap.yaml)

Learn:
- Basic ConfigMap with key-value pairs
- Using ConfigMap as environment variables
- ConfigMap updates require pod restart for env vars
- Separation of configuration from pod spec

**Run**:
```bash
./01-test-configmap.sh
```

**Key concepts**:
- Configuration stored separately from application code
- Environment variables set at pod startup
- ConfigMap updates don't propagate to running pods (for env vars)
- Can be reused across multiple pods

**For LLM serving**:
- Store model configuration (name, path, batch size)
- Store hyperparameters (temperature, top_k, top_p)
- Store feature flags (streaming, caching)

---

### 02: ConfigMap from File (Volume Mount)

**File**: [02-configmap-from-file.yaml](02-configmap-from-file.yaml)

Learn:
- ConfigMap from file data (embedded in YAML)
- Mount ConfigMap as files in container
- Hot reload: File updates propagate without restart
- Applications read config files normally

**Run**:
```bash
./02-test-configmap-from-file.sh
```

**Key concepts**:
- Config files appear as regular files in container
- Updates propagate to files (with some delay)
- Applications can use normal config file parsing
- No code changes needed to read config

**For LLM serving**:
- Store model config files (config.json, tokenizer_config.json)
- Store prompt templates, system prompts
- Store feature flags as TOML/YAML/JSON files
- Update configuration without restarting pods

**Comparison**:
| Feature | Environment Variables | Volume Mount |
|---------|----------------------|--------------|
| Updates | Require restart | Hot reload |
| Use case | Simple values | Config files |
| Application | Use env vars | Read files |

---

### 03: Secret (Basic)

**File**: [03-secret.yaml](03-secret.yaml)

Learn:
- Secret stores sensitive data (base64 encoded)
- Using Secret as environment variables
- Secret vs ConfigMap (encoding, security)
- Security best practices

**Run**:
```bash
./03-test-secret.sh
```

**Key concepts**:
- Secret data is base64 encoded (NOT encrypted by default)
- Use encryption at rest for production
- RBAC controls secret access
- External secret stores for production (Vault, AWS Secrets Manager)

**For LLM serving**:
- Store API keys (OpenAI, Anthropic, HuggingFace)
- Store database credentials
- Store model API tokens
- Store TLS certificates

**Security best practices**:
1. Enable encryption at rest (EncryptionConfiguration)
2. Use RBAC to control secret access
3. Don't commit secrets to git
4. Rotate secrets regularly
5. Use external secret management for production

---

## Running All Examples

Run all ConfigMap and Secret examples sequentially:

```bash
./test-all-config-secrets.sh
```

## Cleanup

Clean up all ConfigMap and Secret examples:

```bash
./cleanup-all-config-secrets.sh
```

Or clean up individual examples:

```bash
kubectl delete -f 01-configmap.yaml
kubectl delete -f 02-configmap-from-file.yaml
kubectl delete -f 03-secret.yaml
```

## ConfigMap vs Secret Comparison

| Feature | ConfigMap | Secret |
|---------|-----------|--------|
| **Use case** | Non-sensitive data | Sensitive data |
| **Encoding** | Plain text | Base64 |
| **Encryption** | No | Optional (at rest) |
| **Etcd storage** | Unencrypted | Can be encrypted |
| **RBAC** | Less restricted | More restricted |
| **Example data** | Config files, env vars | API keys, passwords, tokens |

## Common Commands

### ConfigMap Commands

```bash
# Create ConfigMap from literal values
kubectl create configmap my-config --from-literal=key1=value1 --from-literal=key2=value2

# Create ConfigMap from file
kubectl create configmap my-config --from-file=config.json

# Create ConfigMap from directory
kubectl create configmap my-config --from-file=./config-dir/

# Get ConfigMap
kubectl get configmap my-config

# Describe ConfigMap
kubectl describe configmap my-config

# Get ConfigMap YAML
kubectl get configmap my-config -o yaml

# Decode ConfigMap value
kubectl get configmap my-config -o jsonpath='{.data.key1}'

# Delete ConfigMap
kubectl delete configmap my-config
```

### Secret Commands

```bash
# Create Secret from literal values (base64 encoded automatically)
kubectl create secret generic my-secret --from-literal=password=mypassword

# Create Secret from file
kubectl create secret generic my-secret --from-file=cert.pem

# Create TLS secret
kubectl create secret tls my-tls --cert=path/to/cert.crt --key=path/to/cert.key

# Create docker-registry secret
kubectl create secret docker-registry my-registry --docker-server=registry.example.com --docker-username=user --docker-password=pass

# Get Secret
kubectl get secret my-secret

# Describe Secret (shows encoded values)
kubectl describe secret my-secret

# Decode Secret value
kubectl get secret my-secret -o jsonpath='{.data.password}' | base64 -d

# Delete Secret
kubectl delete secret my-secret
```

## Secret Types

| Type | Description |
|------|-------------|
| `Opaque` | Arbitrary user data (default) |
| `kubernetes.io/service-account-token` | Service account tokens |
| `kubernetes.io/dockercfg` | Docker registry credentials |
| `kubernetes.io/dockerconfigjson` | Docker config.json |
| `kubernetes.io/basic-auth` | Basic authentication |
| `kubernetes.io/ssh-auth` | SSH authentication |
| `kubernetes.io/tls` | TLS certificate data |
| `bootstrap.kubernetes.io/token` | Bootstrap tokens |

## Production Considerations

### Encryption at Rest

Enable encryption in Kubernetes API server:

```yaml
# /etc/kubernetes/manifests/kube-apiserver.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    - --encryption-provider-config=/etc/kubernetes/encryption-config.yaml
```

### External Secret Management

For production, consider:
- **Sealed Secrets**: Encrypt secrets that can be committed to git
- **External Secrets Operator**: Sync secrets from external stores (Vault, AWS Secrets Manager, Azure Key Vault)
- **HashiCorp Vault**: Centralized secret management
- **Cloud provider secret stores**: AWS Secrets Manager, Azure Key Vault, GCP Secret Manager

## Architecture: Configuration in LLM Serving

```
┌─────────────────────────────────────────────────────────┐
│                     Application Pod                      │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Container                                        │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Application                                │  │  │
│  │  │  - Reads env vars                           │  │  │
│  │  │  - Reads config files                       │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                      │                            │  │
│  │                      ▼                            │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Environment Variables                       │  │  │
│  │  │  - MODEL_NAME (from ConfigMap)              │  │  │
│  │  │  - OPENAI_API_KEY (from Secret)             │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                      │                            │  │
│  │                      ▼                            │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Volume Mounts                               │  │  │
│  │  │  /etc/config/config.json (from ConfigMap)   │  │  │
│  │  │  /etc/secrets/api-key.txt (from Secret)     │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
         │                                    │
         ▼                                    ▼
┌─────────────────┐                  ┌─────────────────┐
│    ConfigMap    │                  │     Secret      │
│  - model.name   │                  │  - api.key      │
│  - batch.size   │                  │  - db.password  │
│  - config.json  │                  │  - tls.cert     │
└─────────────────┘                  └─────────────────┘
```

## Next Steps

After mastering ConfigMaps and Secrets:
1. **Storage** - Persistent volumes for model checkpoints
2. **StatefulSets** - For stateful applications
3. **Ingress** - HTTP/HTTPS routing
4. **Advanced Security** - Network policies, Pod Security Standards

## References

- [Kubernetes ConfigMap Documentation](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Kubernetes Secret Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Encrypting Secret Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
- [Managing Secrets with kubectl](https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/)
