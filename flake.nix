{
  description = "A package & home-manager module for hyper-mcp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-24.11?shallow=1";
    crane.url = "github:ipetkov/crane";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyper-mcp-src = {
      flake = false;
      url = "github:tuananh/hyper-mcp/v0.1.2";
    };
  };

  outputs = { self, nixpkgs, crane, rust-overlay, hyper-mcp-src, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSysAttrs = system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ (import rust-overlay) ];
          };

          cargoToml = builtins.fromTOML (builtins.readFile "${hyper-mcp-src}/Cargo.toml");
          version = cargoToml.package.version;

          rustVersion = pkgs.rust-bin.fromRustupToolchainFile "${hyper-mcp-src}/rust-toolchain.toml";
          craneLib = (crane.mkLib pkgs).overrideToolchain rustVersion;

          args = {
            src = hyper-mcp-src;
            strictDeps = true;
            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = [ pkgs.openssl ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              pkgs.libiconv
            ];
          };

          cargoArtifacts = craneLib.buildDepsOnly args;

          hyper-mcp = craneLib.buildPackage (args // {
            inherit cargoArtifacts version;
            pname = "hyper-mcp";
            meta = {
              description = "A fast, secure MCP server that extends its capabilities through WebAssembly plugins";
              homepage = "https://github.com/tuananh/hyper-mcp";
              license = pkgs.lib.licenses.asl20;
              platforms = pkgs.lib.platforms.unix;
            };
          });
        in
        {
          packages = {
            inherit hyper-mcp;
            default = hyper-mcp;
          };

          devShells.default = pkgs.mkShell {
            buildInputs = [
              rustVersion
              pkgs.cargo-watch
              pkgs.rust-analyzer
            ];
          };
        };

      sysAttrs = nixpkgs.lib.genAttrs systems perSysAttrs;

      mkModule = { packagesPath ? [ "environment" "systemPackages" ] }: { config, lib, pkgs, ... }:
        let
          cfg = config.programs.hyper-mcp;

          sharedOptions = {
            enable = lib.mkEnableOption "hyper-mcp";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.default;
              defaultText = lib.literalExpression "self.packages.''${pkgs.system}.default";
              description = "The hyper-mcp package providing the hyper-mcp binary.";
            };
            transport = lib.mkOption {
              type = lib.types.enum [ "sse" "stdio" "streamable-http" ];
              default = "stdio";
              description = "The transport protocol to use.";
            };
            bindAddress = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "The address to bind to (for sse and streamable-http transports).";
            };
            insecureSkipSignature = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Skip OCI image signature verification.";
            };
            useSigstoreTufData = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Use Sigstore TUF data for verification.";
            };
            rekorPubKeys = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Path to Rekor public keys for verification.";
            };
            fulcioCerts = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Path to Fulcio certificates for verification.";
            };
            certIssuer = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Certificate issuer to verify against.";
            };
            certEmail = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Certificate email to verify against.";
            };
            certUrl = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Certificate URL to verify against.";
            };
            configFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Path to the configuration file, overriding the 'plugins' option.";
            };
            plugins = lib.mkOption {
              type = lib.types.listOf (lib.types.submodule {
                options = {
                  name = lib.mkOption { type = lib.types.str; description = "Name of the plugin."; };
                  path = lib.mkOption { type = lib.types.str; description = "Path to the plugin (OCI image reference or local path)."; };
                  runtime_config = lib.mkOption {
                    type = lib.types.attrsOf lib.types.anything;
                    default = { };
                    description = "Runtime configuration for the plugin.";
                  };
                };
              });
              description = "List of plugins to load.";
              default = [ ];
              example = lib.literalExpression ''
                [
                  {
                    name = "fs";
                    path = "oci://ghcr.io/tuananh/fs-plugin:latest";
                    runtime_config = {
                      allowed_paths = [ "/tmp" ];
                    };
                  }
                ]
              '';
            };
          };

          _configFile =
            if cfg.configFile != null
            then toString cfg.configFile
            else builtins.toFile "hyper-mcp-config.json" (builtins.toJSON { inherit (cfg) plugins; });

          wrappedPackage = pkgs.runCommand "hyper-mcp-wrapped"
            {
              buildInputs = [ pkgs.makeWrapper ];
            }
            ''
              mkdir -p $out/bin
              makeWrapper ${cfg.package}/bin/hyper-mcp $out/bin/hyper-mcp \
                --set RUST_LOG "''${RUST_LOG:-info}" \
                --add-flags "--config-file ${_configFile}" \
                ${lib.optionalString (cfg.transport != "stdio") "--add-flags '--transport ${cfg.transport}'"} \
                ${lib.optionalString (cfg.transport != "stdio" && cfg.bindAddress != null) "--add-flags '--bind-address ${cfg.bindAddress}'"} \
                ${lib.optionalString (cfg.insecureSkipSignature) "--add-flags '--insecure-skip-signature'"} \
                ${lib.optionalString (cfg.useSigstoreTufData) "--add-flags '--use-sigstore-tuf-data'"} \
                ${lib.optionalString (cfg.rekorPubKeys != null) "--add-flags '--rekor-pub-keys ${toString cfg.rekorPubKeys}'"} \
                ${lib.optionalString (cfg.fulcioCerts != null) "--add-flags '--fulcio-certs ${toString cfg.fulcioCerts}'"} \
                ${lib.optionalString (cfg.certIssuer != null) "--add-flags '--cert-issuer ${cfg.certIssuer}'"} \
                ${lib.optionalString (cfg.certEmail != null) "--add-flags '--cert-email ${cfg.certEmail}'"} \
                ${lib.optionalString (cfg.certUrl != null) "--add-flags '--cert-url ${cfg.certUrl}'"}
            '';
        in
        {
          options.programs.hyper-mcp = sharedOptions;

          config = lib.mkIf cfg.enable (
            lib.setAttrByPath packagesPath [ wrappedPackage ]
          );
        };

    in
    {
      packages = nixpkgs.lib.genAttrs systems (system: sysAttrs.${system}.packages);

      homeModules.default = mkModule { packagesPath = [ "home" "packages" ]; };
      nixosModules.default = mkModule { };
      darwinModules.default = mkModule { };
    };
}
