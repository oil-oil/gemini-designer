# Gemini Designer

Gemini Designer is a visual-design advisor skill for agents. It helps with design direction, UI critique, HTML mockups, SVG icons, handwritten wordmarks, and file-based visual feedback.

The skill asks Gemini for visual judgment through the bundled `gemini-designer` CLI, then lets the main agent decide how to apply the advice in the current workspace.

## Install

The easiest way is to give this GitHub repository to an agent such as Codex, Claude Code, or Cursor and ask it to install the skill:

```text
https://github.com/oil-oil/gemini-designer
```

You can also install it directly from a terminal:

```bash
npx skills add oil-oil/gemini-designer
```

After installation, agents should use the `gemini-designer` skill when a task needs external visual design judgment.

## Authorization

The CLI reads local configuration from:

```text
~/.config/gemini-designer/config.toml
```

By default, the API key is read from:

```text
~/.config/gemini-designer/api_key
```

Do not commit API keys or local config files. The repository ignores common local secret files, including `.env`, `config.toml`, and `api_key`.

## What Agents Should Know

- Gemini is stateless. It only sees the current prompt, files passed with `-f`, and images passed with `-i`.
- For existing UI, use `gemini-designer advise`.
- For broad art direction or design imagery markdown, use `gemini-designer direction`.
- For new standalone HTML mockups, use `gemini-designer html`.
- For SVG icons, simple illustrations, and single handwritten wordmarks, use `gemini-designer svg`.
- Pass complete relevant files when Gemini needs to judge an existing design.
- Pass screenshots or visual references with `-i` when the visible result matters.
- Do not ask Gemini to patch project files directly. Use its advice, then apply the changes in the workspace.

## CLI

The skill installs a global command:

```bash
gemini-designer
```

Typical examples:

```bash
gemini-designer advise "给这个页面提视觉设计建议" -f ./design.html -o design-page-advice.md
gemini-designer direction "给这个产品生成设计意象 markdown" -o product-design-imagery.md
gemini-designer html "生成一个完整的产品页面设计稿" -f ./brief.md -o ./designs/product-page.html
gemini-designer svg "为 Museon 生成一个手写 SVG 字标" -o museon-wordmark.svg
```

Bare output filenames are saved under `.gemini-designer/` in the current workspace.

## Repository Layout

```text
SKILL.md
scripts/gemini-designer
scripts/install_cli
```

`SKILL.md` tells agents when and how to use Gemini. `scripts/install_cli` installs the CLI into the user's local bin directory. `scripts/gemini-designer` is the command agents call.
