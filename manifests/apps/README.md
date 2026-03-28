# Argo Workflows CI com Kustomize

Cada aplicação define seu próprio workflow de CI (Clone → Build → Push) usando **Kustomize** para parametrizar uma base comum.

## Estrutura

```
manifests/
├── lib/
│   └── argo-workflows-base/      ← Template base reutilizável
│       ├── kustomization.yaml
│       └── workflowtemplate.yaml
└── apps/
    ├── app-finance/              ← App específica
    │   └── kustomization.yaml    ← Patches a base com valores da app
    └── app-outro/
        └── kustomization.yaml
```

## Como funciona

**Base** (`manifests/lib/argo-workflows-base/`):
- WorkflowTemplate genérico com placeholders
- Clone via SSH, build com Kaniko, push para registry
- Reutilizável para qualquer app

**App** (`manifests/apps/app-finance/`):
- Kustomize que referencia a base
- Patches (JSON Merge Patch) substituem valores específicos:
  - Nome do workflow
  - URL do repositório Git
  - URL da imagem no registry

## Adicionar nova app

**1. Criar diretório:**
```bash
mkdir -p manifests/apps/sua-app/
```

**2. Criar `kustomization.yaml`:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: argo

bases:
  - ../../lib/argo-workflows-base

namePrefix: sua-app-

patches:
  - target:
      kind: WorkflowTemplate
      name: ci-build
    patch: |-
      - op: replace
        path: /metadata/name
        value: sua-app-build
      - op: replace
        path: /spec/templates/1/container/args/0
        value: "git clone git@github.com:growcodelabs/sua-app.git /workspace/app"
      - op: replace
        path: /spec/templates/1/initContainers/0/args/0
        value: "git clone git@github.com:growcodelabs/sua-app.git /workspace/app"
      - op: replace
        path: /spec/templates/2/container/args/2
        value: "--destination=registry.digitalocean.com/growcodelabs/sua-app:{{inputs.parameters.revision}}"
      - op: replace
        path: /spec/templates/2/container/args/3
        value: "--destination=registry.digitalocean.com/growcodelabs/sua-app:latest"
      - op: replace
        path: /spec/templates/2/container/args/5
        value: "--cache-repo=registry.digitalocean.com/growcodelabs/sua-app/cache"
```

## Ver manifesto compilado

```bash
kustomize build manifests/apps/app-finance/
```

## Via ArgoCD

O Application `argo-workflows` sincroniza automaticamente:
- `manifests/infra/argo-workflows/` (chart Helm)
- `manifests/apps/` (Kustomize)

Próxima sincronização:
1. ArgoCD compila Kustomize
2. Aplica WorkflowTemplates no namespace `argo`
3. Workflows aparecem no Argo

## Disparar manualmente

```bash
argo submit -n argo --from workflowtemplate/app-finance-build -p revision=main
```

Ou via UI do Argo.

## Requisitos

- ✅ Secret `do-registry-credentials` em namespace `argo`
- ✅ Secret `github-ssh-key` em namespace `argo`
- ✅ Dockerfile na raiz do repositório da app
