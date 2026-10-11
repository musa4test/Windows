"""Check source coverage, offline links and starter payloads without executing commands."""
from pathlib import Path
from html.parser import HTMLParser
import base64,hashlib,json,re,zipfile,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
m=json.loads((ROOT/'handbooks/commands.json').read_text());entries=m['entries'];page=(ROOT/'Windows-Support-Guide.html').read_text()
assert len(entries)==len({re.sub(r'\s+',' ',e['command']).casefold() for e in entries})
assert len({e['anchor'] for e in entries})==len(entries)
assert sum(len(e['sources']) for e in entries)==m['source_occurrences']
assert entries==sorted(entries,key=lambda e:(e['category'],e['subcategory'],e['command'].casefold()))
for s in m['sources']:assert hashlib.sha256((ROOT/'handbooks/sources'/s['name']).read_bytes()).hexdigest()==s['sha256']
ns={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
for p in (ROOT/'handbooks/sources').glob('*.docx'):
 doc=ET.fromstring(zipfile.ZipFile(p).read('word/document.xml'))
 for table in doc.findall('.//w:tbl',ns):
  for tr in table.findall('w:tr',ns)[1:]:
   row=[''.join(t.text or '' for t in cell.findall('.//w:t',ns)).strip() for cell in tr.findall('w:tc',ns)]
   if len(row)>=3 and row[1]:assert any(s['file']==p.name and s['original_command']==row[1] for e in entries for s in e['sources']),row[1]
class Inspect(HTMLParser):
 def __init__(self):super().__init__();self.ids=[];self.targets=[];self.copies=[];self.downloads=[];self.remote=[]
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if 'id' in a:self.ids.append(a['id'])
  if a.get('href','').startswith('#'):self.targets.append(a['href'][1:])
  if 'data-copy' in a:self.copies.append(a['data-copy'])
  if 'download' in a:self.downloads.append(a)
  if a.get('src','').startswith(('http','//')):self.remote.append(a['src'])
p=Inspect();p.feed(page)
assert len(p.ids)==len(set(p.ids));assert set(p.targets+p.copies)<=set(p.ids);assert not p.remote
assert not p.downloads
assert 'source reference(s)' not in page
assert 'id="sources"' not in page
assert all(source['name'] not in page for source in m['sources'])
assert all(e['anchor'] in p.ids and 'code-'+e['anchor'] in p.copies for e in entries)
assert not re.search(r'\b(?!XXXXX)[A-Z0-9]{5}(?:-[A-Z0-9]{5}){4}\b',page)
for filename,target in [('Start-WindowsSupport.ps1','WindowsSupport.ps1'),('Start-WindowsSupportBatch.ps1','WindowsSupport.bat')]:
 s=(ROOT/'dist'/filename).read_text();payload=s.split("$SupportPayload = @'",1)[1].split("'@",1)[0];raw=base64.b64decode(payload);assert raw==(ROOT/'dist'/target).read_bytes();assert hashlib.sha256(raw).hexdigest() in s
 assert '-ExecutionPolicy Bypass' not in s
bat=(ROOT/'WindowsSupport.bat').read_bytes();assert b'\n' not in bat.replace(b'\r\n',b'');labels=set(re.findall(r'^:([A-Za-z0-9_]+)',bat.decode(),re.M));targets=set(re.findall(r'goto ([A-Za-z0-9_]+)',bat.decode(),re.I));assert targets<=labels
(ROOT/'handbooks/Keyboard-ASCII-Keymaps.txt').read_bytes().decode('ascii')
assert len(json.loads((ROOT/'handbooks/toolkit-actions.json').read_text()))==47
assert (ROOT/'handbooks/Handbook-Additions.html').read_bytes()==(ROOT/'Windows-Support-Guide.html').read_bytes()
print(f'PASS: {len(entries)} entries; all DOCX command rows preserved; {m["source_occurrences"]} source occurrences; {len(p.targets)} links; {len(p.copies)} copy buttons; no source citations/downloads; two payload hashes; redacted keys; BAT labels/CRLF; ASCII maps.')

import gzip
cmd=(ROOT/'dist/Start-WindowsSupport-CMD.txt').read_text().strip()
assert len(cmd)<8191 and '\n' not in cmd
assert cmd.startswith('powershell.exe -NoLogo -NoProfile -Command "') and cmd.endswith('"')
script=cmd.split('-Command "',1)[1][:-1]
assert '"' not in script
payload=script.split("$b='",1)[1].split("'",1)[0]
assert gzip.decompress(base64.b64decode(payload))==(ROOT/'WindowsSupport.bat').read_bytes()
assert "('call '+[char]34+$p+[char]34)" in script
assert 'Set-ExecutionPolicy' not in (ROOT/'dist/Start-WindowsSupport.ps1').read_text()
print(f'PASS: native CMD starter is one line, {len(cmd)} characters; compressed payload matches; policy-enable command is a separate manual step.')
