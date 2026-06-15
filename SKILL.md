---
name: gemini-designer
description: Use Gemini as the required external visual design generator/advisor when a task needs design imagery markdown, art direction, UI critique, visual hierarchy judgment, design-system fit, color/type/layout suggestions, HTML mockups, SVG icons, or file-based feedback on existing UI. Trigger on requests like "design a page", "generate design imagery", "give design advice", "optimize this UI", "review this design", "create an icon", "suggest colors", "UI mockup", "visual direction", or when another agent needs a second opinion on visual quality.
---

# Gemini Designer — Visual Design Advisor

Use Gemini as an external visual design advisor for taste, direction, hierarchy, rhythm, and UI experience.

## Critical rules

- ONLY interact with Gemini through the global `gemini-designer` CLI. Do not call the API or provider-specific scripts directly.
- When this skill is used, call `gemini-designer` before giving design imagery, art direction, critique, visual advice, HTML, or SVG output. Do not write those deliverables from the agent's own judgment.
- Call `gemini-designer` directly in the normal path. If the command is missing, install it silently with the bundled `scripts/install_cli` script, then retry.
- For existing UI files, use `gemini-designer advise`. Do not use `gemini-designer html` to refine an existing page.
- For broad art direction, use `gemini-designer direction`. It may include files as background context.
- For design imagery markdown, use `gemini-designer direction` and read the generated markdown before responding.
- For new standalone artifacts, use `gemini-designer html` or `gemini-designer svg`.
- If the user provides screenshots, mockups, moodboards, or visual references, include relevant images with `-i / --image` when they help Gemini judge visual style, layout, hierarchy, mood, or fidelity.
- Gemini is stateless. It does not know the current project, prior conversation, screenshots, local files, design rules, or previous Gemini outputs unless they are included in the current command.
- Do not ask Gemini to review code quality, technical debt, CSS lint, or engineering consistency unless the user explicitly asks. Keep Gemini focused on visual effect, design intent, hierarchy, rhythm, taste, and UI experience.
- Do not ask Gemini to output code patches or diffs for existing files. Use its design advice, then make the actual edits yourself.
- After Gemini returns design advice, design imagery markdown, visual direction, or an HTML mockup, show the output or a concise summary to the user and wait for confirmation before implementing it in project code, unless the user explicitly asked to implement immediately.
- For ordinary asset generation, run the script ONCE per task. Read the output file and proceed.
- For high-art-direction landing pages or hero concepts, treat "art direction" and "HTML generation" as separate tasks: run once for the concept direction, read the output, then run once for the selected direction.
- The CLI manages its own configuration and authorization. Do not pre-check authorization. If a call fails with `error=not_authorized`, report that Gemini Designer is not authorized.

## Gemini CLI

Use `gemini-designer` for every Gemini task.

Normal path: call `gemini-designer` directly. Do not run install or auth checks before every use.

If the shell reports `command not found`, resolve `/path/to/this-skill` to the directory containing this `SKILL.md`, run `/path/to/this-skill/scripts/install_cli` silently, then retry the original `gemini-designer` command. If the installer reports a `path_warning`, use the printed `installed_path` for this turn and tell the user that the CLI directory is not on PATH.

If the CLI returns `error=not_authorized`, stop and tell the user Gemini Designer is not authorized. Do not read, copy, print, or manage API keys.

Commands:

- `gemini-designer advise` — Use for existing HTML/CSS/TSX or design files. Requires `-f` or `-i`, and requires a readable markdown file name with `-o`. Gemini gives concrete implementation-oriented visual suggestions, reuse reminders, and pseudo-code snippets when useful. Use this for small refinements and project-style consistency.
- `gemini-designer direction` — Use before implementation when the task needs a stronger idea, art direction, visual metaphor, design imagery markdown, or high-level design direction. Files are optional. Always provide a readable markdown file name with `-o`.
- `gemini-designer html` — Use only for a new standalone HTML mockup or concept page. Do not use it to revise an existing HTML file.
- `gemini-designer svg` — Use only for a new SVG icon or simple illustration.

Use complete files with `gemini-designer advise` by default. Do not summarize, slice, or annotate the file unless the file is too large for the CLI limit or the user asks for a scoped review.

