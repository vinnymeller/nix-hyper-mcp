{
  description = "Test home flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-24.11?shallow=1";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyper-mcp.url = "path:../..";
  };

  outputs = { self, nixpkgs, home-manager, hyper-mcp, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      homeConfigurations = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          "test-${system}" = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              hyper-mcp.homeModules.default
              {
                home = {
                  username = "tester";
                  homeDirectory =
                    if builtins.match ".*-linux" system != null
                    then "/home/tester"
                    else "/Users/tester";
                  stateVersion = "24.11";
                };

                programs.hyper-mcp = {
                  enable = true;
                  plugins = [{
                    name = "fs";
                    path = "oci://ghcr.io/tuananh/fs-plugin:latest";
                    runtime_config.allowed_paths = [ "/tmp" ];
                  }];
                };

                programs.home-manager.enable = true;
              }
            ];
            extraSpecialArgs = {
              inherit system;
            };
          };
        }
      );
    in
    {
      homeConfigurations =
        nixpkgs.lib.foldl' nixpkgs.lib.recursiveUpdate { } (builtins.attrValues homeConfigurations);
    };
}
