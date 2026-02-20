#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ask_gemini.sh --task <text> [options]

Required:
  -t, --task <text>            Request text (or pipe from stdin)
      --task-file <path>       Read request from file

Options:
  -o, --output <path>          Output file path (default: auto-generated)
      --output-type <type>     Expected output: text (default), html, svg
  -h, --help                   Show this help

Output (on success):
  output_path=<file>           Path to response file

Examples:
  ask_gemini.sh -t "Design a landing page for a coffee shop" --output-type html
  ask_gemini.sh -t "Create an SVG icon for a settings gear" --output-type svg
  ask_gemini.sh -t "Give me 3 color palette suggestions for a tech blog"
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
task_file=""
output_path=""
output_type="text"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--task)        task_text="${2:-}"; shift 2 ;;
    --task-file)      task_file="${2:-}"; shift 2 ;;
    -o|--output)      output_path="${2:-}"; shift 2 ;;
    --output-type)    output_type="${2:-}"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "[ERROR] Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

require_cmd curl
require_cmd jq

# --- Resolve API key ---

api_key=""

# 1. Environment variable
if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
  api_key="$OPENROUTER_API_KEY"
fi

# 2. Project .env.local (if running inside a project)
if [[ -z "$api_key" ]]; then
  for candidate in ".env.local" "../.env.local" "../../.env.local"; do
    if [[ -f "$candidate" ]]; then
      found="$(grep -E '^OPENROUTER_API_KEY=' "$candidate" 2>/dev/null | head -1 | cut -d= -f2-)"
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
if [[ -z "$api_key" && -f "$HOME/.config/openrouter/api_key" ]]; then
  api_key="$(cat "$HOME/.config/openrouter/api_key" | tr -d '[:space:]')"
fi

if [[ -z "$api_key" ]]; then
  echo "[ERROR] No OpenRouter API key found." >&2
  echo "Set OPENROUTER_API_KEY env var, or add it to .env.local, or save to ~/.config/openrouter/api_key" >&2
  exit 1
fi

base_url="${OPENROUTER_BASE_URL:-https://openrouter.ai/api/v1}"
base_url="${base_url%/}"

# --- Resolve task text ---

if [[ -n "$task_file" ]]; then
  if [[ ! -f "$task_file" ]]; then
    echo "[ERROR] Task file does not exist: $task_file" >&2
    exit 1
  fi
  task_text="$(cat "$task_file")"
fi
if [[ -z "$task_text" && ! -t 0 ]]; then
  task_text="$(cat)"
fi

if [[ -z "$task_text" ]]; then
  echo "[ERROR] No task provided. Use --task, --task-file, or pipe from stdin." >&2
  exit 1
fi

# --- Build system prompt based on output type ---

case "$output_type" in
  html)
    system_prompt="You are an expert UI/web designer who thinks in terms of real user interactions. When designing a page or component, you must:

1. Clearly define every interactive element: what happens on click, hover, submit, scroll, etc.
2. Add realistic placeholder content — real-looking text, numbers, names — not lorem ipsum.
3. Include functional states: loading, empty, error, success, disabled, hover, active.
4. Add HTML comments like <!-- FEATURE: description --> before each functional section explaining what it does and how users interact with it.
5. Wire up basic JS interactions where appropriate (tab switching, modal open/close, form validation feedback, accordion toggle, etc.) so the prototype feels alive.
6. For forms: specify validation rules, required fields, input types, and placeholder hints.
7. For navigation: make all links and buttons clearly labeled with their destination or action.

Output a single, complete, self-contained HTML file. Include all CSS in a <style> tag and all JS in a <script> tag. Use modern design: clean typography, good spacing, harmonious colors, responsive layout. No external dependencies. Output ONLY the HTML code, no explanation."
    file_ext="html"
    ;;
  svg)
    system_prompt="You are an expert icon and illustration designer. Output a single, clean SVG. Use modern flat design, consistent stroke widths, and harmonious colors. The SVG should be well-structured with proper viewBox. If the icon represents an action or concept, add a brief <!-- PURPOSE: description --> comment at the top explaining what it conveys. Output ONLY the SVG code, no explanation."
    file_ext="svg"
    ;;
  *)
    system_prompt="You are an expert designer and creative director who bridges design and engineering. When giving design advice, always:

1. Describe each UI section's purpose and the user actions it supports.
2. Specify interactive behaviors: what's clickable, what triggers what, transitions, feedback.
3. Call out functional states: empty, loading, error, success, edge cases (long text, zero items, etc.).
4. Give exact values: hex colors, font stacks, spacing in px/rem, border-radius, shadow values.
5. Explain the why behind design choices — how they serve the user's goal.

Be specific and actionable. Respond in the same language as the user's request."
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
  --arg model "google/gemini-3.1-pro-preview" \
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

# --- Call OpenRouter API ---

response_file="$(mktemp)"
trap 'rm -f "$prompt_file" "$request_file" "$response_file"' EXIT

http_code="$(curl -s -w "%{http_code}" -o "$response_file" \
  -X POST "${base_url}/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${api_key}" \
  --max-time 180 \
  -d @"$request_file")"

if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
  echo "[ERROR] OpenRouter API returned HTTP ${http_code}" >&2
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
