`timescale 1ns / 1ps
`include "Top_netcnn.v"

module tb_top_netcnn;
    // --- 1. 参数定义 (建议先用小规模 6x6 验证逻辑) ---
    localparam IN_BIT      = 8;
    localparam W_BIT       = 4;
    localparam B_BIT       = 32;
    localparam DATA_H      = 6; 
    localparam DATA_W      = 6;
    localparam NUM_CLASSES = 2;

    localparam SHIFT_n = 0;
    // --- 2. 信号定义 ---
    reg clk;
    reg rst_n;
    reg [IN_BIT*DATA_H*DATA_W-1:0] img_flat;
    reg [W_BIT*3*3*1*16-1:0]       w1_flat;
    reg [B_BIT*16-1:0]             b1_flat;
    reg [W_BIT*3*3*16*32-1:0]      w2_flat;
    reg [B_BIT*32-1:0]             b2_flat;
    // 6x6 图像经过两次 2x2 池化(Stride 2)后变为 1x1
    reg [W_BIT*(32*1*1)*NUM_CLASSES-1:0] fc_w_flat;
    reg [B_BIT*NUM_CLASSES-1:0]          fc_b_flat;
    
    wire [B_BIT*NUM_CLASSES-1:0]  final_out;
    wire [3:0]                     prediction;

    // --- 3. 时钟产生 (100MHz) ---
    initial clk = 0;
    always #5 clk = ~clk;

    // --- 4. 激励逻辑 ---
    integer i;
    initial begin
        // 初始化信号
        rst_n = 0;
        img_flat = 0;
        w1_flat = {144{4'd1}}; 
        w2_flat = {4608{4'd1}};
        fc_w_flat = 0;
        fc_b_flat = 0;
        b1_flat = 0;
        b2_flat = 0;

        // 设置全连接层权重：让 Class 1 胜出
        for(i=0; i<32; i=i+1) fc_w_flat[(32+i)*4 +: 4] = 4'd2; // Class 1 权重=2
        for(i=0; i<32; i=i+1) fc_w_flat[i*4 +: 4]      = 4'd1; // Class 0 权重=1

        // 复位释放
        #20 rst_n = 1;

        // 输入第一张测试图 (中心亮点)
        @(posedge clk);
        img_flat[ (DATA_H/2 * DATA_W + DATA_W/2) * IN_BIT +: IN_BIT ] = 8'd100;

        $display("--- CNN Pipeline Started ---");

        // --- 关键：等待 3 个时钟周期 (流水线延迟) ---
        repeat(3) @(posedge clk);

        // 此时结果已经稳定在输出寄存器中
        $display("Time: %t | Final Prediction: Class %d", $time, prediction);
        
        #100;
        $finish;
    end

    // --- 5. 实例化顶层 ---
    Top_NetCNN #(
        .IN_BIT(IN_BIT), .W_BIT(W_BIT), .B_BIT(B_BIT), .SHIFT_N(SHIFT_n),
        .DATA_H(DATA_H), .DATA_W(DATA_W), .NUM_CLASSES(NUM_CLASSES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .img_data(img_flat),
        .conv1_weight(w1_flat), .conv1_bias(b1_flat), .M1_param(32'd1), 
        .conv2_weight(w2_flat), .conv2_bias(b2_flat), .M2_param(32'd1),
        .fc_weight(fc_w_flat),  .fc_bias(fc_b_flat),
        .fc_out_wire(final_out),
        .prediction(prediction)
    );

endmodule