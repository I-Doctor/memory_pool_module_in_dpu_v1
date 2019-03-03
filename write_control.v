`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////
// (c) Copyright EFC of NICS, Tsinghua University. All rights reserved.
// Engineer: Kai Zhong
// Email   : zhongk15@mails.tsinghua.edu.cn
//
// Create Date   : 2019.01.16
// Module Name   : write_control
// Project Name  : dpu_v_1
// Target Devices: KU115
// Tool Versions : vivado 2017.1
// Description   : receive write request to on-chip memory pool 
//                 from conv, dataloader, misc and send data to the 
//                 right group and right bank of on-chip memory pool
// Dependencies  : utilized by mem_pool_top
//                 contains write_arbiter
//
// Revision      :
// Modification History:
// Date by Version Change Description
//=====================================================================
// 2019.03.03    : solve input and output localparam problem
//
//=====================================================================
//
///////////////////////////////////////////////////////////////////////
module write_control #(
    parameter IMG_GRP_NUM       = 3,
    parameter ROW_PARA          = 4,
    parameter COL_PARA          = 1,
    parameter CHL_PARA          = 8,
    parameter BANK_ADDR_WIDTH   = 12,
    parameter BANK_UNIT_WIDTH   = 8
)(
    input clk,
    input rst_p,

    // image write port with Conv
    input [IMG_GRP_NUM              -1:0] conv_write_group_id_i,
    input [ROW_PARA                 -1:0] conv_write_bank_en_i,
    input [ROW_PARA*BANK_ADDR_WIDTH -1:0] conv_write_addr_i,
    input [ROW_PARA*BANK_UNIT_WIDTH*CHL_PARA -1:0] conv_write_data_i,
    output                                conv_write_ready_o,

    // image write port with MISC
    input [IMG_GRP_NUM              -1:0] misc_write_group_id_i,
    input [ROW_PARA                 -1:0] misc_write_bank_en_i,
    input [ROW_PARA*BANK_ADDR_WIDTH -1:0] misc_write_addr_i,
    input [ROW_PARA*BANK_UNIT_WIDTH*CHL_PARA -1:0] misc_write_data_i,
    output                                misc_write_ready_o,
    
    // image write port with Load
    input [IMG_GRP_NUM              -1:0] load_write_group_id_i,
    input [ROW_PARA                 -1:0] load_write_bank_en_i,
    input [ROW_PARA*BANK_ADDR_WIDTH -1:0] load_write_addr_i,
    input [ROW_PARA*BANK_UNIT_WIDTH*CHL_PARA -1:0] load_write_data_i,
    output                                load_write_ready_o,
    
    // image write port with image memory pool (packaged)
    output [IMG_GRP_NUM*ROW_PARA*BANK_UNIT_WIDTH*CHL_PARA-1:0] write_data_o,
    output [IMG_GRP_NUM*ROW_PARA*BANK_ADDR_WIDTH -1:0] write_addr_o,
    output [IMG_GRP_NUM*ROW_PARA                 -1:0] write_bank_en_o
);

//*******************************************************************
// localparam
//*******************************************************************
// IMG: IMG_GRP_NUM groups, ROW_PARA banks, CHL_PARA units
// individual addr: BANK_NUM * BANK_ADDR_WIDTH
localparam IMG_BANK_NUM    = ROW_PARA;
localparam IMG_UNIT_NUM    = CHL_PARA;
localparam IMG_BANK_WIDTH  = BANK_UNIT_WIDTH * IMG_UNIT_NUM;// IMG bank
localparam IMG_DATA_WIDTH  = IMG_BANK_NUM * IMG_BANK_WIDTH; // IMG data
localparam IMG_ADDR_WIDTH  = IMG_BANK_NUM * BANK_ADDR_WIDTH;// IMG addr


//*******************************************************************
// define and logic of ready signal
//*******************************************************************
wire [IMG_GRP_NUM -1:0] conv_write_ready;
wire [IMG_GRP_NUM -1:0] misc_write_ready;
wire [IMG_GRP_NUM -1:0] load_write_ready;
assign conv_write_ready_o = | conv_write_ready;
assign misc_write_ready_o = | misc_write_ready;
assign load_write_ready_o = | load_write_ready;

//*******************************************************************
// utilize and connect arbiter modules (there are no port modules)
//*******************************************************************
generate
    genvar i; //generate IMG_GRP_NUM arbiters connected to groups
    for(i=0; i<IMG_GRP_NUM; i=i+1) 
    begin: wr_abit_of_grps //generator name: write arbiters of groups
        write_arbiter #(
            .IMG_GRP_NUM     (IMG_GRP_NUM ),
            .ROW_PARA        (ROW_PARA),
            .COL_PARA        (COL_PARA),
            .CHL_PARA        (CHL_PARA),
            .BANK_ADDR_WIDTH (BANK_ADDR_WIDTH),
            .BANK_UNIT_WIDTH (BANK_UNIT_WIDTH),
            .ADDR_WIDTH      (IMG_ADDR_WIDTH),
            .DATA_WIDTH      (IMG_DATA_WIDTH)
        ) INST_wr_arbiter (
            .clk        (clk),
            .rst_p      (rst_p),
            // connect with conv
            .conv_write_valid_i      (conv_write_group_id_i[i]),
            .conv_write_bank_en_i    (conv_write_bank_en_i),
            .conv_write_addr_i       (conv_write_addr_i),
            .conv_write_ready_o      (conv_write_ready[i]),
            .conv_write_data_i       (conv_write_data_i),
            // connect with misc
            .misc_write_valid_i      (misc_write_group_id_i[i]),
            .misc_write_bank_en_i    (misc_write_bank_en_i),
            .misc_write_addr_i       (misc_write_addr_i),
            .misc_write_ready_o      (misc_write_ready[i]),
            .misc_write_data_i       (misc_write_data_i),
            // connect with save
            .load_write_valid_i      (load_write_group_id_i[i]),
            .load_write_bank_en_i    (load_write_bank_en_i),
            .load_write_addr_i       (load_write_addr_i),
            .load_write_ready_o      (load_write_ready[i]),
            .load_write_data_i       (load_write_data_i),
            // connect with image memory pool
            .ram_write_bank_en_o (write_bank_en_o [(i+1)*IMG_BANK_NUM
                                                -1 :i*IMG_BANK_NUM]),
            .ram_write_addr_o    (write_addr_o    [(i+1)*IMG_ADDR_WIDTH
                                                -1 :i*IMG_ADDR_WIDTH]),
            .ram_write_data_o    (write_data_o    [(i+1)*IMG_DATA_WIDTH
                                                -1 :i*IMG_DATA_WIDTH])
        );
    end
endgenerate


endmodule