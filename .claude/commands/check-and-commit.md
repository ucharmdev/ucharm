# Check and Commit

Run through all checks before committing changes to ensure consistency across the project.

## Checklist

Work through each item sequentially. Fix any issues found before proceeding.

### 1. Run Tests

First, run the project's test suites to catch regressions:

```bash
# Build PocketPy runtime
cd pocketpy && zig build -Doptimize=ReleaseSmall

# Build the CLI
cd cli && zig build -Doptimize=ReleaseSmall

# Run end-to-end tests
cd cli && ./test_e2e.sh

# Run CPython compatibility tests (PocketPy runtime)
python3 tests/compat_runner.py --report --runtime ./pocketpy/zig-out/bin/pocketpy-ucharm

# Run Vision tests
python3 tests/vision/run_vision.py --timeout 20 --runtime ./pocketpy/zig-out/bin/pocketpy-ucharm

# Verify PocketPy vendor patchset (if PocketPy was updated)
python3 scripts/verify-pocketpy-patches.py
# Optional (requires network): python3 scripts/verify-pocketpy-patches.py --check-upstream
```

If tests fail, fix the issues before continuing.

### 2. Update Type Stubs

If any runtime modules were added or modified, update stubs:

```bash
# Update stubs (manual edits for Zig modules)
# or update scripts/generate_stubs.py if you add a new generator.

# Copy to CLI for embedding
cp stubs/*.pyi cli/src/stubs/
```

### 3. Update AI Instruction Templates

Review and update the AI instruction templates in `cli/src/templates/` if:
- New runtime modules were added
- TUI functions were added/changed
- Import patterns or APIs changed

Files to check:
- `cli/src/templates/AGENTS.md` - Universal (Cursor, Windsurf, Zed)
- `cli/src/templates/CLAUDE.md` - Claude Code instructions
- `cli/src/templates/copilot-instructions.md` - GitHub Copilot

### 4. Update Project Documentation

Review and update if the changes affect:

**CLAUDE.md** (project root):
- Directory structure if files/folders were added
- Runtime module list if modules were added
- Commands or workflows that changed
- Architecture if significant changes were made

**README.md**:
- Feature list if new features were added
- Installation instructions if they changed
- Usage examples if APIs changed

### 5. Update CLI Templates

If TUI APIs changed, update the `ucharm new` template:
- `cli/src/new_cmd.zig` - The project template

### 6. Update Website Documentation

If APIs, modules, or features changed, update the website docs in `website/content/docs/`:
- Module documentation in `website/content/docs/modules/`
- Getting started guides if workflows changed
- API examples if function signatures changed

The website is deployed via Vercel from the `website/` directory.

### 7. Rebuild CLI

After any changes to embedded files (stubs, templates):

```bash
cp VERSION cli/src/VERSION
cd cli && zig build -Doptimize=ReleaseSmall
```

### 8. Review Changes

Review all staged and unstaged changes:

```bash
git status
git diff
git diff --staged
```

### 9. Create Commits

Group related changes into logical commits using conventional commit format:

**Commit types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only
- `style:` - Code style (formatting, no logic change)
- `refactor:` - Code refactoring
- `test:` - Adding/updating tests
- `chore:` - Maintenance tasks
- `perf:` - Performance improvement

**Examples:**
- `feat(term): add raw mode support`
- `fix(ansi): correct color parsing`
- `docs: update CLAUDE.md with PocketPy`
- `chore: update type stubs`

Stage and commit related changes together:

```bash
git add <related-files>
git commit -m "type(scope): description"
```

## Output

After completing all checks and commits, provide a summary of:
1. Tests run and their results
2. Files that were updated for consistency
3. Commits created with their messages
