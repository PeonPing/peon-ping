The reviewer flagged 3 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Harden windows-setup.ps1 config serialization and extraction regex
Type: FASTFOLLOW
Sprint: WINTEST
Files touched: tests/windows-setup.ps1
Items:
- L2: Locale-dependent decimal separator in config serialization. The regex `(?<=\d),(?=\d)` that fixes decimal commas from `ConvertTo-Json` on non-English locales would also corrupt integer arrays like `[1,2,3]` -> `[1.2.3]`. Fix by either forcing `CurrentCulture` to invariant before serialization or targeting only the `volume` key specifically.
- L3: Extraction regex fragility. The regex `hookScript = @'(.+?)'@` assumes exactly one matching here-string in install.ps1. Anchor on a unique marker comment inside the here-string (e.g., `# peon-ping hook for Claude Code`) so that adding a second here-string to install.ps1 does not silently break extraction.
