{
  lib,
  buildPythonPackage,
  fetchPypi,
  fetchpatch,
  setuptools,
  setuptools-scm,
  packaging,

  # tests
  poppler-qt5,
  qgis,
  qgis-ltr,
}:

buildPythonPackage (finalAttrs: {
  pname = "sip";
  version = "6.16.1";
  pyproject = true;

  src = fetchPypi {
    inherit (finalAttrs) pname version;
    hash = "sha256-CnOcnNKSneTgiERW2Mrzz7IsEFNHV8d5e9jca9ntabw=";
  };

  patches = [
    # 6.16.1 rejects bindings that target ABI 12/13 without declaring
    # %MinimumABIVersion, which breaks pyqt5. Fixed upstream after 6.16.1.
    (fetchpatch {
      name = "sip-allow-legacy-abi-without-minimum-abi-version.patch";
      url = "https://github.com/Python-SIP/sip/commit/09598895c607f3e41f0249ade217ace0a4da6437.patch";
      hash = "sha256-v0YeHyg0ymB0v32gpVRbMBIUk9U2etjs93VuOGPGg2M=";
    })
  ];

  build-system = [
    setuptools
    setuptools-scm
  ];

  dependencies = [
    packaging
    setuptools
  ];

  # There aren't tests
  doCheck = false;

  pythonImportsCheck = [ "sipbuild" ];

  passthru.tests = {
    # test depending packages
    inherit poppler-qt5 qgis qgis-ltr;
  };

  meta = {
    description = "Creates C++ bindings for Python modules";
    homepage = "https://riverbankcomputing.com/";
    license = lib.licenses.gpl3Only;
    maintainers = [ ];
  };
})
