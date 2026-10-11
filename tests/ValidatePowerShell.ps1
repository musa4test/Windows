param([string]$Root = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$files = @(Get-ChildItem $Root -Recurse -Filter '*.ps1')
foreach ($file in $files) {
 $tokens=$null; $errors=$null
 $ast=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
 if ($errors.Count) { throw ($errors | ForEach-Object { "$($file.Name): $($_.Message) at $($_.Extent.StartLineNumber)" } | Out-String) }
}
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'WindowsSupport.ps1'),[ref]$tokens,[ref]$errors)
# Load functions and menu definitions only; do not run startup or Windows actions.
foreach($node in $ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]},$false)) { . ([scriptblock]::Create($node.Extent.Text)) }
foreach($node in $ast.EndBlock.Statements) {
 if($node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -in @('$actions','$categoryNames')) { . ([scriptblock]::Create($node.Extent.Text)) }
 if($node -is [Management.Automation.Language.ForStatementAst] -and $node.Extent.Text.Contains('$actions[$i].Category')) { . ([scriptblock]::Create($node.Extent.Text)) }
}
if($actions.Count -ne 47) { throw "Expected 47 menu actions; got $($actions.Count)" }
if(@($actions.Name | Select-Object -Unique).Count -ne 47) { throw 'Duplicate action names' }
if(@($actions | Where-Object { -not $_.Category -or $_.Run -isnot [scriptblock] }).Count) { throw 'Incomplete menu metadata' }
$script:Responses = [Collections.Generic.Queue[string]]::new()
function Read-Host { param($Prompt); if(!$script:Responses.Count) { throw 'Unexpected prompt' }; return $script:Responses.Dequeue() }
foreach($value in @('YES','yes','Y','NO','')) {
 $script:Responses.Enqueue($value)
 if((Confirm-Repair 'Mock confirmation only') -ne ($value -ceq 'YES')) { throw "Incorrect confirmation: $value" }
}
foreach($value in @('0','1','999','abc')) {
 $script:Responses.Enqueue($value)
 $actual=Show-Menu 'Mock menu' @(@{Name='Read-only test';Admin=$false}) 'Exit'
 $expected=-1;if($value -eq '0'){$expected=0};if($value -eq '1'){$expected=1}
 if($actual -ne $expected){throw "Invalid navigation for $value"}
}
function MockNative { $global:LASTEXITCODE=7 }
$failed=$false;try{Invoke-Native 'MockNative' @()}catch{$failed=$true}
if(!$failed){throw 'Native failure was ignored'}
function MockNative { $global:LASTEXITCODE=0 }
Invoke-Native 'MockNative' @()
Write-Host "PASS: $($files.Count) PowerShell files parsed; 47 action definitions; exact YES confirmation; bounded menu input; native failure propagation. Windows operations were not executed."
