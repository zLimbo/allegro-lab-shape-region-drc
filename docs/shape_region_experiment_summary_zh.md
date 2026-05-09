# Shape Region Case 实验结果总结

## 1. 生成物

本次已使用本机 Allegro PCB no-gui 模式生成并执行 DRC：

- 结果板文件：`reports/shape_region_result_cases_drc.brd`
- DRC 报告：`reports/shape_region_result_cases_drc_report.txt`
- 按 case 汇总 CSV：`reports/shape_region_result_summary.csv`
- 生成 journal：`reports/generate.jrl`
- DRC 更新日志：`reports/dbdoctor.log`

板内将 `SR015` 到 `SR057` 共 43 个 case 按网格排列。每个 tile 包含：

- static shape
- line / cline
- 一个或多个 constraint region
- case id、分组、region 关系、预期结果等文字标注

## 2. 执行方式

可复现实验命令：

```powershell
.\scripts\run_shape_region_experiment.ps1
```

脚本流程：

1. 打开 `templates/blank_template.brd`
2. 载入 `scripts/generate_shape_region_cases.il`
3. 生成 43 个 case 的几何、region、netclass、spacing cset、region-class-class table
4. 保存 `out/shape_region_result_cases.brd`
5. 使用 `dbdoctor.exe -drc_only` 更新 DRC
6. 使用 `report.exe -v drc` 导出 DRC 报告
7. 将最终 brd/report/log 复制到 `reports/`

## 3. 约束设置

本实验板使用 mil 作为当前设计单位：

- DEFAULT line-to-shape spacing：`11 MIL`
- R1 spacing：通常为 `21 MIL`
- R2 spacing：通常为 `22 MIL`
- 实际 line-to-shape 间距：`10 MIL`

这样可以保证 default 与 region 规则都会产生 DRC，便于从 report 中观察实际采用的
constraint source 和 required value。

## 4. 当前报告结果

`dbdoctor` 更新后，报告中共有：

- `Etch to Etch`: 43 条
- `Physical Constraint`: 43 条
- 总计：86 条

其中本轮关注的是 `Line to Shape Spacing` 这 43 条。额外的 `Physical Constraint`
来自线宽小于默认 physical minimum neck width，不参与 region-to-shape-spacing
结论分析。

从 `reports/shape_region_result_summary.csv` 可见：

- 部分 case 采用 `DEFAULT = 11 MIL`
- 命中 R1 的 case 采用 `SRxxx_R1_CSET = 21 MIL`
- 命中更严格 R2 的多 region case 采用 `SRxxx_R2_CSET = 22 MIL`

这说明本轮生成板已经能够让 Allegro no-gui DRC 报告区分 default、R1、R2 三类约束来源。

## 5. 当前观察重点

从首轮自动报告看，以下方向已经可以继续做人工/脚本化核对：

1. `inside` 与 `on_edge` / `on_vertex` case 能触发 region cset。
2. `outside` case 能回退到 DEFAULT。
3. 多 region overlap/touch/nested case 中，报告能够显示 R1/R2 的裁决结果。
4. 非唯一最短间距相关 case 已在板内铺好，可进一步结合 DRC marker location 与 region 覆盖范围分析代表点选择。

## 6. 注意事项

当前板是第一版实验 scaffold，主要目标是把 43 个 case 自动落成可检查 brd。

其中 G2 的 arc/concave 相关 case 当前仍以矩形基础几何承载并在文字中标注为
placeholder，后续若要专门验证 arc midpoint 或 concave vertex，需要继续扩展
Skill 脚本，使用 path arc 或 polygon 生成真实弧边/凹顶点几何。

此外，当前 line 通过一个远离测试间距的小型同网 copper island 保持在 `SRD_LINE`
网络上，这是为了避免 Allegro 将孤立 cline 报告为 `Not On A Net`，从而绕过
region-class-class spacing 表。
