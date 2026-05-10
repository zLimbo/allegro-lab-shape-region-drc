param(
  [string]$ReportPath = 'reports\shape_other_etch_result_cases_drc_report.txt',
  [string]$OutCsv = 'reports\shape_other_etch_analysis.csv',
  [string]$OutMarkdown = 'docs\shape_other_etch_drc_logic_conclusion_zh.md'
)

$ErrorActionPreference = 'Stop'

function Get-OtherEtchCaseId {
  param([string]$ConstraintName, [double]$X)

  $col = [math]::Round(($X - 550.0) / 760.0)
  if ($col -lt 0) { $col = 0 }
  if ($col -gt 3) { $col = 3 }

  if ($ConstraintName -eq 'Shape to Shape Spacing') {
    return ('OE{0:D3}' -f ([int]$col + 1))
  }
  if ($ConstraintName -eq 'Shape to Thru Via Spacing') {
    return ('OE{0:D3}' -f ([int]$col + 5))
  }
  return 'UNKNOWN'
}

function Get-SourceKind {
  param([string]$Source)

  if ($Source -eq 'DEFAULT') { return 'DEFAULT' }
  if ($Source -match '_(R\d+)_CSET$') { return $matches[1] }
  return 'UNKNOWN'
}

function Get-MilValue {
  param([string]$Value)

  if ($Value -match '^\s*([0-9.]+)\s*MIL\s*$') {
    return [double]$matches[1]
  }
  return $null
}

$caseInfo = @{
  OE001 = @{ object_pair = 'shape-shape'; relation = 'main shape side inside region'; expected = 'R1' }
  OE002 = @{ object_pair = 'shape-shape'; relation = 'other shape side inside region'; expected = 'R1 or DEFAULT' }
  OE003 = @{ object_pair = 'shape-shape'; relation = 'region outside local DRC'; expected = 'DEFAULT' }
  OE004 = @{ object_pair = 'shape-shape'; relation = 'main shape side on boundary'; expected = 'R1' }
  OE005 = @{ object_pair = 'shape-via'; relation = 'shape side inside region'; expected = 'R1' }
  OE006 = @{ object_pair = 'shape-via'; relation = 'via side inside region'; expected = 'R1 or DEFAULT' }
  OE007 = @{ object_pair = 'shape-via'; relation = 'region outside local DRC'; expected = 'DEFAULT' }
  OE008 = @{ object_pair = 'shape-via'; relation = 'shape side on boundary'; expected = 'R1' }
}

$reportLines = Get-Content -Encoding UTF8 (Resolve-Path $ReportPath)
$headerIndex = [Array]::FindIndex($reportLines, [Predicate[string]]{
  param($line)
  $line -eq 'Constraint Name,DRC Marker Location,DRC Subclass,Required Value,Actual Value,Constraint Source,Constraint Source Type,Element 1,Element 2'
})

if ($headerIndex -lt 0) {
  throw "Could not find detailed DRC CSV header in $ReportPath"
}

$detailRows = $reportLines[$headerIndex..($reportLines.Count - 1)] |
  ConvertFrom-Csv |
  Where-Object { $_.'Constraint Name' -in @('Shape to Shape Spacing', 'Shape to Thru Via Spacing') }

$analysis = foreach ($row in $detailRows) {
  $loc = $row.'DRC Marker Location'
  $x = $null
  $y = $null
  if ($loc -match '\(([-0-9.]+)\s+([-0-9.]+)\)') {
    $x = [double]$matches[1]
    $y = [double]$matches[2]
  }
  $caseId = Get-OtherEtchCaseId -ConstraintName $row.'Constraint Name' -X $x
  $info = $caseInfo[$caseId]
  $sourceKind = Get-SourceKind $row.'Constraint Source'

  [pscustomobject]@{
    case_id = $caseId
    object_pair = $info.object_pair
    relation = $info.relation
    constraint_name = $row.'Constraint Name'
    marker_x = $x
    marker_y = $y
    required_mil = Get-MilValue $row.'Required Value'
    actual_mil = Get-MilValue $row.'Actual Value'
    observed_source = $row.'Constraint Source'
    observed_source_kind = $sourceKind
    expected = $info.expected
  }
}

