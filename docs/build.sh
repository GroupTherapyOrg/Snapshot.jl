#!/usr/bin/env bash
# Build the static Snapshot.jl docs site:
#   1. Therapy SSG → dist/*.html (tailwind=false; Layout links assets/styles.css)
#   2. npm Tailwind v4 + DaisyUI → assets/styles.css (Therapy's CLI can't load
#      @plugin "daisyui", so we own the CSS step). assets/ is copied into dist/ by
#      Therapy's staticfiles, so the stylesheet ships at <base>/assets/styles.css.
# Run from the docs/ dir:  bash build.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "▶ Tailwind v4 + DaisyUI → assets/styles.css"
npx @tailwindcss/cli -i input.css -o assets/styles.css --minify

echo "▶ Therapy.build → dist/*.html (+ copies assets/ → dist/assets/)"
julia --project=. app.jl build

echo "✓ dist/ ready ($(find dist -type f | wc -l | tr -d ' ') files)"
