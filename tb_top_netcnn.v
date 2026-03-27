`timescale 1ns / 1ps
`include "Top_NetCNN.v"

module tb_top_netcnn;
    // 参数设置
    localparam IN_BIT = 8;
    localparam W_BIT  = 4;
    localparam B_BIT  = 32;
    localparam DATA_H = 6; 
    localparam DATA_W = 6;
    localparam NUM_CLASSES = 2;

    // 信号定义
    reg [IN_BIT*DATA_H*DATA_W-1:0] img_flat;
    reg [W_BIT*3*3*1*16-1:0]       w1_flat;
    reg [B_BIT*16-1:0]             b1_flat;
    reg [W_BIT*3*3*16*32-1:0]      w2_flat;
    reg [B_BIT*32-1:0]             b2_flat;
    reg [W_BIT*(32*1*1)*2-1:0]     fc_w_flat; // 6x6经过两层池化变为1x1
    reg [B_BIT*2-1:0]              fc_b_flat;
    
    wire [B_BIT*2-1:0]             fc_raw_out;
    wire [3:0]                     prediction;

    integer i;
    initial begin
        // 1. 初始化
        img_flat = 0;
        w1_flat = {144{4'd1}}; 
        w2_flat = {4608{4'd1}};
        fc_w_flat = 0;
        fc_b_flat = 0;
        b1_flat = 0;
        b2_flat = 0;

        // 2. 构造数据：假设我们想让类别 1 胜出
        // 设置一张中间有亮点的图
        img_flat[18*8 +: 8] = 8'd100; 
        // 设置 FC 权重，让类别 1 的权重比类别 0 大
        for(i=0; i<32; i=i+1) fc_w_flat[(32+i)*4 +: 4] = 4'd2; // Class 1 权重设为 2
        for(i=0; i<32; i=i+1) fc_w_flat[i*4 +: 4]      = 4'd1; // Class 0 权重设为 1

        $display("--- Starting Full NetCNN Test ---");
        #5000; // 等待庞大的组合逻辑稳定

        $display("Time: %t", $time);
        $display("Class 0 Score: %d", $signed(fc_raw_out[31:0]));
        $display("Class 1 Score: %d", $signed(fc_raw_out[63:32]));
        $display("Final Prediction: Class %d", prediction);

        #100;
        $finish;
    end

    Top_NetCNN #(
        .IN_BIT(IN_BIT), .DATA_H(DATA_H), .DATA_W(DATA_W), .NUM_CLASSES(NUM_CLASSES)
    ) dut (
        .img_data(img_flat),
        .conv1_weight(w1_flat), .conv1_bias(b1_flat), .M1_param(32'd1), 
        .conv2_weight(w2_flat), .conv2_bias(b2_flat), .M2_param(32'd1),
        .fc_weight(fc_w_flat),  .fc_bias(fc_b_flat),   .M3_param(32'd1),
        .fc_raw_out(fc_raw_out),
        .prediction(prediction)
    );

endmodule