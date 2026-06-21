# Generating the exercise images with ComfyUI

A start-to-finish guide for adding a picture to every exercise on the Reformwell site.
Written for a normal Windows PC (≈6 GB RAM) and assuming you've never used ComfyUI before.
Everything here is **free**.

The site already works **without** images — each exercise shows a tidy placeholder until
you drop a real picture in. So you can do this gradually, a few exercises at a time.

---

## How the pieces fit together

```
ComfyUI  ─►  generates a PNG  ─►  import-images.ps1  ─►  pt-studio/assets/exercises/<slug>.png  ─►  shows on the site
```

- **`EXERCISE-PROMPTS.md`** — the 257 ready-to-paste prompts, one per exercise, all in the same style.
- **`exercise-prompts.json`** — the same data for tools/scripts (slug, filename, prompt, negative).
- **`import-images.ps1`** — copies your generated images into the website with the correct names.

The website finds an image by turning the exercise name into a **slug**
(e.g. *"Glute Bridge"* → `glute-bridge`). The file must be named `glute-bridge.png`.
You don't have to rename anything by hand — the import script does it for you.

---

## Step 1 — Install ComfyUI (one time)

1. Go to the ComfyUI releases page: <https://github.com/comfyanonymous/ComfyUI/releases>
2. Download **`ComfyUI_windows_portable_nvidia.7z`** (the "portable" build — no Python install needed).
   - **No NVIDIA graphics card?** It still runs on your CPU; it's just slower. When you start it,
     use **`run_cpu.bat`** instead of `run_nvidia_gpu.bat`.
   - ⚠️ **Get the `_nvidia` file, NOT the `_amd` one** — even if you don't have an NVIDIA card. The AMD
     build ships a buggy GPU-detection helper (`offload-arch.exe` / `amdgpu-arch.exe`) that throws a
     "Fatal error in launcher … D:\a\ComfyUI\…" message. The `_nvidia` build runs on CPU fine and has
     no such file. (Only use the `_amd` build if you own a **dedicated/discrete** AMD Radeon graphics
     card — **built-in / integrated** AMD Radeon graphics are not supported; on those, use the `_nvidia`
     build with `run_cpu.bat`.)
