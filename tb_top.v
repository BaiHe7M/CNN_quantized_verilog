`timescale 1ns / 1ps

module tb_top;
    reg [7:0] img_mem [0:1599]; // 40*40 灰度图
    reg [3:0] w_mem [0:143];    // 3*3*1*16 权重
    reg [31:0] b_mem [0:15];    // 16 通道 Bias
    
    // 转换为顶层需要的扁平化向量
    reg [8*1600-1:0] img_flat;
    reg [4*144-1:0] w_flat;
    reg [32*16-1:0] b_flat;
    wire [8*400*16-1:0] result;

    integer i;
    integer x, y, c;
    initial begin
    // --- 1. 初始化图像：生成一个中心白点模式 ---
        for (i = 0; i < 1600; i = i + 1) begin
            img_mem[i] = 8'd0; // 背景全黑
        end
        img_mem[20 * 40 + 20] = 8'd127; // 中心点设为 127 (对应 Normalize 后的 0)

        // --- 2. 初始化权重：写死一个简单的锐化或平滑核 ---
        // 假设是 16 个 3x3x1 的卷积核
        for (i = 0; i < 144; i = i + 1) begin
            w_mem[i] = 4'd1; // 所有权重设为 1，方便心算校验结果
        end

        // --- 3. 初始化 Bias：全部清零或设为常数 ---
        for (i = 0; i < 16; i = i + 1) begin
            b_mem[i] = 32'd0; 
        end
        
        // --- 4. 数据扁平化 (这一步必须有，因为 Top 输入是长向量) ---
        for (i = 0; i < 1600; i = i + 1) img_flat[i*8 +: 8] = img_mem[i];
        for (i = 0; i < 144; i = i + 1)  w_flat[i*4 +: 4] = w_mem[i];
        for (i = 0; i < 16; i = i + 1)   b_flat[i*32 +: 32] = b_mem[i];

        #100; // 等待组合逻辑稳定
        
        // 3. 打印部分结果校验
        $display("First Pixel of Output: %d", result[7:0]);
        $finish;
    end

    // 实例化顶层
    Top_Block1 top_inst (
        .img_data(img_flat),
        .conv1_weight(w_flat),
        .conv1_bias(b_flat),
        .M1_param(32'd163), // 对应你之前输出的 Conv1 M=163
        .layer1_out(result)
    );

endmodule