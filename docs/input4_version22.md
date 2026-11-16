# version22 Q4.10 input4 数据扇出修复计划

2026-11-16。唯一直接对照为version21最终提交907d8724dab8c5fb4d113d4dbf1b914990b19fc8，独立分支exp/coursework-v22，独立目录kalman-q4-10-input4-v22。main与旧实验不修改。

已定位原因：input4为sky130_fd_sc_hd__clkdlybuf4s25_1，输入ui_in[2]、输出net4。综合后布局修复、CTS及CTS后保持时间修复阶段均驱动8个MUX输入；到详细布线时新增ANTENNA_6/7/8三个diode_2保护单元，最终8+3=11，超过原fanout10。不是算术RTL多出逻辑，也不是已修复的时钟根再次失败。阶段原网表及SHA保留，不能忽略二极管负载或放宽限制。

实际方案：保留version21的根时钟2/8/8及_1358_同函数驱动增强。在同一CTS后、标准保持时间修复前的物理步骤中，针对input4的8个MUX负载按物理最长轴二分，将其中4个转到一个新增非反相sky130_fd_sc_hd__buf_4输出。原net4直接负载8→5（4个MUX+新buffer），新分支4，给后续天线保护留余量。新增单元接原电源、标准详细布局合法化，再走原保持时间修复/天线修复/布线。只改变等价物理数据分配，不修改任何RTL或测试。

预期：FF156、MUX138、综合面积11457.2384µm²及RTL39/29保持；新GL40/30需实际确认。input4最终扇出应≤10，九角所有fanout/slew/cap以及setup/hold通过，GDS、GL、precheck完成。新增buffer的面积、布线变化及修复单元净变化按最终报告记录，不预设一定增减。

不变条件：Q4.10共享工作存储RTL、接口/复位、原有限测试、SKY130A、1x1tile、20ns、75%placement、1.5ns transition、30%repair、MAX_FANOUT_CONSTRAINT=10；action395eedb3eeec3c2f4961c3b04ff2cf87f5525636、support-tools9d13ff3e3e6202090740110438c6a10c1d62ca0f、LibreLane3.0.14。

验证：本地1186数值与4096周期golden公共轨迹；云端沿用原有限数值/33协议/固定随机core/公共轨迹，不运行穷举。新增步骤断言原8个MUX、分支5/4；最终断言原SDC10、根2/8/8和两个数据分支≤10，完整九角检查归零后才进入GL/precheck。保留所有失败尝试再修复。精确SHA/Run ID/attempt、源码/测试/config/workflow原Git字节、ZIP/console/XML/FST/病例/GDS/网表/SDF/SPEF/全报告及SHA256均存results/version22；更新两章实验日志。EDA功耗无工作负载回标，GL为UNIT_DELAY。
