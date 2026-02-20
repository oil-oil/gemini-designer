---
name: gemini-designer
description: Delegate design tasks to Gemini (google/gemini-3.1-pro-preview) via OpenRouter. Use when you need UI/web design (single-page HTML), SVG icons/illustrations, color palettes, typography suggestions, layout advice, or any visual design reference. Gemini acts as your designer friend — ask it to create HTML page mockups, design SVG icons, suggest design systems, or give design feedback. Triggers on design-related requests like "design a page", "create an icon", "suggest colors", "make a logo", "UI mockup", "design reference".
---

# Gemini Designer — Your Design Partner

Delegate design tasks to Gemini via OpenRouter. Gemini creates HTML page designs, SVG icons, and provides design advice.

## Critical rules

- ONLY interact with Gemini through the bundled shell script. NEVER call OpenRouter API directly.
- Run the script ONCE per task. Read the output file and proceed.
- The script requires an OpenRouter API key. It checks (in order): `OPENROUTER_API_KEY` env var, `.env.local` in current/parent dirs, `~/.config/openrouter/api_key` file.

## How to call the script

The script path is:

```
~/.claude/skills/gemini-designer/scripts/ask_gemini.sh
```

### HTML page design

```bash
~/.claude/skills/gemini-designer/scripts/ask_gemini.sh \
  --task "Design a modern landing page for a SaaS product called FlowSync" \
  --output-type html
```

### SVG icon

```bash
~/.claude/skills/gemini-designer/scripts/ask_gemini.sh \
  --task "Create a minimal settings gear icon, 24x24, stroke style" \
  --output-type svg
```

### Design advice (text)

```bash
~/.claude/skills/gemini-designer/scripts/ask_gemini.sh \
  --task "Suggest a color palette and typography for a developer blog"
```

### Custom output path

```bash
~/.claude/skills/gemini-designer/scripts/ask_gemini.sh \
  --task "Design a pricing card component" \
  --output-type html \
  --output ./designs/pricing-card.html
```

The script prints on success:

```
output_path=<path to output file>
```

Read the file at `output_path` to get Gemini's response.

## Output types

- `html` — Self-contained HTML file with inline CSS. Ready to open in browser.
- `svg` — Clean SVG code. Can be saved directly or embedded in HTML/React.
- `text` (default) — Design advice in markdown: color palettes, typography, layout suggestions.

## When to use

- Need a visual reference or HTML mockup for a UI component or page
- Need SVG icons or simple illustrations
- Need color palette, typography, or layout suggestions
- Need design feedback or critique on an existing design
- Want a quick single-page HTML prototype to show a concept

## Workflow

1. Describe the design need clearly — include context, style preferences, target audience.
2. Run the script with the appropriate `--output-type`.
3. Read the output file.
4. For HTML/SVG: save to the project and iterate if needed.
5. For text advice: apply the suggestions to your implementation.

## Tips

- Be specific about style: "minimalist", "playful", "corporate", "dark mode", etc.
- Mention target audience or brand context for better results.
- For HTML pages, specify key sections: "hero, features, pricing, footer".
- For SVG icons, specify size, style (filled/stroke), and color.
- Chinese prompts work well — Gemini responds in the same language.
