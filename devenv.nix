{ pkgs, lib, config, inputs, ... }:

{
  packages = with pkgs; [ git awscli2 aws-vault opentofu ];

  languages.opentofu = {
    enable     = true;
    lsp.enable = true;
  };
}
