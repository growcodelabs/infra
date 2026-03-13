# ArgoCD

- [ArgoCD](#argocd)
  - [Pré-requisitos](#pré-requisitos)
    - [Configurar autenticação](#configurar-autenticação)
      - [1. Criar o Google OAuth App](#1-criar-o-google-oauth-app)
      - [2. Criar o secret do Dex no cluster](#2-criar-o-secret-do-dex-no-cluster)
    - [Bootstrap do cluster](#bootstrap-do-cluster)
      - [1. Instalar o ArgoCD](#1-instalar-o-argocd)
      - [2. Configurar credencial do repositório privado](#2-configurar-credencial-do-repositório-privado)
      - [3. Aplicar o bootstrap](#3-aplicar-o-bootstrap)
      - [4. Atualizar o DNS](#4-atualizar-o-dns)


## Pré-requisitos

Os passos a seguir são necessários antes que o ArgoCD seja instalado, para garantir que as aplicações serão corretamente configuradas por ele.

### Configurar autenticação

O Dex — já embutido no ArgoCD — é o hub central de autenticação. Todos os tools (ArgoCD, Argo Workflows, etc.) autenticam via Dex, que por sua vez delega ao Google. Portanto, um único OAuth App no Google é suficiente para tudo.

#### 1. Criar o Google OAuth App

Acesse: [Google Cloud Console → APIs & Services → Credentials → Create Credentials → OAuth client ID](https://console.cloud.google.com/apis/credentials)

| Campo                   | Valor                                              |
| ----------------------- | -------------------------------------------------- |
| Application type        | `Web application`                                  |
| Name                    | `Growcodelabs Infra SSO`                           |
| Authorized redirect URI | `https://argocd.growcodelabs.com/api/dex/callback` |

> O acesso é restrito a contas `@growcodelabs.com`. Qualquer conta Google fora deste domínio será rejeitada pelo Dex.

Após criar, anote o **Client ID** e o **Client Secret**.

#### 2. Criar os secrets no cluster

Gere um valor aleatório para o client secret do Argo Workflows no Dex:

```bash
openssl rand -base64 32
```

Crie os três secrets necessários:

```bash
# Credenciais do Google OAuth para o Dex (namespace argocd)
kubectl create namespace argocd

kubectl create secret generic argocd-dex-google \
  --namespace argocd \
  --from-literal=client-id=<GOOGLE_CLIENT_ID> \
  --from-literal=client-secret=<GOOGLE_CLIENT_SECRET>

# Client secret compartilhado entre Dex e Argo Workflows (namespace argocd)
kubectl create secret generic argo-workflows-dex-client \
  --namespace argocd \
  --from-literal=client-secret=<RANDOM_SECRET>

# Client ID e secret para o Argo Workflows se autenticar no Dex (namespace argo)
kubectl create namespace argo

kubectl create secret generic argo-workflows-sso \
  --namespace argo \
  --from-literal=client-id=argo-workflows \
  --from-literal=client-secret=<MESMO_RANDOM_SECRET>
```

> `<RANDOM_SECRET>` deve ser o mesmo valor nos dois últimos secrets — é o segredo compartilhado entre o Dex e o Argo Workflows.

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

