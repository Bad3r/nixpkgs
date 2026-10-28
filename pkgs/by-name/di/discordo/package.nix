{
  lib,
  stdenv,
  buildGo127Module,
  fetchFromGitHub,
  nix-update-script,
  libpulseaudio,
  makeWrapper,
  xdg-utils,
  zenity,
}:

buildGo127Module (finalAttrs: {
  pname = "discordo";
  version = "0-unstable-2026-10-17";

  src = fetchFromGitHub {
    owner = "ayn2op";
    repo = "discordo";
    rev = "805621bc2e83b4aad48a56ff0e295154813ce285";
    hash = "sha256-gre/tkSfXRZnNGFCR4zJX8jSkAcceblQmhgujPy3roU=";
  };

  # https://github.com/ayn2op/discordo/pull/823 removed notifications.sound; this runs a command instead.
  patches = [ ./notifications-command.patch ];

  vendorHash = "sha256-HBBJswzvKeYUE2mq5BwRWFMCBqxpzAnWsjUvoRgQ5t8=";

  env.CGO_ENABLED = 1;

  ldflags = [
    "-s"
  ];

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    makeWrapper
  ];

  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram $out/bin/discordo \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libpulseaudio ]} \
      --prefix PATH : ${
        lib.makeBinPath [
          xdg-utils
          zenity
        ]
      }
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version=branch" ];
  };

  meta = {
    description = "Lightweight, secure, and feature-rich Discord terminal client";
    homepage = "https://github.com/ayn2op/discordo";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [
      arian-d
      siphc
    ];
    mainProgram = "discordo";
  };
})
