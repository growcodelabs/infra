{ pkgs, lib, config, inputs, ... }:

{
  packages = with pkgs; [ git opentofu postgresql_18 doctl argocd starship kubernetes-helm ];

  languages.opentofu = {
    enable     = true;
    lsp.enable = true;
  };

  dotenv.enable   = true;
  starship.enable = true;
}
