# Pin nixpkgs to ensure all developers use the same version of devenv.
#
# To update: change the rev below and run:
#   nix-prefetch-url --unpack https://github.com/NixOS/nixpkgs/archive/<NEW_REV>.tar.gz
# Then replace the sha256 with the output.
{
  pkgs ? import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/b8bb7269e2be0f5b95c2b119672ad367aa2508ab.tar.gz";
    sha256 = "1arg3m3clhk7mdc9785ipcmbbhsxgxfxmv20dissrksk4ashxw5w";
  }) {}
}:

pkgs.mkShell {
  buildInputs = with pkgs; [
    devenv
  ];

  shellHook = ''
    echo "devenv environment loaded"
  '';
}
