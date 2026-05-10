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
| OE001 | shape-shape | main shape side inside region | Shape to Shape Spacing | 21 MIL | OE001_R1_CSET |
| OE002 | shape-shape | other shape side inside region | Shape to Shape Spacing | 21 MIL | OE002_R1_CSET |
| OE003 | shape-shape | region outside local DRC | Shape to Shape Spacing | 11 MIL | DEFAULT |
| OE004 | shape-shape | main shape side on boundary | Shape to Shape Spacing | 21 MIL | OE004_R1_CSET |
| OE005 | shape-via | shape side inside region | Shape to Thru Via Spacing | 21 MIL | OE005_R1_CSET |
| OE006 | shape-via | via side inside region | Shape to Thru Via Spacing | 21 MIL | OE006_R1_CSET |
| OE007 | shape-via | region outside local DRC | Shape to Thru Via Spacing | 11 MIL | DEFAULT |
| OE008 | shape-via | shape side on boundary | Shape to Thru Via Spacing | 21 MIL | OE008_R1_CSET |

## 4. Shape-to-Shape 观察

Shape to Shape Spacing 共 4 个 case：

- region 命中时，required value 从 DEFAULT 的 11 MIL 切换到 21 MIL
- region 在局部 DRC 外时，回退 DEFAULT
- OE002 中 region 覆盖另一侧 shape 的局部最近点，也触发了 R1，说明 shape-shape 是对两侧 shape 的局部 DRC 关系做 region 判断，而不是只固定看某一个 shape。

## 5. Shape-to-Via 观察

Shape to Thru Via Spacing 共 4 个 case：

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
