# Slot Studio ComfyUI kit installer (Windows + NVIDIA).
# Installs ComfyUI portable v0.42.1, the IMAGE + VIDEO all-in-one workflows, the Slot Studio page and every model they use.
#
# One line (PowerShell):
#   irm https://raw.githubusercontent.com/kumikilongyeyo/comfyui-slot-studio-kit/main/install.ps1 | iex
# With options:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/kumikilongyeyo/comfyui-slot-studio-kit/main/install.ps1))) -Only image -InstallDir D:\AI
#
# Safe to run again: finished downloads are skipped, half-finished ones resume.

param(
    [string]$InstallDir = $(if ($env:SLOTKIT_DIR) { $env:SLOTKIT_DIR } else { "C:\AI" }),
    [ValidateSet("all", "image", "video")]
    [string]$Only = $(if ($env:SLOTKIT_ONLY) { $env:SLOTKIT_ONLY } else { "all" }),
    [switch]$Enhance,     # + Qwen3.5 4B (9.3 GB) for the page's "AI prompt" / Enhance button
    [switch]$NoModels,    # set up ComfyUI + workflows only, download models later
    [switch]$NoShortcuts
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo = "kumikilongyeyo/comfyui-slot-studio-kit"
$ComfyVersion = "v0.42.1"
$ComfyUrl = "https://github.com/Comfy-Org/ComfyUI/releases/download/$ComfyVersion/ComfyUI_windows_portable_nvidia.7z"
$ComfySize = 2018444114

function Say($msg, $color = "Cyan") { Write-Host $msg -ForegroundColor $color }
function GB($bytes) { "{0:N1} GB" -f ($bytes / 1GB) }

function Get-File($url, $dest, [long]$size) {
    if ((Test-Path $dest) -and ($size -le 0 -or (Get-Item $dest).Length -eq $size)) { return $false }
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    $part = "$dest.part"
    for ($try = 1; $try -le 5; $try++) {
        # curl.exe ships with Windows 10/11; -C - resumes a broken download.
        & curl.exe -L --fail --retry 3 --retry-delay 5 -C - -o $part $url
        if ($LASTEXITCODE -eq 0 -and (Test-Path $part) -and ($size -le 0 -or (Get-Item $part).Length -eq $size)) {
            Move-Item -Force $part $dest
            return $true
        }
        if ((Test-Path $part) -and $size -gt 0 -and (Get-Item $part).Length -gt $size) { Remove-Item -Force $part }
        Say "  download interrupted (try $try of 5), retrying..." Yellow
        Start-Sleep 5
    }
    throw "Could not download $url"
}

Say "`n=== Slot Studio ComfyUI kit ===" White
Say "Install folder : $InstallDir"
Say "Workflows      : $Only$(if ($Enhance) { ' + prompt enhancer' })"

# --- 1. checks -------------------------------------------------------------------------------------------
if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) { throw "curl.exe not found (needs Windows 10 1803 or newer)." }
$gpu = $null
try { $gpu = & nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>$null | Select-Object -First 1 } catch {}
if ($gpu) {
    $name, $mem = $gpu -split ",\s*"
    Say "GPU            : $name ($([math]::Round([int]$mem / 1024)) GB)"
    if ([int]$mem -lt 11000) { Say "WARNING: under 12 GB of VRAM. Image models may be slow, video will likely run out of memory." Yellow }
} else {
    Say "WARNING: no NVIDIA GPU found (nvidia-smi missing). This kit needs an NVIDIA card with 12 GB+ and a recent driver." Yellow
}