3. Extract the `.7z` with [7-Zip](https://www.7-zip.org/) (free) to a **plain local folder like
   `C:\ComfyUI`**.
   - ⚠️ **Do NOT extract it inside OneDrive** (e.g. anywhere under `…\OneDrive\…`) and **avoid spaces**
     in the folder name. OneDrive keeps trying to sync the multi-gigabyte files (slow, and it can lock
     them while ComfyUI is using them), and some scripts trip over spaces in the path.

## Step 2 — Add a free model (one time)

ComfyUI needs a "checkpoint" (the AI model). The prompts target a **photorealistic** look, so pick a
**photorealistic** model (a stylized model will look cartoonish):

- **Realistic Vision** (SD 1.5, good on a weak PC at 512x512) — <https://civitai.com/models/4201>
- **RealVisXL** or **Juggernaut XL** (SDXL, sharper, best on cloud/strong GPU at 1024x1024)

> On Comfy Cloud, just choose one of these (or any "realistic"/"photo" checkpoint) in the
> Load Checkpoint node's `ckpt_name` dropdown.

Download the `.safetensors` file and put it in:
`ComfyUI\models\checkpoints\`

> Civitai asks you to make a free account to download. Pick the regular (pruned) version,
> usually ~2 GB — not the larger "inpainting" one.

## Step 3 — Start ComfyUI

Double-click **`run_cpu.bat`** (or `run_nvidia_gpu.bat` if you have an NVIDIA card) inside the
portable folder. A browser tab opens at <http://127.0.0.1:8188>. You'll see a default workflow
already on screen — that's all you need.

## Step 4 — Set it up for our images (once per session)

On the default workflow:

1. **Load Checkpoint** node → pick the model you downloaded.
2. **Empty Latent Image** node → set **width 512**, **height 512**, batch_size 1.
3. **KSampler** node → **steps 22**, **cfg 6.5**, **sampler_name dpmpp_2m**, **scheduler karras**.
4. The two **CLIP Text Encode** boxes are your **positive** (top) and **negative** (bottom) prompts.
   Paste the shared **negative prompt** (from the top of `EXERCISE-PROMPTS.md`) into the negative box
   once — you'll leave it the same for every image.

## Step 5 — Generate an image

For each exercise you want a picture for:

1. Open **`EXERCISE-PROMPTS.md`**, find the exercise, and copy its **Positive prompt**.
2. Paste it into the **positive** box (replace the previous one).
3. In the **Save Image** node, set **`filename_prefix`** to the exercise **slug** — that's the
   filename shown under "Save as" *without* the `.png`. Example: for `assets/exercises/glute-bridge.png`,
   type **`glute-bridge`**.
4. Click **Queue Prompt**. In a few seconds (or a minute on CPU) the image appears and is saved to
   `ComfyUI\output\`.
5. Don't love it? Just press **Queue Prompt** again for a fresh take (it uses a new random seed).

> **Doing many at once:** generate a whole batch, setting the right `filename_prefix` each time, then
> run the import script once at the end. You don't need to import after every single image.

## Step 6 — Pull the images into the website

From this `comfyui` folder, run:

```powershell
powershell -ExecutionPolicy Bypass -File import-images.ps1
```

It finds your ComfyUI `output` folder automatically, copies each image to
`..\assets\exercises\<slug>.png`, skips anything whose name doesn't match a real exercise,
and prints how many of the 257 exercises now have a picture.

If it can't find your output folder, point it there:

```powershell
powershell -ExecutionPolicy Bypass -File import-images.ps1 -ComfyOutput "C:\ComfyUI\output"
```

## Step 7 — See them on the site

Start the local server (from the `pt-studio` folder) and open a program page:

```powershell
powershell -ExecutionPolicy Bypass -File serve.ps1 -Port 8787
```

Open <http://localhost:8787> → click any program. Exercises with an image now show it;
the rest still show the placeholder.

## Step 8 — Put images into the PDFs (optional)

The downloadable PDFs use the same images. After importing, regenerate them:

```powershell
powershell -ExecutionPolicy Bypass -File make-pdfs.ps1
```

---

## Tips & troubleshooting

- **"Fatal error in launcher: Unable to create process … D:\a\ComfyUI\… offload-arch.exe / amdgpu-arch.exe"?** You downloaded the **AMD** build. It's only a *warning* — first check the console for `To see the GUI go to: http://127.0.0.1:8188` and try opening that address; it often still works. If not, download the **`_nvidia`** build instead (it has no such file) and launch with `run_cpu.bat`, and extract it to `C:\ComfyUI` (not inside OneDrive). Only keep the AMD build if you own a **dedicated/discrete** Radeon GPU — **built-in/integrated** Radeon graphics aren't supported, so use the `_nvidia` build + `run_cpu.bat` on those.
- **Where do I get the slug?** It's in `EXERCISE-PROMPTS.md` under each exercise ("Save as: `assets/exercises/<slug>.png`"). The slug is the part between `exercises/` and `.png`.
- **Hands or faces look off?** SD 1.5 struggles with these. Re-queue for another try, or lower how
  much of the body is shown isn't necessary — the prompts already favour clear, simple full-body poses.
- **Too slow on CPU?** Drop **steps to 16–18**. Quality barely changes for these clean illustrations.
- **Image didn't show up on the site?** Check the file is named exactly `<slug>.png` (all lowercase,
  dashes, no spaces) in `pt-studio\assets\exercises\`. Re-run `import-images.ps1` — it reports any
  files whose name didn't match.
- **You don't have to do all 257.** Start with the exercises in the **short "Relief & Reset"** programs
  (they're listed first for each condition) — that already covers the pages most buyers see first.
- **Consistency:** keep the **same model** and the **same negative prompt** for every image so the
  whole set looks like one cohesive product.
