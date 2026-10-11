"""Build the self-contained offline Windows IT support handbook."""
from pathlib import Path
from html import escape as esc
import json,re,hashlib,base64
from note_layout import render_note,command_tags
from startup_helpers import configure_ps_starter,cmd_starter
configure_ps_starter(Path(__file__).resolve().parents[1])
ROOT=Path(__file__).resolve().parents[1];m=json.loads((ROOT/'handbooks/commands.json').read_text());entries=m['entries']
def public_label(s):
 return s.replace('God Mode references','God Mode shortcuts').replace('GUI references','GUI tools').replace('Legacy/version-dependent reference','Legacy/version-dependent tool')
def slug(s):return re.sub(r'[^a-z0-9]+','-',s.lower()).strip('-')
def codebox(ident,code,label='Copy command'):
 return f'<div class="code-box"><button class="copy" data-copy="{ident}" type="button">{esc(label)}</button><span class="copy-status" role="status"></span><pre id="{ident}">{esc(code)}</pre></div>'
# Starter for native CMD menu, launched from Windows PowerShell without a policy bypass.
batch=(ROOT/'WindowsSupport.bat').read_bytes();digest=hashlib.sha256(batch).hexdigest();payload=base64.b64encode(batch).decode();wrapped='\n'.join(payload[i:i+100] for i in range(0,len(payload),100))
batstarter=f'''# Native Windows CMD menu starter. Review the code before running.
if ($env:OS -ne 'Windows_NT') {{ throw 'Windows is required.' }}
$SupportPayload = @'
{wrapped}
'@
$SupportBytes = [Convert]::FromBase64String($SupportPayload)
$SupportHasher = [Security.Cryptography.SHA256]::Create()
try {{ $SupportHash = [BitConverter]::ToString($SupportHasher.ComputeHash($SupportBytes)).Replace('-', '').ToLowerInvariant() }} finally {{ $SupportHasher.Dispose() }}
if ($SupportHash -ne '{digest}') {{ throw 'Checksum mismatch. Nothing executed.' }}
$SupportDirectory = Join-Path $env:LOCALAPPDATA 'WindowsSupport\\Releases\\{digest[:12]}'
New-Item -ItemType Directory -Path $SupportDirectory -Force | Out-Null
$SupportBatch = Join-Path $SupportDirectory 'WindowsSupport.bat'
if (Test-Path -LiteralPath $SupportBatch) {{
 if ((Get-FileHash -LiteralPath $SupportBatch -Algorithm SHA256).Hash.ToLowerInvariant() -ne $SupportHash) {{ throw 'Existing release changed; not overwritten.' }}
}} else {{ [IO.File]::WriteAllBytes($SupportBatch, $SupportBytes) }}
& $env:ComSpec /d /c ('call "{{0}}"' -f $SupportBatch)
'''
(ROOT/'dist/Start-WindowsSupportBatch.ps1').write_text(batstarter)
cmdline,cmdscript=cmd_starter(batch)
(ROOT/'dist/Start-WindowsSupport-CMD.txt').write_text(cmdline+'\n')
(ROOT/'dist/CmdBootstrap.ps1').write_text(cmdscript+'\n')
ps=(ROOT/'WindowsSupport.ps1').read_text();psdigest=hashlib.sha256((ROOT/'WindowsSupport.ps1').read_bytes()).hexdigest()
firstcats=['Diagnostics','Networking','Diagnostics','Windows repairs','Windows repairs','Windows repairs','Networking','Networking','Networking','Printing','Security','Security'];tasks=[]
for i,match in enumerate(re.finditer(r"@\{ (?:Category = '([^']+)'; )?Name = '([^']+)'; Admin = \$(true|false); Run =",ps)):
 tasks.append({'category':match[1] or firstcats[i],'name':match[2],'admin':match[3]=='true'})
assert len(tasks)==47
(ROOT/'handbooks/toolkit-actions.json').write_text(json.dumps(tasks,indent=2))
taskrows=[]
for t in tasks:
 q=t['name'].replace("'","''");command=f"& (Join-Path $env:LOCALAPPDATA 'WindowsSupport\\Releases\\{psdigest[:12]}\\WindowsSupport.ps1') -Task '{q}'"
 ident='task-'+slug(t['name']);taskrows.append(f'<article class="task searchable" id="{ident}" data-kind="terminal"><h4>{esc(t["name"])}</h4><p class="tag">{esc(t["category"])} · {"Administrator" if t["admin"] else "Standard session"}</p><p>Run the PowerShell starter once before using this task shortcut. The task keeps its own prompts and checks.</p>{codebox("code-"+ident,command,"Copy task shortcut")}<a href="#contents">Back to menu</a></article>')
