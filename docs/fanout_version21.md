# version21 Q4.10 时钟根扇出修复

2026-11-16，唯一设计对照为version20，精确提交d4f1fb9799c3a457e1f1a69625ee7e1a6283e83d。新分支exp/coursework-v21，独立目录kalman-q4-10-fanout-v21；不修改main或旧版证据。

目的：在MAX_FANOUT_CONSTRAINT=10保持的条件下，检验根时钟节点16路负载能否拆为2个新时钟buffer、每个驱动8个原分支，消除既有fanout违例并完成GDS。新增LibreLane自动发现插件及CTS后、保持时间修复前的单个物理步骤，使用两个sky130_fd_sc_hd__clkbuf_8，按已有负载物理位置最长轴二分并标准详细布局合法化。根预期扇出16→2，新分支8/8；增加两个时钟单元，净PPA不预设。

算术RTL、完整测试、Q4.10格式及接口/复位均与version20字节相同；FF/MUX及综合结果预期保持156/138。RTL39/29、GL40/30为待重新核对的期望。SKY130A、1tile、20ns、75%placement、1.5ns transition、30%repair及fanout10不变。GDS action与tt-support-tools显式固定到version20实际使用提交；LibreLane仍3.0.14。唯一物理变化为根时钟分配；不能把新增检查造成的失败误称为没有GDS。

有限验证：本地1186数值及4096周期golden轨迹；云端沿用原数值、协议、算术固定随机和轨迹套件，不穷举。新步骤在CTS后立即断言原16→新2/8/8，异常则停；完成时额外检查最终九角电气违例为0、原SDC限制10及新拓扑。随后门级仿真、precheck、DRC/LVS、setup/hold、面积与功耗对账。保持时间修复或布局失败则原样保存attempt，分析原因后再改，不放宽约束。

源码/测试/配置/workflow精确快照与SHA256、原始artifact及console ZIP、XML/波形/病例、GDS/网表/SDF/SPEF及完整物理报告存results/version21。每次SHA、Run ID及attempt分别归档；原始失败证据不替换。实验日志两章增加思考路径和逐版记录。功耗无活动回标，GL为UNIT_DELAY，不能称SDF动态或测硅签核。

## 第二次提交完成GDS后的针对性收敛

61ab8be6426d88a5ed225310b8645cf463d4fc22 / GDS Run43905022361 attempt1已生成GDS，原根fanout问题全部消除，setup/hold和DRC/LVS通过；最终新增全角验收发现_1358_/Y的一条数据网max_ss电容0.059809pF超过0.052195pF，输出和三个输入的slew约1.66765ns超过1.5ns，因此CI失败，GL/precheck跳过。完整原始产物保持。

下一次只将该已定位驱动门从sky130_fd_sc_hd__a211oi_2升级到库内同函数、同引脚的a211oi_4，放在同一物理步骤中重新合法化；RTL、FF/MUX及全部原约束保持。此后PPA包含两级时钟分支及一个数据驱动门增强的合计成本，不能归为仅两个buffer的纯面积变化。不做参数穷举，不提高电容/边沿限值。
