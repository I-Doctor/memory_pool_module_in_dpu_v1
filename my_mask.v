`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////
// (c) Copyright EFC of NICS, Tsinghua University. All rights reserved.
// Engineer: Kai Zhong
// Email   : zhongk15@mails.tsinghua.edu.cn
//
// Create Date   : 2018.01.16
// Module Name   : my_mask
// Project Name  : dpu_v_1
// Target Devices: KU115
// Tool Versions : vivado 2017.3
// Description   : it work as a mask and just apply its ctrl signal 
//                 which is one-hot form to input_data with "and"
//                 gates 
// Dependencies  : utilized by read_arbiter write_arbiter
//
// Revision      :
// Modification History:
// Date by Version Change Description
//====================================
//
//====================================
//
///////////////////////////////////////////////////////////////////////
module my_mask #(
    parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH = 4
)(
    input  [DATA_WIDTH*CTRL_WIDTH -1:0] input_data,
    input  [CTRL_WIDTH            -1:0] input_ctrl,
    output [DATA_WIDTH*CTRL_WIDTH -1:0] output_data
);

//*******************************************************************
// logic to implement mux function
//*******************************************************************

// generate CTRL_WIDTH and_gates and get output_data
generate
    genvar i; 
    for(i=0; i<CTRL_WIDTH; i=i+1) 
    begin: and_gates //generator name: and gates
        assign output_data [(i+1)*DATA_WIDTH -1 : i*DATA_WIDTH]
            =  input_data  [(i+1)*DATA_WIDTH -1 : i*DATA_WIDTH]
             & {DATA_WIDTH {input_ctrl[i]} };
    end
endgenerate


endmodule