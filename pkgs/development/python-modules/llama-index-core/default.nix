{
  lib,
  aiohttp,
  aiosqlite,
  banks,
  buildPythonPackage,
  dataclasses-json,
  deprecated,
  dirtyjson,
  fetchFromGitHub,
  fetchurl,
  filetype,
  fsspec,
  hatchling,
  httpx,
  llama-index-workflows,
  nest-asyncio,
  networkx,
  nltk-data,
  nltk,
  numpy,
  openai,
  pandas,
  pillow,
  platformdirs,
  pydantic,
  pytest-asyncio,
  pytest-mock,
  pytestCheckHook,
  pyyaml,
  requests,
  setuptools,
  sqlalchemy,
  tenacity,
  tinytag,
  tiktoken,
  tqdm,
  typing-extensions,
  typing-inspect,
  wrapt,
}:

let
  # tiktoken keys its on-disk cache by the sha1 of the download URL.
  tiktokenCache = lib.mapAttrs (_: fetchurl) {
    "9b5ad71b2ce5302211f9c61530b329a4922fc6a4" = {
      url = "https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken";
      hash = "sha256-Ijkht27pm96ZW3/3OFE+7xAPtR0YyTWXoRO8/+hlsqc=";
    };
    "6d1cbeee0f20b3d9449abfede4726ed8212e3aee" = {
      url = "https://openaipublic.blob.core.windows.net/gpt-2/encodings/main/vocab.bpe";
      hash = "sha256-HOFmR3PFDz4MyIQmGak+3EYkUltyixiKngvjO3cmrcU=";
    };
    "6c7ea1a7e38e3a7f062df639a5b80947f075ffe6" = {
      url = "https://openaipublic.blob.core.windows.net/gpt-2/encodings/main/encoder.json";
      hash = "sha256-GWE5ZovmPztdZXRCcxeugvYSqXxdHNrzbtIlbb9jZ4M=";
    };
  };
in
buildPythonPackage (finalAttrs: {
  pname = "llama-index-core";
  version = "0.14.25";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "run-llama";
    repo = "llama_index";
    tag = "v${finalAttrs.version}";
    hash = "sha256-JHrDxjXfQmrdNL9PmQvUzupg7su4ShwtVaCHsJjKIgo=";
  };

  sourceRoot = "${finalAttrs.src.name}/${finalAttrs.pname}";

  # llama_index.core.utils looks up NLTK and tiktoken data in _static, the
  # directories upstream's wheel bundles, and downloads whatever is missing.
  postPatch = ''
    mkdir -p llama_index/core/_static/{nltk_cache/corpora,nltk_cache/tokenizers,tiktoken_cache}
    cp -r ${nltk-data.stopwords}/corpora/stopwords llama_index/core/_static/nltk_cache/corpora/
    cp -r ${nltk-data.punkt-tab}/tokenizers/punkt_tab llama_index/core/_static/nltk_cache/tokenizers/
  ''
  + lib.concatStrings (
    lib.mapAttrsToList (name: src: ''
      cp ${src} llama_index/core/_static/tiktoken_cache/${name}
    '') tiktokenCache
  );

  build-system = [ hatchling ];

  dependencies = [
    aiohttp
    aiosqlite
    banks
    dataclasses-json
    deprecated
    dirtyjson
    filetype
    fsspec
    httpx
    llama-index-workflows
    nest-asyncio
    networkx
    nltk
    numpy
    pillow
    platformdirs
    pydantic
    pyyaml
    requests
    setuptools
    sqlalchemy
    tenacity
    tinytag
    tiktoken
    tqdm
    typing-extensions
    typing-inspect
    wrapt
  ]
  ++ sqlalchemy.optional-dependencies.asyncio;

  nativeCheckInputs = [
    openai
    pandas
    pytest-asyncio
    pytest-mock
    pytestCheckHook
  ];

  # get_tokenizer only sets the cache for its own call; pool workers and tests
  # calling tiktoken directly would download.
  preCheck = ''
    export TIKTOKEN_CACHE_DIR=$PWD/llama_index/core/_static/tiktoken_cache
  '';

  pythonImportsCheck = [ "llama_index" ];

  disabledTestPaths = [
    # Tests fetch PDFs, images, or other files over the network
    "tests/base/llms/test_types.py::test_chat_message_aestimate_tokens"
    "tests/base/llms/test_types.py::test_chat_message_amerge"
    "tests/base/llms/test_types.py::test_chat_message_asplit_non_recursive_types"
    "tests/base/llms/test_types.py::test_chat_message_asplit_recursive_types"
    "tests/base/llms/test_types.py::test_chat_message_atruncate_multiple_multimodal_blocks"
    "tests/base/llms/test_types.py::test_chat_message_atruncate_recursive"
    "tests/base/llms/test_types.py::test_chat_message_atruncate_simple"
    "tests/base/llms/test_types.py::test_chat_message_format"
    "tests/base/llms/test_types.py::test_citable_block_aestimate_tokens"
    "tests/base/llms/test_types.py::test_citable_block_amerge"
    "tests/base/llms/test_types.py::test_citable_block_asplit"
    "tests/base/llms/test_types.py::test_citable_block_atruncate"
    "tests/base/llms/test_types.py::test_citable_block_format"
    "tests/base/llms/test_types.py::test_document_block_aestimate_tokens"
    "tests/base/llms/test_types.py::test_document_block_amerge"
    "tests/base/llms/test_types.py::test_document_block_asplit"
    "tests/base/llms/test_types.py::test_document_block_atruncate"
    "tests/base/llms/test_types.py::test_document_block_format"
    "tests/base/llms/test_types.py::test_document_block_from_b64"
    "tests/base/llms/test_types.py::test_document_block_from_bytes"
    "tests/base/llms/test_types.py::test_document_block_from_path"
    "tests/base/llms/test_types.py::test_document_block_from_url"
    "tests/indices/test_prompt_helper.py::test_chat_prompt_helper_atruncate_multimodal"
    "tests/indices/test_prompt_helper.py::test_chat_prompt_helper_chat_prompt_template_repack_arbitrary"
    "tests/indices/test_prompt_helper.py::test_prompt_helper_get_biggest_chat_prompt_text_multimodal"
    "tests/multi_modal_llms/test_generic_utils.py::test_complete_workflow"
    "tests/multi_modal_llms/test_generic_utils.py::test_image_documents_to_base64_failed_url"
    "tests/multi_modal_llms/test_generic_utils.py::test_image_documents_to_base64_multiple_sources"
    "tests/multi_modal_llms/test_generic_utils.py::test_load_image_urls"
    "tests/multi_modal_llms/test_generic_utils.py::test_set_base64_and_mimetype_for_image_docs"
    "tests/prompts/test_rich.py::test_prompt_with_chat_message"
    "tests/prompts/test_rich.py::test_prompt_with_chat_messages"
    "tests/prompts/test_rich.py::test_prompt_with_document_blocks"
    "tests/schema/test_image_document.py::test_real_image_path"
    "tests/schema/test_image_document.py::test_real_image_url"
    "tests/schema/test_media_resource.py::test_mimetype_raw_data"
    "tests/schema/test_schema.py::test_image_document_path"
    "tests/schema/test_schema.py::test_image_document_path_serialization"
    "tests/schema/test_schema.py::test_image_document_url"
  ];

  meta = {
    description = "Data framework for your LLM applications";
    homepage = "https://github.com/run-llama/llama_index/";
    changelog = "https://github.com/run-llama/llama_index/blob/${finalAttrs.src.tag}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ fab ];
  };
})
