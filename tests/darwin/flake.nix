{
  description = "Test darwin flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-24.11?shallow=1";
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyper-mcp.url = "path:../..";
  };

  outputs = { self, nixpkgs, nix-darwin, hyper-mcp, ... }:
    let
      systems = [
        "aarch64-darwin"
      ];

      darwinConfigurations = nixpkgs.lib.genAttrs systems (system:
        nix-darwin.lib.darwinSystem {
          inherit system;
          modules = [
            hyper-mcp.darwinModules.default
            {
              services.nix-daemon.enable = true;

              programs.hyper-mcp = {
                enable = true;
                plugins = [{
                  name = "fs";
                  path = "oci://ghcr.io/tuananh/fs-plugin:latest";
                  runtime_config.allowed_paths = [ "/tmp" ];
                }];
              };

              system.stateVersion = 5;
            }
          ];
        }
      );
    in
    {
      darwinConfigurations = darwinConfigurations // {
        "test-aarch64-darwin" = darwinConfigurations."aarch64-darwin";
      };
    };
}
