{
  description = "QBZ — Native hi-fi Qobuz desktop player for Linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        version = (builtins.fromJSON (builtins.readFile ./package.json)).version;
      in
      {
        packages.default = pkgs.rustPlatform.buildRustPackage {
          inherit version;
          pname = "qbz";
          src = self;

          cargoRoot = "src-tauri";
          buildAndTestSubdir = "src-tauri";

          cargoLock = {
            lockFile = ./src-tauri/Cargo.lock;
          };

          npmDeps = pkgs.importNpmLock {
            npmRoot = self;
          };

          env.LIBCLANG_PATH = "${pkgs.lib.getLib pkgs.llvmPackages.libclang}/lib";

          nativeBuildInputs = with pkgs; [
            clang
            cargo-tauri.hook
            nodejs
            importNpmLock.npmConfigHook
            pkg-config
            makeWrapper
          ];

          buildInputs = with pkgs; [
            alsa-lib
            openssl
            webkitgtk_4_1
            libappindicator-gtk3
            libayatana-appindicator
          ];

          checkFlags = [
            # These require a writable HOME and D-Bus keyring service
            "--skip=credentials::tests::test_credentials_roundtrip"
            "--skip=credentials::tests::test_encryption_roundtrip"
            # Requires machine UUID / fingerprint unavailable in sandbox
            "--skip=qconnect_service::tests::refreshes_local_renderer_id_from_unique_fingerprint_when_uuid_missing"
          ];

          postInstall = ''
            wrapProgram $out/bin/qbz \
              --prefix LD_LIBRARY_PATH : ${
                pkgs.lib.makeLibraryPath [
                  pkgs.libappindicator
                  pkgs.libappindicator-gtk3
                  pkgs.libayatana-appindicator
                ]
              }
          '';

          meta = with pkgs.lib; {
            description = "Native, full-featured hi-fi Qobuz desktop player for Linux";
            homepage = "https://qbz.lol";
            license = licenses.mit;
            mainProgram = "qbz";
            platforms = platforms.linux;
          };
        };

        # Dev shell with all build dependencies
        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.default ];
          packages = with pkgs; [
            rust-analyzer
            rustfmt
            clippy
          ];
        };
      });
}
