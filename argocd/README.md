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

#### 2. Configurar credencial do repositório privado

Gerar o par de chaves SSH (sem passphrase):

```bash
ssh-keygen -t ed25519 -C "argocd@growcodelabs" -f argocd_deploy_key -N ""
```

Adicionar a chave pública como **Deploy Key** no repositório GitHub:
- Acesse: `GitHub → infra-monorepo → Settings → Deploy keys → Add deploy key`
- Título: `argocd`
- Chave: conteúdo de `argocd_deploy_key.pub`
- Marcar como **read-only**

Criar o Secret no cluster com a chave privada:

```bash
kubectl create secret generic argocd-infra-repo \
  --namespace argocd \
  --from-literal=type=git \
  --from-literal=url=git@github.com:growcodelabs/infra.git \
  --from-file=sshPrivateKey=argocd_deploy_key

kubectl label secret argocd-infra-repo \
  --namespace argocd \
  argocd.argoproj.io/secret-type=repository
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

