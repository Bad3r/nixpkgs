{
  lib,
  atk,
  cairo,
  callPackage,
  fetchFromGitHub,
  fontconfig,
  gdk-pixbuf,
  glib,
  gobject-introspection,
  gtk4,
  libglvnd,
  libx11,
  libxcursor,
  libxi,
  libxkbcommon,
  libxrandr,
  lld,
  pango,
  pkg-config,
  rustPlatform,
  stdenv,
  testers,
  wayland,
  wrapGAppsHook4,
  xvfb-run,
  versionCheckHook,
  withGui ? true,
}:

let
  self = rustPlatform.buildRustPackage {
    pname = "czkawka";
    version = "12.0.2";

    src = fetchFromGitHub {
      owner = "qarmin";
      repo = "czkawka";
      tag = self.version;
      hash = "sha256-adatuaG4sR1OJkjJdVgzm+wYqDAYBjId/thQj5rs3nI=";
    };

    cargoHash = "sha256-nTqzQrEWqN89XjQ4bgdCfWAXdyfB7UTQ3tAuL7LtNhA=";

    cargoBuildFlags = if withGui then null else [ "--package=czkawka_cli" ];
    cargoTestFlags = if withGui then null else [ "--package=czkawka_cli" ];

    nativeBuildInputs =
      lib.optionals withGui [
        gobject-introspection
        pkg-config
        wrapGAppsHook4
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        lld # ld crashes
      ];

    buildInputs =
      lib.optionals withGui [
        atk
        cairo
        fontconfig
        gdk-pixbuf
        glib
        gtk4
        pango
      ]
      ++ lib.optionals (withGui && stdenv.hostPlatform.isLinux) [
        libglvnd
        libxkbcommon
        wayland
      ];

    nativeCheckInputs = lib.optionals withGui [ xvfb-run ];

    doCheck = stdenv.hostPlatform.isLinux && (stdenv.hostPlatform == stdenv.buildPlatform);

    checkPhase =
      if withGui then
        ''
          runHook preCheck
          xvfb-run cargo test
          runHook postCheck
        ''
      else
        null;

    # Desktop items, icons and metainfo are not installed automatically
    postInstall = lib.optionalString withGui ''
      # Czkawka
      install -Dm444 -t $out/share/applications data/com.github.qarmin.czkawka.desktop
      install -Dm444 -t $out/share/icons/hicolor/scalable/apps data/icons/com.github.qarmin.czkawka.svg
      install -Dm444 -t $out/share/icons/hicolor/scalable/apps data/icons/com.github.qarmin.czkawka-symbolic.svg
      install -Dm444 -t $out/share/metainfo data/com.github.qarmin.czkawka.metainfo.xml

      # Krokiet
      install -Dm444 -t $out/share/applications data/io.github.qarmin.krokiet.desktop
      install -Dm444 -t $out/share/icons/hicolor/scalable/apps data/icons/io.github.qarmin.krokiet.svg
      install -Dm444 -t $out/share/metainfo data/io.github.qarmin.krokiet.metainfo.xml
    '';
    dontWrapGApps = true;

    postFixup =
      lib.optionalString withGui ''
        wrapGApp $out/bin/czkawka_gui
      ''
      + lib.optionalString (withGui && stdenv.hostPlatform.isLinux) ''
        patchelf --add-rpath "${
          lib.makeLibraryPath [
            fontconfig
            libglvnd
            libx11
            libxcursor
            libxi
            libxrandr
            libxkbcommon
            wayland
          ]
        }" $out/bin/krokiet
      '';

    nativeInstallCheckInputs = [
      versionCheckHook
    ];
    versionCheckProgram = "${placeholder "out"}/bin/czkawka_cli";
    doInstallCheck = true;

    passthru = {
      tests.version = testers.testVersion {
        package = self;
        command = "czkawka_cli --version";
      };
      wrapper = callPackage ./wrapper.nix {
        czkawka = self;
      };
    };

    meta = {
      homepage = "https://github.com/qarmin/czkawka";
      description = "Simple, fast and easy to use app to remove unnecessary files from your computer";
      changelog = "https://github.com/qarmin/czkawka/raw/${self.version}/Changelog.md";
      license = lib.licenses.mit;
      mainProgram = if withGui then "czkawka_gui" else "czkawka_cli";
      maintainers = with lib.maintainers; [
        yanganto
        _0x4A6F
      ];
    };
  };
in
self
