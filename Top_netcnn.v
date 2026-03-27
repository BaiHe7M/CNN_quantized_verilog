`timescale 1ns / 1ps

`include "Top_Block1.v"
`include "FullConnect.v"
`include "Requantize.v"

module Top_NetCNN #(
    // --- 基础位宽参数 ---
    parameter IN_BIT       = 8,    // 输入数据位宽 (如 8-bit 量化)
    parameter W_BIT        = 4,    // 权重位宽 (如 4-bit 量化)
    parameter B_BIT        = 32,   // 累加值/Bias位宽 (通常为 32-bit)
    parameter M_BIT        = 32,   // 再量化缩放因子 M 的位宽
    parameter SHIFT_N      = 16,   // 再量化右移位数 n

    // --- 输入图像参数 ---
    parameter DATA_H       = 40,   // 输入高度
    parameter DATA_W       = 40,   // 输入宽度
    parameter DATA_C       = 1,    // 输入通道数 (灰度图为 1)

    // --- 网络结构参数 ---
    parameter K_SIZE       = 3,    // 卷积核大小 (3x3)
    parameter P_SIZE       = 2,    // 池化核大小 (2x2)
    parameter L1_CH        = 16,   // 第一层卷积输出通道
    parameter L2_CH        = 32,   // 第二层卷积输出通道
    parameter NUM_CLASSES  = 2    // 分类任务的类别数 (输出维度)
)(
    // 信号定义
    input [IN_BIT * DATA_H * DATA_W * DATA_C - 1 : 0] img_data,
    
    // Block 1 权重/偏置
    input [W_BIT * K_SIZE * K_SIZE * DATA_C * L1_CH - 1 : 0] conv1_weight,
    input [B_BIT * L1_CH - 1 : 0]                            conv1_bias,
    input [M_BIT - 1 : 0]                                    M1_param,
    
    // Block 2 权重/偏置
    input [W_BIT * K_SIZE * K_SIZE * L1_CH * L2_CH - 1 : 0]  conv2_weight,
    input [B_BIT * L2_CH - 1 : 0]                            conv2_bias,
    input [M_BIT - 1 : 0]                                    M2_param,
    
    // 全连接层权重/偏置 (输入长度 = L2通道 * 最终特征图高 * 最终特征图宽)
    // 经过两次 2x2 池化，尺寸变为 DATA_H/4 和 DATA_W/4
    input [W_BIT * L2_CH * (DATA_H/4) * (DATA_W/4) * NUM_CLASSES - 1 : 0] fc_weight,
    input [B_BIT * NUM_CLASSES - 1 : 0]                                   fc_bias,
    input [M_BIT - 1 : 0]                                                 M3_param,
    
    output [IN_BIT * NUM_CLASSES - 1 : 0] final_out
);

    // -------------------------------------------------------------------------
    // --- 自动计算中间层尺寸 (Localparam) ---
    // -------------------------------------------------------------------------
    // Block 1 输出尺寸: (40x40) -> Pool(20x20)
    localparam L1_OUT_H = DATA_H / P_SIZE;
    localparam L1_OUT_W = DATA_W / P_SIZE;
    
    // Block 2 输出尺寸: (20x20) -> Pool(10x10)
    localparam L2_OUT_H = L1_OUT_H / P_SIZE;
    localparam L2_OUT_W = L1_OUT_W / P_SIZE;
    
    // FC 输入长度 (Flatten 后的向量长度)
    localparam FC_INPUT_LEN = L2_CH * L2_OUT_H * L2_OUT_W;

    // -------------------------------------------------------------------------
    // --- Block 1: Conv + ReLU + MaxPool ---
    // -------------------------------------------------------------------------
    wire [IN_BIT * L1_CH * L1_OUT_H * L1_OUT_W - 1 : 0] block1_out;
    
    Top_Block1 #(
        .IN_BIT(IN_BIT), .W_BIT(W_BIT), .B_BIT(B_BIT), .M_BIT(M_BIT), .SHIFT_N(SHIFT_N),
        .DATA_H(DATA_H), .DATA_W(DATA_W), .DATACHANEL(DATA_C), 
        .FILTER_BATCH(L1_CH), .FilterSize(K_SIZE)
    ) block1_inst (
        .img_data(img_data),
        .conv1_weight(conv1_weight),
        .conv1_bias(conv1_bias),
        .M1_param(M1_param),
        .layer1_out(block1_out)
    );

    // -------------------------------------------------------------------------
    // --- Block 2: Conv + ReLU + MaxPool ---
    // -------------------------------------------------------------------------
    wire [IN_BIT * L2_CH * L2_OUT_H * L2_OUT_W - 1 : 0] block2_out;
    
    Top_Block1 #(
        .IN_BIT(IN_BIT), .W_BIT(W_BIT), .B_BIT(B_BIT), .M_BIT(M_BIT), .SHIFT_N(SHIFT_N),
        .DATA_H(L1_OUT_H), .DATA_W(L1_OUT_W), .DATACHANEL(L1_CH), 
        .FILTER_BATCH(L2_CH), .FilterSize(K_SIZE)
    ) block2_inst (
        .img_data(block1_out), // 接 Block 1 输出
        .conv1_weight(conv2_weight),
        .conv1_bias(conv2_bias),
        .M1_param(M2_param),
        .layer1_out(block2_out)
    );

    // -------------------------------------------------------------------------
    // --- FullConnect: (L2_CH * 10 * 10) -> NUM_CLASSES ---
    // -------------------------------------------------------------------------
    wire [B_BIT * NUM_CLASSES - 1 : 0] fc_raw;
    
    FullConnect #(
        .IN_BIT(IN_BIT), .W_BIT(W_BIT), .B_BIT(B_BIT),
        .LENGTH(FC_INPUT_LEN), .FILTERBATCH(NUM_CLASSES)
    ) fc_inst (
        .data(block2_out), // 组合逻辑下，block2_out 既是池化结果也是扁平化向量
        .weight(fc_weight),
        .bias(fc_bias),
        .result(fc_raw)
    );
    
    wire signed [B_BIT - 1 : 0] class0_score = fc_raw[31 : 0];
    wire signed [B_BIT - 1 : 0] class1_score = fc_raw[63 : 32];

    // 直接输出 32-bit 结果供观察
    assign fc_raw_out = fc_raw;

    // 硬件 Argmax 判断逻辑
    assign prediction = (class1_score > class0_score) ? 4'd1 : 4'd0;

endmodule