# Allegro 25.1 Region DRC 复验记录

## 1. 复验环境

- Allegro：`C:\Cadence\SPB_25.1\tools\bin\allegro.exe`
- 实测版本：`25.1-S030`
- 复验日期：2026-05-13
- 工作目录：`D:\pcb\allegro-lab-shape-region-drc`

## 2. 复验命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_shape_region_experiment.ps1 -Allegro 'C:\Cadence\SPB_25.1\tools\bin\allegro.exe'
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_shape_other_etch_experiment.ps1 -Allegro 'C:\Cadence\SPB_25.1\tools\bin\allegro.exe'
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\analyze_shape_region_drc_report.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\analyze_shape_other_etch_drc_report.ps1
```

## 3. Shape-to-Line 结果

- DRC report：`reports/shape_region_result_cases_drc_report.txt`
- 分析 CSV：`reports/shape_region_analysis.csv`
- DRC 总数：86
- `Line to Shape Spacing` case 数：43
- source 分布：DEFAULT 12，R1 19，R2 12

25.1 下的明确预期 case 仍保持原结论：

- 单 region：inside / boundary 命中 region 时采用 region cset，outside 回退 DEFAULT。
- 多 region：先筛选对局部 DRC 代表位置有效的 region，再进入 region 裁决。
- 原先记录的 exploratory / mismatch 项仍集中在代表点选择和嵌套 region 裁决，不构成 25.1 的新行为变化。

与旧报告相比，25.1 中少数 DRC marker 坐标出现 10.5 MIL 或 13.2 MIL 级别的代表点位置差异，但 constraint source 与 required value 的归类保持一致。

## 4. 其他 Etch Object 结果

- DRC report：`reports/shape_other_etch_result_cases_drc_report.txt`
- 分析 CSV：`reports/shape_other_etch_analysis.csv`
- DRC 总数：8
- 覆盖对象：static shape 对 static shape、static shape 对 through via

结果如下：

| Case | Object Pair | Constraint | Required | Source |
| --- | --- | --- | ---: | --- |
| OE001 | shape-shape | Shape to Shape Spacing | 21 MIL | OE001_R1_CSET |
| OE002 | shape-shape | Shape to Shape Spacing | 21 MIL | OE002_R1_CSET |
| OE003 | shape-shape | Shape to Shape Spacing | 11 MIL | DEFAULT |
| OE004 | shape-shape | Shape to Shape Spacing | 21 MIL | OE004_R1_CSET |
| OE005 | shape-via | Shape to Thru Via Spacing | 21 MIL | OE005_R1_CSET |
| OE006 | shape-via | Shape to Thru Via Spacing | 21 MIL | OE006_R1_CSET |
| OE007 | shape-via | Shape to Thru Via Spacing | 11 MIL | DEFAULT |
| OE008 | shape-via | Shape to Thru Via Spacing | 21 MIL | OE008_R1_CSET |

25.1 中 OE005 / OE008 的 via DRC marker Y 坐标相对旧版本发生偏移，但 source 仍为 R1，OE007 仍回退 DEFAULT。

## 5. 复验结论

在 Allegro 25.1-S030 上，上述 case 支持原结论仍有效：

region 对 shape 相关 etch spacing DRC 的影响不是对象整体进入 region 后统一生效，而是作用在当前 DRC 的局部代表位置上；局部代表位置命中 region 时采用对应 region cset，未命中时回退 DEFAULT。该结论已由 shape-cline、shape-shape、shape-via 三类 spacing DRC 共同验证。

仍需保留的边界：pin / smd pin / bondpad、dynamic shape、void、复杂 arc/concave shape、多层嵌套 region 的优先级，仍不应直接外推。
