"""Extract source handbooks; this reads documents and never runs their commands."""
from pathlib import Path
import xml.etree.ElementTree as ET
import hashlib,json,re,zipfile
ROOT=Path(__file__).resolve().parents[1]
SOURCES=ROOT/'handbooks/sources'
NS={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
def text(n):return ''.join(t.text or '' for t in n.findall('.//w:t',NS)).strip()
entries={};sources=[];notes=[];count=0

def classify(c):
 low=c.lower();b=low.split()[0]
 if b=='control' and len(low.split())>1:return 'Windows configuration','Control Panel tools'
 if 'softwarelicensing' in low or 'slmgr' in low:return 'Licensing and activation','License status and keys'
 if b.startswith(('get-ad','dsa.','dssite.','domain.','adsiedit.')):return 'Server administration','Active Directory'
 if b.startswith(('get-dnsserver','get-dhcpserver','dnsmgmt.','dhcpmgmt.')):return 'Server administration','DNS and DHCP'
 if b in ('servermanager','virtmgmt.msc','cluadmin.msc','iscsicpl'):return 'Server administration','Roles and virtualization'
 if b in ('gpupdate','gpresult','gpedit.msc','gpmc.msc','rsop.msc','secpol.msc'):return 'Accounts and security','Group Policy'
 if 'firewall' in low or b=='wf.msc' or 'windowsdefender' in low:return 'Accounts and security','Firewall and protection'
 if b in ('netplwiz','lusrmgr.msc','credwiz') or low.startswith(('control userpassword','rundll32 keymgr')):return 'Accounts and security','Users and credentials'
 if b in ('ipconfig','ping','nslookup','tracert','netstat','arp','route','ncpa.cpl','inetcpl.cpl'):return 'Networks and remote support','Network diagnosis'
 if b in ('mstsc','msra','quickassist','shrpubw','fsmgmt.msc','printmanagement.msc') or 'printers' in low or low.startswith('\\'):return 'Networks and remote support','Remote support and printing'
 if b in ('sfc','dism','rstrui','recdisc','sdclt') or low.startswith(('ms-settings:recovery','ms-settings:windowsupdate')):return 'System diagnosis and repair','Recovery and Windows repairs'
 if b in ('chkdsk','diskmgmt.msc','cleanmgr','dfrgui'):return 'System diagnosis and repair','Storage and filesystem'
 if b in ('diskpart','verifier','systemreset'):return 'System diagnosis and repair','Advanced manual tools'
 if b in ('get-process','get-eventlog','get-winevent','msinfo32','dxdiag','perfmon','resmon','eventvwr','taskmgr','winver','sysdm.cpl','msconfig','reliabilitymonitor','sigverif','psr'):return 'System diagnosis and repair','System information and logs'
 if 'godmode' in low or 'servertools.' in low or 'shell:::' in low:return 'Windows configuration','God Mode references'
 if b in ('services.msc','taskschd.msc','get-service','restart-service'):return 'Windows configuration','Services and scheduled tasks'
 if b in ('devmgmt.msc','hdwwiz.cpl','hdwwiz.exe','joy.cpl','main.cpl','mmsys.cpl','wiaacmgr','tabletpc.cpl','tpm.msc'):return 'Windows configuration','Devices and drivers'
 if b in ('winword','excel','powerpnt','outlook','teams','msedge','chrome','firefox','appwiz.cpl','optionalfeatures','pkgmgr'):return 'Windows configuration','Applications and features'
 if low.startswith(('shell:','%')) or low in ('temp','downloads','documents','pictures','videos','music','desktop','c:\\'):return 'Windows configuration','Folders and shell locations'
 if b.startswith(('reg','set-itemproperty','new-itemproperty')):return 'Registry','Queries, backup and editing'
 if low.startswith('ms-settings:') or b.endswith('.cpl') or b=='control.exe':return 'Windows configuration','Settings and Control Panel'
 return 'PowerShell and scripting','Discovery and learning'

def describe(c):
 low=c.lower();b=low.split()[0];n=[]
 ps=bool(re.match(r'^(Get|Set|New|Restart|Test|Resolve|Select|Where|Enable|Disable|Remove|Add|Start)-[A-Za-z]+',c)) or c.startswith(('(', '$'))
 cmd=b in ('ipconfig','ping','nslookup','tracert','netstat','arp','route','gpupdate','gpresult','sfc','chkdsk','dism','wmic','reg','cscript.exe','net','netsh','ver','systeminfo','whoami','driverquery','powercfg','winget','wevtutil','sc','tasklist')
 kind='PowerShell' if ps else 'CMD' if cmd else 'Run / graphical reference'
 change=low.startswith(('gpupdate','sfc','restart-','set-','new-','enable-','disable-','remove-','add-','start-','ipconfig /release','ipconfig /renew','ipconfig /flushdns','reg import')) or '/restorehealth' in low or '/ipk' in low or '/ato' in low or '/f' in low
 risk='Changes settings or performs repair' if change else 'Read-only query' if ps or cmd else 'Opens interface; subsequent actions may change settings'
 if 'oa3xoriginalproductkey' in low:risk='Sensitive: displays full OEM product key';n+=['May return blank when no firmware key exists. Keep output out of shared logs. Never automatically tested.']
 if b=='wmic':n+=['WMIC is deprecated and can be missing on modern Windows; use CIM where supported.']
 if b in ('get-eventlog','get-wmiobject') or 'get-wmiobject' in low:n+=['Windows PowerShell 5.1 legacy command; not available in PowerShell 7.']
 if b in ('write','psr','pkgmgr','sdclt','systemreset','recdisc','access.cpl','wgpocpl.cpl','modem.cpl','password.cpl','netcpl.cpl') or any(x in low for x in ('wgpocpl','modem.cpl','password.cpl','netcpl.cpl','access.cpl','pc card')):n+=['Legacy/version-dependent reference; may be absent on current Windows.']
 if b=='reliabilitymonitor':n+=['Unverified alias: prefer perfmon /rel.']
 if b=='hdwwiz.cpl':n+=['Usually Device Manager; hdwwiz.exe is the Add Hardware wizard.']
 if 'yourdomain.local' in low or '<' in c:n+=['Example placeholder: replace for your authorized environment before running.']
 if b in ('diskpart','verifier','systemreset','adsiedit.msc'):risk='High impact: manual review in an isolated lab'
 if low.startswith('chkdsk') and '/r' in low:n+=['Long surface scan; may schedule a reboot. Back up data first. Cannot physically repair a failing disk.']
 if low.startswith('ipconfig /release'):n+=['Can disconnect remote support. Record the existing network configuration.']
 if kind=='Run / graphical reference':n+=['Reference only; excluded from the terminal toolkit.']
 if 'slmgr' in low:n+=['Use cscript.exe for console output; bare slmgr generally uses graphical dialogs. License information may identify the device.']
 return kind,risk,n

def add(c,p,source,section='',category=None,subcategory=None,extra_notes=None,original=None,admin=None):
 global count
 count+=1;original=original or c;c=re.sub(r'^cmd\s+/k\s+','',c,flags=re.I).strip();key=re.sub(r'\s+',' ',c).casefold()
 if key not in entries:
  cat,sub=classify(c);kind,risk,n=describe(c)
  entries[key]={'command':c,'category':category or cat,'subcategory':subcategory or sub,'kind':kind,'risk':risk,'notes':n,'sources':[],'scope':'Windows client/server; availability depends on build, edition and installed roles','admin':'Administrator may be required' if admin is None else admin,'runtime_status':'Not tested on Windows'}
 e=entries[key]
 if category:e['category']=category
 if subcategory:e['subcategory']=subcategory
 for n in extra_notes or []:
  if n not in e['notes']:e['notes'].append(n)
 if c.lower().split()[0].startswith(('get-ad','get-dnsserver','get-dhcpserver')):e['scope']='Authorized server/domain lab with relevant role or RSAT module'
 e['sources'].append({'file':source,'section':section,'original_command':original,'purpose':p})
for path in sorted(SOURCES.glob('*.docx')):
 sources.append({'name':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
 body=ET.fromstring(zipfile.ZipFile(path).read('word/document.xml')).find('w:body',NS);section='Introduction'
 for node in body:
  if node.tag.endswith('}p'):
   value=text(node)
   if re.match(r'^\d+[.)] ',value):section=value
   if value:notes.append({'title':section,'source':path.name,'text':value})
   if value.startswith('GodMode.{'):add(value,'God Mode folder name',path.name,section)
  elif node.tag.endswith('}tbl'):
   rows=[[text(c) for c in tr.findall('w:tc',NS)] for tr in node.findall('w:tr',NS)][1:]
   for row in rows:
    if len(row)>=3 and row[1]:add(row[1],row[2],path.name,section)
# Curated additions use placeholders and contain no real product keys.
curated=json.loads((SOURCES/'Curated-Additions.json').read_text())
sources.append({'name':'Curated-Additions.json','sha256':hashlib.sha256((SOURCES/'Curated-Additions.json').read_bytes()).hexdigest()})
for e in curated['entries']:add(e['command'],e['purpose'],'Curated-Additions.json',e.get('section','User-requested additions'),e.get('category'),e.get('subcategory'),e.get('notes'),e.get('original'),e.get('admin'))
for p in sorted(SOURCES.glob('*.txt')):sources.append({'name':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
for e in entries.values():e['anchor']='command-'+hashlib.sha256(e['command'].casefold().encode()).hexdigest()[:16]
ordered=sorted(entries.values(),key=lambda e:(e['category'],e['subcategory'],e['command'].casefold()))
manifest={'entries':ordered,'source_occurrences':count,'sources':sources,'source_notes':notes,'study_notes':curated['notes']}
(ROOT/'handbooks/commands.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
print(f'{len(ordered)} commands, {count} source occurrences, {len({e["category"] for e in ordered})} categories, {len({(e["category"],e["subcategory"]) for e in ordered})} subcategories')
