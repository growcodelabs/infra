// Library for generating Argo Workflows manifests for a CI app.
//
// Usage:
//   local app = import '../../lib/app.libsonnet';
//   app.new({ appName: 'my-app' })
//
// Required params:
//   appName        - name of the app and GitHub repo (e.g., 'app-finance')
//
// Optional params (defaults shown):
//   repoOwner      - GitHub org/user             (default: 'growcodelabs')
//   branch         - branch to clone             (default: 'main')
//   registryBase   - container registry base URL (default: 'registry.digitalocean.com/growcodelabs')
//
// Workflow parameter:
//   revision  - when triggered manually: branch name resolved to SHA by the clone step
//               when triggered via GitHub webhook: SHA passed directly (body.after)

{
  new(params):: (
    local p = {
      repoOwner: 'growcodelabs',
      branch: 'main',
      registryBase: 'registry.digitalocean.com/growcodelabs',
    } + params;

    local appName = p.appName;
    local image = p.registryBase + '/' + appName;

    [
      // ── WorkflowTemplate ──────────────────────────────────────────────────
      {
        apiVersion: 'argoproj.io/v1alpha1',
        kind: 'WorkflowTemplate',
        metadata: {
          name: appName + '-build',
          namespace: 'argo',
        },
        spec: {
          entrypoint: 'pipeline',
          // Default revision is the branch name; the clone step resolves it to a SHA.
          // When triggered via GitHub webhook, the SHA arrives directly as a parameter.
          arguments: {
            parameters: [{ name: 'revision', value: p.branch }],
          },
          templates: [

            // ── Entry point: sequential steps ─────────────────────────────
            {
              name: 'pipeline',
              steps: [
                [{ name: 'clone', template: 'git-clone' }],
                [{
                  name: 'build',
                  template: 'kaniko-build',
                  arguments: {
                    parameters: [{
                      name: 'revision',
                      value: '{{steps.clone.outputs.parameters.revision}}',
                    }],
                  },
                }],
              ],
            },

            // ── Step 1: clone and resolve SHA ──────────────────────────────
            {
              name: 'git-clone',
              outputs: {
                parameters: [{
                  name: 'revision',
                  valueFrom: { path: '/tmp/revision' },
                }],
              },
              volumes: [
                { name: 'workspace', emptyDir: {} },
                {
                  name: 'github-ssh-key',
                  secret: {
                    secretName: 'github-ssh-key',
                    items: [{ key: 'id_ed25519', path: 'id_ed25519' }],
                  },
                },
              ],
              container: {
                image: 'alpine/git:latest',
                command: ['sh', '-c'],
                args: [|||
                  set -euo pipefail
                  SSH_DIR="$HOME/.ssh"
                  mkdir -p "$SSH_DIR"
                  chmod 700 "$SSH_DIR"
                  cp /ssh/id_ed25519 "$SSH_DIR/id_ed25519"
                  chmod 600 "$SSH_DIR/id_ed25519"
                  ssh-keyscan -H github.com >> "$SSH_DIR/known_hosts"
                  ssh-keyscan -p 443 -H ssh.github.com >> "$SSH_DIR/known_hosts"
                  git clone git@github.com:%(owner)s/%(app)s.git /workspace/app
                  cd /workspace/app
                  git checkout {{workflow.parameters.revision}}
                  git rev-parse HEAD > /tmp/revision
                ||| % { owner: p.repoOwner, app: appName }],
                volumeMounts: [
                  { name: 'workspace', mountPath: '/workspace' },
                  { name: 'github-ssh-key', mountPath: '/ssh', readOnly: true },
                ],
              },
            },

            // ── Step 2: build and push image ───────────────────────────────
            {
              name: 'kaniko-build',
              inputs: {
                parameters: [{ name: 'revision' }],
              },
              volumes: [
                { name: 'workspace', emptyDir: {} },
                {
                  name: 'docker-credentials',
                  projected: {
                    sources: [{
                      secret: {
                        name: 'do-registry-credentials',
                        items: [{ key: '.dockerconfigjson', path: 'config.json' }],
                      },
                    }],
                  },
                },
                {
                  name: 'github-ssh-key',
                  secret: {
                    secretName: 'github-ssh-key',
                    items: [{ key: 'id_ed25519', path: 'id_ed25519' }],
                  },
                },
              ],
              initContainers: [{
                name: 'git-clone',
                image: 'alpine/git:latest',
                command: ['sh', '-c'],
                args: [|||
                  set -euo pipefail
                  SSH_DIR="$HOME/.ssh"
                  mkdir -p "$SSH_DIR"
                  chmod 700 "$SSH_DIR"
                  cp /ssh/id_ed25519 "$SSH_DIR/id_ed25519"
                  chmod 600 "$SSH_DIR/id_ed25519"
                  ssh-keyscan -H github.com >> "$SSH_DIR/known_hosts"
                  ssh-keyscan -p 443 -H ssh.github.com >> "$SSH_DIR/known_hosts"
                  git clone git@github.com:%(owner)s/%(app)s.git /workspace/app
                  cd /workspace/app
                  git checkout {{inputs.parameters.revision}}
                ||| % { owner: p.repoOwner, app: appName }],
                volumeMounts: [
                  { name: 'workspace', mountPath: '/workspace' },
                  { name: 'github-ssh-key', mountPath: '/ssh', readOnly: true },
                ],
              }],
              container: {
                image: 'gcr.io/kaniko-project/executor:latest',
                args: [
                  '--context=/workspace/app',
                  '--dockerfile=/workspace/app/Dockerfile',
                  '--destination=' + image + ':{{inputs.parameters.revision}}',
                  '--destination=' + image + ':latest',
                  '--cache=true',
                  '--cache-repo=' + image + '/cache',
                ],
                volumeMounts: [
                  { name: 'workspace', mountPath: '/workspace' },
                  { name: 'docker-credentials', mountPath: '/kaniko/.docker' },
                ],
              },
            },

          ],
        },
      },
    ]
  ),
}
