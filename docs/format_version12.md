# version12 Q4.5 融合更新核

直接从Q4.6/version6精确SHA 3269b76ca0bca967606157de934c40d5d1ffa813派生，分支exp/coursework-v12。
只改数值位宽、标度、符号扩展、掩码、循环计数及默认R编码；八状态FSM、共享运算结构和原接口历史保持。
signed X/Z为9bit Q4.5，范围[-8,7.96875]；P/R为相同总宽度无符号格式。
LSB=0.03125；K6bit，加减器11bit，乘法工作17bit。R实数5保持。
预测FF120、正常/快捷周期24/19。若物理失败，不放宽条件；保留停止阶段、面积/密度/时序及错误原文。
有限接口测试1101组、协议33组、独立同拍历史25组；算术仅边界面板和各1000固定随机，仿真超时60秒，不运行任何全域穷举。
共同实数输入采用65组Q4.5网格；F>=6另保留原65组Q4.6相同实数输入。最小格式的输入舍入与输出算术误差分开统计。
保持SKY130A、1tile、20ns、75%放置目标、1.5ns transition、30%repair；config/info/Makefile/docs workflow与基线逐字节相同。
原始源码、workflow、ZIP、console、XML/FST/cases、GDS/网表/SDF/SPEF/物理报告保存在results/version12，SHA256核验；main不改，Pages不发布。
功耗为EDA估算，GL为UNIT_DELAY，不等于SDF动态签核；原始失败与电气问题如实保留。
