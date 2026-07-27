{
  libdisplay-info,
  fetchFromGitLab,
}:

libdisplay-info.overrideAttrs (
  finalAttrs: oldAttrs: {
    version = "0.3.0";

    src = fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "emersion";
      repo = "libdisplay-info";
      rev = finalAttrs.version;
      sha256 = "sha256-nXf2KGovNKvcchlHlzKBkAOeySMJXgxMpbi5z9gLrdc=";
    };
  }
)
