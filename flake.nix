{
  description = "Heaptrack - A heap memory profiler for Linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # --- Core CLI-only package ---
        # This version is minimal and suitable for CI.
        # It disables the GUI build to avoid pulling in Qt/KDE.
        heaptrack-cli = pkgs.stdenv.mkDerivation rec {
          pname = "heaptrack-cli";
          version = "master";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            cmake
            makeWrapper
            kdePackages.extra-cmake-modules
          ];

          buildInputs = with pkgs; [
            boost
            zlib
            libunwind
            elfutils
            rustc-demangle
          ];

          # This is the key to disabling the GUI and its heavy dependencies.
          cmakeFlags = [ "-DHEAPTRACK_BUILD_GUI=OFF" ];

          # We only need to wrap heaptrack_interpret now.
          postInstall = ''
            local demangler_libs="${pkgs.lib.makeLibraryPath [ pkgs.rustc-demangle ]}"
            wrapProgram $out/lib/heaptrack/libexec/heaptrack_interpret \
              --prefix LD_LIBRARY_PATH : "$demangler_libs"
          '';

          meta = with pkgs.lib; {
            description = "A heap memory profiler for Linux (CLI tools only)";
            homepage = "https://github.com/KDE/heaptrack";
            license = with licenses; [ lgpl21Plus gpl2Plus ];
            maintainers = with maintainers; [ ];
            platforms = platforms.linux;
          };
        };

        # --- Full package with GUI ---
        # This is the original package, for developers who want the GUI.
        heaptrack-full = pkgs.stdenv.mkDerivation rec {
          pname = "heaptrack";
          version = "master";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            cmake
            kdePackages.extra-cmake-modules
            kdePackages.wrapQtAppsHook
          ];

          buildInputs = [
            # Re-use the build inputs from the CLI version
            heaptrack-cli.buildInputs
          ] ++ (with pkgs.kdePackages; [
            # Add the GUI-specific dependencies
            kcoreaddons
            kwidgetsaddons
            ki18n
            kitemmodels
            kconfig
            kguiaddons
            kiconthemes
            kio
            kservice
            kxmlgui
            ktextwidgets
            knotifications
            kwindowsystem
            threadweaver
            kdiagram
            qtbase
          ]);

          postInstall = ''
            local demangler_libs="${pkgs.lib.makeLibraryPath [ pkgs.rustc-demangle ]}"
            wrapProgram $out/lib/heaptrack/libexec/heaptrack_interpret \
              --prefix LD_LIBRARY_PATH : "$demangler_libs"
            wrapProgram $out/bin/heaptrack_gui \
              --prefix LD_LIBRARY_PATH : "$demangler_libs"
          '';

          meta = with pkgs.lib; {
            description = "A heap memory profiler for Linux";
            homepage = "https://github.com/KDE/heaptrack";
            license = with licenses; [ lgpl21Plus gpl2Plus ];
            maintainers = with maintainers; [ ];
            platforms = platforms.linux;
          };
        };

      in
      {
        # Export both packages
        packages = {
          heaptrack = heaptrack-full;
          heaptrack-cli = heaptrack-cli;
          # The default package is the full one, for convenience
          default = heaptrack-full;
        };

        # Define apps for both versions
        apps = {
          default = flake-utils.lib.mkApp {
            drv = self.packages.${system}.default;
          };
          heaptrack = flake-utils.lib.mkApp {
            drv = self.packages.${system}.heaptrack;
          };
          # This is the app we will use in CI
          heaptrack-cli = flake-utils.lib.mkApp {
            drv = self.packages.${system}.heaptrack-cli;
            exePath = "/bin/heaptrack";
          };
        };

        # The devShell can provide the full build environment
        devShells.default = pkgs.mkShell {
          buildInputs = heaptrack-full.buildInputs ++ heaptrack-full.nativeBuildInputs;
        };
      });
}