# --- 2. kit files (from this folder, or downloaded from GitHub when run with irm | iex) ----------------
$Kit = $PSScriptRoot
if (-not $Kit -or -not (Test-Path (Join-Path $Kit "models.json"))) {
    $tmp = Join-Path $env:TEMP "slot-studio-kit"
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    New-Item -ItemType Directory -Force $tmp | Out-Null
    Say "Downloading kit files from github.com/$Repo ..."
    & curl.exe -L --fail -o "$tmp\kit.zip" "https://github.com/$Repo/archive/refs/heads/main.zip"
    if ($LASTEXITCODE -ne 0) { throw "Could not download the kit from GitHub." }
    Expand-Archive -Force "$tmp\kit.zip" $tmp
    $Kit = (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName
}
$models = Get-Content -Raw (Join-Path $Kit "models.json") | ConvertFrom-Json
$groups = switch ($Only) { "image" { @("image", "both") } "video" { @("video", "both") } default { @("image", "video", "both") } }
if ($Enhance) { $groups += "enhance" }
$wanted = @($models | Where-Object { $groups -contains $_.group })

# --- 3. ComfyUI portable -----------------------------------------------------------------------------------
$Portable = Join-Path $InstallDir "ComfyUI_windows_portable"
$Comfy = Join-Path $Portable "ComfyUI"
New-Item -ItemType Directory -Force $InstallDir | Out-Null

$need = 0
foreach ($m in $wanted) {
    $f = Join-Path "$Comfy\models" $m.path
    $have = if (Test-Path $f) { (Get-Item $f).Length } elseif (Test-Path "$f.part") { (Get-Item "$f.part").Length } else { 0 }
    if ($have -ne $m.size) { $need += $m.size - $have }
}
if ($NoModels) { $need = 0 }
if (-not (Test-Path "$Comfy\main.py")) { $need += 9GB }
$drive = Get-PSDrive -Name ($InstallDir.Substring(0, 1))
Say "Disk           : needs about $(GB $need), $(GB $drive.Free) free on $($drive.Name):"
if ($drive.Free -lt $need) { throw "Not enough free space on $($drive.Name): for the models. Free some space or use -InstallDir on another drive." }

if (Test-Path "$Comfy\main.py") {
    Say "`nComfyUI already installed in $Portable, keeping it."
} else {
    Say "`n[1/4] Downloading ComfyUI portable $ComfyVersion (2 GB)..."
    $sevenZipFile = Join-Path $InstallDir "ComfyUI_windows_portable_nvidia_$ComfyVersion.7z"
    Get-File $ComfyUrl $sevenZipFile $ComfySize | Out-Null
    $sz = @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $sz) {
        $sz = Join-Path $InstallDir "7zr.exe"   # official stand-alone 7-Zip extractor
        Get-File "https://www.7-zip.org/a/7zr.exe" $sz 0 | Out-Null
    }
    Say "Extracting (a few minutes)..."
    & $sz x $sevenZipFile "-o$InstallDir" -y | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$Comfy\main.py")) { throw "Extracting ComfyUI failed." }
    Remove-Item -Force $sevenZipFile
    if ($sz -eq (Join-Path $InstallDir "7zr.exe")) { Remove-Item -Force $sz }
}

# --- 4. workflows, Slot Studio page, example inputs, launchers ------------------------------------------
Say "`n[2/4] Installing workflows + Slot Studio page..."
$wfDir = "$Comfy\user\default\workflows"
New-Item -ItemType Directory -Force $wfDir, "$Comfy\input", "$Comfy\custom_nodes" | Out-Null
Copy-Item -Force "$Kit\workflows\*.json" $wfDir
$node = "$Comfy\custom_nodes\slot_studio_autoload"
if (Test-Path $node) { Remove-Item -Recurse -Force $node }
Copy-Item -Recurse -Force "$Kit\custom_nodes\slot_studio_autoload" $node
Copy-Item -Force "$Kit\input\*" "$Comfy\input"
Copy-Item -Force "$Kit\launchers\*.bat" $Portable
Copy-Item -Force "$Kit\README.md" "$Portable\SLOT STUDIO README.md"

# --- 5. models ---------------------------------------------------------------------------------------------
if ($NoModels) {
    Say "`n[3/4] Skipping models (-NoModels). Run the installer again later to get them." Yellow
} else {
    $total = ($wanted | Measure-Object size -Sum).Sum
    Say "`n[3/4] Models: $($wanted.Count) files, $(GB $total) in total. Big ones take a while - you can stop and re-run, it resumes."
    $i = 0
    foreach ($m in $wanted) {
        $i++
        $dest = Join-Path "$Comfy\models" $m.path
        if ((Test-Path $dest) -and (Get-Item $dest).Length -eq $m.size) { Say "  [$i/$($wanted.Count)] have $($m.path)" DarkGray; continue }
        Say "  [$i/$($wanted.Count)] $($m.path) ($(GB $m.size))"
        Get-File $m.url $dest $m.size | Out-Null
    }
}

# --- 6. shortcuts ------------------------------------------------------------------------------------------
if (-not $NoShortcuts) {
    Say "`n[4/4] Desktop shortcuts..."
    $shell = New-Object -ComObject WScript.Shell
    $desk = [Environment]::GetFolderPath("Desktop")
    $icons = @{
        "Start ComfyUI" = "$Portable\python_embeded\python.exe,0"
        "Stop ComfyUI"  = "$env:SystemRoot\System32\shell32.dll,131"
        "Slot Studio"   = "$env:SystemRoot\System32\imageres.dll,72"
    }
    foreach ($name in "Start ComfyUI", "Stop ComfyUI", "Slot Studio") {
        $lnk = $shell.CreateShortcut((Join-Path $desk "$name.lnk"))
        $lnk.TargetPath = Join-Path $Portable "$name.bat"
        $lnk.WorkingDirectory = $Portable
        $lnk.IconLocation = $icons[$name]
        $lnk.Save()
    }
}

Say "`nDone!" Green
Say "  Slot Studio page : double-click 'Slot Studio' on the Desktop (Image + Video tabs)" Green
Say "  Node graphs      : 'Start ComfyUI', then Workflows sidebar -> 16_IMAGE_All_In_One / 17_VIDEO_All_In_One" Green
Say "  First start can fail once if Windows Smart App Control checks new files - the launcher retries by itself." Green
