`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////
// (c) Copyright EFC of NICS, Tsinghua University. All rights reserved.
// Engineer: Kai Zhong
// Email   : zhongk15@mails.tsinghua.edu.cn
//
// Create Date   : 2018.12.29
// Module Name   : read_port
// Project Name  : dpu_v_1
// Target Devices: KU115
// Tool Versions : vivado 2017.1
// Description   : receive read request from a specific module like
//                 conv, datasaver, misc, send requests to the right 
//                 arbiter. wait the data back and use fifo to send
//                 data out
// Dependencies  : utilized by read_control
//                 contains my_mux(logic), xpm_fifo_sync(ip)
//
// Revision      :
// Modification History:
// Date by Version Change Description
//=====================================================================
// 2019.03.04    : correct the logic of fifo_read_en and data_valid
//
//=====================================================================
//
///////////////////////////////////////////////////////////////////////
module read_port #(
    parameter IMG_GRP_NUM       = 3,
    parameter ROW_PARA          = 4,
    parameter ADDR_WIDTH        = 48,
    parameter DATA_WIDTH        = 256
)(
    input clk,
    input rst_p,
    // connect with specific module
    input  [IMG_GRP_NUM -1:0] read_group_id_i,
    input  [ROW_PARA    -1:0] read_bank_en_i,
    input  [ADDR_WIDTH  -1:0] read_addr_i,
    output                    read_addr_ready_o,
    output                    read_data_valid_o,
    output [DATA_WIDTH  -1:0] read_data_o,
    input                     read_data_ready_i,
    // connect with arbiter 0
    output                    read_en_group_0_o,
    output [ROW_PARA    -1:0] read_bank_en_group_0_o,
    output [ADDR_WIDTH  -1:0] read_addr_group_0_o,
    input                     read_addr_ready_group_0_i,
    input                     read_data_valid_group_0_i,
    input  [DATA_WIDTH  -1:0] read_data_group_0_i,
    output                    read_nostall_group_0_o, 
    // connect with arbiter 1
    output                    read_en_group_1_o,
    output [ROW_PARA    -1:0] read_bank_en_group_1_o,
    output [ADDR_WIDTH  -1:0] read_addr_group_1_o,
    input                     read_addr_ready_group_1_i,
    input                     read_data_valid_group_1_i,
    input  [DATA_WIDTH  -1:0] read_data_group_1_i,
    output                    read_nostall_group_1_o,
    // connect with arbiter 2
    output                    read_en_group_2_o,
    output [ROW_PARA    -1:0] read_bank_en_group_2_o,
    output [ADDR_WIDTH  -1:0] read_addr_group_2_o,
    input                     read_addr_ready_group_2_i,
    input                     read_data_valid_group_2_i,
    input  [DATA_WIDTH  -1:0] read_data_group_2_i,
    output                    read_nostall_group_2_o
);

//*******************************************************************
// localparam and define
//*******************************************************************
    localparam READ_CYCLE = 5;
    localparam FIFO_DEPTH = 32;
    localparam FIFO_FULL  = FIFO_DEPTH - READ_CYCLE;

//*******************************************************************
// registers
//*******************************************************************
    reg read_data_valid_r;

//*******************************************************************
// utilize and connect mux and mask modules
//*******************************************************************
    // fifo mux
    // ctrl and input and output wires
    wire [IMG_GRP_NUM            -1:0] fifo_mux_ctrl;
    wire [IMG_GRP_NUM*DATA_WIDTH -1:0] fifo_mux_input;
    wire [DATA_WIDTH             -1:0] fifo_data;
    assign fifo_mux_ctrl  = {read_data_valid_group_2_i,  
                             read_data_valid_group_1_i,  
                             read_data_valid_group_0_i};
    assign fifo_mux_input = {read_data_group_2_i,  
                             read_data_group_1_i,  
                             read_data_group_0_i};
    // fifo mux
    my_mux #(
        .DATA_WIDTH  (DATA_WIDTH),
        .CTRL_WIDTH  (IMG_GRP_NUM)
    ) INST_addr_mux (
        .input_data  (fifo_mux_input),
        .input_ctrl  (fifo_mux_ctrl),
        .output_data (fifo_data)
    );

//*******************************************************************
// utilize and connect fifo
//*******************************************************************
    // input ctrl and output signal of fifo
    wire fifo_will_full;
    wire fifo_empty;
    wire fifo_write_en;
    wire fifo_read_en;
    // assgin logic
    // fifo_read_en's logic needs careful consideration with valid
    assign fifo_read_en  = ((~fifo_empty) && (~read_data_valid_o)) ||
                           ((~fifo_empty)       && 
                            (read_data_valid_o) &&
                            (read_data_ready_i));
    // fifo_read_en =  --- fifo_empty 						0
    //				    |
    //					-- ~fifo_empty --- valid --- ready 	1
    //									|		  |
    //									|		  -- ~ready 0
    //									-- ~valid           1
    //
    // valid <= --- read_en 						1
    //			 |
    //			 -- ~read_en --- valid --- ready    0
    //						  |			|
    //						  |			-- ~ready   1
    //						  -- ~valid             0
    assign fifo_write_en = read_data_valid_group_2_i |
                           read_data_valid_group_1_i |
                           read_data_valid_group_0_i;
    assign read_nostall_group_2_o = ~fifo_will_full;
    assign read_nostall_group_1_o = ~fifo_will_full;
    assign read_nostall_group_0_o = ~fifo_will_full;
    // xpm_fifo_sync: Synchronous FIFO
    // Xilinx Parameterized Macro, Version 2017.1
    xpm_fifo_sync # (
        .FIFO_MEMORY_TYPE    ("auto"),    //string; "auto", "block", "distributed", or "ultra";
        .ECC_MODE            ("no_ecc"),  //string;"no_ecc"or"en_ecc";
        .FIFO_WRITE_DEPTH    (FIFO_DEPTH),//positive integer
        .WRITE_DATA_WIDTH    (DATA_WIDTH),//positive integer
        .WR_DATA_COUNT_WIDTH (6),         //positive integer
        .PROG_FULL_THRESH    (FIFO_FULL), //positive integer
        .FULL_RESET_VALUE    (0),         //positive integer; 0 or 1
        .READ_MODE           ("std"),     //string; "std" or "fwft";
        .FIFO_READ_LATENCY   (1),         //positive integer;
        .READ_DATA_WIDTH     (DATA_WIDTH),//positive integer
        .RD_DATA_COUNT_WIDTH (6),         //positive integer
        .PROG_EMPTY_THRESH   (10),        //positive integer
        .DOUT_RESET_VALUE    ("0"),       //string
        .WAKEUP_TIME         (0)          //positive integer; 0 or 2;
    ) INST_xpm_fifo_sync (
        .sleep            (1'b0),
        .rst              (rst_p),
        .wr_clk           (clk),
        .wr_en            (fifo_write_en),
        .din              (fifo_data),
        .full             (),
        .prog_full        (fifo_will_full),
        .wr_data_count    (),
        .overflow         (),
        .wr_rst_busy      (),
        .rd_en            (fifo_read_en),
        .dout             (read_data_o),
        .empty            (fifo_empty),
        .prog_empty       (),
        .rd_data_count    (),
        .underflow        (),
        .rd_rst_busy      (),
        .injectsbiterr    (1'b0),
        .injectdbiterr    (1'b0),
        .sbiterr          (),
        .dbiterr          ()
    );

//*******************************************************************
// utilize and connect output register read_data_valid
//*******************************************************************
    always @ (posedge clk) begin
        if (rst_p) begin
            read_data_valid_r <= 1'b0;
        end
        else begin
            read_data_valid_r <= (fifo_read_en) || 
            					 (   (~fifo_read_en) 
            					   &&( read_data_valid_o)
            					   &&(~read_data_ready_i)
            					 );
        end
    end
    assign read_data_valid_o = read_data_valid_r;

//*******************************************************************
// assign output signals
//*******************************************************************
    // responce to any one of ready
    assign read_addr_ready_o = read_addr_ready_group_0_i ||
                               read_addr_ready_group_1_i ||
                               read_addr_ready_group_2_i;

    // distributed to different group
    assign read_en_group_0_o = read_group_id_i[0];
    assign read_en_group_1_o = read_group_id_i[1];
    assign read_en_group_2_o = read_group_id_i[2];

    assign read_bank_en_group_0_o = read_bank_en_i;
    assign read_bank_en_group_1_o = read_bank_en_i;
    assign read_bank_en_group_2_o = read_bank_en_i;

    assign read_addr_group_0_o = read_addr_i;
    assign read_addr_group_1_o = read_addr_i;
    assign read_addr_group_2_o = read_addr_i;
    

endmodule