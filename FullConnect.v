`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2018/04/18 13:47:58
// Design Name: 
// Module Name: FullConnect
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module FullConnect#(
    parameter IN_BIT = 8,      // 输入数据位宽
    parameter W_BIT = 4,       // 权重位宽
    parameter B_BIT = 32,      // Bias 和结果位宽
    parameter LENGTH = 3200,   // 输入向量长度 (如 32*10*10)
    parameter FILTERBATCH = 2 // 输出类别数
    )
    (
    input                                         clk,    // 新增：时钟信号
    input                                         rst_n,  // 新增：异步复位
    input [IN_BIT * LENGTH - 1 : 0] data,
    input [W_BIT * LENGTH * FILTERBATCH - 1 : 0] weight,
    input [B_BIT * FILTERBATCH - 1 : 0] bias,
    output reg [B_BIT * FILTERBATCH - 1 : 0] result       // 输出 32-bit 累加值，便于后续再量化
    );
    
// --- 1. 数据拆分与中间变量 ---
    wire signed [IN_BIT - 1 : 0] input_vec [0 : LENGTH - 1];
    wire signed [W_BIT - 1 : 0]  weight_mat [0 : FILTERBATCH - 1][0 : LENGTH - 1];
    wire signed [B_BIT - 1 : 0]  bias_vec [0 : FILTERBATCH - 1];
    // 组合逻辑乘积
    wire signed [IN_BIT + W_BIT - 1 : 0] product [0 : FILTERBATCH - 1][0 : LENGTH - 1];
    
    // 组合逻辑累加和
    reg signed [B_BIT - 1 : 0] comb_sum [0 : FILTERBATCH - 1];
    
    // --- 2. 信号解析与并行乘法 (组合逻辑) ---
    genvar i, j;
    generate
        for (j = 0; j < LENGTH; j = j + 1) begin : unpack_data
            assign input_vec[j] = data[j * IN_BIT +: IN_BIT];
        end

        for (i = 0; i < FILTERBATCH; i = i + 1) begin : fc_rows
            assign bias_vec[i] = bias[i * B_BIT +: B_BIT];
            for (j = 0; j < LENGTH; j = j + 1) begin : fc_cols
                assign weight_mat[i][j] = weight[(i * LENGTH + j) * W_BIT +: W_BIT];
                // 乘法器阵列
                assign product[i][j] = $signed(input_vec[j]) * $signed(weight_mat[i][j]);
            end
        end
    endgenerate

    // --- 3. 累加逻辑 (组合逻辑) ---
    integer m, n;
    always @(*) begin
        for (m = 0; m < FILTERBATCH; m = m + 1) begin
            comb_sum[m] = bias_vec[m];
            for (n = 0; n < LENGTH; n = n + 1) begin
                comb_sum[m] = comb_sum[m] + product[m][n];
            end
        end
    end

// --- 4. 流水线输出寄存器 (时序逻辑) ---
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
        end else begin
            for (k = 0; k < FILTERBATCH; k = k + 1) begin
                // 在时钟上升沿，将组合逻辑算好的 comb_sum 锁存到输出
                result[k * B_BIT +: B_BIT] <= comb_sum[k];
            end
        end
    end

endmodule
