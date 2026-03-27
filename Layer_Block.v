`timescale 1ns / 1ps
`include "Requantize.v"
`include "Conv2d.v"
`include "Relu_activation.v"
`include "Max_pool.v"

module Layer_Block #(
    parameter IN_BIT = 8,
    parameter W_BIT  = 4,
    parameter B_BIT  = 32,

    parameter M_BIT  = 32,
    parameter SHIFT_N = 0,

    parameter DATA_H = 40,
    parameter DATA_W = 40,
    parameter DATACHANEL = 1,

    parameter FILTER_BATCH = 16,
    parameter FilterSize = 3
)(
    input clk,
    input rst_n,

    input [IN_BIT * DATA_W * DATA_H * DATACHANEL - 1 : 0] img_data,
    input [W_BIT * FilterSize * FilterSize * DATACHANEL * FILTER_BATCH - 1 : 0] conv1_weight,
    input [B_BIT * FILTER_BATCH - 1 : 0] conv1_bias,
    input [M_BIT - 1 : 0] M1_param,
    output reg [(IN_BIT * (DATA_H/2) * (DATA_W/2) * FILTER_BATCH) - 1 : 0] layer1_out
);

    // 1. Conv1 (使用参数定义位宽)
    wire [B_BIT * FILTER_BATCH * DATA_W * DATA_H - 1 : 0] conv1_raw;
    Conv2d #(
        .IN_BIT(IN_BIT), .W_BIT(W_BIT), .B_BIT(B_BIT),
        .DATAWIDTH(DATA_W), .DATAHEIGHT(DATA_H), .DATACHANNEL(DATACHANEL),
        .FILTERHEIGHT(FilterSize), .FILTERWIDTH(FilterSize), .FILTERBATCH(FILTER_BATCH),
        .STRIDEHEIGHT(1), .STRIDEWIDTH(1), .PADDINGENABLE(1)
    ) conv1_inst (
        .data(img_data), .filterWeight(conv1_weight), .filterBias(conv1_bias),
        .result(conv1_raw)
    );

    // 2. Requantize (循环次数改为参数化)
    wire [IN_BIT * FILTER_BATCH * DATA_W * DATA_H - 1 : 0] conv1_scaled;
    genvar i;
    generate
        for (i = 0; i < FILTER_BATCH * DATA_W * DATA_H; i = i + 1) begin : gen_requant1
            Requantize #(
                .IN_BIT(B_BIT), .OUT_BIT(IN_BIT), .M_BIT(M_BIT), .SHIFT_N(SHIFT_N)
            ) req1_inst (
                .data_in(conv1_raw[(i+1)*B_BIT-1 : i*B_BIT]),
                .M_param(M1_param),
                .data_out(conv1_scaled[(i+1)*IN_BIT-1 : i*IN_BIT])
            );
        end
    endgenerate

    // 3. ReLU (DATACHANNEL 改为卷积后的 FILTER_BATCH)
    wire [IN_BIT * FILTER_BATCH * DATA_W * DATA_H - 1 : 0] conv1_relu;
    Relu_activation #(
        .BITWIDTH(IN_BIT), .DATAWIDTH(DATA_W), .DATAHEIGHT(DATA_H), .DATACHANNEL(FILTER_BATCH)
    ) relu1_inst (
        .data(conv1_scaled),
        .result(conv1_relu)
    );

    // 4. Max Pool
    wire [(IN_BIT * (DATA_H/2) * (DATA_W/2) * FILTER_BATCH) - 1 : 0] pool_out_wire;
    Max_pool #(
        .BITWIDTH(IN_BIT), .DATAWIDTH(DATA_W), .DATAHEIGHT(DATA_H), .DATACHANNEL(FILTER_BATCH),
        .KWIDTH(2), .KHEIGHT(2)
    ) pool1_inst (
        .data(conv1_relu),
        .result(pool_out_wire)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            layer1_out <= 0;
        else
            layer1_out <= pool_out_wire; // 寄存器锁存组合逻辑结果
    end
endmodule