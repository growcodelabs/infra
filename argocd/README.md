# ArgoCD

## Pré-requisitos

Os passos a seguir são necessários antes que o ArgoCD seja instalado, para garantir que as aplicações serão corretamente configuradas por ele.

### Credentials do Argo Workflows (basic auth)

O acesso ao Argo Workflows é protegido por basic auth no Traefik. Crie o secret antes do bootstrap:

```bash
kubectl create namespace argo

kubectl create secret generic argo-workflows-basic-auth-users \
  --namespace argo \
  --type=kubernetes.io/basic-auth \
  --from-literal=username=<USUARIO> \
  --from-literal=password=<SENHA>
```

> As credenciais ficam em texto plano no secret do Kubernetes. Para maior segurança, habilite [encryption at rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/) no cluster.

### DigitalOcean Container Registry

Para que o Argo Workflows faça push de imagens, crie o secret com autenticação automática:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: registry-credentials
  namespace: argo
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $(doctl registry docker-config | base64 -w0)
EOF
```

### Bootstrap do cluster

#### 1. Instalar o ArgoCD

```bash
helm install argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --version 9.4.10 \
  --namespace argocd \
  --create-namespace \
  --values argocd/infra/apps/argocd/values.yaml
```

#### 2. Configurar credencial dos repositórios da organização

O ArgoCD usa um **Credential Template** com autenticação via **GitHub App** para acessar todos os repositórios da organização. Qualquer repo com URL prefixada por `https://github.com/growcodelabs` utilizará automaticamente esta credencial.

Criar o Secret no cluster com as credenciais da GitHub App:

```bash
kubectl create namespace argocd

kubectl create secret generic github-app-credentials \
  --namespace argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/growcodelabs \
  --from-literal=githubAppID=<APP_ID> \
  --from-literal=githubAppInstallationID=<INSTALLATION_ID> \
  --from-file=githubAppPrivateRSAKey=<path-to-private-key.pem>

kubectl label secret github-app-credentials \
  --namespace argocd \
  argocd.argoproj.io/secret-type=repo-creds
```

> O secret no namespace `argo` (usado pelo Argo Workflows para gerar tokens de CI) é copiado automaticamente pelo Job `copy-github-app-credentials` após o primeiro sync.

#### 3. Aplicar o bootstrap

```bash
kubectl apply -f argocd/bootstrap.yaml
```

O ArgoCD irá sincronizar automaticamente todos os componentes:
- Traefik (Ingress controller + Middleware de redirect HTTPS)
- cert-manager (operador + ClusterIssuer Let's Encrypt)
- Aplicações

#### 4. Atualizar o DNS

Obter o IP externo do LoadBalancer:

```bash
kubectl get svc -n traefik
```

Criar/atualizar os registros DNS apontando para o `EXTERNAL-IP` do Traefik. Os certificados TLS serão emitidos automaticamente pelo cert-manager (~2-5 minutos após o DNS propagar).

