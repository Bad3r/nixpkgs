{
  lib,
  buildLua,
  fetchFromGitHub,
  gitUpdater,
  curl,
  wl-clipboard,
  xclip,
}:

buildLua rec {
  pname = "mpvacious";
  version = "26.7.28.0";

  src = fetchFromGitHub {
    owner = "Ajatt-Tools";
    repo = "mpvacious";
    rev = "v${version}";
    sha256 = "sha256-FZvjaIIsU0LNXTJrVJWOhbN2oth9vBcP1vQf4JrXPXg=";
  };
  passthru.updateScript = gitUpdater { rev-prefix = "v"; };

  postPatch = ''
    substituteInPlace mpvacious/platform/nix.lua \
      --replace-fail "'curl" "'${lib.getExe curl}" \
      --replace-fail "'wl-copy" "'${lib.getExe' wl-clipboard "wl-copy"}" \
      --replace-fail "'xclip" "'${lib.getExe xclip}"
  '';

  installPhase = ''
    runHook preInstall
    make PREFIX=$out/share/mpv VERSION=${version} install
    runHook postInstall
  '';

  passthru.scriptName = "mpvacious";

  meta = {
    description = "Adds mpv keybindings to create Anki cards from movies and TV shows";
    homepage = "https://github.com/Ajatt-Tools/mpvacious";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ kmicklas ];
  };
}
