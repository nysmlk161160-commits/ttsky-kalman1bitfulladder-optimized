# version19 Q4.6 S/余数/乘积工作存储复用

直接基于version6精确提交3269b76ca0bca967606157de934c40d5d1ffa813，分支exp/coursework-v19。
目标：在保持原Q4.6数值、输入/输出保持、同拍write/start旧/新操作数历史、busy/ready/reset及27/21周期下，将S11+余数11+有效乘积18共40个FF，改为共享22位工作存储，候选总FF132→114。
只改工作数据存储。两个12位算术路径、两组计数器、running/done、K、delta、持久输入和输出都保持。所有数据继续异步复位；不叠加去复位、无效期自由更新或计数器共享。原算术叶模块只作为有限算术检查参考保留，不从顶层实例化，综合应消除未使用模块。
乘积原声明19位中重复符号位已被原综合合并，本版显式以连线重建，不把已消除的冗余位重引入bank。
预期：FF约114，周期保持；减少18个FF的毛面积472.9536µm²，不承诺最终面积减少5.42%，新增MUX/控制/修复需扣除。
验证：1170个有限接口用例、33协议历史、25独立同拍历史、边界+各1000固定随机的算术检查；新增4096周期公共端口轨迹与精确原RTL逐周期比较，并用于RTL/GL回放。没有全域穷举，所有仿真设超时。
不变条件：SKY130A、1tile、20ns、75%placement、1.5ns transition、30%repair；config/info/Makefile/docs workflow与原版逐字节一致。
源码、测试、workflow与配置精确快照，原始artifact/console ZIP、XML/FST/cases、GDS/网表/SDF/SPEF和全物理报告保留于results/version19。所有attempt分开保留，SHA256清单核对。main不修改，大产物不推GitHub，不发布Pages。
功耗无活动回标时为EDA估算；GL为UNIT_DELAY，不是SDF动态签核。若失败，保留原因和失败attempt，不放宽条件。
