# version11：Q4.7完整融合更新核

## 基线与改变边界

直接从Q4.6融合版version6精确SHA `3269b76ca0bca967606157de934c40d5d1ffa813`建立exp/coursework-v11。
只做数值位宽与配套修改：X/Z signed11bit Q4.7、P/R unsigned11bit UQ4.7，整数侧4位含符号。
增益8bit/7fraction，delta/S12bit，加减器13bit，乘法工作21bit；两个计数器仍3bit。
R实数5不变，code320改640。接口上字段由2位变3位，仍两次8bit传输。
八状态FSM、共享乘法器、运算顺序、算术右移取整、输出截位、异步reset、busy/ready和同拍write/start采样语义保持。
源自基线的状态case块在归一化两个符号扩展索引后逐字符一致，详见rtl_change_audit.json。

## 预测，与实测分开

正常/快捷周期30/23，FF约144、MUX约107。最终面积中心约12255µm²，预算11274–13235µm²。
原65组相同真实输入的软件模型X/P MAE约0.018115/0.027654。均为实验前估计，不替代RTL或GL。

## 验证策略

原65输入code乘2，另1000个全11bit固定随机输入及44个逐输入bit，共1109组接口向量。
RTL及GL执行相同整数参考和33项协议场景，另有独立本地/云端25个同拍写入启动历史。
核心验证为1196组除法边界/固定随机及2548组乘法边界/固定随机，上限明确；不做全域穷举。
云端保存XML、FST和逐case JSON，artifact上传使用always以保留失败/取消证据。
测试函数数量不作为向量数量；不同测试与重复artifact不合并计数。

## 实现条件和保存

SKY130A、1×1tile、20ns、75%放置目标、1.5ns transition、30%repair保持。
config/info/Makefile及docs工作流与基线逐字节相同。GDS action引用保持，不放宽条件，不改main，不发布Pages。
精确源码/测试/工作流ZIP、原artifact和consoleZIP、case、波形、网表/GDS/SDF/SPEF和完整报告保存results/version11及SHA256清单。
功耗为无工作负载回标的EDA估算；GL使用UNIT_DELAY，不宣称SDF时序签核。保留所有电气违例。
