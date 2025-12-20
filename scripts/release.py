#!/usr/bin/env python3
"""
Interactive release script for ucharm - built with ucharm!
Creates a new version tag and pushes it to trigger the release workflow.

Run with: ucharm run scripts/release.py
"""

import subprocess
import sys

# Add ucharm library to path (works for both PocketPy and CPython)
# When run from repo root, this adds the ucharm package
sys.path.insert(0, ".")
sys.path.insert(0, "..")

from ucharm import box, confirm, error, info, rule, select, style, success, warning


def run(cmd, capture=True):
    """Run a shell command using native subprocess."""
    # getstatusoutput runs via shell and returns (status, output)
    code, output = subprocess.getstatusoutput(cmd)
    if capture:
        return output, code
    else:
        return "", code


def get_current_version():
    """Get current version from git tags."""
    output, code = run("git describe --tags --abbrev=0 2>/dev/null")
    if code != 0 or not output:
        return "0.0.0"
    return output.lstrip("v")


def parse_version(version):
    """Parse version string into components."""
    parts = version.split(".")
    return int(parts[0]), int(parts[1]), int(parts[2])


def bump_version(version, bump_type):
    """Bump version based on type."""
    major, minor, patch = parse_version(version)

    if bump_type == "major":
        return f"{major + 1}.0.0"
    elif bump_type == "minor":
        return f"{major}.{minor + 1}.0"
    else:  # patch
        return f"{major}.{minor}.{patch + 1}"


def has_uncommitted_changes():
    """Check for uncommitted changes."""
    _, code = run("git diff-index --quiet HEAD --")
    return code != 0


def get_recent_commits(since_tag):
    """Get commits since last tag."""
    if since_tag == "0.0.0":
        cmd = "git log --oneline -10"
    else:
        cmd = f"git log v{since_tag}..HEAD --oneline"
    output, _ = run(cmd)
    return output.split("\n") if output else []


def main():
    # Header
    print()
    box(
        style("Release Manager", bold=True),
        title="ucharm",
        border_color="cyan",
        padding=1,
    )
    print()

    # Check for uncommitted changes
    if has_uncommitted_changes():
        error("You have uncommitted changes")
        print(style("  Please commit or stash them before releasing.", fg="gray"))
        print()
        sys.exit(1)

    # Get current version
    current = get_current_version()
    version_styled = style("v" + current, fg="green", bold=True)
    info("Current version: " + version_styled)
    print()

    # Show recent commits
    commits = get_recent_commits(current)
    if commits and commits[0]:
        print(style("  Recent commits:", fg="gray"))
        for commit in commits[:5]:
            print(style(f"    {commit}", fg="gray"))
        if len(commits) > 5:
            print(style(f"    ... and {len(commits) - 5} more", fg="gray"))
        print()

    # Calculate next versions
    next_patch = bump_version(current, "patch")
    next_minor = bump_version(current, "minor")
    next_major = bump_version(current, "major")

    # Version selection
    choices = [
        f"Patch  v{next_patch}  {style('(bug fixes)', fg='gray')}",
        f"Minor  v{next_minor}  {style('(new features)', fg='gray')}",
        f"Major  v{next_major}  {style('(breaking changes)', fg='gray')}",
    ]

    choice = select("Select version bump:", choices)

    if choice is None:
        print()
        warning("Release cancelled")
        sys.exit(0)

    # Map choice to version
    if "Patch" in choice:
        new_version = next_patch
    elif "Minor" in choice:
        new_version = next_minor
    else:
        new_version = next_major

    print()
    rule()
    print()

    # Confirm
    release_styled = style("v" + new_version, fg="cyan", bold=True)
    print("  Will create release: " + release_styled)
    print()

    if not confirm("Continue?"):
        print()
        warning("Release cancelled")
        sys.exit(0)

    print()

    # Update VERSION file
    info("Updating VERSION file...")
    try:
        with open("VERSION", "w") as f:
            f.write(new_version + "\n")
        success("Updated VERSION file")
    except Exception as e:
        error(f"Failed to update VERSION file: {e}")
        sys.exit(1)

    # Commit VERSION change
    info("Committing version bump...")
    _, code = run(
        f'git add VERSION && git commit -m "chore: bump version to {new_version}"'
    )
    if code != 0:
        error("Failed to commit version bump")
        # Restore VERSION file
        run("git checkout VERSION")
        sys.exit(1)
    success("Committed version bump")

    # Create tag
    info("Creating tag...")
    _, code = run(f'git tag -a "v{new_version}" -m "Release v{new_version}"')
    if code != 0:
        error(f"Failed to create tag v{new_version}")
        # Undo the commit
        run("git reset --hard HEAD~1")
        sys.exit(1)
    success(f"Created tag v{new_version}")

    # Push commit and tag
    info("Pushing to origin...")
    _, code = run("git push origin main", capture=False)
    if code != 0:
        error("Failed to push commit")
        # Cleanup
        run(f'git tag -d "v{new_version}"')
        run("git reset --hard HEAD~1")
        sys.exit(1)

    _, code = run(f'git push origin "v{new_version}"', capture=False)
    if code != 0:
        error("Failed to push tag")
        # Cleanup
        run(f'git tag -d "v{new_version}"')
        sys.exit(1)
    success("Pushed to origin")

    print()
    rule()
    print()

    # Success message - build string without multiline f-string (PocketPy limitation)
    msg = style("Release v" + new_version + " initiated!", bold=True) + "\n\n"
    msg = msg + "The workflow will now:\n"
    msg = msg + "  " + style("1.", fg="cyan") + " Build binaries for all platforms\n"
    msg = msg + "  " + style("2.", fg="cyan") + " Generate AI-powered release notes\n"
    msg = msg + "  " + style("3.", fg="cyan") + " Create GitHub release with assets\n"
    msg = msg + "  " + style("4.", fg="cyan") + " Update Homebrew formula"
    box(msg, border_color="green", padding=1)
    print()

    url = "https://github.com/ucharmdev/ucharm/actions"
    print(f"  Watch progress: {style(url, fg='cyan', underline=True)}")
    print()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
        warning("Cancelled")
        sys.exit(0)
