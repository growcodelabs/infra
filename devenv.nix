{ pkgs, lib, config, inputs, ... }:

{
  packages = with pkgs; [
    argocd
    doctl
    git
    kustomize
    kubernetes-helm
    opentofu
    postgresql_18
    starship
  ];

  languages.opentofu = {
    enable     = true;
    lsp.enable = true;
  };

  dotenv.enable   = true;
  starship.enable = true;
}