toolkit=f'''<section id="terminal-menus" class="reference-section"><h2>Terminal menus for staff</h2><p>Choose the menu that fits the session. Copy the complete starter into Windows PowerShell 5.1 or newer; it writes a checksum-verified local release and opens the menu. No WSL, Python, download host, or separate script attachment is needed on the staff PC.</p><p>The PowerShell menu provides 47 actions in 14 categories, logs by ticket, prompts before repairs, saves selected registry/firewall states, and offers restore actions. The CMD menu has 26 checks and selected repairs in 6 categories. Neither menu automatically reboots. Execution policies and organization controls retain precedence.</p><p class="note"><strong>PowerShell setup: paste into PowerShell. CMD setup: paste the one-line command directly into CMD.</strong> For PowerShell on an approved unmanaged PC, complete the policy step below before copying the menu setup. Organization policy retains precedence.</p><details><summary>Using the older PowerShell-based setup</summary><p> If your prompt looks like <code>C:&#92;Users&#92;name&gt;</code>, you are in CMD. Run <code>powershell</code> first. Wait for a prompt starting with <code>PS</code>, then paste the complete setup block. The older multiline CMD setup uses PowerShell; the new one-line CMD setup below works directly in Command Prompt.</p></details><div class="focus-panel caution"><h3>PowerShell: one-time approved setup</h3><ol><li>Open Windows PowerShell as Administrator for administrative tasks.</li><li>Run <code>Get-ExecutionPolicy -List</code>. If MachinePolicy or UserPolicy is configured, follow your IT administrator's approved workflow.</li><li>When permitted on an unmanaged PC, copy the enable command below into PowerShell and confirm its prompt. This changes CurrentUser policy persistently.</li><li>Copy the PowerShell menu setup below and paste the whole block.</li></ol>{codebox("enable-policy", "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned", "Copy approved policy-enable command")}<p>Record the previous CurrentUser policy before changing it. The CMD one-line starter does not need this policy step.</p></div><div class="starter-grid"><div class="starter"><h3>PowerShell toolkit</h3><p>Diagnostics, repairs, installs, Windows features, firewall, users, policy, registry and services.</p><button data-copy="ps-starter" class="primary">Copy PowerShell menu setup</button><span class="copy-status" role="status"></span><details><summary>Inspect the complete starter</summary><pre id="ps-starter">{esc((ROOT/'dist/Start-WindowsSupport.ps1').read_text())}</pre></details></div><div class="starter"><h3>CMD / BAT toolkit</h3><p>Native command menu for diagnostics, repairs, networking, firewall, users and feature inventory.</p><button data-copy="cmd-starter" class="primary">Copy one-line CMD starter</button><span class="copy-status" role="status"></span><p>Open Command Prompt as Administrator for admin tasks. Paste this complete single line and press Enter.</p><details><summary>Inspect the one-line CMD starter</summary><pre id="cmd-starter">{esc(cmdline)}</pre></details><details><summary>Alternative: setup from PowerShell</summary>{codebox("bat-starter",batstarter,"Copy alternative PowerShell setup")}</details></div></div><details><summary>Inspect toolkit code</summary><h3>PowerShell code</h3>{codebox('ps-source',ps,'Copy PowerShell code')}<h3>CMD / BAT code</h3>{codebox('bat-source',batch.decode('ascii'),'Copy BAT code')}</details><details><summary>47 individual PowerShell task shortcuts</summary>{''.join(taskrows)}</details><a href="#contents">Back to menu</a></section>'''
nav=[];content=[];colors=['blue','green','amber','purple']
for index,cat in enumerate(sorted({e['category'] for e in entries})):
 cid='category-'+slug(cat);subs=[];links=[]
 for sub in sorted({e['subcategory'] for e in entries if e['category']==cat}):
  sid='subcategory-'+slug(cat)+'-'+slug(sub);cards=[];group=[e for e in entries if e['category']==cat and e['subcategory']==sub]
  for e in group:
   ident=e['anchor'];notes=''.join(f'<li>{esc(public_label(n))}</li>' for n in e['notes'] if not n.startswith(('Reference only;', 'Exact supplied full path:')))
   cards.append(f'<article class="entry searchable" id="{ident}" data-kind="{"gui" if e["kind"]=="Run / graphical reference" else "terminal"}"><h4>{esc(e["command"])}</h4>{command_tags(e["kind"],e["risk"])}<p>{esc(e["sources"][0]["purpose"])}</p><p class="small">{esc(e["scope"])} · {esc(e["admin"])}</p>{codebox("code-"+ident,e["command"],"Copy Run shortcut" if e["kind"]=="Run / graphical reference" else "Copy command")}<ul>{notes}</ul><p class="small">Windows execution: not tested.</p><p><a href="#{ident}">Direct link</a> · <a href="#contents">Back to menu</a></p></article>')
  subs.append(f'<section class="subcategory" id="{sid}"><h3>{esc(public_label(sub))} <span class="small">{len(cards)} entries</span></h3>{"".join(cards)}</section>');links.append(f'<a href="#{sid}">{esc(public_label(sub))} <span>{len(cards)}</span></a>')
 content.append(f'<section class="category {colors[index%len(colors)]}" id="{cid}"><h2>{esc(cat)}</h2>{"".join(subs)}</section>')
 nav.append(f'<details class="menu-group" open><summary><a href="#{cid}">{esc(cat)}</a></summary>{"".join(links)}</details>')
