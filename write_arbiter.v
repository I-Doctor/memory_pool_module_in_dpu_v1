`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////
// (c) Copyright EFC of NICS, Tsinghua University. All rights reserved.
// Engineer: Kai Zhong
// Email   : zhongk15@mails.tsinghua.edu.cn
//
// Create Date   : 2018.01.16
// Module Name   : write_abiter
// Project Name  : dpu_v_1
// Target Devices: KU115
// Tool Versions : vivado 2017.3
// Description   : receive wirte request to a specific group of memory //                 pool from conv, dataloader, misc, then write data
//                 to this group
// Dependencies  : utilized by write_control
//                 contains my_mux(logic), my_mask(logic)
//
// Revision      :
// Modification History:
// Date by Version Change Description
//====================================
//
//====================================
//
///////////////////////////////////////////////////////////////////////
module write_arbiter #(
    parameter IMG_GRP_NUM       = 3,
    parameter ROW_PARA          = 4,
    parameter COL_PARA          = 1,
    parameter CHL_PARA          = 8,
    parameter BANK_ADDR_WIDTH   = 12,
    parameter BANK_UNIT_WIDTH   = 8,
    parameter ADDR_WIDTH        = 48,
    parameter DATA_WIDTH        = 256
    )(
    input clk,
    input rst_p,

    // connect with Conv
    input                    conv_write_valid_i,
    input [ROW_PARA    -1:0] conv_write_bank_en_i,
    input [ADDR_WIDTH  -1:0] conv_write_addr_i,
    input [DATA_WIDTH  -1:0] conv_write_data_i,
    output                   conv_write_ready_o,

    // connect with MISC
    input                    misc_write_valid_i,
    input [ROW_PARA    -1:0] misc_write_bank_en_i,
    input [ADDR_WIDTH  -1:0] misc_write_addr_i,
    input [DATA_WIDTH  -1:0] misc_write_data_i,
    output                   misc_write_ready_o,
    
    // connect with Load
    input                    load_write_valid_i,
    input [ROW_PARA    -1:0] load_write_bank_en_i,
    input [ADDR_WIDTH  -1:0] load_write_addr_i,
    input [DATA_WIDTH  -1:0] load_write_data_i,
    output                   load_write_ready_o,
    
    // connect with image memory pool
    input  [DATA_WIDTH -1:0] ram_write_data_o,
    output [ADDR_WIDTH -1:0] ram_write_addr_o,
    output [ROW_PARA   -1:0] ram_write_bank_en_o
);


//*******************************************************************
// localparam and define
//*******************************************************************
    localparam CONV_USE = 3'b001;
    localparam MISC_USE = 3'b010;
    localparam SAVE_USE = 3'b100;
    localparam NONE_USE = 3'b000;

//*******************************************************************
// registers
//*******************************************************************
    reg [2            :0] write_state_r;
    reg [ROW_PARA   -1:0] write_bank_en_r;
    reg [ADDR_WIDTH -1:0] write_addr_r;
    reg [DATA_WIDTH -1:0] write_data_r;

//*******************************************************************
// utilize and connect distribute logic and FSM
//*******************************************************************
    // output wires of distribute logic module
    reg [2:0] write_state;
    // output logic of distribute as priority 
    // 1. using first 2. conv misc load order
    always @ (*) begin
        case(write_state_r)
            CONV_USE: begin     // conv is using so conv first
                if (conv_write_valid_i) begin
                    write_state = CONV_USE;
                end 
                else if (misc_write_valid_i) begin
                    write_state = MISC_USE;
                end
                else if (load_write_valid_i) begin
                    write_state = SAVE_USE;
                end
                else write_state = NONE_USE;
            end
            MISC_USE: begin     // misc is using so misc first
                if (misc_write_valid_i) begin
                    write_state = MISC_USE;
                end 
                else if (conv_write_valid_i) begin
                    write_state = CONV_USE;
                end
                else if (load_write_valid_i) begin
                    write_state = SAVE_USE;
                end
                else write_state = NONE_USE;
            end
            SAVE_USE: begin     // load is using so load first
                if (load_write_valid_i) begin
                    write_state = SAVE_USE;
                end 
                else if (conv_write_valid_i) begin
                    write_state = CONV_USE;
                end
                else if (misc_write_valid_i) begin
                    write_state = MISC_USE;
                end
                else write_state = NONE_USE;
            end
            NONE_USE: begin     // no one is using so as priority order
                if (conv_write_valid_i) begin
                    write_state = CONV_USE;
                end 
                else if (misc_write_valid_i) begin
                    write_state = MISC_USE;
                end
                else if (load_write_valid_i) begin
                    write_state = SAVE_USE;
                end
                else write_state = NONE_USE;
            end
            default: write_state = NONE_USE; // default state
        endcase
    end

    // FSM     : write_state_r   next_state: write_state
    always @ (posedge clk) begin
        if (rst_p) begin
            write_state_r <= NONE_USE;
        end
        else begin
            write_state_r <= write_state;
        end
    end

//*******************************************************************
// utilize and connect mux and mask modules
//*******************************************************************
    // bank_en mux
    // input and output wires
    wire [3*ROW_PARA -1:0] bank_en_mux_input;
    wire [ROW_PARA   -1:0] write_bank_en;
    assign bank_en_mux_input = {load_write_bank_en_i,   
                                misc_write_bank_en_i,  
                                conv_write_bank_en_i};
    // bank_en mux
    my_mux #(
        .DATA_WIDTH  (ROW_PARA),
        .CTRL_WIDTH  (3)
    ) INST_bank_en_mux (
        .input_data  (bank_en_mux_input),
        .input_ctrl  (write_state),
        .output_data (write_bank_en)
    );

    // addr mux
    // input and output wires
    wire [3*ADDR_WIDTH -1:0] addr_mux_input;
    wire [ADDR_WIDTH   -1:0] write_addr;
    assign addr_mux_input = {load_write_addr_i, 
                             misc_write_addr_i,
                             conv_write_addr_i};
    // addr mux
    my_mux #(
        .DATA_WIDTH  (ADDR_WIDTH),
        .CTRL_WIDTH  (3)
    ) INST_addr_mux (
        .input_data  (addr_mux_input),
        .input_ctrl  (write_state),
        .output_data (write_addr)
    );

    // addr mux
    // input and output wires
    wire [3*DATA_WIDTH -1:0] data_mux_input;
    wire [DATA_WIDTH   -1:0] write_data;
    assign data_mux_input = {load_write_data_i, 
                             misc_write_data_i,
                             conv_write_data_i};
    // data mux
    my_mux #(
        .DATA_WIDTH  (DATA_WIDTH),
        .CTRL_WIDTH  (3)
    ) INST_data_mux (
        .input_data  (data_mux_input),
        .input_ctrl  (write_state),
        .output_data (write_data)
    );


//*******************************************************************
// utilize and connect other registers
//*******************************************************************
    // bank_en register: write_bank_en_r
    always @ (posedge clk) begin
        if (rst_p) begin
            write_bank_en_r <= {ROW_PARA{1'b0}};
        end
        else begin
            write_bank_en_r <= write_bank_en;
        end
    end
    // addr register : write_addr_r
    always @ (posedge clk) begin
        if (rst_p) begin
            write_addr_r <= {ADDR_WIDTH{1'b0}};
        end
        else begin
            write_addr_r <= write_addr;
        end
    end
    // data register : write_data_r
    always @ (posedge clk) begin
        if (rst_p) begin
            write_data_r <= {DATA_WIDTH{1'b0}};
        end
        else begin
            write_data_r <= write_data;
        end
    end

//*******************************************************************
// output to connect block RAMs
//*******************************************************************
    assign ram_write_bank_en_o = write_bank_en_r;
    assign ram_write_addr_o    = write_addr_r;
    assign ram_write_data_o    = write_data_r;

//*******************************************************************
// output to connect ports
//*******************************************************************
    assign load_write_ready_o = write_state[2];  
    assign misc_write_ready_o = write_state[1]; 
    assign conv_write_ready_o = write_state[0];


endmodule