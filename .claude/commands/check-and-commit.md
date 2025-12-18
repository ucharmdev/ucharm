# Check and Commit

Run through all checks before committing changes to ensure consistency across the project.

## Checklist

Work through each item sequentially. Fix any issues found before proceeding.

### 1. Run Tests

First, run the project's test suites to catch any regressions:

```bash
# Build the CLI first
cd cli && zig build -Doptimize=ReleaseSmall

# Run end-to-end tests
cd cli && ./test_e2e.sh

# Run CPython compatibility tests (check for regressions)
python3 tests/compat_runner.py --report
```

If tests fail, fix the issues before continuing.

### 2. Regenerate Type Stubs

If any native modules were added or modified, regenerate the type stubs:

```bash
# Generate stubs from C source
python3 scripts/generate_stubs.py

# Copy to CLI for embedding
cp stubs/*.pyi cli/src/stubs/
```

Check if any stubs changed and stage them if so.

### 3. Update AI Instruction Templates

Review and update the AI instruction templates in `cli/src/templates/` if:
- New native modules were added (update module lists)
- TUI functions were added/changed (update Available Functions)
- Import patterns or APIs changed

Files to check:
- `cli/src/templates/AGENTS.md` - Universal (Cursor, Windsurf, Zed)
- `cli/src/templates/CLAUDE.md` - Claude Code
- `cli/src/templates/copilot-instructions.md` - GitHub Copilot

### 4. Update Project Documentation

Review and update if the changes affect:

**CLAUDE.md** (project root):
- Directory structure if files/folders were added
- Native module list if modules were added
- Commands or workflows that changed
- Architecture if significant changes were made

**README.md**:
- Feature list if new features were added
- Installation instructions if they changed
- Usage examples if APIs changed

### 5. Update CLI Templates

If TUI APIs changed, update the `ucharm new` template:
- `cli/src/new_cmd.zig` - The project template

### 6. Rebuild CLI

After any changes to embedded files (stubs, templates):

```bash
cp VERSION cli/src/VERSION
cd cli && zig build -Doptimize=ReleaseSmall
```

### 7. Review Changes

Review all staged and unstaged changes:

```bash
git status
git diff
git diff --staged
```

### 8. Create Commits

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
- `feat(input): add password prompt function`
- `fix(charm): correct box border rendering`
- `docs: update CLAUDE.md with new module`
- `chore: regenerate type stubs`

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