reference=[];reflinks=[]
for note in m['study_notes']:
 ident='notes-'+slug(note['title'])
 title={'PowerShell code corrections':'PowerShell syntax and compatibility','BSOD triage':'Blue screen (BSOD): diagnosis and repair'}.get(note['title'],note['title'])
 rendered=render_note(note);section_links=[]
 def link_heading(match):
  heading=match[1];section_id=ident+'-'+slug(heading)
  section_links.append(f'<a href="#{section_id}">{esc(heading)}</a>')
  return f'<h3 id="{section_id}" class="reading-heading">{heading}</h3>'
 rendered=re.sub(r'<h3>(.*?)</h3>',link_heading,rendered)
 reference.append(f'<section class="reference-section searchable" id="{ident}" data-kind="note"><h2>{esc(title)}</h2><p class="tag">{esc(note["group"])} · practical guidance</p>{rendered}<a href="#contents">Back to menu</a></section>')
 reflinks.append(f'<details class="guide-menu"><summary><a href="#{ident}">{esc(title)}</a></summary>{"".join(section_links)}</details>')
keymaps=(ROOT/'handbooks/Keyboard-ASCII-Keymaps.txt').read_text();reference.append(f'<section class="reference-section searchable" id="keyboard-ascii" data-kind="note"><h2>ASCII keyboard diagrams and key maps</h2><p>Standard German, Danish, US and British layouts. Named labels keep the table ASCII.</p>{codebox("keymaps",keymaps,"Copy ASCII tables")}<a href="#contents">Back to menu</a></section>');reflinks.append('<a href="#keyboard-ascii">ASCII keyboard key maps</a>')
css=(ROOT/'tools/guide.css').read_text();js=(ROOT/'tools/guide.js').read_text();subcount=len({(e['category'],e['subcategory']) for e in entries})
page=f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Windows IT Support — Staff Handbook</title><style>{css}</style></head><body><nav id="contents" aria-label="Handbook menu"><a class="brand" href="#overview">WINDOWS SUPPORT<span>Staff handbook · offline edition</span></a><label for="search">Find a task or topic</label><input id="search" type="search" placeholder="DNS, BSOD, firewall, German…"><label for="view">Show</label><select id="view"><option value="all">All commands and guides</option><option value="terminal">Terminal commands</option><option value="gui">Run / graphical shortcuts</option><option value="note">Learning and troubleshooting notes</option></select><p id="count" class="small" aria-live="polite"></p><button id="theme" type="button">Switch to dark theme</button><button id="expand" type="button">Expand menu</button><button id="collapse" type="button">Collapse menu</button><div class="menu-links"><a href="#overview">Start here</a><a href="#terminal-menus">PowerShell and CMD menus</a>{''.join(nav)}<details open><summary>Guides and key maps</summary>{''.join(reflinks)}<a href="#validation">Validation and limits</a></details></div></nav><header id="overview"><p class="eyebrow">IT SUPPORT · WINDOWS CLIENT & SERVER</p><h1>One handbook.<br>Clear steps for your staff.</h1><p class="intro">Diagnose, repair and configure Windows with organized commands and native terminal menus.</p><div class="stats"><div><strong>{len(entries)}</strong><span>commands</span></div><div><strong>9 / {subcount}</strong><span>categories / subcategories</span></div><div><strong>47 + 26</strong><span>PowerShell / CMD menu tasks</span></div></div><div class="color-legend" aria-label="Reading color guide"><span class="info">Blue: key points</span><span class="steps">Green: steps / read-only</span><span class="caution">Amber: cautions / changes</span><span class="danger">Red: sensitive / high impact</span></div><div class="resources"><a href="#terminal-menus">Copy a menu starter</a><a href="#notes-start-here-staff-workflow">Staff workflow</a><a href="#keyboard-ascii">Keyboard key maps</a></div><p class="note">Open this HTML file directly in a browser. Everything needed to read, search, copy, and inspect the guide is embedded. Copied commands must be run in the shell indicated. Graphical shortcuts are documentation; the terminal toolkit does not launch them.</p></header><main><p id="empty" hidden>No matching entries. Change the search or view.</p>{toolkit}{''.join(content)}{''.join(reference)}<section id="validation"><h2>Validation and practical limits</h2><p>The recovered PowerShell toolkit matches SHA-256 <code>{psdigest}</code>. This release checks command deduplication, menu links, embedded payload hashes, script syntax and browser behavior. Detailed results are included in the release package.</p><p>Real Windows effects, CMD execution, feature transitions and domain/server operations have not been tested here: the build environment is Linux. Earlier mock test results are not claimed as current Windows validation. Run changes in an isolated Windows lab before company deployment. Completion of a command does not prove a symptom is fixed.</p><p>Version 1.0 · rebuilt 10 October 2026 · commands are a growing curated collection, not an exhaustive list of every possible repair.</p><a href="#contents">Back to menu</a></section></main><script>{js}</script></body></html>'''
for name in ['Windows-Support-Guide.html','handbooks/Handbook-Additions.html']:(ROOT/name).write_text(page,encoding='utf-8')
print('Built standalone handbook:',len(page.encode()),'bytes;',len(tasks),'PowerShell task shortcuts')
