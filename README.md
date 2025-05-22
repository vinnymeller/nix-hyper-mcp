# nix-hyper-mcp

A Nix flake providing a [hyper-mcp](https://github.com/tuananh/hyper-mcp) package and home-manager module.

## Package

Run directly:
```bash
nix run github:cmacrae/hyper-mcp-flake
```

Install to profile:
```bash
nix profile install github:cmacrae/hyper-mcp-flake
```

## home-manager

After adding to your inputs, use in your home-manager config:
```nix
{
  imports = [ inputs.hyper-mcp.homeModules.default ];

  programs.hyper-mcp = {
    enable = true;
    transport = "stdio";
    plugins = [
      {
        name = "fs";
        path = "oci://ghcr.io/tuananh/fs-plugin:latest";
        runtime_config = {
          allowed_paths = [ "/tmp" ];
        };
      }
    ];
  };
}
```

## Supported Systems

- x86_64-linux
- aarch64-linux
- aarch64-darwin