For `advise` and `direction`, always name the markdown file at call time with `-o`. Prefer a bare readable filename, such as `accounts-filter-advice.md`, `museon-home-art-direction.md`, or `pricing-page-design-imagery.md`; the CLI saves bare names under `.gemini-designer/`. Use an explicit path only when a specific directory is required.

## Context Rules

Gemini receives only the command text, files passed with `-f`, and images passed with `-i`. It has no memory across calls.

When asking about an existing UI, pass the smallest complete set of files needed for the visual judgment:

- The target file or component being judged
- The project design guide or style reference, if one exists in the workspace
- Related CSS/theme/token files when they materially affect the visual result
- Nearby component files only when they define visible structure or reused UI patterns
- Screenshots, mockups, moodboards, reference images, or exported previews when the user's visual question depends on what the UI looks like

Prefer complete files over excerpts. Use multiple `-f` flags:

```bash
gemini-designer advise "判断这个页面是否符合项目现有视觉风格，并给出具体优化建议" \
  -f ./design.html \
  -f ./src/styles/tokens.css \
  -f ./src/components/Button.tsx \
  -o design-page-advice.md
```

Use `-i` for image context:

```bash
gemini-designer advise "结合截图判断这个页面哪里最影响视觉完成度" \
  -f ./design.html \
  -i ./screenshots/current.png \
  -o current-page-screenshot-advice.md

gemini-designer direction "参考这张图，提炼更适合产品的设计意象 markdown" \
  -i ./references/moodboard.png \
  -o product-design-imagery.md
```

When images are passed with `-i`, the CLI may internally send an optimized WebP version to Gemini to reduce request size while preserving readable UI detail. Agents should still pass the original screenshot or reference image path.

Do not pass unrelated source files, build output, dependency folders, logs, or implementation details that do not affect the visual result. If the needed context is too large, choose representative design-system files and say in the task text what is missing.

If Gemini's `advise` output says it needs more context, do not treat that as final advice. Gather the requested files or information when available, then run `gemini-designer advise` again with the added `-f` inputs. If the requested context cannot be found, tell the user exactly what is missing and ask for it.

The built-in `advise` prompt asks Gemini to:

- stay independent and avoid flattery
- focus on visual effect, design intent, information hierarchy, reading rhythm, atmosphere, UI finish, and user feeling
- avoid turning the response into code review
- keep the answer concrete and actionable enough for implementation
- explain exactly where to change, how to change it, and why the visual result improves
- include pseudo-code, CSS, or JSX snippets when useful, with enough length to explain the change, without outputting a full file
- remind the implementing agent to prefer existing components, selectors, classes, tokens, variables, layout patterns, and interaction patterns
- name reusable components or tokens only when they are visible in the provided files; otherwise do not invent project-specific names
- include a short "do not change" section when there are concrete areas, tokens, components, visual traits, copy, or states that should be preserved
- avoid suggesting a new design system, unrelated components, or decorative additions when existing patterns can be reused
- avoid outputting full HTML
- ask for missing context instead of guessing when a reliable visual judgment is not possible

Useful commands:

```bash
gemini-designer advise "给这个设计规范页提视觉优化建议" -f ./design.html -o design-page-advice.md
gemini-designer advise "结合截图给这个页面提视觉优化建议" -f ./design.html -i ./screenshots/current.png -o page-screenshot-advice.md
gemini-designer direction "给这个产品生成设计意象 markdown" -o product-design-imagery.md
gemini-designer direction "基于这个页面提炼更强的视觉意象" -f ./design.html -o page-design-imagery.md
gemini-designer html "生成一个自包含的活动页设计稿" -o ./designs/page.html
gemini-designer svg "生成一个设置图标" -o ./icons/settings.svg
```

Read the output file before acting. Apply only the suggestions that fit the project.

`advise` and `direction` outputs include a final `原始提示词` section. It records the task text and readable paths for referenced files or images, without copying the full file contents into the appendix.

For advisory outputs (`advise` and `direction`) and generated HTML mockups, do not immediately edit project files. Present Gemini's output or a concise summary, ask the user to choose or confirm the direction, then implement only the confirmed parts. SVG icon generation can be saved directly when the user's request is only to create the asset.

The script prints on success:

```
output_path=<path to output file>
```

Read the file at `output_path` to get Gemini's response.

