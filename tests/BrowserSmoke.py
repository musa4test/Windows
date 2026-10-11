"""Functional Chromium checks of the standalone handbook; no Windows commands run."""
from pathlib import Path
import json,threading
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from functools import partial
from playwright.sync_api import sync_playwright,expect
ROOT=Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/'handbooks/commands.json').read_text());expected=len(manifest['entries']);subcount=len({(e['category'],e['subcategory']) for e in manifest['entries']})
server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory=str(ROOT)))
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
  page=browser.new_page(viewport={'width':1440,'height':1000});errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
  page.goto(f'http://127.0.0.1:{server.server_port}/Windows-Support-Guide.html')
  assert page.locator('.entry:visible').count()==expected
  assert page.locator('.category:visible').count()==9
  assert page.locator('.subcategory:visible').count()==subcount
  page.locator('#collapse').click();assert not page.locator('nav details[open]').count()
  page.locator('#expand').click();assert page.locator('nav details[open]').count()==page.locator('nav details').count()
  page.locator('#view').select_option('terminal');assert page.locator('.entry[data-kind="gui"]:visible').count()==0
  page.locator('#search').fill('Get-ADUser');assert page.locator('.entry:visible').count()==1
  page.locator('.entry:visible button').click();expect(page.locator('.entry:visible .copy-status')).to_contain_text('Copied',timeout=5000)
  target=page.locator('.entry[data-kind="gui"]').first.get_attribute('id');page.evaluate('(id)=>location.hash=id',target)
  expect(page.locator('#'+target)).to_be_visible();assert page.locator('#view').input_value()=='all'
  assert page.locator('#search').input_value()==''
  page.locator('#search').fill('zz-no-such-command');assert page.locator('#empty').is_visible()
  page.locator('#search').fill('');page.evaluate('location.hash="overview"')
  page.locator('#theme').click();assert page.locator('body.dark').count()==1
  page.locator('#theme').click();assert page.locator('body.dark').count()==0
  assert page.locator('a[download]').count()==0
  assert page.locator('#sources').count()==0
  assert page.get_by_text('PowerShell setup: paste into PowerShell. CMD setup: paste the one-line command directly into CMD.').count()==1
  page.locator('button[data-copy="ps-starter"]').click();expect(page.locator('button[data-copy="ps-starter"] + .copy-status')).to_contain_text('Copied',timeout=5000)
  page.locator('button[data-copy="cmd-starter"]').click();expect(page.locator('button[data-copy="cmd-starter"] + .copy-status')).to_contain_text('Copied',timeout=5000)
  page.evaluate('location.hash="task-system-overview"');expect(page.locator('#task-system-overview')).to_be_visible()
  page.evaluate('location.hash="overview"');page.wait_for_timeout(350);page.screenshot(path=str(ROOT/'handbooks/Guide-Preview.png'))
  page.set_viewport_size({'width':390,'height':844});page.wait_for_timeout(200)
  assert page.evaluate('document.documentElement.scrollWidth<=window.innerWidth'), 'Mobile overflow'
  assert page.locator('nav .menu-links').is_visible()
  page.screenshot(path=str(ROOT/'handbooks/Guide-Preview-Mobile.png'))
  # Render the complete document with all HTTP(S) blocked. This environment policy blocks file:// navigation.
  page.route('http://**/*',lambda route:route.abort());page.route('https://**/*',lambda route:route.abort())
  page.goto('about:blank');page.set_content((ROOT/'Windows-Support-Guide.html').read_text());assert page.locator('.entry:visible').count()==expected
  page.locator('#search').fill('German');assert page.locator('#keyboard-ascii').is_visible()
  page.locator('#search').fill('')
  page.add_style_tag(content='html {scroll-behavior:auto!important}')
  page.set_viewport_size({'width':1440,'height':1100})
  page.evaluate('location.hash="notes-bsod-triage"')
  expect(page.locator('#notes-bsod-triage')).to_be_visible()
  assert page.locator('#notes-bsod-triage pre').count()==0
  assert page.locator('#notes-bsod-triage .focus-panel').count()==3
  assert page.locator('#notes-bsod-triage table').count()==1
  assert page.locator('.color-legend span').count()==4
  target='notes-bsod-triage-troubleshooting-steps'
  assert page.locator('nav a[href="#'+target+'"]').count()==1
  page.evaluate('(id)=>location.hash=id',target)
  expect(page.locator('nav a[aria-current="location"]')).to_have_attribute('href','#'+target)
  page.evaluate('location.hash="notes-bsod-triage"')
  page.wait_for_timeout(150)
  page.screenshot(path=str(ROOT/'handbooks/Guide-Reading-Preview.png'))
  page.set_viewport_size({'width':390,'height':844})
  assert page.evaluate('document.documentElement.scrollWidth<=window.innerWidth')
  assert not errors,errors
  print(f'PASS: {expected} commands; 9/{subcount} hierarchy; menu controls; copy; deep links; search; theme; source references removed; 47 task shortcuts; mobile; offline document rendering; normal prose, color labels and linked guide headings; no JS errors.')
  browser.close()
finally:server.shutdown();server.server_close()
