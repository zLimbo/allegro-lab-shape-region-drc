param(
  [string]$ReportPath = 'reports\shape_region_result_cases_drc_report.txt',
  [string]$MatrixPath = 'matrix\shape_region_case_matrix.csv',
  [string]$OutCsv = 'reports\shape_region_analysis.csv',
  [string]$OutGroupCsv = 'reports\shape_region_analysis_by_group.csv',
  [string]$OutSourceCsv = 'reports\shape_region_analysis_by_source.csv',
  [string]$OutMarkdown = 'docs\shape_region_drc_logic_conclusion_zh.md'
)

$ErrorActionPreference = 'Stop'

function Get-CaseIdFromLocation {
  param([double]$X, [double]$Y)

  $col = [math]::Round(($X - 550.0) / 750.0)
  $row = [math]::Round(($Y - 530.0) / 520.0)
  if ($col -lt 0) { $col = 0 }
  if ($col -gt 5) { $col = 5 }
  if ($row -lt 0) { $row = 0 }

  $idx = [int]($row * 6 + $col)
  if ($idx -lt 0 -or $idx -gt 42) { return 'UNKNOWN' }
  return ('SR{0:D3}' -f ($idx + 15))
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

function Get-ExpectedKind {
  param([string]$ExpectedSource)

  if ([string]::IsNullOrWhiteSpace($ExpectedSource)) { return 'UNKNOWN' }
  $upper = $ExpectedSource.ToUpperInvariant()
  if ($upper -eq 'DEFAULT') { return 'DEFAULT' }
  if ($upper -match '^(R\d+)') { return $matches[1] }
  return $upper
}

$reportFullPath = Resolve-Path $ReportPath
$matrixFullPath = Resolve-Path $MatrixPath

$reportLines = Get-Content -Encoding UTF8 $reportFullPath
$headerIndex = [Array]::FindIndex($reportLines, [Predicate[string]]{
  param($line)
  $line -eq 'Constraint Name,DRC Marker Location,DRC Subclass,Required Value,Actual Value,Constraint Source,Constraint Source Type,Element 1,Element 2'
})

if ($headerIndex -lt 0) {
  throw "Could not find detailed DRC CSV header in $ReportPath"
}

$detailLines = $reportLines[$headerIndex..($reportLines.Count - 1)]
$drcRows = $detailLines | ConvertFrom-Csv | Where-Object {
  $_.'Constraint Name' -eq 'Line to Shape Spacing'
}

$matrixByCase = @{}
Import-Csv -Encoding UTF8 $matrixFullPath | ForEach-Object {
  $matrixByCase[$_.case_id.ToUpperInvariant()] = $_
}

$analysis = foreach ($row in $drcRows) {
  $loc = $row.'DRC Marker Location'
  $x = $null
  $y = $null
  if ($loc -match '\(([-0-9.]+)\s+([-0-9.]+)\)') {
    $x = [double]$matches[1]
    $y = [double]$matches[2]
  }

  $caseId = if ($null -ne $x -and $null -ne $y) { Get-CaseIdFromLocation -X $x -Y $y } else { 'UNKNOWN' }
  $case = $matrixByCase[$caseId]
  $source = $row.'Constraint Source'
  $sourceKind = Get-SourceKind $source
  $expectedKind = if ($case) { Get-ExpectedKind $case.expected_source } else { 'UNKNOWN' }
  $requiredMil = Get-MilValue $row.'Required Value'
  $actualMil = Get-MilValue $row.'Actual Value'

  $expectationStatus = 'unclassified'
  if ($expectedKind -eq 'UNKNOWN' -or $expectedKind -like 'SAME*') {
    $expectationStatus = 'exploratory'
  } elseif ($sourceKind -eq $expectedKind) {
    $expectationStatus = 'match'
  } else {
    $expectationStatus = 'mismatch'
  }

  [pscustomobject]@{
    case_id = $caseId
    group = if ($case) { $case.group } else { '' }
    priority = if ($case) { $case.priority } else { '' }
    marker_x = $x
    marker_y = $y
    required_mil = $requiredMil
    actual_mil = $actualMil
    observed_source = $source
    observed_source_kind = $sourceKind
    expected_source_kind = $expectedKind
    expectation_status = $expectationStatus
    shape_side_reference_relation = if ($case) { $case.shape_side_reference_relation } else { '' }
    region_relation = if ($case) { $case.region_relation } else { '' }
    question_answered = if ($case) { $case.question_answered } else { '' }
  }
}

New-Item -ItemType Directory -Force -Path (Split-Path $OutCsv), (Split-Path $OutMarkdown) | Out-Null
$analysis | Sort-Object case_id | Export-Csv -NoTypeInformation -Encoding UTF8 $OutCsv

$byGroup = $analysis |
  Group-Object group |
  Sort-Object Name |
  ForEach-Object {
    [pscustomobject]@{
      group = $_.Name
      count = $_.Count
      default_count = @($_.Group | Where-Object observed_source_kind -eq 'DEFAULT').Count
      r1_count = @($_.Group | Where-Object observed_source_kind -eq 'R1').Count
      r2_count = @($_.Group | Where-Object observed_source_kind -eq 'R2').Count
      match_count = @($_.Group | Where-Object expectation_status -eq 'match').Count
      exploratory_count = @($_.Group | Where-Object expectation_status -eq 'exploratory').Count
      mismatch_count = @($_.Group | Where-Object expectation_status -eq 'mismatch').Count
    }
  }
$byGroup | Export-Csv -NoTypeInformation -Encoding UTF8 $OutGroupCsv

$bySource = $analysis |
  Group-Object observed_source_kind |
  Sort-Object Name |
  ForEach-Object {
    [pscustomobject]@{
      observed_source_kind = $_.Name
      count = $_.Count
      cases = ($_.Group | Sort-Object case_id | ForEach-Object case_id) -join ', '
    }
  }
$bySource | Export-Csv -NoTypeInformation -Encoding UTF8 $OutSourceCsv

$total = @($analysis).Count
$defaultCount = @($analysis | Where-Object observed_source_kind -eq 'DEFAULT').Count
$r1Count = @($analysis | Where-Object observed_source_kind -eq 'R1').Count
$r2Count = @($analysis | Where-Object observed_source_kind -eq 'R2').Count
$matchCount = @($analysis | Where-Object expectation_status -eq 'match').Count
$exploratoryCount = @($analysis | Where-Object expectation_status -eq 'exploratory').Count
$mismatchRows = @($analysis | Where-Object expectation_status -eq 'mismatch' | Sort-Object case_id)

$insideRows = @($analysis | Where-Object { $_.shape_side_reference_relation -match 'inside' -and $_.observed_source_kind -ne 'DEFAULT' })
$outsideRows = @($analysis | Where-Object { $_.shape_side_reference_relation -eq 'outside' -and $_.observed_source_kind -eq 'DEFAULT' })
$boundaryRows = @($analysis | Where-Object { $_.shape_side_reference_relation -match 'edge|vertex|boundary' -and $_.observed_source_kind -ne 'DEFAULT' })
$multiRegionRows = @($analysis | Where-Object { $_.region_relation -match 'overlap|touch|nested|non_nested|inside_both|nested_3' -or $_.observed_source_kind -eq 'R2' })

$groupTable = ($byGroup | ForEach-Object {
  "| $($_.group) | $($_.count) | $($_.default_count) | $($_.r1_count) | $($_.r2_count) | $($_.match_count) | $($_.exploratory_count) | $($_.mismatch_count) |"
}) -join "`n"

$mismatchText = if ($mismatchRows.Count -eq 0) {
  '未发现按 matrix 中明确预期分类后的 mismatch。'
} else {
  ($mismatchRows | ForEach-Object {
    ('- `{0}`：预期 `{1}`，实际 `{2}`，source=`{3}`' -f $_.case_id, $_.expected_source_kind, $_.observed_source_kind, $_.observed_source)
  }) -join "`n"
}

$markdown = @"
# Region 对 Static Shape 的 Shape-to-Line DRC 影响逻辑结论

## 1. 输入与输出

本结论由脚本 scripts/analyze_shape_region_drc_report.ps1 自动解析 Allegro DRC report 得到。

- 输入 DRC report：$ReportPath
- 输入 case matrix：$MatrixPath
- 明细输出：$OutCsv
- 分组统计：$OutGroupCsv
- source 统计：$OutSourceCsv

本次只分析 Line to Shape Spacing，忽略 report 中额外的 Physical Constraint
类 DRC。

## 2. 总体统计

- Shape-to-line DRC 总数：$total
- 采用 DEFAULT：$defaultCount
- 采用 R1 region cset：$r1Count
- 采用 R2 region cset：$r2Count
- 与 matrix 明确预期匹配：$matchCount
- 探索型或 UNKNOWN/SAME 预期：$exploratoryCount
- 明确 mismatch：$($mismatchRows.Count)

| Group | Count | DEFAULT | R1 | R2 | Match | Exploratory | Mismatch |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
$groupTable

## 3. 从报告反推的核心逻辑

当前实验支持如下 region 生效逻辑：

1. Allegro 先产生一个实际用于该 DRC 的代表位置。
2. 对 static shape + shape-to-line 来说，region 是否生效更接近于判断该代表位置对应的 shape 侧参考点是否落入 region。
3. 若 shape 侧参考点在 region 内，或位于 region 边界上，则 report 会采用对应 region cset。
4. 若 shape 侧参考点不在 region 中，则 report 回退到 DEFAULT。
5. 当多个 region 同时有效时，report 会在有效 region 中进行裁决。非嵌套/接触/重叠场景中，本实验多表现为采用更严格值；嵌套场景仍需结合真实几何继续验证，因为当前 scaffold 中部分嵌套 case 仍出现 R2 更严格值优先。

## 4. 单 Region 结论

单 region case 的主要结论是：inside 和 on boundary 都可以让 region 生效，outside
则回退 DEFAULT。

- inside 命中 region 的样本数：$($insideRows.Count)
- boundary 命中 region 的样本数：$($boundaryRows.Count)
- outside 回退 DEFAULT 的样本数：$($outsideRows.Count)

这说明整体关系如 cross、mostly inside、no cross 不能单独作为主判据。
更稳定的判据是当前 DRC 代表点对应的 shape-side reference point 的 region 归属。

## 5. 多 Region 结论

本次 report 能清楚区分 R1 / R2：

- 当最终 source 为 SRxxx_R1_CSET 时，Required Value 为 21 MIL。
- 当最终 source 为 SRxxx_R2_CSET 时，Required Value 为 22 MIL。
- 当最终 source 为 DEFAULT 时，Required Value 为 11 MIL。

多 region case 表明：Allegro 并非只看附近所有 region，而是先筛选对当前 DRC 代表点有效的 region，再在有效 region 中裁决。否则不会出现同一张板中 DEFAULT、R1、R2 并存的结果。

## 6. 代表 DRC 位置

G4 相关 case 中，同样的平行/近似等距几何会因 region 覆盖位置不同而得到 DEFAULT 或 R1。
这说明当最短距离候选位置不唯一时，不能用“只要某处命中 region 就采用 region”解释。
更合理的模型是：先选代表 DRC 位置，再判断该代表点的 shape-side reference point 是否命中 region。

## 7. 当前 Mismatch / 未定项

$mismatchText

另外，当前实验板仍有 scaffold 限制：

- G2 中 arc/concave 相关 case 目前仍是矩形基础几何 placeholder。
- G6 中嵌套 region 的“内层优先”需要用更贴近原始图形的嵌套几何继续复验。
- 当前自动分析通过 DRC marker 坐标反推 case id，适合本实验板网格布局；若后续更改 tile 布局，需要同步更新脚本中的映射参数。

## 8. 可作为实现参考的规则

面向兼容实现，可暂按以下顺序处理：

~~~text
选择代表 DRC 位置
-> 找到该位置对应的 shape-side reference point
-> 过滤包含该点或边界命中该点的 region
-> 无有效 region 时采用 DEFAULT
-> 单个有效 region 时采用该 region cset
-> 多个有效 region 时进入 region 裁决
~~~

其中，多 region 裁决当前建议保守处理：

- 非嵌套/重叠/接触：优先验证并采用更严格 spacing 值。
- 嵌套/包含：不要简单全局取最大值，需要继续用真实嵌套 case 确认是否存在内层优先。

## 9. 一句话结论

在当前 static shape + shape-to-line 范围内，region 对 shape DRC 的影响不是对象整体进入区域后统一生效，而是更像附着在 Allegro 内部 DRC 代表点选择之后的局部约束覆盖：代表点的 shape 侧参考位置命中哪个 region，哪个 region 才有资格影响最终 spacing 约束。

## 10. 对其他 Etch Object 的补充

补充实验见 `docs/shape_other_etch_drc_logic_conclusion_zh.md`。该实验覆盖：

- static shape 对 static shape：`Shape to Shape Spacing`
- static shape 对 through via：`Shape to Thru Via Spacing`

补充结果显示，上述两类 DRC 也会受 region cset 影响：局部 DRC 位置命中 region 时采用 region cset，局部 DRC 位置不命中 region 时回退 DEFAULT。因此，当前结论已不只限于 shape-cline，而可以谨慎扩展为 shape 相关 etch spacing DRC 的局部 region 覆盖模型。
"@

Set-Content -Encoding UTF8 -Path $OutMarkdown -Value $markdown

Write-Host "Wrote $OutCsv"
Write-Host "Wrote $OutGroupCsv"
Write-Host "Wrote $OutSourceCsv"
Write-Host "Wrote $OutMarkdown"



