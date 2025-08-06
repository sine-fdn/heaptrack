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
      in
      {
        packages.default = pkgs.stdenv.mkDerivation rec {
          pname = "heaptrack";
          version = "master";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            cmake
            kdePackages.extra-cmake-modules
            kdePackages.wrapQtAppsHook
          ];

          buildInputs = with pkgs; [
            boost
            zlib
            libunwind
            elfutils
            rustc-demangle
          ] ++ (with pkgs.kdePackages; [
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

        packages.heaptrack = self.packages.${system}.default;

        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.default;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = self.packages.${system}.default.buildInputs
                     ++ self.packages.${system}.default.nativeBuildInputs;
        };
      });
}