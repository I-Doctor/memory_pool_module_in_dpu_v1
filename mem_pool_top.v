`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////
// (c) Copyright EFC of NICS, Tsinghua University. All rights reserved.
// Engineer: Kai Zhong
// Email   : zhongk15@mails.tsinghua.edu.cn
//
// Create Date   : 2018.12.29
// Module Name   : mem_pool_top
// Project Name  : dpu_v_1
// Target Devices: KU115
// Tool Versions : vivado 2017.3
// Description   : memory pool module, contains IMG_GRP_NUM image
//                 block RAM groups, a weight group and a bias group.
//                 There are read and write control to schedule the
//                 image groups, and weight control to control others 
// Dependencies  : utilized by dpu_top
//                 contains read_control, write_control, weight_control
//                 bram_group
//                 parametered by dpu_top and 
// Revision      :
// Modification History:
// Date by Version Change Description
//====================================
//
//====================================
//
///////////////////////////////////////////////////////////////////////

module mem_pool_top #(
    parameter IMG_GRP_NUM       = 3,  // number of image memory group
    parameter ROW_PARA          = 4,  // number of bank in image group
    parameter COL_PARA          = 1,  // colomn parallize
    parameter CHL_PARA          = 8,  // number of unit in a image bank
    parameter BANK_ADDR_WIDTH   = 12, // width of address of a bank
    parameter BANK_UNIT_WIDTH   = 8   // quantize bits width
)(
    input clk,
    input rst_p,

    // IMAGE read 
    // image read port with Conv
    input  [IMG_GRP_NUM    -1:0] conv_read_group_id_i,
    input  [IMG_BANK_NUM   -1:0] conv_read_bank_en_i,
    input  [IMG_ADDR_WIDTH -1:0] conv_read_addr_i,
    output                       conv_read_addr_ready_o,
    output                       conv_read_data_valid_o,
    output [IMG_DATA_WIDTH -1:0] conv_read_data_o,
    input                        conv_read_data_ready_i,
    // image read port with MISC
    input  [IMG_GRP_NUM    -1:0] misc_read_group_id_i,
    input  [IMG_BANK_NUM   -1:0] misc_read_bank_en_i,
    input  [IMG_ADDR_WIDTH -1:0] misc_read_addr_i,
    output                       misc_read_addr_ready_o,
    output                       misc_read_data_valid_o,
    output [IMG_DATA_WIDTH -1:0] misc_read_data_o,
    input                        misc_read_data_ready_i,
    // image read port with Save
    input  [IMG_GRP_NUM    -1:0] save_read_group_id_i,
    input  [IMG_BANK_NUM   -1:0] save_read_bank_en_i,
    input  [IMG_ADDR_WIDTH -1:0] save_read_addr_i,
    output                       save_read_addr_ready_o,
    output                       save_read_data_valid_o,
    output [IMG_DATA_WIDTH -1:0] save_read_data_o,
    input                        save_read_data_ready_i,

    // IMAGE write
    // image write port with Conv
    input  [IMG_GRP_NUM    -1:0] conv_write_group_id_i,
    input  [IMG_BANK_NUM   -1:0] conv_write_bank_en_i,
    input  [IMG_ADDR_WIDTH -1:0] conv_write_addr_i,
    input  [IMG_DATA_WIDTH -1:0] conv_write_data_i,
    output                       conv_write_ready_o,
    // image write port with MISC
    input  [IMG_GRP_NUM    -1:0] misc_write_group_id_i,
    input  [IMG_BANK_NUM   -1:0] misc_write_bank_en_i,
    input  [IMG_ADDR_WIDTH -1:0] misc_write_addr_i,
    input  [IMG_DATA_WIDTH -1:0] misc_write_data_i,
    output                       misc_write_ready_o,
    // image write port with Load
    input  [IMG_GRP_NUM    -1:0] load_write_group_id_i,
    input  [IMG_BANK_NUM   -1:0] load_write_bank_en_i,
    input  [IMG_ADDR_WIDTH -1:0] load_write_addr_i,
    input  [IMG_DATA_WIDTH -1:0] load_write_data_i,
    output                       load_write_ready_o,

    // WEIGHTS read and write
    // weights(weight&bias) read port with Conv
    input                         weight_read_en_i,
    input  [WEIT_ADDR_WIDTH -1:0] weight_read_addr_i,
    output [WEIT_DATA_WIDTH -1:0] weight_read_data_o,
    input                         bias_read_en_i,
    input  [BIAS_ADDR_WIDTH -1:0] bias_read_addr_i,
    output [BIAS_DATA_WIDTH -1:0] bias_read_data_o,
    // weights(weight&bias) write port with Load
    input                         weight_write_en_i,
    input  [WEIT_ADDR_WIDTH -1:0] weight_write_addr_i,
    input  [WEIT_DATA_WIDTH -1:0] weight_write_data_i,
    input                         bias_write_en_i,
    input  [BIAS_ADDR_WIDTH -1:0] bias_write_addr_i,
    input  [BIAS_DATA_WIDTH -1:0] bias_write_data_i
);


//*******************************************************************
// localparam and define
//*******************************************************************
// parameters begin with BANK or end with PARA is baisc and 
// which begin with IMG/WEIT/BIAS are specific
localparam BANK_DEPTH      = 2 ** BANK_ADDR_WIDTH;

// IMG: IMG_GRP_NUM groups, ROW_PARA banks, CHL_PARA units
// individual addr: BANK_NUM * BANK_ADDR_WIDTH
localparam IMG_BANK_NUM    = ROW_PARA;
localparam IMG_UNIT_NUM    = CHL_PARA;
localparam IMG_BANK_WIDTH  = BANK_UNIT_WIDTH * IMG_UNIT_NUM;// IMG bank
localparam IMG_DATA_WIDTH  = IMG_BANK_NUM * IMG_BANK_WIDTH; // IMG data
localparam IMG_ADDR_WIDTH  = IMG_BANK_NUM * BANK_ADDR_WIDTH;// IMG addr
localparam IMG_BANK_SIZE   = IMG_BANK_WIDTH * BANK_DEPTH;

// WEIT: 1 groups, CHL_PARA banks, CHL_PARA units
// all same addr: 1 * BANK_ADDR_WIDTH
localparam WEIT_BANK_NUM   = CHL_PARA;
localparam WEIT_UNIT_NUM   = CHL_PARA;
localparam WEIT_BANK_WIDTH = BANK_UNIT_WIDTH * WEIT_UNIT_NUM;//WEITbank
localparam WEIT_DATA_WIDTH = WEIT_BANK_NUM * WEIT_BANK_WIDTH;//WEITdata
localparam WEIT_ADDR_WIDTH = 1 * BANK_ADDR_WIDTH;            //WEITaddr
localparam WEIT_BANK_SIZE  = WEIT_BANK_WIDTH * BANK_DEPTH;

// BIAS: 1 groups, 1 banks, CHL_PARA units
// all same addr: 1 * BANK_ADDR_WIDTH
localparam BIAS_BANK_NUM   = 1;
localparam BIAS_UNIT_NUM   = CHL_PARA;
localparam BIAS_BANK_WIDTH = BANK_UNIT_WIDTH * BIAS_UNIT_NUM;//BIASbank
localparam BIAS_DATA_WIDTH = BIAS_BANK_NUM * BIAS_BANK_WIDTH;//BIASdata
localparam BIAS_ADDR_WIDTH = 1 * BANK_ADDR_WIDTH;            //BIASaddr
localparam BIAS_BANK_SIZE  = BIAS_BANK_WIDTH * BANK_DEPTH;


//*******************************************************************
// wires between three control modules and bram_groups
//*******************************************************************
// read wires
wire [IMG_GRP_NUM * IMG_DATA_WIDTH -1:0] img_read_data;
wire [IMG_GRP_NUM * IMG_ADDR_WIDTH -1:0] img_read_addr;
wire [IMG_GRP_NUM * IMG_BANK_NUM   -1:0] img_read_bank_en;
// write wires
wire [IMG_GRP_NUM * IMG_DATA_WIDTH -1:0] img_write_data;
wire [IMG_GRP_NUM * IMG_ADDR_WIDTH -1:0] img_write_addr;
wire [IMG_GRP_NUM * IMG_BANK_NUM   -1:0] img_write_bank_en;


//*******************************************************************
// utilize and connect read control
//*******************************************************************
read_control #(
    .IMG_GRP_NUM     (IMG_GRP_NUM),
    .ROW_PARA        (ROW_PARA),
    .COL_PARA        (COL_PARA),
    .CHL_PARA        (CHL_PARA),
    .BANK_ADDR_WIDTH (BANK_ADDR_WIDTH),
    .BANK_UNIT_WIDTH (BANK_UNIT_WIDTH)
) INST_read_control (
    .clk    (clk),
    .rst_p  (rst_p),
    // image read port with Conv
    .conv_read_group_id_i   (conv_read_group_id_i),
    .conv_read_bank_en_i    (conv_read_bank_en_i),
    .conv_read_addr_i       (conv_read_addr_i),
    .conv_read_addr_ready_o (conv_read_addr_ready_o),
    .conv_read_data_valid_o (conv_read_data_valid_o),
    .conv_read_data_o       (conv_read_data_o),
    .conv_read_data_ready_i (conv_read_data_ready_i),
    // image read port with MISC
    .misc_read_group_id_i   (misc_read_group_id_i),
    .misc_read_bank_en_i    (misc_read_bank_en_i),
    .misc_read_addr_i       (misc_read_addr_i),
    .misc_read_addr_ready_o (misc_read_addr_ready_o),
    .misc_read_data_valid_o (misc_read_data_valid_o),
    .misc_read_data_o       (misc_read_data_o),
    .misc_read_data_ready_i (misc_read_data_ready_i),  
    // image read port with Save
    .save_read_group_id_i   (save_read_group_id_i),
    .save_read_bank_en_i    (save_read_bank_en_i),
    .save_read_addr_i       (save_read_addr_i),
    .save_read_addr_ready_o (save_read_addr_ready_o),
    .save_read_data_valid_o (save_read_data_valid_o),
    .save_read_data_o       (save_read_data_o),
    .save_read_data_ready_i (save_read_data_ready_i),  
    // image read port with image memory pool (packaged)
    .read_data_i            (img_read_data),
    .read_addr_o            (img_read_addr),
    .read_bank_en_o         (img_read_bank_en)
);


//*******************************************************************
// utilize and connect write control
//*******************************************************************
write_control #(
    .IMG_GRP_NUM     (IMG_GRP_NUM),
    .ROW_PARA        (ROW_PARA),
    .COL_PARA        (COL_PARA),
    .CHL_PARA        (CHL_PARA),
    .BANK_ADDR_WIDTH (BANK_ADDR_WIDTH),
    .BANK_UNIT_WIDTH (BANK_UNIT_WIDTH)
) INST_write_control (
    .clk    (clk),
    .rst_p  (rst_p),
    // image write port with conv
    .conv_write_group_id_i   (conv_write_group_id_i),
    .conv_write_bank_en_i    (conv_write_bank_en_i),
    .conv_write_addr_i       (conv_write_addr_i),
    .conv_write_ready_o      (conv_write_ready_o),
    .conv_write_data_i       (conv_write_data_i),
    // image write port with misc
    .misc_write_group_id_i   (misc_write_group_id_i),
    .misc_write_bank_en_i    (misc_write_bank_en_i),
    .misc_write_addr_i       (misc_write_addr_i),
    .misc_write_ready_o      (misc_write_ready_o),
    .misc_write_data_i       (misc_write_data_i),
    // image write port with save
    .load_write_group_id_i   (load_write_group_id_i),
    .load_write_bank_en_i    (load_write_bank_en_i),
    .load_write_addr_i       (load_write_addr_i),
    .load_write_ready_o      (load_write_ready_o),
    .load_write_data_i       (load_write_data_i),
    // image write port with image memory pool (packaged)
    .write_data_o            (img_write_data),
    .write_addr_o            (img_write_addr),
    .write_bank_en_o         (img_write_bank_en)
);


//*******************************************************************
// utilize and connect weight control
//*******************************************************************

//*******************************************************************
// utilize and connect image groups
//*******************************************************************
generate
    genvar i; //generate IMG_GRP_NUM groups used for image
    for(i=0; i<IMG_GRP_NUM; i=i+1) 
    begin: img_grp //generator name: image group
        bram_group #(
            .BANK_NUM           (IMG_BANK_NUM),
            .BANK_UNIT_NUM      (IMG_UNIT_NUM),
            .BANK_ADDR_WIDTH    (BANK_ADDR_WIDTH),
            .BANK_UNIT_WIDTH    (BANK_UNIT_WIDTH)
        ) INST_img_grp(
            .clk(clk),
            .rst_p(rst_p),

            .write_bank_en_i(img_write_bank_en [(i+1)*IMG_BANK_NUM -1
                                                   :i*IMG_BANK_NUM]),
            .write_addr_i   (img_write_addr    [(i+1)*IMG_ADDR_WIDTH -1
                                                   :i*IMG_ADDR_WIDTH]),
            .write_data_i   (img_write_data    [(i+1)*IMG_DATA_WIDTH -1
                                                   :i*IMG_DATA_WIDTH]),
            
            .read_bank_en_i (img_read_bank_en [(i+1)*IMG_BANK_NUM -1
                                                   :i*IMG_BANK_NUM]),
            .read_addr_i    (img_read_addr    [(i+1)*IMG_ADDR_WIDTH -1
                                                   :i*IMG_ADDR_WIDTH]),
            .read_data_o    (img_read_data    [(i+1)*IMG_DATA_WIDTH -1
                                                   :i*IMG_DATA_WIDTH])
        );
    end
endgenerate


//*******************************************************************
// utilize and connect weight group
//*******************************************************************
bram_group #(
    .BANK_NUM           (WEIT_BANK_NUM),
    .BANK_UNIT_NUM      (WEIT_UNIT_NUM),
    .BANK_ADDR_WIDTH    (BANK_ADDR_WIDTH),
    .BANK_UNIT_WIDTH    (BANK_UNIT_WIDTH)
) INST_weit_grp(
    .clk(clk),
    .rst_p(rst_p),

    .write_bank_en_i ({WEIT_BANK_NUM{weight_write_en_i  }}),
    .write_addr_i    ({WEIT_BANK_NUM{weight_write_addr_i}}),
    .write_data_i    (               weight_write_data_i ),
    
    .read_bank_en_i  ({WEIT_BANK_NUM{weight_read_en_i   }}),
    .read_addr_i     ({WEIT_BANK_NUM{weight_read_addr_i }}),
    .read_data_o     (               weight_read_data_o  )
);


//*******************************************************************
// utilize and connect bias group
//*******************************************************************
bram_group #(
    .BANK_NUM           (BIAS_BANK_NUM),
    .BANK_UNIT_NUM      (BIAS_UNIT_NUM),
    .BANK_ADDR_WIDTH    (BANK_ADDR_WIDTH),
    .BANK_UNIT_WIDTH    (BANK_UNIT_WIDTH)
) INST_bias_grp(
    .clk(clk),
    .rst_p(rst_p),

    .write_bank_en_i ({BIAS_BANK_NUM{bias_write_en_i  }}),
    .write_addr_i    ({BIAS_BANK_NUM{bias_write_addr_i}}),
    .write_data_i    (               bias_write_data_i ),
    
    .read_bank_en_i  ({BIAS_BANK_NUM{bias_read_en_i   }}),
    .read_addr_i     ({BIAS_BANK_NUM{bias_read_addr_i }}),
    .read_data_o     (               bias_read_data_o  )
);


endmodule