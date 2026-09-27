# CUDA hot experts and adaptive KV streaming

This fork combines a GPU cache for host-resident MoE experts with adaptive KV streaming for Qwen4Exp / Qwen3.8-Flash-Next. Hot experts execute on the GPU; uncached experts remain on the CPU. Attention keeps its authoritative KV in pinned RAM, reads resident rows from VRAM, and fetches nonresident rows from RAM.

One fixed CUDA arena is shared between prefill compute workspace and decode KV residency. This reduces their combined GPU footprint without shortening the context or compressing KV. The indexer and recurrent state remain on the GPU.

## Results

The [combined benchmark report](fork-test/index.html) and [sanitized JSON](fork-test/data.json) cover all 24 variants: CPU baseline, microbatch, expert slots, insertion/staging limits, MTP, and fiction-scifi generation. The report includes throughput curves, memory peaks, failures, and checkpoint attribution; open it with its accompanying stylesheet.

The best measured sustained configuration uses **54 expert slots, 1 insertion, and 1 staging slot**. With resident KV, average decode increased from **13.57 to 14.52 tokens/s**, with **15,776 MiB** peak total GPU usage on an RTX 5080 with IQ4_XS model weights. These are single-run observations with differing generated sequences. Context capacity was 262144 Q8 tokens; actual history reached about 20.8K tokens, so this is not a full-context throughput result.

## Best measured startup configuration

Build this fork with CUDA using the [build instructions](docs/build.md). Use commit `ff0f7c03c` or later for resident sparse KV. In Windows Command Prompt, set `MODEL_GGUF` to the model's GGUF file and make `llama-server` available on `PATH`. The example reproduces the measured resource configuration; sampling and chat options can be configured separately.

```bat
set "GGML_CUDA_ENABLE_UNIFIED_MEMORY="
set "LLAMA_MOE_CACHE_SPARE=1"

llama-server --model "%MODEL_GGUF%" ^
  --host 127.0.0.1 --port 8080 ^
  --parallel 1 --no-warmup --ctx-checkpoints 32 ^
  --threads 13 --threads-batch 15 ^
  --ctx-size 262144 --batch-size 8138 --ubatch-size 1024 ^
  --n-gpu-layers 999 --fit off --flash-attn on ^
  --kv-unified --cache-type-k q8_0 --cache-type-v q8_0 ^
  --load-mode mmap --lazy-mode on ^
  --override-tensor "ffn_(gate|up|down)_exps\.weight=CUDA_Host,per_layer_token_embd\.weight=CPU" ^
  --moe-expert-cache 54 --moe-expert-cache-inserts 1 ^
  --kv-stream-arena-mib 4000 --spec-type none
```

### Fork-specific options and behavior

- `--moe-expert-cache 54`: allocate 54 expert-cache slots per eligible layer. Slots include staging; with the setting below, 53 experts per layer can remain resident.
- `--moe-expert-cache-inserts 1`: permit at most one expert upload per layer per decode step. More uploads can increase transfer overhead.
- `LLAMA_MOE_CACHE_SPARE=1`: reserve one cache slot per layer for replacement uploads. The old expert remains available until its replacement is ready. Default: two staging slots.
- `--kv-stream-arena-mib 4000`: reserve a 4000 MiB shared compute/KV arena, repartitioned between prefill and decode. Zero disables streaming. This is not a limit on total VRAM usage; weights, expert cache, indexer, and recurrent state are additional allocations.
- `--override-tensor ...=CUDA_Host`: extends the existing tensor-override option with explicit pinned-host placement that survives mmap loading. Here it keeps the expert-weight pool in RAM; the separate `per_layer_token_embd.weight=CPU` rule places the lazy embedding table on the CPU.

The other command-line options above already exist in the upstream base. Resident sparse-KV reuse is automatic when streaming is enabled; it needs no extra switch.

## How this fork got here

Based on upstream llama.cpp at `2145525a4081`. The integration includes [csantiago78's expert cache (#27861)](https://github.com/ggml-org/llama.cpp/pull/27861), [Inovello's pinned-host loading changes (#28223)](https://github.com/ggml-org/llama.cpp/pull/28223), and [Ryan Monsurate and Daniel Han's MTP support (#28243)](https://github.com/ggml-org/llama.cpp/pull/28243).

| Checkpoint | Contribution |
| --- | --- |
| `d7680c67b89f` | [Raymond Huang's adaptive KV branch](https://github.com/RaymondHuang210129/llama.cpp-adaptive-kv-streaming/tree/feature/kv-stream-phase-arena): host-backed KV, resident pages, and shared prefill/decode arena. |
| `00a8a8250` | Qwen4Exp integration: hybrid/indexer memory, sparse host-row gathering, tiled prefill, and arena sizing. |
| `ff0f7c03c` | Sparse attention reuses resident GPU KV, with host fallback, mirrored writes, and cache invalidation. |

Additional integration fixes adapt Inovello's duplicate-ID handling, Xiang Chang's Windows logging fix, mtrx93's staged replacements, and TacoTakumi's draft-cache isolation. Source links and original author records are retained in the relevant commits; assisted integration commits carry attribution.

## Scope and validation

- Hot-expert caching currently handles batches of up to eight tokens; normal prefill uses the ordinary expert path. Adding slots alone does not accelerate large-batch prefill.
- Streaming KV currently requires single-token generation. MTP is available with native KV, but the configuration above disables it. Use one target model per process; the expert cache remains a singleton.
- The arena must fit the selected microbatch's compute workspace plus streaming buffers. Expert-cache memory is not included in automatic fit accounting, so the example disables auto-fit. A larger cache is not always faster.
- Validation includes 953 CUDA expert-operation cases and six KV-streaming suites, with 616 attention assertions covering partial/full residency, changing writes, graph replay, layout changes, and cache replacement. Benchmark results are performance measurements, not a model-quality evaluation.
