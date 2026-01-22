---
description: Commit current changes with a well-formatted message following cPanel standards
tools:
  ['vscode', 'execute', 'read', 'agent', 'edit', 'search', 'web', 'todo']
---

## User Input

```text
$ARGUMENTS
```

If the user provided input above, use it as hints for the commit message intent or focus. This is optional context to guide the commit message creation.

Your goal is to commit the current staged/unstaged changes with a properly formatted commit message following cPanel & WHM commit standards.

## Required Reading

**MANDATORY: Before proceeding, read and apply the complete commit message standards from:**
[.github/instructions/commit-messages.instructions.md](.github/instructions/commit-messages.instructions.md)

Use the `read_file` tool to load these instructions if they are not already available.

## Workflow Steps

1. Run `git status` to see all changes (staged and unstaged)
2. Run `git diff` and `git diff --staged` to see unstaged and staged changes
3. Run `git branch --show-current` to extract the case number from the branch name
4. Analyze all changes and draft a commit message following the commit message standards

## Commit Process

1. Stage all relevant changes with `git add`
2. Create the commit using a HEREDOC for proper formatting:

```bash
git commit -m "$(cat <<'EOF'
<summary, max 50 chars, imperative mood>

Case <PROJECT-XXXXX>: <detailed description wrapped at 72 chars explaining
what changed and why>

Changelog: <user-visible change description, or empty if internal-only>
EOF
)"
```

3. Run `git status` to verify the commit succeeded

## Important

- Do NOT commit files that may contain secrets (.env, credentials, etc.)
- Do NOT push to remote unless explicitly requested
- Do NOT use `git commit --amend` unless explicitly requested
- Each commit should be an atomic change that provides standalone value
- Code should function and pass all tests at each commit stage
