{
  stdenv,
  electron-unwrapped,
  gbm-zygote-preload,
  wrapGAppsHook3,
  makeWrapper,
  gsettings-desktop-schemas,
  glib,
  gtk3,
  gtk4,
}:

stdenv.mkDerivation {
  pname = "electron";
  inherit (electron-unwrapped) version;

  nativeBuildInputs = [
    wrapGAppsHook3
    makeWrapper
  ];
  buildInputs = [
    # needed for GSETTINGS_SCHEMAS_PATH
    gsettings-desktop-schemas
    glib
    gtk3
    gtk4
  ];
  dontWrapGApps = true;

  buildCommand = ''
    gappsWrapperArgsHook
    mkdir -p $out/bin
    makeWrapper "${electron-unwrapped}/libexec/electron/electron" "$out/bin/electron" \
      "''${gappsWrapperArgs[@]}" \
      --set CHROME_DEVEL_SANDBOX $out/libexec/electron/chrome-sandbox \
      --prefix LD_PRELOAD : ${gbm-zygote-preload}/lib/gbm-zygote-preload.so --set GBM_ZYGOTE_PRELOAD_EXE ${electron-unwrapped}/libexec/electron/electron

    ln -s ${electron-unwrapped}/libexec $out/libexec
  '';

  passthru = {
    unwrapped = electron-unwrapped;
    inherit (electron-unwrapped) headers dist;
  };

  __structuredAttrs = true;
  strictDeps = true;

  inherit (electron-unwrapped) meta;
}
