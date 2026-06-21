Exercise images go here.

Each file must be named with the exercise "slug" and end in .png, for example:
  glute-bridge.png
  cat-camel.png
  diaphragmatic-belly-breathing.png

The website turns each exercise name into this slug automatically and looks for the
matching .png in this folder. If the file isn't here yet, a tidy placeholder is shown
instead, so the site always looks complete.

You don't create these names by hand. Generate the pictures in ComfyUI and run
  ..\comfyui\import-images.ps1
which copies them in with the correct names.

The full list of slugs and the prompt for each exercise is in:
  ..\comfyui\EXERCISE-PROMPTS.md   (human-readable)
  ..\comfyui\exercise-prompts.json (for tools/scripts)

See ..\comfyui\COMFYUI-GUIDE.md for the complete step-by-step guide.
