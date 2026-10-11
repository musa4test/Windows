"""Readable normal-text layouts for the staff learning guides."""
from html import escape as esc
import re

def panel(label,items,tone='info',ordered=False):
 tag='ol' if ordered else 'ul'
 return f'<div class="focus-panel {tone}"><h3>{esc(label)}</h3><{tag}>'+''.join('<li>'+esc(item)+'</li>' for item in items)+f'</{tag}></div>'

def render_note(note):
 title=note['title'];text=note['text'].replace('GUI references are retained for the manual','GUI tools are listed in the manual').replace('confirm that its source is trusted','confirm that its publisher is trusted')
 text=text.replace('The supplied $msg =', 'The expression $msg =').replace('The source PowerShell 7.3 links are historical version-pinned references.', 'Use documentation that matches your installed PowerShell version.').replace('The source also describes remote download-and-execute activation scripts: these remain unreviewed source text only and have no command button.', 'Do not run unreviewed remote activation scripts.').replace('Product keys in the supplied source were redacted.', 'Keep real product keys private.').replace('Your supplied images depict Danish, US and British.', 'Danish, US and British layouts use QWERTY.').replace('Cp / roo was unclear and is retained without interpretation.', '').replace('The words bash and Copy in the earlier pasted explanation were formatting labels. SFC and CHKDSK are Windows commands.', 'Run SFC and CHKDSK in the indicated Windows shell.')
 if title=='PowerShell setup: scripts are disabled':
  return '<div class="reading-text"><p class="lead"><strong>Meaning of the error:</strong> the setup decoded the toolkit, but Windows blocked execution of the saved PowerShell script. The support menu has not started.</p>'+panel('Check the policy first',[
   'Open Windows PowerShell and run Get-ExecutionPolicy -List. This only reads policy settings.',
   'Read MachinePolicy and UserPolicy first. If either is configured, follow the organization-approved process; local policy changes cannot override these scopes.',
   'For a company workstation, ask the IT administrator for an approved or signed toolkit and the permitted execution workflow.'
  ],'info')+panel('If you own the PC and are authorized to change policy',[
   'Review the toolkit code and confirm that its source is trusted.',
   'When no organization policy applies, RemoteSigned at CurrentUser can allow local scripts while still requiring signatures for scripts marked as downloaded.',
   'The command Set-ExecutionPolicy RemoteSigned -Scope CurrentUser is a persistent setting change, not a read-only fix. Record the previous CurrentUser setting and use only when your policy permits it.',
   'Rerun the menu setup after an approved policy change. To undo a change, restore the recorded previous setting; do not assume every PC previously used Restricted.'
  ],'steps',True)+panel('Important limits',[
   'Running as Administrator does not automatically override execution policy.',
   'Organization controls, application allowlisting and script signing requirements may still block execution.',
   'There is no execution-policy bypass in either menu setup. CMD users must still enter PowerShell before pasting a setup block.'
  ],'caution')+'</div>'
 if title=='BSOD triage':
  return '''<div class="reading-text"><p class="lead"><strong>BSOD means Blue Screen of Death.</strong> Windows shows this stop-error screen when a critical problem prevents it from continuing safely. The computer may restart automatically.</p>'''+panel('Focus first: capture the evidence',[
   'Record the exact stop code, time of the crash, any driver or file name shown, and what the user was doing.',
   'Ask about recent Windows updates, driver changes, new hardware, software installations or overclocking.',
   'Preserve crash dumps before cleanup or reinstallation. Compare the crash time with System event logs.'
  ])+'''<h3>What happens during a crash</h3><p>Windows halts to limit further damage. It may write a memory dump containing the state at the time of the crash. A dump can help identify the failing component; its availability depends on crash-dump settings and whether Windows could write it.</p><h3>Common causes</h3><ul><li><strong>Hardware:</strong> faulty RAM, failing storage, loose connections, overheating or unstable overclocking.</li><li><strong>Drivers:</strong> incompatible, damaged or recently changed graphics, network, storage or chipset drivers.</li><li><strong>Windows and software:</strong> corrupted system files, filesystem problems or conflicts with software that uses low-level drivers.</li><li><strong>Recent changes:</strong> an update, device installation or configuration change may be relevant.</li><li><strong>Malware:</strong> investigate when there is supporting evidence; a BSOD alone does not establish an infection.</li></ul><h3>Common stop codes</h3><div class="table-scroll"><table class="reading-table"><thead><tr><th>Stop code</th><th>Area to investigate</th></tr></thead><tbody><tr><td>0x0000007B — INACCESSIBLE_BOOT_DEVICE</td><td>Boot-storage access, controller drivers and recent storage changes.</td></tr><tr><td>0x00000050 — PAGE_FAULT_IN_NONPAGED_AREA</td><td>Memory, drivers and system corruption.</td></tr><tr><td>0x0000001E — KMODE_EXCEPTION_NOT_HANDLED</td><td>Unhandled kernel exception; use driver details and dump analysis.</td></tr><tr><td>0x0000007E — SYSTEM_THREAD_EXCEPTION_NOT_HANDLED</td><td>System-thread exception; inspect the named driver and crash dump.</td></tr><tr><td>0x0000009F — DRIVER_POWER_STATE_FAILURE</td><td>Driver/device power transitions, including sleep and resume.</td></tr></tbody></table></div>'''+panel('Troubleshooting steps',[
   'If the machine can restart safely, verify whether the failure recurs. A restart alone does not explain the cause.',
   'Check cooling, connections, RAM and storage health. Protect data before intensive disk scans.',
   'Use manufacturer-approved drivers. Review recent updates; consider an appropriate rollback when evidence points to a change.',
   'Run memory diagnostics in an appropriate lab or maintenance window. Some tests require a restart.',
   'Use the relevant Windows repair commands below the command categories when system or filesystem damage is suspected.',
   'Consider a suitable restore point or removal of a specific problematic application after reviewing the impact.',
   'Return overclocking to supported defaults when relevant. Retest the same symptom and record the result.',
   'Consider Windows reinstallation only after other diagnosis and after preserving data, keys and required application information.'
  ],'steps',True)+panel('Cautions and limits',[
   'Stop codes suggest investigation areas; they are not certain diagnoses. Kernel-Power event 41 alone does not identify the cause.',
   'Back up data before repair. CHKDSK cannot physically repair a failing disk. A /r scan can take hours and may need a restart.',
   'The words bash and Copy in the earlier pasted explanation were formatting labels. SFC and CHKDSK are Windows commands.'
  ],'caution')+'</div>'
 # Preserve the complete reviewed note while dividing it into readable sections.
 sentences=re.split(r'(?<=[.!?])\s+(?=[A-Z])',text)
 cautions=[];steps=[];overview=[]
 for sentence in sentences:
  low=sentence.lower()
  if any(word in low for word in ['back up','backup','before an authorized','not a complete','not system recovery','not remove','do not','never ','not equivalent','not interchangeable','can be absent','not required','not a built-in','unmatched','placeholder','not approved','not certain','overrid','precedence','last resort','unclear','redacted','not reproduced','not reproduce','not executed','not reviewed','unreviewed','not supplied','not provided']):cautions.append(sentence)
  elif any(word in low for word in ['record ','choose ','inspect','use ','win+','settings >','get-winuser','export','review ','begin ','retain ','preserve ','retet','retest','refresh','requires','require ']):steps.append(sentence)
  else:overview.append(sentence)
 result='<div class="reading-text">'
 if overview:result+=panel('Key points',overview,'info')
 if steps:result+=panel('Steps and practical use',steps,'steps')
 if cautions:result+=panel('Cautions and important differences',cautions,'caution')
 return result+'</div>'

def command_tags(kind,risk):
 low=risk.lower();tone='danger' if any(w in low for w in ('sensitive','high impact')) else 'caution' if any(w in low for w in ('changes','repair')) else 'steps' if 'read-only' in low else 'info'
 kind=kind.replace('Run / graphical reference','Windows Run / graphical shortcut')
 return f'<div class="command-tags"><span class="shell-badge">{esc(kind)}</span><span class="risk-badge {tone}">{esc(risk)}</span></div>'
