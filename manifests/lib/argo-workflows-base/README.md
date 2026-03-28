# Argo Workflows Base Template

Template reutilizável para workflows de CI (Clone → Build → Push).

## O que faz

1. **Clone** — `git clone` via SSH da branch `main`
2. **Resolve SHA** — Extrai `git rev-parse HEAD` como tag
3. **Build** — Kaniko compila Dockerfile
4. **Push** — Faz push para registry com 2 tags: `{git-sha}` e `latest`

## Placeholders (para substituir via patch)

| Placeholder     | Descrição                                                                     |
| --------------- | ----------------------------------------------------------------------------- |
| `GIT_OWNER`     | Organization no GitHub (ex: `growcodelabs`)                                   |
| `GIT_REPO`      | Nome do repositório (ex: `app-finance`)                                       |
| `REGISTRY_BASE` | Base URL da imagem (ex: `registry.digitalocean.com/growcodelabs/app-finance`) |

## Como usar

**Não use diretamente!** Use via Kustomize (veja `manifests/apps/`).

As apps fazem patch dos placeholders via Kustomize:
```yaml
patches:
  - target:
      kind: WorkflowTemplate
      name: ci-build
    patch: |-
      - op: replace
        path: /spec/templates/1/container/args/0
        value: "git clone git@github.com:growcodelabs/app-finance.git /workspace/app"
      ...
```

## Secrets necessários

No namespace `argo`:
- `github-ssh-key` — chave SSH para clonar repositórios
- `do-registry-credentials` — credenciais do Docker Registry (DigitalOcean)

## Volumes e Mounts

- **workspace** — `emptyDir` compartilhado entre steps
- **github-ssh-key** — montado em `/ssh` (read-only)
- **docker-credentials** — config.json do Docker, montado em `/kaniko/.docker`
