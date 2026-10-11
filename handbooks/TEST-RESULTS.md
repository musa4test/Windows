# Final handbook validation — 10 October 2026

This release was rebuilt from four original Word handbooks, three uploaded text sources, the user's pasted additions, and the original embedded PowerShell starter. The recovered PowerShell script matches its original SHA-256: `38fef8d92dfa14a049608799b04a84e59f09c8a4e84020631fa2f8aa559daf14`.

The standalone guide contains 292 deduplicated command references, 467 preserved command-source occurrences, 9 categories and 25 subcategories. It includes 47 original PowerShell menu actions, 26 rebuilt CMD actions and four ASCII keyboard layouts. Original Word files are unchanged. Licensing text is redacted before inclusion; personal product keys are excluded.

| Check | Result |
| --- | --- |
| Every command row from the four DOCX documents retained with source provenance | Passed |
| Sorting, deduplication, stable command anchors, 702 internal links and 344 copy targets | Passed |
| Embedded offline source downloads compared with their source bytes | Passed |
| Both starter Base64 payloads, SHA-256 digests and release bytes | Passed |
| Product-key redaction, ASCII maps, BAT labels and CRLF | Passed |
| Microsoft PowerShell 7.5.4 archive checked against published SHA-256 | Passed |
| Seven PowerShell files parsed by Microsoft's parser | Passed |
| 47 original menu action definitions and unique names loaded without execution | Passed |
| Exact YES confirmations, bounded menu input and native failure propagation, with mocks | Passed |
| Windows command effects, Windows CMD menu execution and Windows Sandbox launcher | Not run — build machine is Linux |
| AD/DNS/DHCP/domain queries and installations/repairs | Not run |

Mocked checks validate control flow only. They do not establish Windows behavior, compatibility with every Windows edition, or successful repair outcomes. Previous session mock results are not reused as current evidence.

Reproduce document checks with `python tests/ValidateHandbook.py`, PowerShell parsing/control-flow checks with `tests/ValidatePowerShell.ps1`, and browser checks with `python tests/BrowserSmoke.py` using Playwright and `/usr/bin/chromium`. Developer-only Python and Chromium are not required on staff PCs.

For a disposable Windows lab, run `tests/StartWindowsSandbox.ps1` on a compatible Windows host. Its source mapping is read-only and networking/clipboard are disabled. The integration runner attempts selected read-only Windows diagnostics and the parser/control-flow checks, writes `WindowsResults.json` and a transcript, and leaves repairs and sensitive key queries unrun. Review output for identifying details before sharing. Feature transitions, long repairs, installations and server roles need appropriate separately reviewed lab tests.

Browser functional checks passed: 292 visible command references, 9 categories/25 subcategories, menu expand/collapse, filtering, empty-state search, command and starter copying, direct command/task navigation, theme switching, embedded DOCX downloads, mobile menu/no page overflow, and complete document rendering with HTTP(S) requests blocked. No JavaScript errors occurred. The managed Chromium policy blocks file:// navigation, so local-file navigation was not claimed as tested; self-contained document rendering and embedded assets were tested instead.

## Guide without source references

Removed command citations, original-source excerpts, embedded source downloads and the source-document menu. Preserved all 292 commands, 47 PowerShell actions, 26 CMD actions, reviewed troubleshooting notes and ASCII maps. The two starter setups now explicitly identify PowerShell as their input shell and explain switching from a CMD prompt. Shared release archives omit original-source files and provenance manifests. Source integrity remains verified in the development workspace.

## Readable guide layout and reported script-policy error

Learning guides now use normal Arial paragraphs, separated headings and labelled color panels: blue key points, green steps/read-only queries, amber cautions/changes and red sensitive/high-impact operations. Guide subheadings have stable menu links. BSOD explanations are organized into evidence, crash behavior, causes, stop codes, troubleshooting steps and cautions, with a readable stop-code table. Commands and ASCII maps retain monospace formatting. Source excerpts/citations remain removed.

Added a read-only Get-ExecutionPolicy -List command and a structured explanation of the reported running-scripts-disabled error. No execution-policy settings were changed. Current totals: 293 commands, nine categories, 26 subcategories, 468 command-source occurrences. Browser checks passed for normal-prose rendering, linked guide headings, current-menu highlighting, color labels, table layout and mobile overflow, alongside the existing navigation/copy/search checks. Toolkit payload digests remain unchanged.

## Staff startup update

Added a clearly separated, copyable CurrentUser RemoteSigned policy-enable step for authorized unmanaged PCs. Starters do not change execution policy. Added a native-CMD one-line bootstrap: 3404 characters, below the CMD limit, with a gzip payload and verified SHA-256. It uses PowerShell inline command execution for local unpacking and launches the native batch through quoted CALL. No external download, saved PowerShell execution or policy bypass is needed for the CMD bootstrap. Both alternative and direct starters remain available. Payload, length, quote and parser checks passed; real Windows CMD execution remains untested.
