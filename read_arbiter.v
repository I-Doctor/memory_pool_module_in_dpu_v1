`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////
// (c) Copyright EFC of NICS, Tsinghua University. All rights reserved.
// Engineer: Kai Zhong
// Email   : zhongk15@mails.tsinghua.edu.cn
//
// Create Date   : 2018.12.29
// Module Name   : read_abiter
// Project Name  : dpu_v_1
// Target Devices: KU115
// Tool Versions : vivado 2017.1
// Description   : receive read request to a specific group of memory //                 pool from conv, datasaver, misc, then read data
//                 from this group and send data back
// Dependencies  : utilized by read_control
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
module read_arbiter #(
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

    // connect with conv
    input                    conv_read_valid_i,
    input  [ROW_PARA   -1:0] conv_read_bank_en_i,
    input  [ADDR_WIDTH -1:0] conv_read_addr_i,
    output                   conv_read_addr_ready_o,
    output                   conv_read_data_valid_o,
    output [DATA_WIDTH -1:0] conv_read_data_o,
    input                    conv_read_nostall_i,
    // connect with misc
    input                    misc_read_valid_i,
    input  [ROW_PARA   -1:0] misc_read_bank_en_i,
    input  [ADDR_WIDTH -1:0] misc_read_addr_i,
    output                   misc_read_addr_ready_o,
    output                   misc_read_data_valid_o,
    output [DATA_WIDTH -1:0] misc_read_data_o,
    input                    misc_read_nostall_i,
    // connect with save
    input                    save_read_valid_i,
    input  [ROW_PARA   -1:0] save_read_bank_en_i,
    input  [ADDR_WIDTH -1:0] save_read_addr_i,
    output                   save_read_addr_ready_o,
    output                   save_read_data_valid_o,
    output [DATA_WIDTH -1:0] save_read_data_o,
    input                    save_read_nostall_i,
    // connect with image memory pool
    input  [DATA_WIDTH -1:0] ram_read_data_i,
    output [ROW_PARA   -1:0] ram_read_bank_en_o,
    output [ADDR_WIDTH -1:0] ram_read_addr_o    
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
    reg [2            :0] read_state_t0_r;
    reg [2            :0] read_state_t1_r;
    reg [2            :0] read_state_t2_r;
    reg [ROW_PARA   -1:0] read_bank_en_t0_r;
    reg [ROW_PARA   -1:0] read_bank_en_t1_r;
    reg [ROW_PARA   -1:0] read_bank_en_t2_r;
    reg [ADDR_WIDTH -1:0] read_addr_r;

//*******************************************************************
// utilize and connect distribute logic and FSM
//*******************************************************************
    // output wires of distribute logic module
    reg [2:0] read_state;
    // output logic of distribute as priority 
    // 1. nostall first 2. using first 3. conv misc save order
    always @ (*) begin
        case(read_state_t0_r)
            CONV_USE: begin     // conv is using so conv first
                if (conv_read_valid_i&conv_read_nostall_i) begin
                    read_state = CONV_USE;
                end 
                else if (misc_read_valid_i&misc_read_nostall_i) begin
                    read_state = MISC_USE;
                end
                else if (save_read_valid_i&save_read_nostall_i) begin
                    read_state = SAVE_USE;
                end
                else read_state = NONE_USE;
            end
            MISC_USE: begin     // misc is using so misc first
                if (misc_read_valid_i&misc_read_nostall_i) begin
                    read_state = MISC_USE;
                end 
                else if (conv_read_valid_i&conv_read_nostall_i) begin
                    read_state = CONV_USE;
                end
                else if (save_read_valid_i&save_read_nostall_i) begin
                    read_state = SAVE_USE;
                end
                else read_state = NONE_USE;
            end
            SAVE_USE: begin     // save is using so save first
                if (save_read_valid_i&save_read_nostall_i) begin
                    read_state = SAVE_USE;
                end 
                else if (conv_read_valid_i&conv_read_nostall_i) begin
                    read_state = CONV_USE;
                end
                else if (misc_read_valid_i&misc_read_nostall_i) begin
                    read_state = MISC_USE;
                end
                else read_state = NONE_USE;
            end
            NONE_USE: begin     // no one is using so as priority order
                if (conv_read_valid_i&conv_read_nostall_i) begin
                    read_state = CONV_USE;
                end 
                else if (misc_read_valid_i&misc_read_nostall_i) begin
                    read_state = MISC_USE;
                end
                else if (save_read_valid_i&save_read_nostall_i) begin
                    read_state = SAVE_USE;
                end
                else read_state = NONE_USE;
            end
            default: read_state = NONE_USE; // default state
        endcase
    end

    // FSM     : read_state_t0_r   next_state: read_state
    // FSM pipe: read_state_t1_r & read_state_t2_r
    always @ (posedge clk) begin
        if (rst_p) begin
            read_state_t0_r <= NONE_USE;
            read_state_t1_r <= NONE_USE;
            read_state_t2_r <= NONE_USE;
        end
        else begin
            read_state_t0_r <= read_state;
            read_state_t1_r <= read_state_t0_r;
            read_state_t2_r <= read_state_t1_r;
        end
    end

//*******************************************************************
// utilize and connect mux and mask modules
//*******************************************************************
    // bank_en mux
    // input and output wires
    wire [3*ROW_PARA -1:0] bank_en_mux_input;
    wire [ROW_PARA   -1:0] read_bank_en;
    assign bank_en_mux_input = {save_read_bank_en_i,   
                                misc_read_bank_en_i,  
                                conv_read_bank_en_i};
    // bank_en mux
    my_mux #(
        .DATA_WIDTH  (ROW_PARA),
        .CTRL_WIDTH  (3)
    ) INST_bank_en_mux (
        .input_data  (bank_en_mux_input),
        .input_ctrl  (read_state),
        .output_data (read_bank_en)
    );

    // addr mux
    // input and output wires
    wire [3*ADDR_WIDTH -1:0] addr_mux_input;
    wire [ADDR_WIDTH   -1:0] read_addr;
    assign addr_mux_input = {save_read_addr_i, misc_read_addr_i,conv_read_addr_i};
    // addr mux
    my_mux #(
        .DATA_WIDTH  (ADDR_WIDTH),
        .CTRL_WIDTH  (3)
    ) INST_addr_mux (
        .input_data  (addr_mux_input),
        .input_ctrl  (read_state),
        .output_data (read_addr)
    );

    // output mask
    // input and output wires
    wire [DATA_WIDTH -1:0] data_mask_input;
    wire [DATA_WIDTH -1:0] masked_read_data;    // masked by bank_en
    assign data_mask_input = ram_read_data_i;        // data from RAM
    // output mask
    my_mask #(
        .DATA_WIDTH  (CHL_PARA*BANK_UNIT_WIDTH),
        .CTRL_WIDTH  (ROW_PARA)
    ) INST_out_mask (
        .input_data  (data_mask_input),
        .input_ctrl  (read_bank_en_t2_r),
        .output_data (masked_read_data)
    );

//*******************************************************************
// utilize and connect other registers
//*******************************************************************
    // bank_en register: read_bank_en_t0_r
    // bank_en pipe    : read_bank_en_t1_r & read_bank_en_t2_r
    always @ (posedge clk) begin
        if (rst_p) begin
            read_bank_en_t0_r <= {ROW_PARA{1'b0}};
            read_bank_en_t1_r <= {ROW_PARA{1'b0}};
            read_bank_en_t2_r <= {ROW_PARA{1'b0}};
        end
        else begin
            read_bank_en_t0_r <= read_bank_en;
            read_bank_en_t1_r <= read_bank_en_t0_r;
            read_bank_en_t2_r <= read_bank_en_t1_r;
        end
    end
    // addr register : read_addr_r
    always @ (posedge clk) begin
        if (rst_p) begin
            read_addr_r <= {ADDR_WIDTH{1'b0}};
        end
        else begin
            read_addr_r <= read_addr;
        end
    end

//*******************************************************************
// output to connect block RAMs
//*******************************************************************
    assign ram_read_bank_en_o = read_bank_en_t0_r;
    assign ram_read_addr_o    = read_addr_r;

//*******************************************************************
// output to connect ports
//*******************************************************************
    assign {save_read_addr_ready_o,  
            misc_read_addr_ready_o,  
            conv_read_addr_ready_o} = read_state;
    assign {save_read_data_valid_o,  
            misc_read_data_valid_o,  
            conv_read_data_valid_o} = read_state_t2_r;
    assign save_read_data_o = masked_read_data;
    assign misc_read_data_o = masked_read_data;
    assign conv_read_data_o = masked_read_data;

endmodule