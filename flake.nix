{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    fenix,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            fenix.overlays.default
          ];
        };
        nativeBuildInputs = with pkgs;
          [
            (fenix.packages."${system}".stable.withComponents [
              "cargo"
              "rust-src"
              "rust-docs"
              "rustc"
            ])
            rust-analyzer
            pkg-config
            openssl
            clang
            cmake
            cargo-deny
            cargo-edit
            cargo-watch
            alejandra
          ]
          ++ lib.optionals stdenv.isDarwin [
            pkgs.darwin.apple_sdk.frameworks.Security
            pkgs.darwin.apple_sdk.frameworks.CoreFoundation
          ];
      in {
        devShells.default = pkgs.mkShell {
          inherit nativeBuildInputs;
          RUST_SRC_PATH = "${fenix.packages.${system}.stable.rust-src}/bin/rust-lib/src";
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeBuildInputs;
          LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
          NIX_LDFLAGS = "${pkgs.lib.optionalString pkgs.stdenv.isDarwin "\
            -F${pkgs.darwin.apple_sdk.frameworks.Security}/Library/Frameworks -framework Security \
            -F${pkgs.darwin.apple_sdk.frameworks.CoreFoundation}/Library/Frameworks -framework CoreFoundation"}";
          buildInputs = with pkgs; [
            (fenix.packages."${system}".stable.withComponents ["clippy" "rustfmt"])
            # setting LIBCLANG_PATH manually breaks globally installed `ssh` binary and transitively breaks git
            # so we use a local version of `ssh` in this dev env (maybe there is a better way to fix it)
            openssh
          ];
        };
      }
    );
}
