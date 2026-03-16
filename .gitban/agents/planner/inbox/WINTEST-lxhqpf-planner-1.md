The reviewer flagged 3 non-blocking items, grouped into 2 cards below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Remove duplicate deepagents structural tests from peon-adapters.Tests.ps1
Type: FASTFOLLOW
Sprint: WINTEST
Files touched: tests/peon-adapters.Tests.ps1
Items:
- L1: Lines 683-698 of peon-adapters.Tests.ps1 contain a standalone "Structural: deepagents.ps1 syntax validation" Describe block that checks valid PowerShell syntax and absence of ExecutionPolicy Bypass. These exact checks are already performed by adapters-windows.Tests.ps1 via its ForEach-parameterized blocks which now include deepagents. The standalone block in peon-adapters.Tests.ps1 should be removed to eliminate the DRY violation.

### Card 2: Harden Category B function extraction to use PowerShell AST parser
Type: BACKLOG
Sprint: none
Files touched: tests/peon-adapters.Tests.ps1
Items:
- L2: The regex `(?s)(function Emit-Event \{.*?\n\})` (and similar for Process-WireLine) relies on the closing brace being the first unindented `}` after the signature. A future refactor could silently break extraction. Replace with PowerShell AST parser (`[System.Management.Automation.Language.Parser]::ParseFile()`) for robust function extraction.
