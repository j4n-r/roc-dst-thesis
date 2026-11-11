{
  description = "Run FoundationDB's simulator by hand (TigerBeetle brings its own Zig, see README)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      # The test files come from ./foundationdb, so the binary must be built from the same tag.
      fdbTag = "7.3.68";
    in
    {
      devShells.x86_64-linux.default =
        assert nixpkgs.lib.assertMsg (pkgs.foundationdb.version == fdbTag)
          "nixpkgs has foundationdb ${pkgs.foundationdb.version}, but ./foundationdb is at ${fdbTag}: check out that tag in the submodule and update fdbTag, or roll back flake.lock";
        pkgs.mkShell { packages = [ pkgs.foundationdb ]; };
    };
}
