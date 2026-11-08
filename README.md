# Slot Studio – ComfyUI kit (Image + Video all-in-one)

One installer that sets up the same ComfyUI as the original PC: **ComfyUI portable v0.42.1**, the two
all-in-one workflows, the Freepik-style **Slot Studio** page and every model those workflows use.

| Workflow | What it does |
| --- | --- |
| `16_IMAGE_All_In_One` | Text-to-image and picture edit with **Qwen-Image 2.1** (turbo + full), **Z-Image Turbo**, **FLUX.2 Klein 4B**, **Qwen-Image-Edit 2511**, **SDXL**; paint-mask precise edit, 3D camera angles, style LoRAs |
| `17_VIDEO_All_In_One` | **MiniMax H3** video: animate a picture (start/end frame, loop), text-to-video, copy motion / swap character (SDPose + ControlNet), new background, new camera angle, sound on/off |

Only core ComfyUI nodes are used, plus the small `slot_studio_autoload` extension (Slot Studio page, gallery
trash route, storyboard stitching).

## Install

**Needs:** Windows 10/11 · NVIDIA GPU with **12 GB+ VRAM** and a recent driver · **32 GB RAM** · free disk:
~100 GB for image only, ~120 GB for video only, **~170 GB for both**.

Open **PowerShell** and paste:

```powershell
irm https://raw.githubusercontent.com/kumikilongyeyo/comfyui-slot-studio-kit/main/install.ps1 | iex
```

That installs everything into `C:\AI\ComfyUI_windows_portable` and adds three Desktop shortcuts:
**Slot Studio**, **Start ComfyUI**, **Stop ComfyUI**.

Options (other folder, only one workflow, extra prompt-enhancer model):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/kumikilongyeyo/comfyui-slot-studio-kit/main/install.ps1))) -InstallDir D:\AI -Only image -Enhance
```

| Option | Meaning |
| --- | --- |
| `-InstallDir D:\AI` | Install somewhere else (default `C:\AI`). Pointing it at a folder that already has `ComfyUI_windows_portable` reuses that ComfyUI. |
| `-Only image` / `-Only video` | Download only the models for one workflow (default: both). |
| `-Enhance` | Also get Qwen3.5 4B (9.3 GB) for the Slot Studio "AI prompt" / Enhance button. |
| `-NoModels` | Set up ComfyUI + workflows now, models later. |

Or download this repo as a ZIP (green **Code** button → Download ZIP), unzip, and double-click **`install.bat`**.

The downloads are big (the video model alone is 21 GB). If it stops, just run the same command again:
finished files are skipped and half-done files resume.

## Use

* **Slot Studio** (Desktop) – simple page with **Image** and **Video** tabs. Pick model, write a prompt, Generate.
  Results land in `ComfyUI\output\STUDIO` and `ComfyUI\output\video\STUDIO`.
  * Type **@** in a prompt to tag a reference (`@Picture1`, `@Picture2`; video: `@Start`, `@End`, `@Image`, `@Video`).
    The page swaps each tag for the name the chosen model uses for that picture (`Picture 2` for Qwen Edit,
    `<image2>` for Qwen-Image 2.1, `image 2` for Klein, `<Picture 1>` / `<Video 1>` for MiniMax H3).
  * Generate stays usable while a job runs: extra jobs wait in ComfyUI's queue (one GPU = one at a time).
    Switching between Image and Video keeps your running jobs; they show up when you come back.
  * 🗑 Delete (pictures and videos) moves the files to `ComfyUI\output\_trash`, so they can still be recovered.
* **Start ComfyUI** – the node editor. Open the **Workflows** sidebar → `16_IMAGE_All_In_One` or
  `17_VIDEO_All_In_One`; switch MODEL / TASK / MODE in the panel at the top and press Run.
* **Stop ComfyUI** – closes it and frees the GPU.

First start: Windows Smart App Control may block a new file once; the launcher retries by itself.

Rough speed on an RTX 4070 SUPER (12 GB): image 7–27 s, 3 s video clip ~70 s.

## Models downloaded

Listed with URL, size and licence in [`models.json`](models.json). All come straight from Hugging Face; nothing
is re-hosted here.

**Licences – read before commercial use:**
* **Qwen-Image 2.1** – Qwen Research licence, **non-commercial**.
* **MiniMax H3** (all video models) – open weights; companies over USD 20M revenue need MiniMax's written OK and
  outputs must credit "MiniMax H3".
* SDXL – CreativeML OpenRAIL++-M. Z-Image, FLUX.2 Klein 4B, Qwen-Image-Edit 2511, the LoRAs – Apache 2.0.
  BiRefNet – MIT.

## What's in this repo

```
install.ps1 / install.bat        installer
models.json                      every model: folder, URL, size, licence, which workflow needs it
workflows/                       16_IMAGE_All_In_One.json, 17_VIDEO_All_In_One.json
custom_nodes/slot_studio_autoload  Slot Studio page (Image + Video) + autoload of workflow 16
input/                           placeholder picture + example motion clip the workflows expect
launchers/                       Start / Stop ComfyUI, Slot Studio
```
