`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2018/04/11 16:12:39
// Design Name: 
// Module Name: ConvKernel
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


module ConvKernel#(
    parameter integer IN_BIT = 8,    // 输入位宽
    parameter integer W_BIT = 4,     // 权重位宽
    parameter integer B_BIT = 32,    // Bias位宽
    
    parameter integer DATACHANNEL = 3, 
    parameter integer FILTERHEIGHT = 3,
    parameter integer FILTERWIDTH = 3
    )
    (
    input [IN_BIT * DATACHANNEL * FILTERHEIGHT * FILTERWIDTH - 1 : 0] data,
    input [W_BIT * DATACHANNEL * FILTERHEIGHT * FILTERWIDTH - 1 : 0] weight,
    input signed [B_BIT - 1 : 0] bias,
    // 输出位宽设为32，用于后续的再量化(Scaling)
    output reg signed [B_BIT - 1 : 0] result 
    );
    
    // 乘积位宽为 IN_BIT + W_BIT
    wire signed [IN_BIT + W_BIT - 1 : 0] out [FILTERHEIGHT * FILTERWIDTH * DATACHANNEL - 1 : 0];
    
    genvar i;
    generate
        for(i = 0; i < FILTERHEIGHT * FILTERWIDTH * DATACHANNEL; i = i + 1) begin
            // 实例化乘法器，需支持混合位宽输入
            // 注意：如果Mult模块不支持混合位宽，建议直接用 a * b
            assign out[i] = $signed(data[(i + 1) * IN_BIT - 1 : i * IN_BIT]) * $signed(weight[(i + 1) * W_BIT - 1 : i * W_BIT]);
        end
    endgenerate
    
    integer j;
    always @(*) begin
        result = bias; // 初始值为32-bit Bias
        for(j = 0; j < FILTERHEIGHT * FILTERWIDTH * DATACHANNEL; j = j + 1) begin
            result = result + $signed(out[j]);
        end
    end
    
endmodule