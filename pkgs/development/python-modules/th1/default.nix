{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  dpkt,
  pyyaml,
  pytestCheckHook,
}:
buildPythonPackage {
  pname = "th1";
  version = "0-unstable-2026-10-20";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "lexiforest";
    repo = "th1";
    rev = "5a644e50fe3460edf3197727acc18f7ed83fc642";
    hash = "sha256-Xp934wBdeIogb1ydlf+w/ExDjSIevwAdlIvaVRYgcfM=";
  };

  build-system = [ setuptools ];

  dependencies = [
    dpkt
    pyyaml
  ];

  nativeCheckInputs = [ pytestCheckHook ];

  disabledTests = [
    "test_nghttpd_log_parsing" # Attempts to load things from logs/ which it cannot find for some reason.
  ];

  meta = {
    description = "TLS and HTTP signature and fingerprint library";
    homepage = "https://github.com/lexiforest/th1";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
}
