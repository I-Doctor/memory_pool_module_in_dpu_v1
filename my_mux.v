`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////
// (c) Copyright EFC of NICS, Tsinghua University. All rights reserved.
// Engineer: Kai Zhong
// Email   : zhongk15@mails.tsinghua.edu.cn
//
// Create Date   : 2018.01.16
// Module Name   : my_mux
// Project Name  : dpu_v_1
// Target Devices: KU115
// Tool Versions : vivado 2017.3
// Description   : it work as normal mux but its ctrl signal is
//                 one-hot form so we use logic operation "and",
//                 "or" to implement 
// Dependencies  : utilized by read_arbiter write_arbiter read_port
//
// Revision      :
// Modification History:
// Date by Version Change Description
//====================================
//
//====================================
//
///////////////////////////////////////////////////////////////////////
module my_mux #(
    parameter DATA_WIDTH = 48,
    parameter CTRL_WIDTH = 3
)(
    input  [DATA_WIDTH*CTRL_WIDTH -1:0] input_data,
    input  [CTRL_WIDTH            -1:0] input_ctrl,
    output [DATA_WIDTH            -1:0] output_data
);

//*******************************************************************
// logic to implement mux function
//*******************************************************************
wire [DATA_WIDTH*CTRL_WIDTH -1:0] and_result;// results of (data&ctrl)

// generate CTRL_WIDTH and_gates and get and_results
generate
    genvar i; 
    for(i=0; i<CTRL_WIDTH; i=i+1) 
    begin: and_gates //generator name: and gates
        assign and_result [(i+1)*DATA_WIDTH -1 : i*DATA_WIDTH]
            =  input_data [(i+1)*DATA_WIDTH -1 : i*DATA_WIDTH]
             & {DATA_WIDTH {input_ctrl[i]} };
    end
endgenerate

// only support CTRL_WIDTH==3 or 4 now
generate
    if (CTRL_WIDTH == 3)
    begin: or_gates //generator name: or gates
        assign output_data =  and_result [3*DATA_WIDTH-1:2*DATA_WIDTH]
                            | and_result [2*DATA_WIDTH-1:1*DATA_WIDTH]
                            | and_result [1*DATA_WIDTH-1:0*DATA_WIDTH];
    end
    else if (CTRL_WIDTH == 4)
    begin
        assign output_data =  and_result [4*DATA_WIDTH-1:3*DATA_WIDTH]
                            | and_result [3*DATA_WIDTH-1:2*DATA_WIDTH]
                            | and_result [2*DATA_WIDTH-1:1*DATA_WIDTH]
                            | and_result [1*DATA_WIDTH-1:0*DATA_WIDTH];
    end
    else if (CTRL_WIDTH == 1)
    begin
        assign output_data =  and_result [DATA_WIDTH-1:0];
                            
    end

endgenerate


endmodule
