{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cmake,
  git,
  perl,
  nix-update-script,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "pvcli";
  version = "0.1.0-unstable-2026-08-13";
  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "cloudflareresearch";
    repo = "pvcli";
    rev = "fd64f2f26c85130eef1cf8d69becd9b34c5409ac";
    hash = "sha256-jXuS+PFuguJC4Bxia1Dxf+l6P64PkaITg64lWFcvuOo=";
  };

  cargoHash = "sha256-Q1YQ/BsCzUX1m7R8LNJCdmYW5+OGeZEaGYFouEq2IAA=";

  nativeBuildInputs = [
    # boring-sys and quiche build the BoringSSL vendored in their crates
    cmake
    perl
    # boring-sys applies patches/*.patch to that tree with git apply
    git
    rustPlatform.bindgenHook
  ];

  dontUseCmakeConfigure = true;

  # tests/integration_tests.rs expects the wrangler-hosted mock OHTTP gateway from
  # docker-compose.test.yml on 127.0.0.1:8787
  cargoTestFlags = [
    "--lib"
    "--bins"
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version=branch" ];
  };

  meta = {
    description = "Curl-like client for the OHTTP, MASQUE and CONNECT privacy protocols";
    longDescription = ''
      pvcli performs each step of an Oblivious HTTP (RFC 9458) exchange in a single
      command: it fetches the gateway key configuration, encodes the inner request as
      Binary HTTP, encrypts it under HPKE, forwards it through the relay and gateway,
      and decrypts the response. It also speaks HTTP/2 CONNECT proxying, MASQUE, and
      mints Privacy Pass tokens (RFC 9578) for proxy authorization.
    '';
    homepage = "https://github.com/cloudflareresearch/pvcli";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ bad3r ];
    mainProgram = "pvcli";
    platforms = lib.platforms.unix;
  };
})
