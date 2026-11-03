{
  lib,
  rustPlatform,
  openshell,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  cacert,
  coreutils,
  gitMinimal,
  openssh,
  pkg-config,
  z3,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "openshell-gateway";
  # the gateway embeds the image tag, so it must match the CLI release
  inherit (openshell) version src cargoHash;

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [ z3 ];

  nativeCheckInputs = [
    cacert
    gitMinimal
    openssh
    writableTmpDirAsHomeHook
  ];

  postPatch = ''
    substituteInPlace Cargo.toml \
      --replace-fail 'version = "0.0.0"' 'version = "${finalAttrs.version}"'
    # test fixtures exec tools at FHS paths absent from the build sandbox
    substituteInPlace crates/openshell-gateway/tests/config_preflight.rs \
      --replace-fail '/bin/sleep' '${lib.getExe' coreutils "sleep"}'
  '';

  cargoBuildFlags = [
    "--package"
    "openshell-gateway"
  ];
  cargoTestFlags = finalAttrs.cargoBuildFlags;

  # every default feature except anonymous telemetry
  buildNoDefaultFeatures = true;
  buildFeatures = [ "defaults-without-telemetry" ];

  env.OPENSHELL_IMAGE_TAG = finalAttrs.version;

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    inherit (openshell.meta) homepage license maintainers;
    changelog = "https://github.com/NVIDIA/OpenShell/releases/tag/v${finalAttrs.version}";
    description = "Control plane that runs OpenShell sandboxes, built without telemetry";
    mainProgram = "openshell-gateway";
    platforms = lib.platforms.linux;
  };
})