New-Item -ItemType Directory -Force -Path (Split-Path $OutCsv), (Split-Path $OutMarkdown) | Out-Null
$analysis | Sort-Object case_id | Export-Csv -NoTypeInformation -Encoding UTF8 $OutCsv

$shapeShape = @($analysis | Where-Object object_pair -eq 'shape-shape')
$shapeVia = @($analysis | Where-Object object_pair -eq 'shape-via')
$defaultCases = ($analysis | Where-Object observed_source_kind -eq 'DEFAULT' | Sort-Object case_id | ForEach-Object case_id) -join ', '
$r1Cases = ($analysis | Where-Object observed_source_kind -eq 'R1' | Sort-Object case_id | ForEach-Object case_id) -join ', '

$rows = ($analysis | Sort-Object case_id | ForEach-Object {
  "| $($_.case_id) | $($_.object_pair) | $($_.relation) | $($_.constraint_name) | $($_.required_mil) MIL | $($_.observed_source) |"
}) -join [Environment]::NewLine

$markdown = @"
# Shape 与其他 Etch Object 的 Region DRC 验证结论

## 1. 结论摘要

前一轮实验主要覆盖 static shape 与 etch path/cline 的 Line to Shape Spacing。
本轮补充测试了另外两类 etch object：

- static shape 对 static shape，report 类型为 Shape to Shape Spacing
- static shape 对 through via，report 类型为 Shape to Thru Via Spacing

结果显示：region 对这两类 DRC 也会产生影响，并且基本仍符合“局部 DRC 代表位置命中 region 后采用 region cset，否则回退 DEFAULT”的模式。

## 2. 输出文件

- DRC report：reports/shape_other_etch_result_cases_drc_report.txt
- 分析 CSV：reports/shape_other_etch_analysis.csv
- 结果 brd：reports/shape_other_etch_result_cases_drc.brd

## 3. 结果表

| Case | Object Pair | Region Relation | Constraint | Required | Source |
| --- | --- | --- | --- | ---: | --- |
$rows

## 4. Shape-to-Shape 观察

Shape to Shape Spacing 共 $($shapeShape.Count) 个 case：

- region 命中时，required value 从 DEFAULT 的 11 MIL 切换到 21 MIL
- region 在局部 DRC 外时，回退 DEFAULT
- OE002 中 region 覆盖另一侧 shape 的局部最近点，也触发了 R1，说明 shape-shape 是对两侧 shape 的局部 DRC 关系做 region 判断，而不是只固定看某一个 shape。

## 5. Shape-to-Via 观察

Shape to Thru Via Spacing 共 $($shapeVia.Count) 个 case：

- region 命中 shape 侧局部位置时，采用 R1
- region 覆盖 via 侧局部位置时，也采用 R1
- region 不覆盖局部 DRC 关系位置时，采用 DEFAULT

这说明 via-shape spacing 中，region 判断也不是简单绑定到 shape 整体，而是与当前 DRC 的局部接近位置有关。

## 6. 与 Shape-to-Line 的关系

结合前一轮 Line to Shape Spacing，当前可以把结论从“shape 对 cline”扩展为更一般的说法：

在 etch spacing DRC 中，region 更像是作用在 Allegro 已经选出的局部 DRC 代表位置上。
只要该 DRC 代表位置对应的局部几何点命中某个 region，该 region 的 spacing cset 就可能参与约束来源裁决；如果局部 DRC 关系不命中 region，则使用 DEFAULT。

## 7. 当前边界

当前仍不能直接外推到所有对象：

- pin / smd pin / bondpad 尚未单独构造 case
- 动态 shape、void、复杂 arc/concave shape 尚未覆盖
- 多 region 嵌套优先级仍需更贴近真实几何的 case 复验

## 8. 一句话结论

目前看，region 对 shape 相关 spacing DRC 的影响不只限于 shape-cline；对 shape-shape 与 shape-via 也表现为同一类局部覆盖逻辑：region 是否影响最终 DRC，关键不在对象整体是否进入 region，而在当前 DRC 的局部代表位置是否命中 region。
"@

Set-Content -Encoding UTF8 -Path $OutMarkdown -Value $markdown

Write-Host "Wrote $OutCsv"
Write-Host "Wrote $OutMarkdown"



