#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ask_gemini.sh [options] "<task text>"

The first non-flag argument is the task text (or use -t / --task, or pipe from stdin).

Options:
  -t, --task <text>            Request text (alternative to positional arg)
      --html                   Output as self-contained HTML (shorthand for --output-type html)
      --svg                    Output as SVG (shorthand for --output-type svg)
      --output-type <type>     Expected output: text (default), html, svg
  -o, --output <path>          Output file path (default: auto-generated)
                               Auto-infers output type from extension (.html, .svg)
  -h, --help                   Show this help

Output (on success):
  output_path=<file>           Path to response file

Examples:
  ask_gemini.sh "Design a landing page for a coffee shop" --html
  ask_gemini.sh "Create an SVG icon for a settings gear" --svg
  ask_gemini.sh "Give me 3 color palette suggestions for a tech blog"
  ask_gemini.sh "Design a pricing card" -o ./designs/card.html
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] Missing required command: $1" >&2
    exit 1
  fi
}

# --- Parse arguments ---

task_text=""
output_path=""
output_type="text"
output_type_explicit=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--task)        task_text="${2:-}"; shift 2 ;;
    -o|--output)      output_path="${2:-}"; shift 2 ;;
    --output-type)    output_type="${2:-}"; output_type_explicit=true; shift 2 ;;
    --html)           output_type="html"; output_type_explicit=true; shift ;;
    --svg)            output_type="svg"; output_type_explicit=true; shift ;;
    -h|--help)        usage; exit 0 ;;
    *)
      if [[ -z "$task_text" ]]; then
        task_text="$1"; shift
      else
        echo "[ERROR] Unknown argument: $1" >&2; usage >&2; exit 1
      fi
      ;;
  esac
done

# Auto-infer output type from output path extension
if [[ "$output_type_explicit" == false && -n "$output_path" ]]; then
  case "$output_path" in
    *.html) output_type="html" ;;
    *.svg)  output_type="svg" ;;
  esac
fi

require_cmd curl
require_cmd jq

# --- Resolve API key ---

api_key=""

# 1. Environment variable
if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  api_key="$GEMINI_API_KEY"
fi

# 2. Project .env.local (if running inside a project)
if [[ -z "$api_key" ]]; then
  for candidate in ".env.local" "../.env.local" "../../.env.local"; do
    if [[ -f "$candidate" ]]; then
      found="$(grep -E '^GEMINI_API_KEY=' "$candidate" 2>/dev/null | head -1 | cut -d= -f2-)"
      found="${found//\'/}"
      found="${found//\"/}"
      if [[ -n "$found" ]]; then
        api_key="$found"
        break
      fi
    fi
  done
fi

# 3. Global config
if [[ -z "$api_key" && -f "$HOME/.config/gemini-designer/api_key" ]]; then
  api_key="$(cat "$HOME/.config/gemini-designer/api_key" | tr -d '[:space:]')"
fi

if [[ -z "$api_key" ]]; then
  echo "[ERROR] No Gemini API key found." >&2
  echo "Set GEMINI_API_KEY env var, or add it to .env.local, or save to ~/.config/gemini-designer/api_key" >&2
  exit 1
fi

base_url="${GEMINI_BASE_URL:-https://api.aicodemirror.com/api/gemini/v1}"
base_url="${base_url%/}"

# --- Resolve task text ---

if [[ -z "$task_text" && ! -t 0 ]]; then
  task_text="$(cat)"
fi

if [[ -z "$task_text" ]]; then
  echo "[ERROR] No task provided. Pass as first argument, use --task, or pipe from stdin." >&2
  exit 1
fi

# --- Build system prompt based on output type ---

case "$output_type" in
  html)
    system_prompt="You are a talented UI/web designer with strong aesthetic taste and creative vision.

Requirements:
- Use realistic placeholder content, not lorem ipsum.
- Add <!-- FEATURE: description --> comments before each functional section explaining what it does.
- Wire up JS interactions so the prototype feels alive and usable.

Everything else — visual style, layout, colors, typography, states, animations, micro-interactions — is up to you. Be creative and opinionated. Don't default to generic styles.

Output a single self-contained HTML file (CSS in <style>, JS in <script>). No external dependencies. Output ONLY the HTML code, no explanation."
    file_ext="html"
    ;;
  svg)
    system_prompt="You are a talented icon and illustration designer. Create a clean, expressive SVG. Style, color, and artistic approach are entirely up to you — be creative. The SVG must have a proper viewBox and be well-structured. Output ONLY the SVG code, no explanation."
    file_ext="svg"
    ;;
  *)
    system_prompt="You are a talented designer and creative director. Give concrete, actionable design advice with specific values (hex colors, fonts, spacing) so it's directly usable. Don't hold back your creative opinion — suggest bold ideas and distinctive visual directions. Respond in the same language as the user's request."
    file_ext="md"
    ;;
esac

# --- Prepare output path ---

if [[ -z "$output_path" ]]; then
  timestamp="$(date -u +"%Y%m%d-%H%M%S")"
  output_dir="${PWD}/.runtime/gemini-designer"
  mkdir -p "$output_dir"
  output_path="${output_dir}/${timestamp}.${file_ext}"
fi
mkdir -p "$(dirname "$output_path")"

# --- Build request JSON ---

prompt_file="$(mktemp)"
request_file="$(mktemp)"
trap 'rm -f "$prompt_file" "$request_file"' EXIT

printf "%s" "$task_text" > "$prompt_file"

jq -n \
  --arg model "gemini-2.5-flash-preview" \
  --arg system "$system_prompt" \
  --rawfile user "$prompt_file" \
  '{
    model: $model,
    temperature: 0.7,
    max_tokens: 16384,
    messages: [
      { role: "system", content: $system },
      { role: "user", content: $user }
    ]
  }' > "$request_file"

# --- Call Gemini API ---

response_file="$(mktemp)"
trap 'rm -f "$prompt_file" "$request_file" "$response_file"' EXIT

http_code="$(curl -s -w "%{http_code}" -o "$response_file" \
  -X POST "${base_url}/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${api_key}" \
  --max-time 180 \
  -d @"$request_file")"

if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
  echo "[ERROR] Gemini API returned HTTP ${http_code}" >&2
  cat "$response_file" >&2
  exit 1
fi

# --- Extract content ---

content="$(jq -r '.choices[0].message.content // empty' < "$response_file")"

if [[ -z "$content" ]]; then
  echo "[ERROR] Empty response from Gemini" >&2
  jq . < "$response_file" >&2
  exit 1
fi

# For html/svg, strip markdown fences if present
if [[ "$output_type" == "html" || "$output_type" == "svg" ]]; then
  # Remove ```html ... ``` or ```svg ... ``` wrappers
  content="$(echo "$content" | sed -E '/^```(html|svg|xml)?[[:space:]]*$/d')"
fi

printf "%s\n" "$content" > "$output_path"
echo "output_path=$output_path"