On failure, the CLI prints stable fields:

```text
error=<code>
message=<short explanation>
hint=<next step>
```

Follow the `hint` when it is actionable. If `error=not_authorized`, stop and tell the user Gemini Designer is not authorized.

## Output types

- `gemini-designer html` — Self-contained HTML file with inline CSS. Ready to open in browser.
- `gemini-designer svg` — Clean SVG code. Can be saved directly or embedded in HTML/React.
- `gemini-designer advise` and `gemini-designer direction` — Markdown output.

## Configuration

- The global CLI reads `~/.config/gemini-designer/config.toml`.
- Image optimization defaults to WebP when supported by the local CLI environment.
- Agents should not read, copy, or manage API keys.
- Do not check authorization in the normal path. Use `gemini-designer auth status` only when explicitly debugging authorization.

## When to use

- Need Gemini to inspect existing HTML/CSS/TSX and give visual design advice
- Need a concise visual optimization plan based on one or more local files
- Need a visual reference or HTML mockup for a UI component or page
- Need SVG icons or simple illustrations
- Need color palette, typography, or layout suggestions
- Need design feedback or critique on an existing design
- Want a quick single-page HTML prototype to show a concept

## Workflow

1. Choose the smallest useful Gemini task: `advise`, `direction`, `html`, or `svg`.
2. Run `gemini-designer` with a readable `-o` path and get an `output_path` before writing the final answer or artifact.
3. For existing files, call `gemini-designer advise` with full file input. Do not prepend your own analysis.
4. For design imagery markdown or visual direction, call `gemini-designer direction`.
5. For new HTML/SVG artifacts, call `gemini-designer html` or `gemini-designer svg`.
6. Read Gemini's output.
7. If `advise` says more context is needed, gather the requested context and rerun `gemini-designer advise` once before presenting advice to the user. If the context is unavailable, ask the user for it.
8. When implementing `advise` output, first look for existing project components, selectors, classes, tokens, variables, and layout patterns to reuse. If Gemini suggests replacing a broad system or inventing unrelated UI, narrow it to existing patterns before editing.
9. If Gemini drifts into code review when the task is visual, rerun with a visual-only goal such as: "只从视觉设计角度判断，不要评论代码规范或工程债。"
10. Present advisory outputs or HTML mockups to the user for confirmation before editing project code, unless the user explicitly asked to implement immediately.
11. Base the final response on Gemini's output. You may summarize, select, or implement useful parts, but do not replace Gemini's design judgment with your own generated design direction.

## High-Art-Direction Workflow

Use this two-step flow when the user asks for a page that needs a strong visual idea, such as a premium landing hero, memorable brand page, abstract 3D/illustrative direction, or "high-design" web mockup.

### Step 1: Ask for art direction only

Do not ask Gemini to write HTML yet. Ask it to act as a design director:

```bash
gemini-designer direction \
  "[Product] is a [category] that helps [audience] turn [input/problem] into [output/outcome]. Identify the product's transformation, name the industry visual cliches to avoid, propose high-design hero visual metaphors, and recommend the strongest direction." \
  -o product-art-direction.md
```

### Step 2: Generate from the selected metaphor

Read the art direction output, present the candidate directions to the user, and wait for the user to choose or confirm one before generating HTML. After confirmation, ask Gemini to generate only the chosen surface. Keep the brief short, precise, open, and bounded:

```bash
gemini-designer html \
  "[Product] is a [category] that helps [audience] turn [input/problem] into [output/outcome]. Create a self-contained HTML [hero/module/page]. Visual direction: [selected metaphor], high-design, abstract, specific to [human/product context]. Avoid [industry cliches] and ordinary SaaS templates. Choose one concrete visual interpretation and execute it."
```

Good prompts describe the product's transformation and aesthetic boundaries, not exact colors or layout. Let Gemini own the visual language unless the user already chose one.

## Tips

- Keep the task prompt short and focused on what it is, not how it should look.
- For high-design pages, first let Gemini choose the visual metaphor; then reuse Gemini's own chosen direction to generate the page.
- If the user didn't specify a style/color/font, don't invent one — let Gemini decide.
- Only pass explicit user preferences (e.g. "dark mode", "use blue") when the user actually said so.
- Chinese prompts work well — Gemini responds in the same language.
