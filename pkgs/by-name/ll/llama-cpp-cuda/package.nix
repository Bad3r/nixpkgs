{ llama-cpp }:

# nixpkgs-update: no auto update
(llama-cpp.override { cudaSupport = true; }).overrideAttrs (oldAttrs: {
  pname = "llama-cpp-cuda";

  patches = (oldAttrs.patches or [ ]) ++ [
    # Strict chat templates (Qwen3.5+) raise on the mid-conversation system and
    # developer messages Claude Code and Codex send, so fold them into the first one.
    # Applied here only, so the CPU package and its dependents stay cached.
    # https://github.com/ggml-org/llama.cpp/issues/27367
    ./fold-non-leading-system-messages.patch
  ];

  meta = oldAttrs.meta // {
    # Re-anchor meta.position here so nixpkgs-update sees the opt-out above.
    inherit (oldAttrs.meta) description;
  };
})
