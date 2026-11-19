# version23：Q4.10 60 MHz 目标频率实验

2026-11-19。基线为已完成的 version22 / SHA `990539f52e80ca13c49a3a7443e7c15bde34018a`，独立分支 `exp/coursework-v23`，工作目录 `kalman-q4-10-60mhz-v23`。main 和旧版不改。

目的：version22 在50MHz实现下，max_ss STA最小周期15.51ns、Fmax64.49MHz，最差setup+4.494536ns。该数值是旧布局的STA估计，不是新目标实现或测硅结果。先尝试60MHz；只有60MHz失败时才启动独立55MHz实验，保留所有失败原始证据。此轮目标 60MHz / 16.666666667ns。

实际改动：只把src/config.json CLOCK_PERIOD从20ns改为16.666666667ns，info.yaml改为60000000Hz，并配套调整实际执行的有限测试时钟及结果标签；新增最终SDC周期和九角setup/hold/electrical验收。1ps仿真精度下使用偶数ps周期16.666ns（略快于目标），保留原1ns/5ns采样偏移。既有比例接口I/O预算可能随目标周期缩短，最终SDC须审计；不得称全部绝对I/O预算不变。

不变条件：src/project.v、Q4.10位宽/舍入/截断、156FF候选架构、共享30bit工作存储、39/29架构周期、接口与复位、golden RTL和fixture及输入向量、原clock2/8/8和input4修复、fanout10、slew1.5ns、repair30%、75%放置目标、SKY130A/1tile。action395eedb3eeec3c2f4961c3b04ff2cf87f5525636、support-tools9d13ff3e3e6202090740110438c6a10c1d62ca0f固定；不放宽约束、不改变算术逻辑、不穷举。

预期：RTL数值与周期保持，正常更新目标延迟39/60=0.650000µs，原0.78µs。频率提高不减少周期；面积、buffer数量、功耗和新Fmax必须重新测报告，不能从旧结果宣称保证成功。九角setup/hold/slew/cap/fanout、DRC/LVS、GL、precheck都作为验收，生成GDS本身不足以通过。GL依旧UNIT_DELAY而非SDF验证；功耗为无活动回标EDA估算。

测试策略：保留1186组数值、33协议场景、固定随机core、4096周期公共轨迹；本地有限interface+golden trace一次，云端运行原有限套件。原始ZIP/console/XML/波形/病例/GDS/网表/SDF/SPEF/完整物理报告、精确SHA/Run/attempt与SHA256存results/version23，失败不覆盖。

Local Windows Icarus is unavailable (compiler exits0xC0000005); bounded RTL/GL tests run on Ubuntu CI. Standalone benches use integer1ps delays with original sampling offsets preserved. Arithmetic RTL unchanged.
