# version20 Q4.10 共享工作存储

从已成功的version19精确提交9a477f9fd38d42c14982b259cbb48b3a15714b58扩展数值格式至Q4.10。主要对照为原结构Q4.10/version18（364c52d1b72f4f0ec7db6360e24cceffe370c8cf），不重写其失败记录。
数据14bit F10，signed X/Z范围[-8,7.9990234375]，unsigned P/R最大15.9990234375，LSB1/1024；K11、delta/S/余数15、加减器16、逻辑乘积27（有效26），两核迭代计数器4位。默认R实数5、编码5120。
复用S15+余数15+乘积26共56位为30位工作bank；FF候选182→156，26 FF毛面积683.1552µm²。保持39/29 RTL周期、原输入/输出与同拍write/start历史、异步复位及两套算术路径，不叠加去复位、计数器共享或放宽物理约束。
验证1186个有限数值、33协议场景、25独立同拍历史，算术固定边界面板+各1000固定随机；4096周期公共端口轨迹直接对照精确原Q4.10 RTL，覆盖各阶段读回和reset中止，供RTL/GL回放。没有全域穷举，各仿真有超时。
保持SKY130A、1tile、20ns、75%placement、1.5ns transition、30%repair；config/info/Makefile/docs workflow与version18字节一致。关键问题是能否通过version18失败的CTS后hold修复与详细布局。
若失败，保留错误原文、停止阶段和全部原始attempt，不放宽密度/时钟等条件；阶段面积不写成最终面积，缺失不补零。若成功，完整收集GDS、GL、precheck、9角时序、电气违例、面积/功耗及网表单元对账。
分支exp/coursework-v20；源码、测试、配置、workflow精确快照及原始artifact/console ZIP、XML/波形/病例、GDS/网表/SDF/SPEF和完整报告保存在results/version20。精确Git对象字节另存并保留SHA256。main不修改，大产物不推GitHub，不发布Pages。
功耗为无活动回标EDA估算；GL为UNIT_DELAY，非SDF动态签核。最终面积只能与成功的同阶段结果比较；version18不存在最终PPA，不能计算相对其最终面积下降百分比。
