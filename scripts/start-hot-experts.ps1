param(
    [string]$Model = 'C:\models\qwen38_flashnext\Qwen3.8-Flash-Next-UD-IQ4_XS-00001-of-00003.gguf',
    [string]$DraftModel = 'C:\models\qwen38_flashnext\mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf',
    [int]$CacheSlots = 16,
    [int]$Context = 8192,
    [int]$Port = 8080,
    [switch]$Mtp
)
$ErrorActionPreference = 'Stop'
$server = Join-Path $PSScriptRoot '..\build-cuda\bin\llama-server.exe'
if (!(Test-Path -LiteralPath $server)) { throw 'Build first with scripts\build-hot-experts-cuda.cmd' }
if (!(Test-Path -LiteralPath $Model)) { throw "Model not found: $Model" }
if ($CacheSlots -lt 2) { throw 'Use at least two cache slots (one live and one staging slot).' }
$serverArgs = @(
    '-m', $Model, '--host', '127.0.0.1', '--port', "$Port",
    '-ngl', '99', '--fit', 'off', '-c', "$Context", '--parallel', '1',
    '-fa', 'on', '-ctk', 'q8_0', '-ctv', 'q8_0', '-b', '512', '-ub', '128',
    '-t', '13', '-tb', '15', '--load-mode', 'mmap', '-lzm', 'off',
    '-ot', 'ffn_(gate|up|down)_exps\.weight=CUDA_Host,per_layer_token_embd\.weight=CPU',
    '--moe-expert-cache', "$CacheSlots", '--moe-expert-cache-inserts', '2',
    '--jinja', '-lv', '4'
)
if ($Mtp) {
    if (!(Test-Path -LiteralPath $DraftModel)) { throw "Draft model not found: $DraftModel" }
    $serverArgs += @('-md', $DraftModel, '--spec-type', 'draft-mtp', '-devd', 'CUDA0', '--spec-draft-n-max', '3')
}
& $server @serverArgs
exit $LASTEXITCODE
