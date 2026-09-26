# CUDA hot-expert fork

Personal integration branch: [`hendrikp/llama.cpp`, `hot-experts-cuda`](https://github.com/hendrikp/llama.cpp/tree/hot-experts-cuda).

This checkout was cloned from **ggml-org/llama.cpp**, not from the replication fork. Its upstream base is [`2145525a4081d66ff1a87cf43ef809f95a85ac0c`](https://github.com/ggml-org/llama.cpp/commit/2145525a4081d66ff1a87cf43ef809f95a85ac0c), checked on **2026-09-26**. Only the selected unmerged changes and integration fixes are added above that base. Original PR authors and source hashes are preserved through `git cherry-pick -x`.

The starting reference is [Inovello's Flash-Next replication post](https://www.reddit.com/r/LocalLLaMA/comments/1w6ozbj/update_qwen38flashnext_on_2x3090_ddr4_part_2_2529/). Its 2x3090 benchmark numbers are not measurements of this machine.

## Selected PRs

| PR | State when checked | Why included |
| --- | --- | --- |
| [#27861](https://github.com/ggml-org/llama.cpp/pull/27861), csantiago78 | Open, draft, unmerged | GPU-resident LRU cache for host-offloaded MoE experts. Multiple independent reports support its potential, but it has no approving review and needs fixes. |
| [#28223](https://github.com/ggml-org/llama.cpp/pull/28223), Inovello | Closed, **not merged** | Exposes CUDA_Host tensor overrides, preserves them with mmap, and reads allocated host tensors directly from the file. The author explicitly parked the PR because of the one-open-PR rule; closure did not mean the feature landed. |
| [#28243](https://github.com/ggml-org/llama.cpp/pull/28243), Ryan Monsurate and Daniel Han | Open, unmerged | Qwen3.8-Flash-Next MTP, including draft-only exports and borrowing the target's embedding/output tensors. Includes the September 21 review changes. |

The current MTP PR was used instead of its older version inside the September 3 replication squash. Merge commits were not cherry-picked wholesale. The necessary NextN norm reshape from the MTP merge resolution was retained explicitly.

The replication branch later added #28198 and a radix top-k fallback. **#28198 is already upstream** as `0ba6499c3`, so its fork cherry-pick `2fc84fc80` was not duplicated. The top-k fallback (`dd64a3db0`) targets builds without CUB DeviceTopK; this CUDA 13.3 toolkit supplies CUB 3.3.4 and upstream already selects DeviceTopK, so that fallback was not imported.

## Commit provenance

All source hashes below belong to the linked upstream PRs. Use `git show <fork-commit>` for original author metadata and the full source hash.

| Source commit | Fork commit | Change |
| --- | --- | --- |
| `bccbacdb8945` | `9acb1b464` | #27861 expert cache |
| `5cfa6a875e8c` | `86354a836` | #28223 host-buffer overrides with mmap |
| `c59754bfc185` | `9d429a099` | #28223 direct host-buffer reads |
| `c8c3a5bfe3f3` | `891b88605` | #28243 GGUF NextN tensors |
| `57672d973fcf` | `52798532a` | MTP model/graph support |
| `84f9558855e1` | `4cd19e1ef` | MTP conversion |
| `86d321a292e6` | `bb1db5222` | Shared embeddings/head support |
| `30b65375afa1` | `11024d494` | Draft-only exports |
| `44c79602c840` | `a708fc236` | MTP cleanup |
| `eb65412fc1c9` | `4f80c45aa` | Conversion mixin declaration |
| `44ff8032376a` | `30aa4fba0` | Reject standalone shared drafts |
| `cc2c59a74c6f` | `9c26d6e6c` | Borrow tensors through ctx_other |
| `2c967293c263` | `f6e41fc70` | MTP cleanup |
| `d1a92352cbd4` | `1fbef9ea0` | Separate MTP KV cache |
| `6fcaa16f4b36` | `ec35bcfb7` | Latest MTP review changes |
| Sources detailed below | `c9a113534` | CUDA/Windows integration and duplicate-ID tests |
| Sources detailed below | `5c04c7c0c` | Staged cache replacement and draft isolation |

## Other expert-cache candidates considered

This is a practical selection for Windows, one RTX 5080, and Flash-Next. It is not a claim that #27861 is merge-ready or the fastest design for every machine.

| Candidate | Assessment on 2026-09-26 |
| --- | --- |
| [#26824](https://github.com/ggml-org/llama.cpp/pull/26824) | Broader heatmap-based expert placement/caching. Closed without merging, no approving reviews found. Not selected over the narrower cache with independent Flash-Next reports. |
| [#26414](https://github.com/ggml-org/llama.cpp/pull/26414) | Pins hot experts in system RAM. Addresses disk paging rather than providing the same VRAM cache. |
| [#28414](https://github.com/ggml-org/llama.cpp/pull/28414) | Lookahead expert prefetch, mainly a prefill optimization. Still draft; discussion identifies multi-GPU correctness and allocation-padding concerns. Not a replacement for decode caching. |
| [#21067](https://github.com/ggml-org/llama.cpp/pull/21067) | Tensor-override prefetch with more reviewer activity, including an approval, but different semantics. Benefits depend on PCIe bandwidth and batch size; not evidence of a better hot-expert decode cache. |
| [neurall's fork](https://github.com/neurall/llama.cpp) | Newer adaptive sizing/admission and CPU/GPU overlap work built on #27861. Interesting, but [a Windows Flash-Next tester reported about 10-11 t/s versus 42 t/s with a patched #27861 build](https://github.com/ggml-org/llama.cpp/pull/27861#issuecomment-5839255669). This single report is not a controlled comparison on this machine. |
| [pjsgsy's September 23 patch](https://github.com/ggml-org/llama.cpp/pull/27861#issuecomment-5797708954) | Adds admission policies, more controls, and fixes for a 12 GB RTX 3060. Reviewed as a source of findings, but not imported wholesale: it overlaps the original PR and includes hardware/policy changes beyond this integration. |

No clearly better-backed replacement for the requested GPU cache was found. Community reports are useful evidence, not maintainer approval or proof of correctness.

## Integration fixes and attribution

* **Current upstream CMake:** add `llama-moecache.cpp` to `LLAMA_CORE_SOURCES`, preserving the current unity-build exclusions.
* **MTP rebase:** keep upstream's `[n_embd, hc]` normalization shapes and `TENSOR_ALLOW_RESHAPE` while adding the PR's loading flags. Preserve the NextN output norm reshape found in Daniel Han's merge commit `6fd37b7111194713f0a8fb060e6b2e0e0e3ac9a8`.
* **CUDA duplicate IDs:** adapt Inovello's helper fix from [replication commit `9bd97fe54833`](https://github.com/Inovello/llama.cpp/commit/9bd97fe54833d02fee8a56e8e476f0069bd94006) and [bug analysis](https://github.com/ggml-org/llama.cpp/pull/27861#issuecomment-5529656015). Each matching lane gets its own compact row; shared-memory sizing accounts for duplicates where it fits. This is **not** a complete fix for every batched CUDA path.
* **Safe cache window:** use quantized gate/up/down tensors only, at most eight tokens, and flatten/reshape the ID lookup for MTP verification. Larger batches use the ordinary path. Eight is the vector-kernel limit on the tested Blackwell GPU; some other GPU/quant combinations need a smaller limit. Floating-point expert weights do not use this cache path.
* **Backend coverage:** adapt Inovello's duplicate-ID cases to the current test helpers, preserving upstream activation-magnitude and FP4 tests. Exercise 1/4/8 tokens with Q4_K, Q5_1, Q6_K, and IQ4_XS. Deliberately do not assert that known-unsafe larger-batch or F16 duplicate-ID cases work.
* **Windows logging:** use MSVC `_lock_file`/`_unlock_file`, following [Xiang Chang's report](https://github.com/ggml-org/llama.cpp/pull/27861#issuecomment-5543984918). Guard the POSIX calls for other Windows compilers.
* **Cache replacement staging:** apply [mtrx93's patch](https://github.com/ggml-org/llama.cpp/pull/27861#issuecomment-5616462231). Upload into spare slots, publish the replacement only when complete, then retire its victim. This bounds outstanding work and avoids emptying live cache capacity during slow uploads. Two staging slots are reserved by default; `LLAMA_MOE_CACHE_SPARE` controls this.
* **Draft isolation:** set draft cache slots to zero following [TacoTakumi's MTP finding](https://github.com/ggml-org/llama.cpp/pull/27861#issuecomment-5785685095). This fork retains the original singleton initialization model, so it does not import the later patch's rebind implementation.
* **Integration safeguards:** zero-slot contexts must not permanently disable later cache initialization. Only cache-enabled target contexts publish updates, after explicit backend synchronization. Handle the one-slot staging arithmetic without a negative live budget; the supplied launcher requires at least two slots.
* **Observability:** report cache hit-rate summaries at INFO level, following the replication branch.

The original PR authors retain their Git author records. Adapted fixes cite their source authors and links; the staging/draft fix commit carries human `Co-authored-by:` trailers. The README commit credits the assisting agent/model with `Co-authored-by: Codex (GPT-6) <noreply@openai.com>`.

## Local CUDA build

Target machine: Windows x64, RTX 5080 16 GB, Threadripper 2990WX with 16 logical processors exposed, 128 GiB RAM. Toolchain: CUDA 13.3.73, Visual Studio 2026 MSVC 19.51, CMake 4.4.3, Ninja.

```powershell
.\scripts\build-hot-experts-cuda.cmd
```

The Release build targets `120a` and native CPU AVX2, with CUDA as its only GPU backend. The CPU backend is required for host-resident experts and other CPU work. Vulkan, SYCL, RPC and NCCL are disabled. This is a local hardware-specific build, not a portable GPU binary bundle.

Executables are in `build-cuda\bin`: `llama-server.exe`, `llama-cli.exe`, and `llama-bench.exe`. Keep their DLLs beside them. CUDA runtime DLLs are supplied by the installed toolkit. Backend and argument-parser test executables are also built.

OpenSSL development files were not installed, so this build has no HTTPS support. Local HTTP serving and local model files do not require it. Reconfigure with OpenSSL or an upstream-supported bundled TLS option if HTTPS model downloads/MCP connections are needed.

## Local launcher

The primary launcher requested for this machine is next to the existing model scripts:

```text
C:\models\qwen38_flashnext\start _qwen38flash_q4xs_16core_code_tools_hotexperts.bat
```

It is based on `start _qwen38flash_q4xs_16core_code_tools.bat`; that original remains unchanged. The new file points to this checkout's `build-cuda\bin\llama-server.exe`, uses the same three IQ4_XS shards, and explicitly sets `--spec-type none`. No draft model is loaded. It preserves the original alias, tools, sampling, reasoning options, 13/15 threads, 100,000-token context, unified q8_0 KV, mmap and lazy PLE mode.

Hot-expert settings are **32 slots per layer, 2 inserts per step**, with expert tensors assigned to `CUDA_Host`. Auto-fit is off. The original **batch size 8138 and microbatch size 4096 are preserved**, as requested. The default port is 8080; an optional first argument selects a different port for testing. The original script had its Web UI config-file flag commented out, so the new script also leaves it unset. The user will test this final 100K/32-slot/4096-microbatch configuration; its VRAM fit and performance have not been validated here.

The smaller PowerShell launcher is also available for conservative checks:

```powershell
# No MTP by default, 16 cache slots and 8K context:
.\scripts\start-hot-experts.ps1

# Explicit tuning example (check VRAM use before increasing):
.\scripts\start-hot-experts.ps1 -CacheSlots 16 -Context 8192 -Port 8080
```

The PowerShell defaults use 16 cache slots, 8K context, q8_0 KV, one server slot, and localhost binding. Its optional `-Mtp` switch was used only to validate the integrated MTP PR; MTP is not the user's preferred runtime configuration. Experts are explicitly assigned to `CUDA_Host` and the PLE table to CPU. Auto-fitting is disabled so it cannot silently consume the cache's VRAM allowance. These are starting settings, not a performance optimum or the original 2x3090 configuration.

The expert cache's memory is not included in upstream auto-fit accounting. Leave room for cache, MTP, KV and compute buffers; WDDM paging can severely reduce performance. More cache slots or uploads are not automatically faster. MTP and cache can change floating-point execution order and generated text; throughput needs representative workload testing.

The cache remains an experimental process singleton. Use one target model per process and restart the process when changing models; model unloading/reloading and concurrent independent model contexts have not been validated. No model weights or build outputs are committed.

## Validation

* Release CUDA build succeeded; `--list-devices` identifies the RTX 5080 as CUDA0.
* All **953/953 CUDA MUL_MAT_ID cases** passed against the CPU reference, including all **24/24 added duplicate-ID cases**. The duplicate-ID subset was also run separately.
* `test-arg-parser` passed, including its HTTP download checks.
* The 8K/16-slot cache+MTP integration smoke loaded all 48 cache layers (1884.7 MiB), used 56762.5 MiB of CUDA_Host expert weights, and reached server readiness in about 98 seconds. A coding prompt produced 157 output tokens; 119 of 120 draft tokens were accepted.
* A second chat-API request processed a fresh 1557-token prompt across multiple prefill batches and correctly answered `42`. This exercises the larger-batch fallback after cache-enabled generation.
* These are local smoke/correctness checks, not a perplexity evaluation, a long-context quality study, or a cache-on/off throughput comparison. MTP support was validated but is disabled in the requested everyday .bat launcher.

Logs and JSON responses are kept locally under ignored `build-local\`. The additional everyday-.bat runtime check was stopped at the user's request, and batch/microbatch were restored to 8138/4096. The user will perform further runtime testing. No temporary test server is intentionally left running.
