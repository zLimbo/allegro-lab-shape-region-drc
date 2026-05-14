<a id="english"></a>

# Allegro Lab: Shape Region DRC

[English](#english) | [中文](#中文)

This repository is a local research project for characterizing how Cadence Allegro constraint regions affect shape-related etch spacing DRC behavior.

- Main constraint family: physical spacing CSet / region-class-class spacing
- Primary DRC type: `Line to Shape Spacing`
- Supplemental DRC types: `Shape to Shape Spacing`, `Shape to Thru Via Spacing`
- Default spacing used by the lab boards: `11 MIL`
- Region R1 spacing used by the lab boards: `21 MIL`
- Region R2 spacing used by the lab boards: `22 MIL`
- Tested Allegro versions: `Allegro PCB 24.1 S001` and `Allegro PCB 25.1 S030`
- Local Cadence tool path used during testing: `C:\Cadence\SPB_24.1\tools\bin` or `C:\Cadence\SPB_25.1\tools\bin`

The project has verified that Allegro can be driven through no-GUI/batch execution for this workflow:

```powershell
allegro.exe -expert -p . -nographic -s <script.scr> <board.brd>
dbdoctor.exe -drc_only -outfile <out.brd> <in.brd>
report.exe -v drc <board.brd> <report.rpt>
```

## Repository Contents

- `docs/shape_region_case_design.md`: case design notes for the shape-to-line region experiment.
- `docs/shape_region_drc_logic_conclusion_zh.md`: main Chinese conclusion for region behavior on static shape + line spacing.
- `docs/shape_region_case_summary_zh.md`: Chinese summary of the generated case board and case groups.
- `docs/shape_region_experiment_summary_zh.md`: Chinese experiment summary for the generated board and DRC report.
- `docs/shape_other_etch_drc_logic_conclusion_zh.md`: supplemental conclusion for shape-shape and shape-via spacing.
- `docs/allegro_25_1_validation_zh.md`: Allegro 25.1 re-validation notes.
- `matrix/shape_region_case_matrix.csv`: scripted case matrix for the shape-to-line experiment.
- `scripts/generate_shape_region_cases.il`: Allegro SKILL script that generates the 43 shape-to-line region cases.
- `scripts/generate_shape_other_etch_cases.il`: Allegro SKILL script that generates supplemental shape-shape and shape-via cases.
- `scripts/run_shape_region_experiment.ps1`: PowerShell wrapper for generating the main board, running DRC, and exporting the report.
- `scripts/run_shape_other_etch_experiment.ps1`: PowerShell wrapper for the supplemental etch-object board.
- `scripts/analyze_shape_region_drc_report.ps1`: parser and summarizer for the main DRC report.
- `scripts/analyze_shape_other_etch_drc_report.ps1`: parser for the supplemental DRC report.
- `templates/blank_template.brd`: blank Allegro board template used by the generators.
- `reports/shape_region_result_cases_drc.brd`: generated main board with regenerated DRC markers.
- `reports/shape_region_result_cases_drc_report.txt`: exported DRC report for the main board.
- `reports/shape_region_analysis.csv`: parsed per-case result table.
- `reports/shape_region_analysis_by_group.csv`: grouped summary.
- `reports/shape_region_analysis_by_source.csv`: source summary for DEFAULT/R1/R2.
- `reports/shape_other_etch_result_cases_drc.brd`: generated supplemental board with regenerated DRC markers.
- `reports/shape_other_etch_result_cases_drc_report.txt`: exported supplemental DRC report.
- `reports/shape_other_etch_analysis.csv`: parsed supplemental result table.

## Regenerate The Shape Region Board

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_shape_region_experiment.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\analyze_shape_region_drc_report.ps1
```

To run with a specific Allegro installation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_shape_region_experiment.ps1 -Allegro 'C:\Cadence\SPB_25.1\tools\bin\allegro.exe'
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\analyze_shape_region_drc_report.ps1
```

The generated board places cases `SR015` through `SR057` in a grid. Each tile contains a static shape, a line/cline, one or more constraint regions, related spacing CSet assignments, and text labels for the case id and expected behavior.

## Regenerate Supplemental Etch Cases

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_shape_other_etch_experiment.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\analyze_shape_other_etch_drc_report.ps1
```

These cases cover:

- static shape to static shape: `Shape to Shape Spacing`
- static shape to through via: `Shape to Thru Via Spacing`

## Current Boundary Model

The observed behavior is best modeled as:

```text
for a shape-related etch spacing DRC:
  Allegro first chooses a local representative DRC position
  then checks which constraint region contains the local DRC reference point
  if no effective region contains that point, use DEFAULT
  if one effective region contains that point, use that region CSet
  if multiple effective regions contain that point, resolve among those regions
```

For the current static shape + line cases, the important reference point appears to be the shape-side local DRC reference point rather than the overall object relationship. A region that contains this point, including an exact boundary hit, can affect the reported spacing source. A region outside the local DRC relationship falls back to `DEFAULT`.

The main report contains 43 `Line to Shape Spacing` cases:

- `DEFAULT`: 12 cases
- `R1`: 19 cases
- `R2`: 12 cases

The supplemental shape-shape and shape-via cases show the same local-region override pattern: when the local DRC relationship hits a region, the report uses the region CSet; when it does not, the report uses `DEFAULT`.

See `docs/shape_region_drc_logic_conclusion_zh.md` and `docs/shape_other_etch_drc_logic_conclusion_zh.md` for detailed evidence.

## Current Boundaries

The current result should not yet be generalized to every Allegro object or geometry type. The following areas still need dedicated cases:

- pin / SMD pin / bondpad spacing
- dynamic shape behavior
- void behavior
- complex arc or concave shape geometry
- deeper multi-region nested priority rules

---

<a id="中文"></a>

# Allegro Lab: Shape Region DRC

[English](#english) | [中文](#中文)

本仓库用于调研 Cadence Allegro 中 constraint region 对 shape 相关 etch spacing DRC 的真实影响边界。

- 主要约束类型：physical spacing CSet / region-class-class spacing
- 主要 DRC 类型：`Line to Shape Spacing`
- 补充 DRC 类型：`Shape to Shape Spacing`、`Shape to Thru Via Spacing`
- 实验板 DEFAULT spacing：`11 MIL`
- 实验板 R1 region spacing：`21 MIL`
- 实验板 R2 region spacing：`22 MIL`
- 实测 Allegro 版本：`Allegro PCB 24.1 S001` 与 `Allegro PCB 25.1 S030`
- 本地 Cadence 工具路径：`C:\Cadence\SPB_24.1\tools\bin` 或 `C:\Cadence\SPB_25.1\tools\bin`

本项目已验证 Allegro 可以通过 no-GUI/batch 方式执行以下流程：

```powershell
allegro.exe -expert -p . -nographic -s <script.scr> <board.brd>
dbdoctor.exe -drc_only -outfile <out.brd> <in.brd>
report.exe -v drc <board.brd> <report.rpt>
```

## 仓库内容

- `docs/shape_region_case_design.md`：shape-to-line region 实验的 case 设计说明。
- `docs/shape_region_drc_logic_conclusion_zh.md`：static shape + line spacing 的 region 行为主结论。
- `docs/shape_region_case_summary_zh.md`：生成板和 case 分组中文总结。
- `docs/shape_region_experiment_summary_zh.md`：生成板与 DRC report 的实验总结。
- `docs/shape_other_etch_drc_logic_conclusion_zh.md`：shape-shape 与 shape-via spacing 的补充结论。
- `docs/allegro_25_1_validation_zh.md`：Allegro 25.1 复验记录。
- `matrix/shape_region_case_matrix.csv`：shape-to-line 实验的脚本化 case matrix。
- `scripts/generate_shape_region_cases.il`：生成 43 个 shape-to-line region case 的 Allegro SKILL 脚本。
- `scripts/generate_shape_other_etch_cases.il`：生成 shape-shape 与 shape-via 补充 case 的 Allegro SKILL 脚本。
- `scripts/run_shape_region_experiment.ps1`：生成主实验板、刷新 DRC、导出 report 的 PowerShell 封装。
- `scripts/run_shape_other_etch_experiment.ps1`：补充 etch object 实验板的 PowerShell 封装。
- `scripts/analyze_shape_region_drc_report.ps1`：主 DRC report 的解析与汇总脚本。
- `scripts/analyze_shape_other_etch_drc_report.ps1`：补充 DRC report 的解析脚本。
- `templates/blank_template.brd`：生成脚本使用的空白 Allegro board template。
- `reports/shape_region_result_cases_drc.brd`：已刷新 DRC marker 的主实验板。
- `reports/shape_region_result_cases_drc_report.txt`：主实验板导出的 DRC report。
- `reports/shape_region_analysis.csv`：逐 case 解析结果。
- `reports/shape_region_analysis_by_group.csv`：按 group 汇总结果。
- `reports/shape_region_analysis_by_source.csv`：按 DEFAULT/R1/R2 来源汇总结果。
- `reports/shape_other_etch_result_cases_drc.brd`：已刷新 DRC marker 的补充实验板。
- `reports/shape_other_etch_result_cases_drc_report.txt`：补充实验板导出的 DRC report。
- `reports/shape_other_etch_analysis.csv`：补充实验解析结果。

## 重新生成 Shape Region 实验板

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_shape_region_experiment.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\analyze_shape_region_drc_report.ps1
```

指定 Allegro 安装路径时：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_shape_region_experiment.ps1 -Allegro 'C:\Cadence\SPB_25.1\tools\bin\allegro.exe'
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\analyze_shape_region_drc_report.ps1
```

生成板中将 `SR015` 到 `SR057` 共 43 个 case 按网格排列。每个 tile 包含 static shape、line/cline、一个或多个 constraint region、相关 spacing CSet 设置，以及 case id 和预期行为文字标注。

## 重新生成补充 Etch Case

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_shape_other_etch_experiment.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\analyze_shape_other_etch_drc_report.ps1
```

补充实验覆盖：

- static shape 对 static shape：`Shape to Shape Spacing`
- static shape 对 through via：`Shape to Thru Via Spacing`

## 当前边界模型

实测行为更接近以下模型：

```text
for a shape-related etch spacing DRC:
  Allegro 先选择一个局部代表 DRC 位置
  再判断该局部 DRC reference point 命中哪些 constraint region
  如果没有有效 region 命中该点，则使用 DEFAULT
  如果一个有效 region 命中该点，则使用该 region CSet
  如果多个有效 region 命中该点，则只在这些有效 region 中裁决
```

对于当前 static shape + line case，关键参考点更像是 shape-side local DRC reference point，而不是 shape 与 line 的整体空间关系。region 覆盖该点，包括刚好落在边界上时，可以影响 report 中的 spacing source；region 不覆盖局部 DRC 关系时，则回退到 `DEFAULT`。

主 report 中共有 43 个 `Line to Shape Spacing` case：

- `DEFAULT`：12 个
- `R1`：19 个
- `R2`：12 个

补充的 shape-shape 与 shape-via case 也表现出同类局部 region 覆盖逻辑：局部 DRC 关系命中 region 时采用 region CSet，未命中时回退 `DEFAULT`。

详细证据见 `docs/shape_region_drc_logic_conclusion_zh.md` 和 `docs/shape_other_etch_drc_logic_conclusion_zh.md`。

## 当前边界

当前结论不应直接外推到所有 Allegro 对象或几何类型。以下方向仍需单独构造 case：

- pin / SMD pin / bondpad spacing
- dynamic shape 行为
- void 行为
- 复杂 arc 或 concave shape 几何
- 更深层的多 region 嵌套优先级
