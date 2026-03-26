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
    //input clk,
    //input clken,
    input [IN_BIT * LENGTH - 1 : 0] data,
    input [W_BIT * LENGTH * FILTERBATCH - 1 : 0] weight,
    input [B_BIT * FILTERBATCH - 1 : 0] bias,
    output [B_BIT * FILTERBATCH - 1 : 0] result // 输出 32-bit 累加值，便于后续再量化
    );
    
    //reg [B_BIT * FILTERBATCH- 1:0] out;
    wire signed [IN_BIT + W_BIT - 1 : 0] out [0:FILTERBATCH - 1][0:LENGTH - 1];
    wire signed [B_BIT - 1 : 0] biasArray[0:FILTERBATCH - 1];
    reg signed [B_BIT - 1 : 0] resultArray [0:FILTERBATCH - 1];
    
    //wire [B_BIT * FILTERBATCH - 1 : 0] out2;
    
    genvar i, j;
    generate
        for(i = 0; i < FILTERBATCH; i = i + 1) begin : fc_gen
            // 提取 32-bit Bias
            assign biasArray[i] = bias[(i + 1) * B_BIT - 1 : i * B_BIT];
            assign result[(i + 1) * B_BIT - 1 : i * B_BIT] = resultArray[i];
            
            for(j = 0; j < LENGTH; j = j + 1) begin : mult_gen
                // 核心修改：输入取 IN_BIT 位，权重取 W_BIT 位
                assign out[i][j] = $signed(data[(j + 1) * IN_BIT - 1 : j * IN_BIT]) * $signed(weight[(i * LENGTH + j) * W_BIT + W_BIT - 1 : (i * LENGTH + j) * W_BIT]);
            end
        end
    endgenerate
    
    integer sum, m, n;
    always @(*) begin
        for(m = 0; m < FILTERBATCH; m = m + 1) begin
            sum = biasArray[m]; // 直接用 32-bit Bias 初始化
            for(n = 0; n < LENGTH; n = n + 1) begin
                sum = sum + out[m][n];
            end
            resultArray[m] = sum;
        end
    end    
    
    // always @(posedge clk) begin
    //     if(clken == 1) begin
    //         result = out2;
    //     end
    // end 
    
endmodule
