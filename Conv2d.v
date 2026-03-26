`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 卷积模块
//////////////////////////////////////////////////////////////////////////////////


module Conv2d #(
    parameter integer IN_BIT = 8,
    parameter integer W_BIT = 4,
    parameter integer B_BIT = 32,
    
    parameter integer DATAWIDTH = 28,
    parameter integer DATAHEIGHT = 28,
    parameter integer DATACHANNEL = 3,
    
    parameter integer FILTERHEIGHT = 5,
    parameter integer FILTERWIDTH = 5,
    parameter integer FILTERBATCH = 1,
    
    parameter integer STRIDEHEIGHT = 1,
    parameter integer STRIDEWIDTH = 1,
    
    parameter integer PADDINGENABLE = 1
    )
    (
    //input clk,
    //input clken,
    input [IN_BIT * DATAWIDTH * DATAHEIGHT * DATACHANNEL - 1 : 0] data,
    input [W_BIT * FILTERHEIGHT * FILTERWIDTH * DATACHANNEL * FILTERBATCH - 1 : 0] filterWeight,
    input [B_BIT * FILTERBATCH - 1 : 0] filterBias,
    
    output [B_BIT * FILTERBATCH * OH * OW - 1 : 0] result    
    );
    // 计算输出特征图的高度 (OH) 和宽度 (OW)
    localparam OH = (PADDINGENABLE == 1) ? (DATAHEIGHT / STRIDEHEIGHT) : ((DATAHEIGHT - FILTERHEIGHT + 1) / STRIDEHEIGHT);
    localparam OW = (PADDINGENABLE == 1) ? (DATAWIDTH / STRIDEWIDTH) : ((DATAWIDTH - FILTERWIDTH + 1) / STRIDEWIDTH);

    // 中间阵列定义
        // 原始输入数据拆分为三维数组
    wire [IN_BIT - 1 : 0] dataArray[0 : DATACHANNEL - 1][0 : DATAHEIGHT-1][0 : DATAWIDTH - 1]; 
        // 添加零填充后的输入数据阵列
    wire [IN_BIT - 1 : 0] dataArrayWithPadding[0 : DATACHANNEL - 1][0 : (PADDINGENABLE == 1 ? DATAHEIGHT + FILTERHEIGHT - 1 : DATAHEIGHT)-1][0 : (PADDINGENABLE == 1 ? DATAWIDTH + FILTERWIDTH - 1 : DATAWIDTH)-1];
        // 每个输出特征图中的每个像素的参数阵列
    wire [IN_BIT * FILTERHEIGHT * FILTERWIDTH * DATACHANNEL - 1 : 0] paramArray[0: (PADDINGENABLE == 1 ? DATAHEIGHT / STRIDEHEIGHT: (DATAHEIGHT - FILTERHEIGHT + 1) / STRIDEHEIGHT)-1][0: (PADDINGENABLE == 1 ? DATAWIDTH / STRIDEWIDTH : (DATAWIDTH - FILTERWIDTH + 1) / STRIDEWIDTH)-1];
        // 每个输出特征图的weight阵列
    wire [W_BIT * DATACHANNEL * FILTERHEIGHT * FILTERWIDTH - 1 : 0] filterWeightArray[0: FILTERBATCH - 1];
 
    // wire [(BITWIDTH * 2) * FILTERBATCH * (PADDINGENABLE == 0 ? (DATAWIDTH - FILTERWIDTH + 1) / STRIDEWIDTH : (DATAWIDTH / STRIDEWIDTH)) * (PADDINGENABLE == 0 ? (DATAHEIGHT - FILTERHEIGHT + 1) / STRIDEHEIGHT : (DATAHEIGHT / STRIDEHEIGHT)) - 1 : 0] out;
    
    genvar i, j, k, m, n;
    // 将输入数据拆分为三维数组
    generate       
        for(i = 0; i < DATACHANNEL; i = i + 1) begin
            for(j = 0; j < DATAHEIGHT; j = j + 1) begin
                for(k = 0; k < DATAWIDTH; k = k + 1) begin
                    assign dataArray[i][j][k] = data[(i * DATAHEIGHT * DATAWIDTH + j * DATAHEIGHT + k) * IN_BIT + IN_BIT - 1 : (i * DATAHEIGHT * DATAWIDTH + j * DATAHEIGHT + k) * IN_BIT];
                end
            end
        end      
    endgenerate
    // 添加零填充
    generate
        for(i = 0; i < DATACHANNEL; i = i + 1) begin
            for(m = 0; m < (PADDINGENABLE == 1 ? DATAHEIGHT + FILTERHEIGHT - 1 : DATAHEIGHT); m = m + 1) begin
                for(n = 0; n < (PADDINGENABLE == 1 ? DATAWIDTH + FILTERWIDTH - 1 : DATAWIDTH); n = n + 1) begin
                    if(PADDINGENABLE == 1) begin
                        if(m < (FILTERHEIGHT / 2) || m > (DATAHEIGHT + FILTERHEIGHT / 2 - 1)) begin
                            assign dataArrayWithPadding[i][m][n] = 0;
                        end
                        else if(n < (FILTERWIDTH / 2) || n > (DATAWIDTH + FILTERWIDTH / 2 - 1)) begin
                            assign dataArrayWithPadding[i][m][n] = 0;
                        end
                        else begin
                            assign dataArrayWithPadding[i][m][n] = dataArray[i][m - FILTERHEIGHT / 2][n - FILTERWIDTH / 2];
                        end
                    end
                    else begin
                        assign dataArrayWithPadding[i][m][n] = dataArray[i][m][n];
                    end
                end
            end
        end
    endgenerate
    // 生成每个输出像素的参数阵列
    generate
            for(j = FILTERHEIGHT / 2; j < (PADDINGENABLE == 1 ? DATAHEIGHT + FILTERHEIGHT - 1 - FILTERHEIGHT / 2: DATAHEIGHT - FILTERHEIGHT / 2); j = j + STRIDEHEIGHT) begin
                for(k = FILTERWIDTH / 2; k < (PADDINGENABLE == 1 ? DATAWIDTH + FILTERWIDTH - 1 - FILTERWIDTH / 2 : DATAWIDTH - FILTERWIDTH / 2); k = k + STRIDEWIDTH) begin
                    for(i = 0; i < DATACHANNEL; i = i + 1) begin
                        for(m = j - FILTERHEIGHT / 2; m <= j + FILTERHEIGHT / 2; m = m + 1) begin
                            for(n = k - FILTERWIDTH / 2; n <= k + FILTERWIDTH / 2; n = n + 1) begin
                                assign paramArray[(j - FILTERHEIGHT / 2) / STRIDEHEIGHT][(k - FILTERWIDTH / 2) / STRIDEWIDTH][(i * FILTERHEIGHT * FILTERWIDTH + (m - j + FILTERHEIGHT / 2) * FILTERWIDTH + (n - k + FILTERWIDTH / 2)) * IN_BIT + IN_BIT - 1:(i * FILTERHEIGHT * FILTERWIDTH + (m - j + FILTERHEIGHT / 2) * FILTERWIDTH + (n - k + FILTERWIDTH / 2)) * IN_BIT] = 
                                    dataArrayWithPadding[i][m][n];
                            end
                        end
                    end
                end
            end
    endgenerate
    
    // 将权重拆分为单独的filterWeightArray
    generate 
        for(i = 0; i < FILTERBATCH; i = i + 1) begin
            assign filterWeightArray[i] = filterWeight[(i + 1) * DATACHANNEL * FILTERHEIGHT * FILTERWIDTH * W_BIT - 1 : i * DATACHANNEL * FILTERHEIGHT * FILTERWIDTH * W_BIT];
        end
    endgenerate
    
generate
        for(i = 0; i < FILTERBATCH; i = i + 1) begin : batch_gen
            for(m = 0; m < OH; m = m + 1) begin : height_gen
                for(n = 0; n < OW; n = n + 1) begin : width_gen
                    ConvKernel#(
                        .IN_BIT(IN_BIT), 
                        .W_BIT(W_BIT), 
                        .B_BIT(B_BIT), 
                        .DATACHANNEL(DATACHANNEL), 
                        .FILTERHEIGHT(FILTERHEIGHT), 
                        .FILTERWIDTH(FILTERWIDTH)
                    ) convKernel_inst (
                        .data(paramArray[m][n]), 
                        .weight(filterWeightArray[i]), 
                        .bias(filterBias[(i + 1) * B_BIT - 1 : i * B_BIT]),
                        // 修正后的寻址公式：
                        .result(result[( (i * OH * OW) + m * OW + n ) * B_BIT + B_BIT - 1 : ( (i * OH * OW) + m * OW + n ) * B_BIT])
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
