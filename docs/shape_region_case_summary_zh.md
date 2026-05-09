# Shape Region DRC 验证 Case 中文总结

## 1. 背景

本仓库用于调研 Allegro 中 `region` 对 `static shape + shape-to-line`
spacing DRC 的影响。现有观察结果显示，Allegro 的行为不像是简单地按
shape、line 与 region 的整体空间关系决定约束来源，而更像是围绕某个被选中的
局部 DRC 参考点进行判断。

本次新增的 case 设计目标，是把已有观察沉淀成可复验、可扩展、可脚本化的测试
集合，用于验证当前规则假设是否稳定。

## 2. 当前待验证的核心假设

当前调研结果可以概括为三层模型：

1. **代表 DRC 位置选择**
   - 当 shape 与 line 之间的最短连接关系唯一时，直接使用该最短连接位置。
   - 当存在一段平行或近似等距的候选最短间距区域时，Allegro 可能会先从中选择
     一个代表性 DRC 位置。

2. **单 region 有效性判定**
   - 约束来源更像是由代表 DRC 位置对应的 `shape-side reference point`
     决定，而不是由 line-side DRC marker 或对象整体关系决定。
   - 当前样本支持：
     - `inside`：region 生效
     - `on boundary`：region 生效
     - `outside`：回退到 default

3. **多 region 裁决**
   - 多个 region 同时出现时，并不是直接对所有附近 region 取最大 spacing。
   - 更可能的流程是：先筛选对当前参考点有效的 region，再在有效 region 内裁决。
   - 当前样本支持：
     - 非嵌套或交叉场景下，结果倾向于取更严格 spacing。
     - 嵌套场景下，更具体的内层 region 可能优先于外层 region，即使外层值更严格。

## 3. 新增 Case 分组

本次设计共新增 43 个 case，分为 7 组。

| 分组 | 数量 | 目的 |
| --- | ---: | --- |
| G1 单 region 边界语义 | 6 | 验证 inside、outside、edge、vertex 的有效性，以及 shape-side 点是否比 line-side marker 更关键 |
| G2 shape-side 几何类型 | 6 | 验证 vertex、直边中点、arc 中点、凹顶点是否都只受 region 归属影响 |
| G3 整体关系反例 | 4 | 验证 overall cross、mostly inside 等整体关系不能单独决定结果 |
| G4 代表 DRC 位置选择 | 8 | 专门验证非唯一最短间距区域中 Allegro 如何选择代表位置 |
| G5 非嵌套多 region | 8 | 验证多个有效 region 是否取更严格值，以及是否受名称、边界状态、创建顺序影响 |
| G6 嵌套多 region | 7 | 验证内层 region 优先是否稳定，以及三层嵌套是否递归成立 |
| G7 边界容差 | 4 | 验证 exact boundary、一 DBU 内外、近切 arc 等数值容差行为 |

## 4. 优先执行集合

如果测试时间有限，建议优先执行以下最小回归集合：

- G1：`sr015`, `sr016`, `sr019`, `sr020`
- G2：`sr021`, `sr023`
- G4：`sr031`, `sr032`, `sr034`, `sr037`, `sr038`
- G5：`sr039`, `sr040`, `sr043`, `sr044`
- G6：`sr047`, `sr048`, `sr049`, `sr050`, `sr052`
- G7：`sr054`, `sr055`, `sr056`

这组 case 覆盖了当前最关键的风险点：

- shape-side reference point 是否是主判据
- 非唯一最短间距时代表点如何选取
- 非嵌套多 region 是否取更严格值
- 嵌套多 region 是否内层优先
- boundary 判定是否存在容差

## 5. 建议记录字段

每个 case 执行时建议至少记录以下信息：

- DRC origin xy
- Show Constraints 中的 line element location
- Show Constraints 中的 shape element location
- 实际 reported constraint value
- 实际 reported constraint source
- shape-side reference point 相对每个 region 的归属
- region 之间的空间关系：单 region、交叉、相切、嵌套、三层嵌套等
- 与预期是否一致

这些字段可以帮助区分两类问题：

- region 归属判断是否错误
- Allegro 选择的代表 DRC 位置是否与预设不同

## 6. 文件说明

- `docs/shape_region_case_design.md`
  - 英文版详细 case 设计说明。
  - 包含每组 case 的目的、几何变化、预期结果和通过条件。

- `matrix/shape_region_case_matrix.csv`
  - 可脚本化的 case matrix。
  - 每行对应一个 case，包含优先级、对照关系、变化变量、预期结果和待回答问题。

- `docs/shape_region_case_summary_zh.md`
  - 当前中文总结文档。
  - 用于快速理解本轮 case 设计的调研目标和执行重点。

## 7. 后续建议

短期建议先实现 case board 的自动生成与 DRC report 解析能力，使每个 case 都能输出
稳定的实际结果字段。中期建议把 `UNKNOWN` 预期的 case 转化为新的规则结论，逐步更新
matrix 中的 expected source 和 expected value。长期则可以把这套 case 作为兼容模式的
回归测试基线，防止后续 region 规则实现发生不可见退化。
