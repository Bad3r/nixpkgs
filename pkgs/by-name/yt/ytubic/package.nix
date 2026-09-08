{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,

  # nativeBuildInputs
  cargo-tauri,
  jq,
  moreutils,
  nodejs,
  pkg-config,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  wrapGAppsHook3,

  # buildInputs
  dbus,
  glib-networking,
  gst_all_1,
  gtk3,
  libayatana-appindicator,
  libsoup_3,
  openssl,
  webkitgtk_4_1,

  # runtime
  yt-dlp,

  nix-update-script,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ytubic";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "NUber-dev";
    repo = "YTubic";
    tag = "v${finalAttrs.version}";
    hash = "sha256-JAYVgTl73Mt7hOLIYchCW3jk3Q8n4vhNLIjgtVL0VhU=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 4;
    hash = "sha256-07WnExlcdwRTkjyabjvNckNkzArxn0x0lTcF8IUBFc0=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs)
      pname
      version
      src
      cargoRoot
      ;
    hash = "sha256-QCVhrxxav09AZ0iu78g9c8gXZG4jGDORytltN2qbEtA=";
  };

  postPatch = ''
    jq \
      '.plugins.updater.endpoints = [ ]
      | .bundle.createUpdaterArtifacts = false' \
      src-tauri/tauri.conf.json \
      | sponge src-tauri/tauri.conf.json

    # Upstream downloads its own yt-dlp into the app data directory on first run
    # and refreshes it every 72 hours. That release asset is a PyInstaller build
    # that cannot run here, so spawn the packaged yt-dlp and skip the download.
    substituteInPlace src-tauri/src/ytdlp.rs \
      --replace-fail \
        'pub fn program(managed: &Path) -> PathBuf {
        if managed.exists() {
            managed.to_path_buf()
        } else {
            PathBuf::from("yt-dlp")
        }
    }' \
        'pub fn program(_managed: &Path) -> PathBuf {
        PathBuf::from("${lib.getExe yt-dlp}")
    }' \
      --replace-fail \
        'pub async fn ensure(app: tauri::AppHandle) {' \
        'pub async fn ensure(app: tauri::AppHandle) {
        emit_state(&app, "ready", None);
    }

    #[allow(dead_code)]
    async fn ensure_managed(app: tauri::AppHandle) {'
  '';

  nativeBuildInputs = [
    cargo-tauri.hook
    jq
    moreutils
    nodejs
    pkg-config
    pnpmConfigHook
    pnpm_10
    rustPlatform.cargoSetupHook
    wrapGAppsHook3
  ];

  buildInputs = [
    dbus
    glib-networking
    gst_all_1.gst-libav
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gstreamer
    gtk3
    libayatana-appindicator
    libsoup_3
    openssl
    webkitgtk_4_1
  ];

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libayatana-appindicator ]}"
    )
  '';

  __structuredAttrs = true;
  strictDeps = true;

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Fast, responsive YouTube Music desktop client";
    homepage = "https://github.com/NUber-dev/YTubic";
    changelog = "https://github.com/NUber-dev/YTubic/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.gpl3Only;
    mainProgram = "ytubic";
    maintainers = with lib.maintainers; [ bad3r ];
    platforms = lib.platforms.linux;
  };
})
