`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////
// (c) Copyright EFC of NICS, Tsinghua University. All rights reserved.
// Engineer: Kai Zhong
// Email   : zhongk15@mails.tsinghua.edu.cn
//
// Create Date   : 2018.12.29
// Module Name   : bram_group
// Project Name  : dpu_v_1
// Target Devices: KU115
// Tool Versions : vivado 2017.1
// Description   : receive read request to a specific group of memory 
//                 pool from conv, datasaver, misc then read data from 
//                 the group and send data out
// Dependencies  : utilized by mem_pool_top
//                 contains xpm_mempory_sdpram(ip)
//
// Revision      :
// Modification History:
// Date by Version Change Description
//=====================================================================
//
//=====================================================================
//
///////////////////////////////////////////////////////////////////////
module bram_group #(
    parameter BANK_NUM          = 4,
    parameter BANK_UNIT_NUM     = 8,
    parameter BANK_ADDR_WIDTH   = 12,
    parameter BANK_UNIT_WIDTH   = 8
)(
    input clk,
    input rst_p,

    input  [BANK_NUM                 -1:0] write_bank_en_i,
    input  [BANK_NUM*BANK_ADDR_WIDTH -1:0] write_addr_i,
    input  [BANK_NUM*BANK_UNIT_WIDTH*BANK_UNIT_NUM -1:0] write_data_i,
    
    input  [BANK_NUM                 -1:0] read_bank_en_i,
    input  [BANK_NUM*BANK_ADDR_WIDTH -1:0] read_addr_i,
    output [BANK_NUM*BANK_UNIT_WIDTH*BANK_UNIT_NUM -1:0] read_data_o
);

//*******************************************************************
// localparam and define
//*******************************************************************
localparam BANK_DATA_WIDTH = BANK_UNIT_WIDTH * BANK_UNIT_NUM;
localparam BANK_DEPTH      = 2 ** BANK_ADDR_WIDTH;
localparam BANK_SIZE       = BANK_DATA_WIDTH * BANK_DEPTH;

//*******************************************************************
// generate and connect block RAMs
//*******************************************************************
generate
    genvar i; //generate a group with BANK_NUM banks
    for(i=0; i<BANK_NUM; i=i+1) begin: grp_of_banks //generator name

        // xpm_memory_sdpram: Simple Dual Port RAM
        // Xilinx Parameterized Macro, Version 2017.1
        xpm_memory_sdpram # (
            // Common module parameters
            .MEMORY_SIZE        (BANK_SIZE),       //size of bank
            .MEMORY_PRIMITIVE   ("auto"),          //choose "d" "b" "u"
            .CLOCKING_MODE      ("common_clock"),  //a,b use one clock 
            .MEMORY_INIT_FILE   ("none"),          //no init
            .MEMORY_INIT_PARAM  (""    ),          //no init
            .USE_MEM_INIT       (1),
            .WAKEUP_TIME        ("disable_sleep"), //no sleep
            .MESSAGE_CONTROL    (0),
            .ECC_MODE           ("no_ecc"),        //no ecc
            .AUTO_SLEEP_TIME    (0),               //Do not Change
            // Port A module parameters
            .WRITE_DATA_WIDTH_A (BANK_DATA_WIDTH), //bank data width
            .BYTE_WRITE_WIDTH_A (BANK_DATA_WIDTH), //not byte write 
            .ADDR_WIDTH_A       (BANK_ADDR_WIDTH), //addr width
            // Port B module parameters
            .READ_DATA_WIDTH_B  (BANK_DATA_WIDTH), //bank data width
            .ADDR_WIDTH_B       (BANK_ADDR_WIDTH), //addr width
            .READ_RESET_VALUE_B ("0"),
            .READ_LATENCY_B     (2),               //latency cycles
            .WRITE_MODE_B       ("no_change")      //no change order
        ) INST_sdpram_bank (
            // Common module ports
            .sleep          (1'b0),
            // Port A module ports
            .clka           (clk),
            .ena            (1'b1),
            .wea            (write_bank_en_i[i]),
            .addra          (write_addr_i   [BANK_ADDR_WIDTH*(i+1)-1   
                                                : BANK_ADDR_WIDTH*i]),
            .dina           (write_data_i   [BANK_DATA_WIDTH*(i+1)-1   
                                                : BANK_DATA_WIDTH*i]),
            .injectsbiterra (1'b0),
            .injectdbiterra (1'b0),
            // Port B module ports
            .clkb           (clk),
            .rstb           (rst_p),
            .enb            (read_bank_en_i[i]),
            .regceb         (1'b1),
            .addrb          (read_addr_i   [BANK_ADDR_WIDTH*(i+1)-1   
                                                : BANK_ADDR_WIDTH*i]),
            .doutb          (read_data_o   [BANK_DATA_WIDTH*(i+1)-1   
                                                : BANK_DATA_WIDTH*i]),
            .sbiterrb       (),
            .dbiterrb       ()
        );
    end // block: grp_with_banks
endgenerate

endmodule