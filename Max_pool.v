`timescale 1ns / 1ps
`include "Max.v"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2018/04/15 14:29:19
// Design Name: 
// Module Name: Max_pool
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


module Max_pool#(
    parameter integer BITWIDTH = 8,
    
    parameter integer DATAWIDTH = 28,
    parameter integer DATAHEIGHT = 28,
    parameter integer DATACHANNEL = 3,
    
    parameter integer KWIDTH = 2,
    parameter integer KHEIGHT = 2
    )
    (
    //input clk,
    //input clken,
    input [BITWIDTH * DATAWIDTH * DATAHEIGHT * DATACHANNEL - 1 : 0]data,
    // output reg [BITWIDTH * DATAWIDTH / KWIDTH * DATAHEIGHT / KHEIGHT * DATACHANNEL - 1 : 0] result
    output [(BITWIDTH * (DATAWIDTH / KWIDTH) * (DATAHEIGHT / KHEIGHT) * DATACHANNEL) - 1 : 0] result

    );
    localparam OH = DATAHEIGHT / KHEIGHT;
    localparam OW = DATAWIDTH / KWIDTH;

    wire [BITWIDTH - 1 : 0] dataArray[0 : DATACHANNEL - 1][0 : DATAHEIGHT-1][0 : DATAWIDTH - 1];
    wire [BITWIDTH * KHEIGHT * KWIDTH - 1 : 0]paramArray [0: DATACHANNEL - 1][0: DATAHEIGHT / KHEIGHT - 1][0: DATAWIDTH / KWIDTH - 1];
    
    //wire [BITWIDTH * DATAWIDTH / KWIDTH * DATAHEIGHT / KHEIGHT * DATACHANNEL - 1 : 0] out;
    
    genvar i, j, k, m, n;
    generate       
        for(i = 0; i < DATACHANNEL; i = i + 1) begin
            for(j = 0; j < DATAHEIGHT; j = j + 1) begin
                for(k = 0; k < DATAWIDTH; k = k + 1) begin
                    assign dataArray[i][j][k] = data[(i * DATAHEIGHT * DATAWIDTH + j * DATAWIDTH + k) * BITWIDTH +: BITWIDTH];
                end
            end
        end      
    endgenerate
    
    generate 
        for(i = 0; i < DATACHANNEL; i = i + 1) begin
            for(j = 0; j < DATAHEIGHT / KHEIGHT; j = j + 1) begin
                for(k = 0; k < DATAWIDTH / KWIDTH; k = k + 1) begin
                    for(m = j * 2; m < j * 2 + KHEIGHT; m = m + 1) begin
                        for(n = k * 2; n < k * 2 + KWIDTH; n = n + 1) begin
                            assign paramArray[i][j][k][((m - j * 2) * KWIDTH + n - k * 2) * BITWIDTH + BITWIDTH - 1:((m - j * 2) * KWIDTH + n - k * 2) * BITWIDTH] = dataArray[i][m][n];
                        end
                    end                   
                end
            end
        end
    endgenerate
    
    generate
        for(i = 0; i < DATACHANNEL; i = i + 1) begin
            for(j = 0; j < DATAHEIGHT / KHEIGHT; j = j + 1) begin
                for(k = 0; k < DATAWIDTH / KWIDTH; k = k + 1) begin
                // 修正 Max 例化的 result 索引逻辑
                Max #(BITWIDTH, KHEIGHT * KWIDTH) max (
                    paramArray[i][j][k], 
                    result[(i * OH * OW + j * OW + k) * BITWIDTH + BITWIDTH - 1 : 
                        (i * OH * OW + j * OW + k) * BITWIDTH]
                );
                end
            end
        end
    endgenerate
    
    // always @(posedge clk) begin
    //     if(clken == 1) begin
    //         result = out;
    //     end
    // end
    
endmodule
