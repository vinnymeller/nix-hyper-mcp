{
  description = "Test nixos flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-24.11?shallow=1";
    hyper-mcp.url = "path:../..";
  };

  outputs = { self, nixpkgs, hyper-mcp, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      nixosConfigurations = nixpkgs.lib.genAttrs systems (system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            hyper-mcp.nixosModules.default
            {
              boot.loader.grub.enable = false;
              fileSystems."/" = {
                device = "/dev/disk/by-label/nixos";
                fsType = "ext4";
              };

              programs.hyper-mcp = {
                enable = true;
                plugins = [{
                  name = "fs";
                  path = "oci://ghcr.io/tuananh/fs-plugin:latest";
                  runtime_config.allowed_paths = [ "/tmp" ];
                }];
              };

              system.stateVersion = "24.11";
            }
          ];
        }
      );
    in
    {
      nixosConfigurations = nixosConfigurations // {
        "test-x86_64-linux" = nixosConfigurations."x86_64-linux";
        "test-aarch64-linux" = nixosConfigurations."aarch64-linux";
      };
    };
}
