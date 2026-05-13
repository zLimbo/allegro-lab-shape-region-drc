# Region 对 Static Shape 的 Shape-to-Line DRC 影响逻辑结论

## 1. 输入与输出

本结论由脚本 scripts/analyze_shape_region_drc_report.ps1 自动解析 Allegro DRC report 得到。

- 输入 DRC report：reports\shape_region_result_cases_drc_report.txt
- 输入 case matrix：matrix\shape_region_case_matrix.csv
- 明细输出：reports\shape_region_analysis.csv
- 分组统计：reports\shape_region_analysis_by_group.csv
- source 统计：reports\shape_region_analysis_by_source.csv

本次只分析 Line to Shape Spacing，忽略 report 中额外的 Physical Constraint
类 DRC。

## 2. 总体统计

- Shape-to-line DRC 总数：43
- 采用 DEFAULT：12
- 采用 R1 region cset：19
- 采用 R2 region cset：12
- 与 matrix 明确预期匹配：28
- 探索型或 UNKNOWN/SAME 预期：11
- 明确 mismatch：4

| Group | Count | DEFAULT | R1 | R2 | Match | Exploratory | Mismatch |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| G1 | 6 | 1 | 5 | 0 | 5 | 0 | 1 |
| G2 | 6 | 3 | 3 | 0 | 6 | 0 | 0 |
| G3 | 4 | 2 | 2 | 0 | 4 | 0 | 0 |
| G4 | 8 | 5 | 3 | 0 | 2 | 6 | 0 |
| G5 | 8 | 0 | 2 | 6 | 6 | 2 | 0 |
| G6 | 7 | 0 | 1 | 6 | 2 | 2 | 3 |
| G7 | 4 | 1 | 3 | 0 | 3 | 1 | 0 |

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

- inside 命中 region 的样本数：20
- boundary 命中 region 的样本数：10
- outside 回退 DEFAULT 的样本数：8

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

- `SR019`：预期 `DEFAULT`，实际 `R1`，source=`SR019_R1_CSET`
- `SR047`：预期 `R1`，实际 `R2`，source=`SR047_R2_CSET`
- `SR050`：预期 `R1`，实际 `R2`，source=`SR050_R2_CSET`
- `SR052`：预期 `R1`，实际 `R2`，source=`SR052_R2_CSET`

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

补充实验见 docs/shape_other_etch_drc_logic_conclusion_zh.md。该实验覆盖：

- static shape 对 static shape：Shape to Shape Spacing
- static shape 对 through via：Shape to Thru Via Spacing

补充结果显示，上述两类 DRC 也会受 region cset 影响：局部 DRC 位置命中 region 时采用 region cset，局部 DRC 位置不命中 region 时回退 DEFAULT。因此，当前结论已不只限于 shape-cline，而可以谨慎扩展为 shape 相关 etch spacing DRC 的局部 region 覆盖模型。
