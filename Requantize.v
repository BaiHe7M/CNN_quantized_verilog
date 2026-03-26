`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//再量化模块：将上层卷积输出的 32-bit 累加值缩放回 8-bit，供下一层输入
//需要输入 M 参数（缩放系数）和 n 参数（右移位数），以及卷积输出的 32-bit 累加值
//其中M和n应在模型训练后确定，并作为常数参数输入模块
//////////////////////////////////////////////////////////////////////////////////20260326刘俊麟

module Requantize #(
    parameter integer IN_BIT = 32,   // 卷积输出的 32-bit 累加值
    parameter integer OUT_BIT = 8,  // 缩放回的位宽 (对应下一层的 IN_BIT)
    parameter integer M_BIT = 32,   // 缩放系数 M 的位宽
    parameter integer SHIFT_N = 16  // 右移位数 n
)(
    input signed [IN_BIT - 1 : 0] data_in, // 卷积核输出的一个 32-bit 像素
    input [M_BIT - 1 : 0] M_param,         // 该层专用的 M 值
    output reg signed [OUT_BIT - 1 : 0] data_out
);

    wire signed [IN_BIT + M_BIT - 1 : 0] multiplied;
    wire signed [IN_BIT + M_BIT - 1 : 0] shifted;
    
    // 1. 乘法缩放
    assign multiplied = data_in * $signed({1'b0, M_param}); // M 作为正整数参与乘法
    
    // 2. 右移 n 位
    assign shifted = multiplied >>> SHIFT_N;

    // 3. 饱和截断 (Saturation/Clipping)
    // 针对 8-bit 有符号数，范围为 -128 到 127
    localparam signed [OUT_BIT-1:0] QMAX = 127;
    localparam signed [OUT_BIT-1:0] QMIN = -128;

    always @(*) begin
        if (shifted > $signed(QMAX))
            data_out = QMAX;
        else if (shifted < $signed(QMIN))
            data_out = QMIN;
        else
            data_out = shifted[OUT_BIT-1:0];
    end

endmodule