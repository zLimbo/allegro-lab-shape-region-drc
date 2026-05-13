param(
  [string]$Allegro = 'C:\Cadence\SPB_24.1\tools\bin\allegro.exe'
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ToolBin = Split-Path -Parent $Allegro
$DbDoctor = Join-Path $ToolBin 'dbdoctor.exe'
$Report = Join-Path $ToolBin 'report.exe'

foreach ($tool in @($Allegro, $DbDoctor, $Report)) {
  if (-not (Test-Path $tool)) {
    throw "Required Allegro tool not found: $tool"
  }
}

$Out = Join-Path $Root 'out'
$Reports = Join-Path $Root 'reports'
New-Item -ItemType Directory -Force -Path $Out, $Reports | Out-Null

$template = Join-Path $Root 'templates\blank_template.brd'
$generated = Join-Path $Out 'shape_region_result_cases.brd'
$drcBoard = Join-Path $Out 'shape_region_result_cases_drc.brd'
$reportTxt = Join-Path $Out 'shape_region_result_cases_drc_report.txt'
$journal = Join-Path $Out 'generate.jrl'
$dbdoctorLog = Join-Path $Out 'dbdoctor.log'

Remove-Item -Force -ErrorAction SilentlyContinue `
  "$generated", "$generated.lck", "$drcBoard", "$drcBoard.lck", "$reportTxt", "$journal", "$dbdoctorLog", "$template.lck"

$args = @(
  '-expert',
  '-p', $Root,
  '-nographic',
  '-j', $journal,
  '-s', 'scripts\run_generate_shape_region_cases.scr',
  $template
)

$p = Start-Process -FilePath $Allegro -ArgumentList $args -WorkingDirectory $Root -PassThru -WindowStyle Hidden
if (-not $p.WaitForExit(60000)) {
  Stop-Process -Id $p.Id -Force
  throw 'Timed out while generating Allegro board.'
}

$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& $DbDoctor -drc_only -no_backup -outfile $drcBoard $generated *>&1 | Set-Content -Encoding UTF8 $dbdoctorLog
$ErrorActionPreference = $oldErrorActionPreference
& $Report -v drc $drcBoard $reportTxt

Copy-Item -Force $drcBoard (Join-Path $Reports 'shape_region_result_cases_drc.brd')
Copy-Item -Force $reportTxt (Join-Path $Reports 'shape_region_result_cases_drc_report.txt')
Copy-Item -Force $dbdoctorLog (Join-Path $Reports 'dbdoctor.log')
Copy-Item -Force $journal (Join-Path $Reports 'generate.jrl')

Write-Host "Generated $drcBoard"
Write-Host "Report    $reportTxt"
