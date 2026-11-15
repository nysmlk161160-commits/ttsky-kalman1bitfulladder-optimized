# version10：完整融合Kalman更新核的12-bit Q4.8精度扩展

基线为归档version6/PPT融合V7，SHA `3269b76ca0bca967606157de934c40d5d1ffa813`。
独立目录kalman-q4-8-v10，分支exp/coursework-v10。不是从诊断version9派生。

## 本次改变及目的

X/Z由signed10-bit Q4.6扩为signed12-bit Q4.8，整数侧4位包含符号位。
P/R由unsigned10-bit UQ4.6扩为unsigned12-bit UQ4.8。范围大体保持，正端点略有扩展。
数值步长从1/64变为1/256。K由7位UQ1.6扩为9位UQ1.8，包含K=1的code256。
delta和S由11扩13位；融合加减器12扩14位；乘法工作寄存器19扩23位；乘法计数器3扩4位。
R默认实数值5不变，code320改为1280。
固定8-bit数据接口不变，仍分两次传输，第二次有效位从2变4；不宣称旧二进制数据协议位精确兼容。
八状态调度和单个共享乘法器保留，不做寄存器复用、不加流水。

## 整数定义

S=P+R，delta=signed(Z)-signed(X)，G=floor(256P/S)，S=0时G=0。
Xout=(X+floor(G*delta/256)) mod4096；Pout=(P-floor(G*P/256)) mod4096。
负数算术右移向负无穷取整，输出截低12位，异步复位及原输入保持/结果读回行为保留。
同拍IDLE写入和start按原非阻塞语义：delta/S捕获旧输入，下一拍除法读live P，最后ALU读live X/P。
本次不改变该语义，协议测试独立覆盖它。

## 周期预测，尚非实测

除法8轮，乘法9轮且使用两次，加7个调度周期。正常33、快捷25周期。
预计FF约157；MUX约117–127；最终面积约12500–13300µm²，仅为先前模型，不是承诺。

## 测试策略

原65组输入code乘4，使实数输入一致；另1000组完整12-bit随机及48个逐输入bit用例。
共1113接口数值向量。原65组与旧版原始RTL/GL实际输出分别评估相对理想实数的MAE/RMSE。
穷举4096×4096=16777216组P/R和257×8192=2105344组增益/有符号乘数。
云端RTL及UNIT_DELAY GL还覆盖24组同拍写入启动、历史反例、busy写入/重启、ready保持、重复启动、upper字节掩码、多个阶段reset和默认R恢复。
XML测试函数数不等于向量数，不累加重复artifact或相互重叠测试。

## 不变实现条件

SKY130A、1×1tile、20ns、75%放置目标、1.5ns transition、30%repair margin。
src/config.json、info.yaml、Makefile与原版逐字节相同，保留GDS action引用、IO及PVT。
不放宽约束以取得成功，不改main、不发布Pages。保留失败尝试和精确SHA证据。
原ZIP、日志、源码、XML、波形、case、GDS/网表/SDF/SPEF和九角报告保存在results/version10。
功耗没有工作负载回标时只称EDA估算。GL单位延迟模型不等于SDF时序签核。
