# Slot AI Studio: open the default workflow instead of ComfyUI's built-in sample graph, serve the
# Slot Studio page (js/studio), and give the page a "move to trash" route for its gallery and a
# "stitch" route that joins storyboard shots into one video.
import asyncio
import os
import shutil
from fractions import Fraction

import av
import numpy as np
from aiohttp import web

import folder_paths
from server import PromptServer

NODE_CLASS_MAPPINGS = {}
WEB_DIRECTORY = "./js"
__all__ = ["NODE_CLASS_MAPPINGS", "WEB_DIRECTORY"]


@PromptServer.instance.routes.post("/slot_studio/trash")
async def trash(request):
    """Move gallery files to output/_trash/<subfolder>/ (recoverable, never deletes)."""
    body = await request.json()
    out_dir = os.path.realpath(folder_paths.get_output_directory())
    trash_dir = os.path.join(out_dir, "_trash")
    moved, skipped = [], []
    for f in body.get("files", []):
        sub = (f.get("subfolder") or "").replace("\\", "/")
        src = os.path.realpath(os.path.join(out_dir, sub, f.get("filename", "")))
        if f.get("type", "output") != "output" or not src.startswith(out_dir + os.sep) or not os.path.isfile(src):
            skipped.append(f.get("filename"))
            continue
        dst_dir = os.path.join(trash_dir, sub)
        os.makedirs(dst_dir, exist_ok=True)
        shutil.move(src, os.path.join(dst_dir, os.path.basename(src)))
        moved.append(f.get("filename"))
    return web.json_response({"moved": moved, "skipped": skipped})


def _stitch(paths_skip, out_path):
    """Join clips end to end (same size + fps). skip=True drops a clip's first frame (and its sound) because
    the clip before it already ended on that exact picture. Clips without sound get silence."""
    clips = []
    for path, skip in paths_skip:
        with av.open(path) as c:
            vs = c.streams.video[0]
            fps = vs.average_rate or Fraction(24)
            frames = [f.to_ndarray(format="rgb24") for f in c.decode(vs)]
        sound = None
        with av.open(path) as c:
            if c.streams.audio:
                rs = av.AudioResampler(format="fltp", layout="stereo", rate=32000)
                parts = []
                for f in c.decode(c.streams.audio[0]):
                    parts += [r.to_ndarray() for r in rs.resample(f)]
                parts += [r.to_ndarray() for r in rs.resample(None)]
                if parts:
                    sound = np.concatenate(parts, axis=1)
        if skip and len(frames) > 1:
            frames = frames[1:]
            if sound is not None:
                sound = sound[:, int(round(32000 / float(fps))):]
        clips.append((frames, sound, fps))
    if not clips or not clips[0][0]:
        raise ValueError("no frames")
    fps = clips[0][2]
    h, w = clips[0][0][0].shape[:2]
    any_sound = any(s is not None for _, s, _ in clips)

    with av.open(out_path, "w") as out:
        vs = out.add_stream("libx264", rate=fps)
        vs.width, vs.height, vs.pix_fmt = w, h, "yuv420p"
        vs.options = {"crf": "17", "preset": "medium"}
        as_ = out.add_stream("aac", rate=32000, layout="stereo") if any_sound else None
        n = 0
        audio = []
        for frames, sound, _ in clips:
            for a in frames:
                if a.shape[:2] != (h, w):
                    raise ValueError("all shots must have the same size (same shape + quality)")
                vf = av.VideoFrame.from_ndarray(a, format="rgb24")
                vf.pts = n
                n += 1
                for p in vs.encode(vf):
                    out.mux(p)
            if as_ is not None:
                want = int(round(len(frames) * 32000 / float(fps)))
                s = sound if sound is not None else np.zeros((2, 0), np.float32)
                s = s[:, :want] if s.shape[1] >= want else np.pad(s, ((0, 0), (0, want - s.shape[1])))
                audio.append(s.astype(np.float32))
        for p in vs.encode():
            out.mux(p)
        if as_ is not None:
            pcm = np.ascontiguousarray(np.concatenate(audio, axis=1))
            for i in range(0, pcm.shape[1], 1024):
                af = av.AudioFrame.from_ndarray(np.ascontiguousarray(pcm[:, i:i + 1024]), format="fltp", layout="stereo")
                af.sample_rate, af.pts = 32000, i
                for p in as_.encode(af):
                    out.mux(p)
            for p in as_.encode():
                out.mux(p)


@PromptServer.instance.routes.post("/slot_studio/stitch")
async def stitch(request):
    """Join storyboard shot clips (output files) into output/video/STUDIO/storyboard_NNNNN.mp4."""
    body = await request.json()
    out_dir = os.path.realpath(folder_paths.get_output_directory())
    items = []
    for f in body.get("clips", []):
        sub = (f.get("subfolder") or "").replace("\\", "/")
        src = os.path.realpath(os.path.join(out_dir, sub, f.get("filename", "")))
        if f.get("type", "output") != "output" or not src.startswith(out_dir + os.sep) or not os.path.isfile(src):
            return web.json_response({"error": "clip not found: %s" % f.get("filename")}, status=400)
        items.append((src, bool(f.get("skip_first"))))
    sub = "video/STUDIO"
    dst_dir = os.path.join(out_dir, sub)
    os.makedirs(dst_dir, exist_ok=True)
    i = 1
    while os.path.exists(os.path.join(dst_dir, "storyboard_%05d.mp4" % i)):
        i += 1
    name = "storyboard_%05d.mp4" % i
    try:
        await asyncio.get_running_loop().run_in_executor(None, _stitch, items, os.path.join(dst_dir, name))
    except Exception as e:
        return web.json_response({"error": "stitch failed: %s" % e}, status=500)
    return web.json_response({"filename": name, "subfolder": sub, "type": "output"})
