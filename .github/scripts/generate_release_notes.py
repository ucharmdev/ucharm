#!/usr/bin/env python3
"""
Generate AI-powered release notes using OpenRouter.

This script analyzes git commits and uses AI to generate polished,
user-friendly release notes for GitHub releases.
"""

import os
import subprocess
import sys
from typing import Optional


def get_commits(prev_tag: Optional[str], current_tag: str) -> str:
    """Fetch commit messages with their full bodies between two tags."""
    if prev_tag:
        range_spec = f"{prev_tag}..{current_tag}"
    else:
        range_spec = current_tag

    cmd = ["git", "log", "--pretty=format:%h|%s|%b|||", range_spec]

    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return result.stdout


def parse_commits(raw_commits: str) -> list[dict]:
    """Parse raw git log output into structured commit data."""
    commits = []

    for commit_block in raw_commits.split("|||"):
        commit_block = commit_block.strip()
        if not commit_block:
            continue

        parts = commit_block.split("|", 2)
        if len(parts) >= 2:
            commit_hash = parts[0].strip()
            subject = parts[1].strip()
            body = parts[2].strip() if len(parts) > 2 else ""

            if subject.startswith("Merge"):
                continue

            commits.append({"hash": commit_hash, "subject": subject, "body": body})

    return commits


def generate_release_notes_with_ai(
    commits: list[dict],
    current_tag: str,
    prev_tag: Optional[str],
    repo: str,
    api_key: str,
    model: str = "anthropic/claude-haiku-4.5",
) -> str:
    """Generate release notes using OpenRouter AI."""
    import requests

    commits_context = []
    for commit in commits:
        commit_text = f"**{commit['subject']}** ({commit['hash']})"
        if commit["body"]:
            commit_text += f"\n{commit['body']}"
        commits_context.append(commit_text)

    commits_text = "\n\n".join(commits_context)

    prompt = f"""You are writing release notes for "ucharm" (μcharm) - a CLI toolkit for building beautiful, fast, tiny command-line applications with MicroPython. It provides Python syntax with native Zig performance and sub-1MB standalone binaries.

# Commits:

{commits_text}

# Task:

Generate concise release notes in markdown. Guidelines:

1. **Structure**: Use sections like "Features", "Bug Fixes", "Improvements", "Documentation", "Maintenance" (only if applicable)

2. **Style**:
   - Be terse - one short line per change (max 10-15 words per bullet)
   - Present tense ("Add" not "Added")
   - Focus on what changed, not why or how
   - No introductory paragraphs or summaries

3. **Format**:
   - Use simple bullets with dash (-)
   - **Bold** only for feature/command names or module names
   - No nested bullets - flatten everything to single-level lists
   - No commit hashes

4. **Content**:
   - List all changes but keep each item to ONE line
   - Consolidate related micro-changes into single bullets
   - Highlight new native modules, performance improvements, CLI changes
   - Omit version bumps and merge commits

Example style:
## Features
- Add **subprocess** module with run, call, check_output
- Add **signal** module (6.6x faster than CPython)

## Improvements
- Improve CLI output with progress indicators
- Update universal binary format for faster startup

Generate ONLY the release notes, starting with the first section header."""

    response = requests.post(
        "https://openrouter.ai/api/v1/chat/completions",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": f"https://github.com/{repo}",
            "X-Title": "ucharm Release Notes Generator",
        },
        json={
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.5,
            "max_tokens": 1000,
        },
        timeout=60,
    )

    response.raise_for_status()
    result = response.json()

    release_notes = result["choices"][0]["message"]["content"].strip()

    if prev_tag:
        release_notes += f"\n\n---\n\n**Full Changelog**: https://github.com/{repo}/compare/{prev_tag}...{current_tag}"

    return release_notes


def main():
    """Main entry point."""
    current_tag = os.environ.get("CURRENT_TAG")
    prev_tag = os.environ.get("PREV_TAG", "").strip()
    repo = os.environ.get("GITHUB_REPOSITORY")
    api_key = os.environ.get("OPENROUTER_API_KEY")
    model = os.environ.get("AI_MODEL", "anthropic/claude-haiku-4.5")

    if not current_tag:
        print("Error: CURRENT_TAG environment variable is required", file=sys.stderr)
        sys.exit(1)

    if not repo:
        print(
            "Error: GITHUB_REPOSITORY environment variable is required", file=sys.stderr
        )
        sys.exit(1)

    if not api_key:
        print(
            "Error: OPENROUTER_API_KEY environment variable is required",
            file=sys.stderr,
        )
        sys.exit(1)

    prev_tag = prev_tag if prev_tag else None

    print(f"Generating release notes for {current_tag}", file=sys.stderr)
    if prev_tag:
        print(f"Previous tag: {prev_tag}", file=sys.stderr)
    else:
        print("First release (no previous tag)", file=sys.stderr)

    raw_commits = get_commits(prev_tag, current_tag)
    commits = parse_commits(raw_commits)

    print(f"Found {len(commits)} commits to analyze", file=sys.stderr)

    if not commits:
        print("No commits found. Generating minimal release notes.", file=sys.stderr)
        release_notes = f"Release {current_tag}"
    else:
        try:
            release_notes = generate_release_notes_with_ai(
                commits=commits,
                current_tag=current_tag,
                prev_tag=prev_tag,
                repo=repo,
                api_key=api_key,
                model=model,
            )
        except Exception as e:
            print(f"Error calling OpenRouter API: {e}", file=sys.stderr)
            print("Falling back to basic release notes", file=sys.stderr)

            release_notes = "## Changes\n\n"
            for commit in commits:
                release_notes += f"- {commit['subject']}\n"

            if prev_tag:
                release_notes += f"\n\n**Full Changelog**: https://github.com/{repo}/compare/{prev_tag}...{current_tag}"

    print(release_notes)


if __name__ == "__main__":
    main()
