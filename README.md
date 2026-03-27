# 整体架构

Top_netcnn
	TopBlock 卷积层+再量化(含溢出截断处理)+激活+池化
		Conv2d
		Requantize
		Relu_activation
		Requantize
	TopBlock 第二层
	FullConnect

即：Conv -> Requantize -> Relu -> MaxPool -> Conv -> Requantize -> Relu -> MaxPool -> FullConnect
# 功能解析
- 参数设置：weight位宽4b、input位宽8b、bias及累加器位宽32b
- 输入：0-256灰度值（int8、整张图片进行处理（40 * 40 * 8b)
- **再量化**：由于模型训练时使用标准化、归一化的输入，且weight、bias均存在量化映射，再结合应将每层的输出重新映射到8b范围内的需求，针对量化模型上板计算应引入**再量化requantization**层，整合Scale_weight、Scale_input、和右移shift位数，保证数据的有效性
- 目前三层网络、设置**三级流水**，层内组合逻辑，单层资源占用较大，存在优化空间