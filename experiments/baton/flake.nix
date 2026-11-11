{
  description = "baton: several Roc app instances under a seeded, single-runner scheduler";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Roc source for src/glue/src/RustGlue.roc. Keep this rev in sync with the
    # roc nightly from roc-overlay in ~/nix-config (`roc version`).
    roc-src = {
      url = "github:roc-lang/roc/34f137a34d15b3800404ac99ee32b4ceeda1421a";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      rust-overlay,
      roc-src,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
      rustChannel = (builtins.fromTOML (builtins.readFile ./rust-toolchain.toml)).toolchain.channel;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
          };
          # Equivalent of `rustup target add x86_64-unknown-linux-musl`.
          rustToolchain = pkgs.rust-bin.stable.${rustChannel}.default.override {
            extensions = [
              "rust-src"
              "rust-analyzer"
            ];
            targets = [ "x86_64-unknown-linux-musl" ];
          };
        in
        {
          default = pkgs.mkShell {
            packages = [
              rustToolchain
              pkgs.python3
            ];
            # roc glue $ROC_GLUE_SPEC ./src/ platform/main.roc
            ROC_GLUE_SPEC = "${roc-src}/src/glue/src/RustGlue.roc";
          };
        }
      );
    };
}
