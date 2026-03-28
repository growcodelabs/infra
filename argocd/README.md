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

O ArgoCD usa um **Credential Template** para aplicar a mesma chave SSH a todos os repositórios da organização. Qualquer repo com URL prefixada por `git@github.com:growcodelabs` utilizará automaticamente esta credencial.

Gerar o par de chaves SSH (sem passphrase):

```bash
ssh-keygen -t ed25519 -C "argocd@growcodelabs" -f argocd_deploy_key -N ""
```

Adicionar a chave pública como **Deploy Key** nos repositórios GitHub desejados:
- Acesse: `GitHub → <repo> → Settings → Deploy keys → Add deploy key`
- Título: `argocd`
- Chave: conteúdo de `argocd_deploy_key.pub`
- Marcar como **read-only**

Garanta que este repositório tenha esta chave configurada.

Criar o Secret no cluster com a chave privada:

```bash
kubectl create namespace argocd

kubectl create secret generic deploy-ssh-key \
  --namespace argocd \
  --from-literal=type=git \
  --from-literal=url=git@github.com:growcodelabs \
  --from-file=sshPrivateKey=argocd_deploy_key

kubectl label secret deploy-ssh-key \
  --namespace argocd \
  argocd.argoproj.io/secret-type=repo-creds
```

Remover os arquivos de chave da máquina local após aplicar:

```bash
rm argocd_deploy_key argocd_deploy_key.pub
```

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

