`timescale 1ns / 1ps

module Top_Block1 #(
    parameter IN_BIT = 8,
    parameter W_BIT  = 4,
    parameter B_BIT  = 32,
    parameter M_BIT  = 32,
    parameter SHIFT_N = 16,
    parameter FilterSize = 3
)(
    input [IN_BIT * 40 * 40 * 1 - 1 : 0] img_data,
    input [W_BIT * FilterSize * FilterSize * 1 * 16 - 1 : 0] conv1_weight,
    input [B_BIT * 16 - 1 : 0] conv1_bias,
    input [M_BIT - 1 : 0] M1_param, // Python算出的第一层M
    output [IN_BIT * 20 * 20 * 16 - 1 : 0] layer1_out
);

    // --- 1. Conv1 实例化 (40x40 -> 40x40, 16 channels) ---
    wire [B_BIT * 16 * 40 * 40 - 1 : 0] conv1_raw;
    Conv2d #(
        .IN_BIT(IN_BIT), .W_BIT(W_BIT), .B_BIT(B_BIT),
        .DATAWIDTH(40), .DATAHEIGHT(40), .DATACHANNEL(1),
        .FILTERHEIGHT(3), .FILTERWIDTH(3), .FILTERBATCH(16),
        .STRIDEHEIGHT(1), .STRIDEWIDTH(1), .PADDINGENABLE(1)
    ) conv1_inst (
        .data(img_data), .filterWeight(conv1_weight), .filterBias(conv1_bias),
        .result(conv1_raw)
    );

    // --- 2. Requantize 实例化 (32-bit -> 8-bit) ---
    wire [IN_BIT * 16 * 40 * 40 - 1 : 0] conv1_scaled;
    genvar i;
    generate
        for (i = 0; i < 16 * 40 * 40; i = i + 1) begin : gen_requant1
            Requantize #(
                .IN_BIT(B_BIT), .OUT_BIT(IN_BIT), .M_BIT(M_BIT), .SHIFT_N(SHIFT_N)
            ) req1_inst (
                .data_in(conv1_raw[(i+1)*B_BIT-1 : i*B_BIT]),
                .M_param(M1_param),
                .data_out(conv1_scaled[(i+1)*IN_BIT-1 : i*IN_BIT])
            );
        end
    endgenerate

    // --- 3. ReLU 激活 ---
    wire [IN_BIT * 16 * 40 * 40 - 1 : 0] conv1_relu;
    Relu_activation #(
        .BITWIDTH(IN_BIT), .DATAWIDTH(40), .DATAHEIGHT(40), .DATACHANNEL(16)
    ) relu1_inst (
        .data(conv1_scaled),
        .result(conv1_relu)
    );

    // --- 4. Max Pool (40x40 -> 20x20) ---
    Max_pool #(
        .BITWIDTH(IN_BIT), .DATAWIDTH(40), .DATAHEIGHT(40), .DATACHANNEL(16),
        .KWIDTH(2), .KHEIGHT(2)
    ) pool1_inst (
        .data(conv1_relu),
        .result(layer1_out)
    );

endmodule