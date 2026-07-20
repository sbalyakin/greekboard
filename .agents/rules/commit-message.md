When suggesting commit messages for this repository, always follow these rules.

# Main format

Use this format:

<scope>: <subject>

# Language

- Write commit messages in English only.
- Use imperative mood when natural.
- Keep the subject concise, specific, and factual.
- Start the subject with an uppercase letter.
- Do not end the subject with a period.

# Subject length

- Keep the entire first line at 72 characters or fewer.
- Prefer compact wording without losing meaning.
- Omit routine implementation details instead of moving them into a body.

# Scope selection

Choose the narrowest meaningful scope based on the changed subsystem.

## Available scopes

### 1. Production subsystems
- `keyboard`: On-screen layout, key models, Greek monotonic mapping, keyboard state, and layout metrics.
- `insertion`: Click-to-type text insertion into the previously active application.
- `input-monitor`: Physical key event monitoring and on-screen key highlighting.
- `settings`: User preferences, SettingsStore, and settings UI or window.
- `permissions`: Accessibility and Input Monitoring permission checks and prompts.
- `launch`: Launch at login wiring and related adapters.
- `l10n`: Localization strings, L10n helpers, and string catalog resources.
- `ui`: Keyboard or settings presentation not owned by a more specific subsystem.

### 2. Architectural fallback scopes
- `app`: Application lifecycle, bootstrap, coordinator, menu bar, and cross-feature ViewModel wiring.
- `domain`: Cross-subsystem business logic, models, policies, protocols, and use cases.
- `infra`: Cross-subsystem stores, persistence, and infrastructure helpers.
- `platform`: Concrete macOS adapters not covered by a specific subsystem.
- `runtime`: Cross-subsystem runtime behavior, container wiring, or event processing.
- `core`: Comparable changes across multiple GreekKeyboardCore architectural layers with no dominant subsystem.

### 3. Repository and infrastructure
- `tests`: Test-only changes, fixtures, and test launchers.
- `build`: Package.swift, app-bundle configuration, packaging, and build scripts.
- `scripts`: General maintenance and repository automation not owned by build, tests, or AI workflows.
- `ai`: Agent rules, skills, and Cursor, Claude, or Codex configuration.
- `docs`: Project documentation, README, and architecture decisions.
- `chore`: Gitignore, editor metadata, and local maintenance with no more specific scope.

## Scope rules
- Use one scope only.
- Prefer specific subsystem scopes over broader layer scopes.
- If a change spans multiple subsystems, choose the dominant one from the user-visible or architectural perspective.
- Use the production scope when production code and its tests change together.
- Use `tests` only when the selected scope contains no production behavior change.
- Use `build` for package manifests, app-bundle configuration, packaging, and build automation.
- Use `scripts` only when the script is not better described by `build`, `tests`, or `ai`.
- Use `core` only when multiple architectural layers change comparably and no subsystem dominates.
- Use `chore` only when no production, architectural, test, build, script, AI, or documentation scope fits.
- Do not use change types such as `fix`, `refactoring`, or `cleanup` as scopes.

# Message style

Prefer describing the actual behavioral or architectural outcome, not low-level edits.

# Special cases

For purely local cleanup with no meaningful subsystem, use:
- chore: Remove unused gitignore patterns

For documentation-only changes, use:
- docs: Clarify Accessibility permission requirements

# Body rules

Do not add a body by default. Add a body only when the subject would otherwise hide important information that is not obvious from the diff itself.

A body is allowed only when at least one of these is true:
- the commit has an important user-visible caveat or behavior change
- the change has a non-obvious limitation, compatibility concern, or rollback risk
- the behavior differs across apps, environments, or runtime modes
- the commit introduces a significant architectural decision or tradeoff
- the commit changes public API, persisted config format, or external protocol
- the commit requires special migration or follow-up work

Body rules:
- use short bullet points
- include only non-obvious information
- do not restate the diff or list implementation steps
- do not mention file or type names unless essential to understanding the impact
- for agent rules, skills, commit workflows, documentation, tests, formatting,
  and routine refactoring, use a subject line only unless there is an explicit
  migration, compatibility, security, or rollback concern

# Output rules

When asked to generate a commit message:
- return only the final commit message unless additional explanation is requested
- include a body when needed by the rules above
- do not return multiple options unless explicitly requested
- do NOT wrap the output in markdown code blocks (```) or quotes
- choose the most specific scope supported by the changes

# Examples

**Good:**
keyboard: Highlight physical keys without changing typed input

**Good:**
insertion: Insert Unicode text into the previously active app

**Good (Body included for non-obvious migration caveat):**
settings: Change persisted opacity key format

- Existing settings files are not migrated automatically

**Bad (Uses Conventional Commits format):**
feat(keyboard): highlight physical keys -> **Do not use parentheses or feat/fix prefixes.**

**Bad (Past tense, ends with period, capitalized scope):**
Keyboard: Highlighted physical keys. -> **Scope must be lowercase, use imperative mood, no period.**
