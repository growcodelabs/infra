{ pkgs, lib, config, inputs, ... }:

{
  packages = with pkgs; [ git opentofu postgresql_18 doctl ];

  languages.opentofu = {
    enable     = true;
    lsp.enable = true;
  };

  dotenv.enable = true;
}
