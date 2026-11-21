{
  lib,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "gbm-zygote-preload";
  version = "0.1.0";

  src = ./gbm-zygote-preload.c;
  dontUnpack = true;

  buildPhase = ''
    runHook preBuild
    $CC -O2 -Wall -Wextra -Werror -shared -fPIC -o gbm-zygote-preload.so $src
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 gbm-zygote-preload.so $out/lib/gbm-zygote-preload.so
    runHook postInstall
  '';

  meta = {
    description = "LD_PRELOAD shim that loads Mesa's GBM backends into the GPU zygote of Chromium and Electron apps";
    longDescription = ''
      The GPU process of Chromium and Electron apps forks from the unsandboxed
      zygote, and its seccomp broker denies /run/opengl-driver, so libgbm's
      lazy dlopen of its backend fails with EACCES. Preloaded into an app with
      GBM_ZYGOTE_PRELOAD_EXE set to the app's executable, the shim loads the
      backends in that zygote only and removes itself from the environment of
      every other program the app starts.
    '';
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
}
