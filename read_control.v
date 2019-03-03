`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////
// (c) Copyright EFC of NICS, Tsinghua University. All rights reserved.
// Engineer: Kai Zhong
// Email   : zhongk15@mails.tsinghua.edu.cn
//
// Create Date   : 2018.12.29
// Module Name   : read_control
// Project Name  : dpu_v_1
// Target Devices: KU115
// Tool Versions : vivado 2017.1
// Description   : receive read request to on-chip image memory pool 
//                 from conv, datasaver, misc, then read data from the 
//                 right group and right bank of on-chip memory pool 
//                 and send data back to the right module
// Dependencies  : utilized by mem_pool_top
//                 contains read_port, read_arbiter
//
// Revision      :
// Modification History:
// Date by Version Change Description
//=====================================================================
// 2019.03.03    : change input and output localparam
// 
//=====================================================================
//
///////////////////////////////////////////////////////////////////////
module read_control #(
    parameter IMG_GRP_NUM       = 3,
    parameter ROW_PARA          = 4,
    parameter COL_PARA          = 1,
    parameter CHL_PARA          = 8,
    parameter BANK_ADDR_WIDTH   = 12,
    parameter BANK_UNIT_WIDTH   = 8
    )(
    input clk,
    input rst_p,

   // image read port with Conv
    input  [IMG_GRP_NUM    -1:0] conv_read_group_id_i,
    input  [ROW_PARA       -1:0] conv_read_bank_en_i,
    input  [ROW_PARA* BANK_ADDR_WIDTH -1:0] conv_read_addr_i,
    output                       conv_read_addr_ready_o,
    output                       conv_read_data_valid_o,
    output [IMG_DATA_WIDTH -1:0] conv_read_data_o,
    input                        conv_read_data_ready_i,

    // image read port with MISC
    input  [IMG_GRP_NUM    -1:0] misc_read_group_id_i,
    input  [ROW_PARA       -1:0] misc_read_bank_en_i,
    input  [ROW_PARA* BANK_ADDR_WIDTH -1:0] misc_read_addr_i,
    output                       misc_read_addr_ready_o,
    output                       misc_read_data_valid_o,
    output [IMG_DATA_WIDTH -1:0] misc_read_data_o,
    input                        misc_read_data_ready_i,
    
    // image read port with Save
    input  [IMG_GRP_NUM    -1:0] save_read_group_id_i,
    input  [ROW_PARA       -1:0] save_read_bank_en_i,
    input  [ROW_PARA* BANK_ADDR_WIDTH -1:0] save_read_addr_i,
    output                       save_read_addr_ready_o,
    output                       save_read_data_valid_o,
    output [IMG_DATA_WIDTH -1:0] save_read_data_o,
    input                        save_read_data_ready_i,
    
    // image read port with image memory pool (packaged)
    input  [IMG_GRP_NUM * IMG_DATA_WIDTH -1:0] read_data_i,
    output [IMG_GRP_NUM * ROW_PARA* BANK_ADDR_WIDTH -1:0] read_addr_o,
    output [IMG_GRP_NUM * IMG_BANK_NUM   -1:0] read_bank_en_o

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
// crossbar wires
//*******************************************************************
// conv port -- group 0
wire                       conv_read_en_group_0;
wire [IMG_BANK_NUM   -1:0] conv_read_bank_en_group_0;
wire [IMG_ADDR_WIDTH -1:0] conv_read_addr_group_0;
wire                       conv_read_addr_ready_group_0;
wire                       conv_read_data_valid_group_0;
wire [IMG_DATA_WIDTH -1:0] conv_read_data_group_0;
wire                       conv_read_nostall_group_0;
// conv port -- group 1
wire                       conv_read_en_group_1;
wire [IMG_BANK_NUM   -1:0] conv_read_bank_en_group_1;
wire [IMG_ADDR_WIDTH -1:0] conv_read_addr_group_1;
wire                       conv_read_addr_ready_group_1;
wire                       conv_read_data_valid_group_1;
wire [IMG_DATA_WIDTH -1:0] conv_read_data_group_1;
wire                       conv_read_nostall_group_1;
// conv port -- group 2
wire                       conv_read_en_group_2;
wire [IMG_BANK_NUM   -1:0] conv_read_bank_en_group_2;
wire [IMG_ADDR_WIDTH -1:0] conv_read_addr_group_2;
wire                       conv_read_addr_ready_group_2;
wire                       conv_read_data_valid_group_2;
wire [IMG_DATA_WIDTH -1:0] conv_read_data_group_2;
wire                       conv_read_nostall_group_2;
// misc port -- group 0
wire                       misc_read_en_group_0;
wire [IMG_BANK_NUM   -1:0] misc_read_bank_en_group_0;
wire [IMG_ADDR_WIDTH -1:0] misc_read_addr_group_0;
wire                       misc_read_addr_ready_group_0;
wire                       misc_read_data_valid_group_0;
wire [IMG_DATA_WIDTH -1:0] misc_read_data_group_0;
wire                       misc_read_nostall_group_0;
// misc port -- group 1
wire                       misc_read_en_group_1;
wire [IMG_BANK_NUM   -1:0] misc_read_bank_en_group_1;
wire [IMG_ADDR_WIDTH -1:0] misc_read_addr_group_1;
wire                       misc_read_addr_ready_group_1;
wire                       misc_read_data_valid_group_1;
wire [IMG_DATA_WIDTH -1:0] misc_read_data_group_1;
wire                       misc_read_nostall_group_1;
// misc port -- group 2
wire                       misc_read_en_group_2;
wire [IMG_BANK_NUM   -1:0] misc_read_bank_en_group_2;
wire [IMG_ADDR_WIDTH -1:0] misc_read_addr_group_2;
wire                       misc_read_addr_ready_group_2;
wire                       misc_read_data_valid_group_2;
wire [IMG_DATA_WIDTH -1:0] misc_read_data_group_2;
wire                       misc_read_nostall_group_2;
// save port -- group 0
wire                       save_read_en_group_0;
wire [IMG_BANK_NUM   -1:0] save_read_bank_en_group_0;
wire [IMG_ADDR_WIDTH -1:0] save_read_addr_group_0;
wire                       save_read_addr_ready_group_0;
wire                       save_read_data_valid_group_0;
wire [IMG_DATA_WIDTH -1:0] save_read_data_group_0;
wire                       save_read_nostall_group_0;
// save port -- group 1
wire                       save_read_en_group_1;
wire [IMG_BANK_NUM   -1:0] save_read_bank_en_group_1;
wire [IMG_ADDR_WIDTH -1:0] save_read_addr_group_1;
wire                       save_read_addr_ready_group_1;
wire                       save_read_data_valid_group_1;
wire [IMG_DATA_WIDTH -1:0] save_read_data_group_1;
wire                       save_read_nostall_group_1;
// save port -- group 2
wire                       save_read_en_group_2;
wire [IMG_BANK_NUM   -1:0] save_read_bank_en_group_2;
wire [IMG_ADDR_WIDTH -1:0] save_read_addr_group_2;
wire                       save_read_addr_ready_group_2;
wire                       save_read_data_valid_group_2;
wire [IMG_DATA_WIDTH -1:0] save_read_data_group_2;
wire                       save_read_nostall_group_2;

//*******************************************************************
// utilize and connect port modules
//*******************************************************************
// conv port
read_port #(
    .IMG_GRP_NUM  (IMG_GRP_NUM ),
    .ROW_PARA     (ROW_PARA),
    .ADDR_WIDTH   (IMG_ADDR_WIDTH),
    .DATA_WIDTH   (IMG_DATA_WIDTH)
) INST_conv_read_port (
    .clk    (clk),
    .rst_p  (rst_p),
    // connect with conv
    .read_group_id_i   (conv_read_group_id_i),
    .read_bank_en_i    (conv_read_bank_en_i),
    .read_addr_i       (conv_read_addr_i),
    .read_addr_ready_o (conv_read_addr_ready_o),
    .read_data_valid_o (conv_read_data_valid_o),
    .read_data_o       (conv_read_data_o),
    .read_data_ready_i (conv_read_data_ready_i),
    // connect with arbiter 0
    .read_en_group_0_o           (conv_read_en_group_0),
    .read_bank_en_group_0_o      (conv_read_bank_en_group_0),
    .read_addr_group_0_o         (conv_read_addr_group_0),
    .read_addr_ready_group_0_i   (conv_read_addr_ready_group_0),
    .read_data_valid_group_0_i   (conv_read_data_valid_group_0),
    .read_data_group_0_i         (conv_read_data_group_0),
    .read_nostall_group_0_o      (conv_read_nostall_group_0),
    // connect with arbiter 1
    .read_en_group_1_o           (conv_read_en_group_1),
    .read_bank_en_group_1_o      (conv_read_bank_en_group_1),
    .read_addr_group_1_o         (conv_read_addr_group_1),
    .read_addr_ready_group_1_i   (conv_read_addr_ready_group_1),
    .read_data_valid_group_1_i   (conv_read_data_valid_group_1),
    .read_data_group_1_i         (conv_read_data_group_1),
    .read_nostall_group_1_o      (conv_read_nostall_group_1),
    // connect with arbiter 2
    .read_en_group_2_o           (conv_read_en_group_2),
    .read_bank_en_group_2_o      (conv_read_bank_en_group_2),
    .read_addr_group_2_o         (conv_read_addr_group_2),
    .read_addr_ready_group_2_i   (conv_read_addr_ready_group_2),
    .read_data_valid_group_2_i   (conv_read_data_valid_group_2),
    .read_data_group_2_i         (conv_read_data_group_2),
    .read_nostall_group_2_o      (conv_read_nostall_group_2)
);

// mics port
read_port #(
    .IMG_GRP_NUM  (IMG_GRP_NUM ),
    .ROW_PARA     (ROW_PARA),
    .ADDR_WIDTH   (IMG_ADDR_WIDTH),
    .DATA_WIDTH   (IMG_DATA_WIDTH)
) INST_misc_read_port (
    .clk    (clk),
    .rst_p  (rst_p),
    // connect with misc
    .read_group_id_i   (misc_read_group_id_i),
    .read_bank_en_i    (misc_read_bank_en_i),
    .read_addr_i       (misc_read_addr_i),
    .read_addr_ready_o (misc_read_addr_ready_o),
    .read_data_valid_o (misc_read_data_valid_o),
    .read_data_o       (misc_read_data_o),
    .read_data_ready_i (misc_read_data_ready_i),
    // connect with arbiter 0
    .read_en_group_0_o           (misc_read_en_group_0),
    .read_bank_en_group_0_o      (misc_read_bank_en_group_0),
    .read_addr_group_0_o         (misc_read_addr_group_0),
    .read_addr_ready_group_0_i   (misc_read_addr_ready_group_0),
    .read_data_valid_group_0_i   (misc_read_data_valid_group_0),
    .read_data_group_0_i         (misc_read_data_group_0),
    .read_nostall_group_0_o      (misc_read_nostall_group_0),
    // connect with arbiter 1
    .read_en_group_1_o           (misc_read_en_group_1),
    .read_bank_en_group_1_o      (misc_read_bank_en_group_1),
    .read_addr_group_1_o         (misc_read_addr_group_1),
    .read_addr_ready_group_1_i   (misc_read_addr_ready_group_1),
    .read_data_valid_group_1_i   (misc_read_data_valid_group_1),
    .read_data_group_1_i         (misc_read_data_group_1),
    .read_nostall_group_1_o (misc_read_nostall_group_1),
    // connect with arbiter 2
    .read_en_group_2_o           (misc_read_en_group_2),
    .read_bank_en_group_2_o      (misc_read_bank_en_group_2),
    .read_addr_group_2_o         (misc_read_addr_group_2),
    .read_addr_ready_group_2_i   (misc_read_addr_ready_group_2),
    .read_data_valid_group_2_i   (misc_read_data_valid_group_2),
    .read_data_group_2_i         (misc_read_data_group_2),
    .read_nostall_group_2_o      (misc_read_nostall_group_2)
);

// save port
read_port #(
    .IMG_GRP_NUM  (IMG_GRP_NUM ),
    .ROW_PARA     (ROW_PARA),
    .ADDR_WIDTH   (IMG_ADDR_WIDTH),
    .DATA_WIDTH   (IMG_DATA_WIDTH)
) INST_save_read_port (
    .clk    (clk),
    .rst_p  (rst_p),
    // connect with save
    .read_group_id_i   (save_read_group_id_i),
    .read_bank_en_i    (save_read_bank_en_i),
    .read_addr_i       (save_read_addr_i),
    .read_addr_ready_o (save_read_addr_ready_o),
    .read_data_valid_o (save_read_data_valid_o),
    .read_data_o       (save_read_data_o),
    .read_data_ready_i (save_read_data_ready_i),
    // connect with arbiter 0
    .read_en_group_0_o           (save_read_en_group_0),
    .read_bank_en_group_0_o      (save_read_bank_en_group_0),
    .read_addr_group_0_o         (save_read_addr_group_0),
    .read_addr_ready_group_0_i   (save_read_addr_ready_group_0),
    .read_data_valid_group_0_i   (save_read_data_valid_group_0),
    .read_data_group_0_i         (save_read_data_group_0),
    .read_nostall_group_0_o      (save_read_nostall_group_0),
    // connect with arbiter 1
    .read_en_group_1_o           (save_read_en_group_1),
    .read_bank_en_group_1_o      (save_read_bank_en_group_1),
    .read_addr_group_1_o         (save_read_addr_group_1),
    .read_addr_ready_group_1_i   (save_read_addr_ready_group_1),
    .read_data_valid_group_1_i   (save_read_data_valid_group_1),
    .read_data_group_1_i         (save_read_data_group_1),
    .read_nostall_group_1_o      (save_read_nostall_group_1),
    // connect with arbiter 2
    .read_en_group_2_o           (save_read_en_group_2),
    .read_bank_en_group_2_o      (save_read_bank_en_group_2),
    .read_addr_group_2_o         (save_read_addr_group_2),
    .read_addr_ready_group_2_i   (save_read_addr_ready_group_2),
    .read_data_valid_group_2_i   (save_read_data_valid_group_2),
    .read_data_group_2_i         (save_read_data_group_2),
    .read_nostall_group_2_o      (save_read_nostall_group_2)
);

//*******************************************************************
// utilize and connect arbiter modules
//*******************************************************************
// group 0 arbiter
read_arbiter #(
    .IMG_GRP_NUM     (IMG_GRP_NUM ),
    .ROW_PARA        (ROW_PARA),
    .COL_PARA        (COL_PARA),
    .CHL_PARA        (CHL_PARA),
    .BANK_ADDR_WIDTH (BANK_ADDR_WIDTH),
    .BANK_UNIT_WIDTH (BANK_UNIT_WIDTH),
    .ADDR_WIDTH      (IMG_ADDR_WIDTH),
    .DATA_WIDTH      (IMG_DATA_WIDTH)
) INST_group_0_arbiter (
    .clk(clk),
    .rst_p(rst_p),
    // connect with conv
    .conv_read_valid_i      (conv_read_en_group_0),
    .conv_read_bank_en_i    (conv_read_bank_en_group_0),
    .conv_read_addr_i       (conv_read_addr_group_0),
    .conv_read_addr_ready_o (conv_read_addr_ready_group_0),
    .conv_read_data_valid_o (conv_read_data_valid_group_0),
    .conv_read_data_o       (conv_read_data_group_0),
    .conv_read_nostall_i    (conv_read_nostall_group_0),
    // connect with misc
    .misc_read_valid_i      (misc_read_en_group_0),
    .misc_read_bank_en_i    (misc_read_bank_en_group_0),
    .misc_read_addr_i       (misc_read_addr_group_0),
    .misc_read_addr_ready_o (misc_read_addr_ready_group_0),
    .misc_read_data_valid_o (misc_read_data_valid_group_0),
    .misc_read_data_o       (misc_read_data_group_0),
    .misc_read_nostall_i    (misc_read_nostall_group_0),
    // connect with save
    .save_read_valid_i      (save_read_en_group_0),
    .save_read_bank_en_i    (save_read_bank_en_group_0),
    .save_read_addr_i       (save_read_addr_group_0),
    .save_read_addr_ready_o (save_read_addr_ready_group_0),
    .save_read_data_valid_o (save_read_data_valid_group_0),
    .save_read_data_o       (save_read_data_group_0),
    .save_read_nostall_i    (save_read_nostall_group_0),
    // connect with image memory pool
    .ram_read_bank_en_o     (read_bank_en_o [IMG_BANK_NUM   -1:0]),
    .ram_read_addr_o        (read_addr_o    [IMG_ADDR_WIDTH -1:0]),
    .ram_read_data_i        (read_data_i    [IMG_DATA_WIDTH -1:0])
);

// group 1 arbiter
read_arbiter #(
    .IMG_GRP_NUM     (IMG_GRP_NUM ),
    .ROW_PARA        (ROW_PARA),
    .COL_PARA        (COL_PARA),
    .CHL_PARA        (CHL_PARA),
    .BANK_ADDR_WIDTH (BANK_ADDR_WIDTH),
    .BANK_UNIT_WIDTH (BANK_UNIT_WIDTH),
    .ADDR_WIDTH      (IMG_ADDR_WIDTH),
    .DATA_WIDTH      (IMG_DATA_WIDTH)
) INST_group_1_arbiter (
    .clk(clk),
    .rst_p(rst_p),
    // connect with conv
    .conv_read_valid_i      (conv_read_en_group_1),
    .conv_read_bank_en_i    (conv_read_bank_en_group_1),
    .conv_read_addr_i       (conv_read_addr_group_1),
    .conv_read_addr_ready_o (conv_read_addr_ready_group_1),
    .conv_read_data_valid_o (conv_read_data_valid_group_1),
    .conv_read_data_o       (conv_read_data_group_1),
    .conv_read_nostall_i    (conv_read_nostall_group_1),
    // connect with misc
    .misc_read_valid_i      (misc_read_en_group_1),
    .misc_read_bank_en_i    (misc_read_bank_en_group_1),
    .misc_read_addr_i       (misc_read_addr_group_1),
    .misc_read_addr_ready_o (misc_read_addr_ready_group_1),
    .misc_read_data_valid_o (misc_read_data_valid_group_1),
    .misc_read_data_o       (misc_read_data_group_1),
    .misc_read_nostall_i    (misc_read_nostall_group_1),
    // connect with save
    .save_read_valid_i      (save_read_en_group_1),
    .save_read_bank_en_i    (save_read_bank_en_group_1),
    .save_read_addr_i       (save_read_addr_group_1),
    .save_read_addr_ready_o (save_read_addr_ready_group_1),
    .save_read_data_valid_o (save_read_data_valid_group_1),
    .save_read_data_o       (save_read_data_group_1),
    .save_read_nostall_i    (save_read_nostall_group_1),
    // connect with image memory pool
    .ram_read_bank_en_o (read_bank_en_o [2*IMG_BANK_NUM   -1: 
                                                IMG_BANK_NUM]),
    .ram_read_addr_o    (read_addr_o    [2*IMG_ADDR_WIDTH -1:
                                                IMG_ADDR_WIDTH]),
    .ram_read_data_i    (read_data_i    [2*IMG_DATA_WIDTH -1:
                                                IMG_DATA_WIDTH])
);

// group 2 arbiter
read_arbiter #(
    .IMG_GRP_NUM     (IMG_GRP_NUM ),
    .ROW_PARA        (ROW_PARA),
    .COL_PARA        (COL_PARA),
    .CHL_PARA        (CHL_PARA),
    .BANK_ADDR_WIDTH (BANK_ADDR_WIDTH),
    .BANK_UNIT_WIDTH (BANK_UNIT_WIDTH),
    .ADDR_WIDTH      (IMG_ADDR_WIDTH),
    .DATA_WIDTH      (IMG_DATA_WIDTH)
) INST_group_2_arbiter(
    .clk(clk),
    .rst_p(rst_p),
    // connect with conv
    .conv_read_valid_i      (conv_read_en_group_2),
    .conv_read_bank_en_i    (conv_read_bank_en_group_2),
    .conv_read_addr_i       (conv_read_addr_group_2),
    .conv_read_addr_ready_o (conv_read_addr_ready_group_2),
    .conv_read_data_valid_o (conv_read_data_valid_group_2),
    .conv_read_data_o       (conv_read_data_group_2),
    .conv_read_nostall_i    (conv_read_nostall_group_2),
    // connect with misc
    .misc_read_valid_i      (misc_read_en_group_2),
    .misc_read_bank_en_i    (misc_read_bank_en_group_2),
    .misc_read_addr_i       (misc_read_addr_group_2),
    .misc_read_addr_ready_o (misc_read_addr_ready_group_2),
    .misc_read_data_valid_o (misc_read_data_valid_group_2),
    .misc_read_data_o       (misc_read_data_group_2),
    .misc_read_nostall_i    (misc_read_nostall_group_2),
    // connect with save
    .save_read_valid_i      (save_read_en_group_2),
    .save_read_bank_en_i    (save_read_bank_en_group_2),
    .save_read_addr_i       (save_read_addr_group_2),
    .save_read_addr_ready_o (save_read_addr_ready_group_2),
    .save_read_data_valid_o (save_read_data_valid_group_2),
    .save_read_data_o       (save_read_data_group_2),
    .save_read_nostall_i    (save_read_nostall_group_2),
    // connect with image memory pool
    .ram_read_bank_en_o (read_bank_en_o[3*IMG_BANK_NUM  -1: 
                                                2*IMG_BANK_NUM]),
    .ram_read_addr_o    (read_addr_o   [3*IMG_ADDR_WIDTH-1: 
                                                2*IMG_ADDR_WIDTH]),
    .ram_read_data_i    (read_data_i   [3*IMG_DATA_WIDTH-1: 
                                                2*IMG_DATA_WIDTH])
);

endmodule