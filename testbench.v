`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////
// (c) Copyright EFC of NICS; Tsinghua University. All rights reserved.
// Engineer: Kai Zhong
// Email   : zhongk15@mails.tsinghua.edu.cn
//
// Create Date   : 2018.12.29
// Module Name   : testbench_mem_pool
// Project Name  : dpu_v_1
// Target Devices: KU115
// Tool Versions : vivado 2017.1
// Description   : generate test signal for mem_pool_top module to test
// Dependencies  : 
//                 contains mem_pool_top
//
// Revision      :
// Modification History:
// Date by Version Change Description
//=====================================================================
// 2019.03.01    : change fwrite to fdisplay so that we get new line
//
//=====================================================================
//
///////////////////////////////////////////////////////////////////////
module testbench_mem_pool #(
    parameter IMG_GRP_NUM       = 3,  // number of image memory group
    parameter ROW_PARA          = 4,  // number of bank in image group
    parameter COL_PARA          = 1,  // colomn parallize
    parameter CHL_PARA          = 8,  // number of unit in a image bank
    parameter BANK_ADDR_WIDTH   = 12, // width of address of a bank
    parameter BANK_UNIT_WIDTH   = 8   // quantize bits width
)(
);

//*********************************************************************
// local parameter
//*********************************************************************
localparam CONV = 2'b00;
localparam MISC = 2'b01;
localparam LOAD = 2'b10;
localparam SAVE = 2'b11;

localparam LENGTH = 16;
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



//*********************************************************************
// input signal regs and output signal wires
//*********************************************************************
reg clk;
reg rst_p;

// IMAGE read 
// image read port with Conv
reg  [IMG_GRP_NUM    -1:0] conv_read_group_id_i;
reg  [IMG_BANK_NUM   -1:0] conv_read_bank_en_i;
reg  [IMG_ADDR_WIDTH -1:0] conv_read_addr_i;
wire                       conv_read_addr_ready_o;
wire                       conv_read_data_valid_o;
wire [IMG_DATA_WIDTH -1:0] conv_read_data_o;
reg                        conv_read_data_ready_i;
// image read port with MISC
reg  [IMG_GRP_NUM    -1:0] misc_read_group_id_i;
reg  [IMG_BANK_NUM   -1:0] misc_read_bank_en_i;
reg  [IMG_ADDR_WIDTH -1:0] misc_read_addr_i;
wire                       misc_read_addr_ready_o;
wire                       misc_read_data_valid_o;
wire [IMG_DATA_WIDTH -1:0] misc_read_data_o;
reg                        misc_read_data_ready_i;
// image read port with Save
reg  [IMG_GRP_NUM    -1:0] save_read_group_id_i;
reg  [IMG_BANK_NUM   -1:0] save_read_bank_en_i;
reg  [IMG_ADDR_WIDTH -1:0] save_read_addr_i;
wire                       save_read_addr_ready_o;
wire                       save_read_data_valid_o;
wire [IMG_DATA_WIDTH -1:0] save_read_data_o;
reg                        save_read_data_ready_i;

// IMAGE write
// image write port with Conv
reg  [IMG_GRP_NUM    -1:0] conv_write_group_id_i;
reg  [IMG_BANK_NUM   -1:0] conv_write_bank_en_i;
reg  [IMG_ADDR_WIDTH -1:0] conv_write_addr_i;
reg  [IMG_DATA_WIDTH -1:0] conv_write_data_i;
wire                       conv_write_ready_o;
// image write port with MISC
reg  [IMG_GRP_NUM    -1:0] misc_write_group_id_i;
reg  [IMG_BANK_NUM   -1:0] misc_write_bank_en_i;
reg  [IMG_ADDR_WIDTH -1:0] misc_write_addr_i;
reg  [IMG_DATA_WIDTH -1:0] misc_write_data_i;
wire                       misc_write_ready_o;
// image write port with Load
reg  [IMG_GRP_NUM    -1:0] load_write_group_id_i;
reg  [IMG_BANK_NUM   -1:0] load_write_bank_en_i;
reg  [IMG_ADDR_WIDTH -1:0] load_write_addr_i;
reg  [IMG_DATA_WIDTH -1:0] load_write_data_i;
wire                       load_write_ready_o;

// WEIGHTS read and write
// weights(weight&bias) read port with Conv
reg                         weight_read_en_i;
reg  [WEIT_ADDR_WIDTH -1:0] weight_read_addr_i;
wire [WEIT_DATA_WIDTH -1:0] weight_read_data_o;
reg                         bias_read_en_i;
reg  [BIAS_ADDR_WIDTH -1:0] bias_read_addr_i;
wire [BIAS_DATA_WIDTH -1:0] bias_read_data_o;
// weights(weight&bias) write port with Load
reg                         weight_write_en_i;
reg  [WEIT_ADDR_WIDTH -1:0] weight_write_addr_i;
reg  [WEIT_DATA_WIDTH -1:0] weight_write_data_i;
reg                         bias_write_en_i;
reg  [BIAS_ADDR_WIDTH -1:0] bias_write_addr_i;
reg  [BIAS_DATA_WIDTH -1:0] bias_write_data_i;

// temp reg for read data jump in read file
reg [IMG_DATA_WIDTH -1:0] conv_read_data_temp;
reg [IMG_DATA_WIDTH -1:0] misc_read_data_temp;
reg [IMG_DATA_WIDTH -1:0] save_read_data_temp;
// receive temp store before write into file
reg [IMG_DATA_WIDTH -1:0] conv_read_data_receive;
reg [IMG_DATA_WIDTH -1:0] misc_read_data_receive;
reg [IMG_DATA_WIDTH -1:0] save_read_data_receive;

//*********************************************************************
// generate reset and clk signals
//*********************************************************************
initial begin
    rst_p = 0;
    #5 rst_p = 1;
    #55 rst_p = 0;
end

initial begin
    clk = 1;
    forever #10 clk = ~clk;
end


//*********************************************************************
// write tasks define
//*********************************************************************
// task of conv write
task ConvWrite;
integer conv_i;
integer conv_write_file;  
begin
    $display($time, " << CONV write mem_pool >>");
    conv_write_file = $fopen("/home/zk/workspace/dpu_dev/project/data/conv_write.txt","r");
    @(posedge clk);
    for(conv_i=0;conv_i<LENGTH;conv_i=conv_i+1) begin 
        $fscanf(conv_write_file, "%h", conv_write_group_id_i);
        $fscanf(conv_write_file, "%h", conv_write_bank_en_i);
        $fscanf(conv_write_file, "%h", conv_write_addr_i);
        $fscanf(conv_write_file, "%h", conv_write_data_i);
        $display($time, " CONV write %3d grp: %h",   conv_i, conv_write_group_id_i);
        $display($time, " CONV write %3d bank: %h",  conv_i, conv_write_bank_en_i);
        @(posedge clk);
        $display($time, " CONV write %3d ready? %h", conv_i, conv_write_ready_o);
        while (conv_write_group_id_i!=0&&conv_write_ready_o!=1) begin
            @(posedge clk);
        end
        $display($time, " CONV write %3d ready? %h", conv_i, conv_write_ready_o);
    end
    conv_write_group_id_i <= 0;
    $fclose(conv_write_file);
end
endtask

// task of misc write
task MiscWrite;
integer misc_i;
integer misc_write_file;  
begin
    $display($time, " << MISC write mem_pool >>");
    misc_write_file = $fopen("/home/zk/workspace/dpu_dev/project/data/misc_write.txt","r");
    @(posedge clk);
    for(misc_i=0;misc_i<LENGTH;misc_i=misc_i+1) begin 
        $fscanf(misc_write_file, "%h", misc_write_group_id_i);
        $fscanf(misc_write_file, "%h", misc_write_bank_en_i);
        $fscanf(misc_write_file, "%h", misc_write_addr_i);
        $fscanf(misc_write_file, "%h", misc_write_data_i);
        $display($time, " MISC write %d grp: %h",   misc_i, misc_write_group_id_i);
        $display($time, " MISC write %d bank: %h",  misc_i, misc_write_bank_en_i);
        @(posedge clk);
        $display($time, " MISC write %d ready? %h", misc_i, misc_write_ready_o);
        while (misc_write_group_id_i!=0&&misc_write_ready_o!=1) begin
            @(posedge clk);
        end
        $display($time, " MISC write %d ready? %h", misc_i, misc_write_ready_o);
    end
    misc_write_group_id_i <= 0;
    $fclose(misc_write_file);
end
endtask

// task of load write
task LoadWrite;
integer load_i;
integer load_write_file;  
begin
    $display($time, " << LOAD write mem_pool >>");
    load_write_file = $fopen("/home/zk/workspace/dpu_dev/project/data/load_write.txt","r");
    @(posedge clk);
    for(load_i=0;load_i<LENGTH;load_i=load_i+1) begin 
        $fscanf(load_write_file, "%h", load_write_group_id_i);
        $fscanf(load_write_file, "%h", load_write_bank_en_i);
        $fscanf(load_write_file, "%h", load_write_addr_i);
        $fscanf(load_write_file, "%h", load_write_data_i);
        $display($time, " LOAD write%d grp: %h",   load_i, load_write_group_id_i);
        $display($time, " LOAD write%d bank: %h",  load_i, load_write_bank_en_i);
        @(posedge clk);
        $display($time, " LOAD write%d ready? %h", load_i, load_write_ready_o);
        while (load_write_group_id_i!=0&&load_write_ready_o!=1) begin
            @(posedge clk);
        end
        $display($time, " LOAD write%d ready? %h", load_i, load_write_ready_o);
    end
    load_write_group_id_i <= 0;
    $fclose(load_write_file);
end
endtask


//*********************************************************************
// read request tasks
//*********************************************************************
// task of conv read request
task ConvRead;
integer conv_i;
integer conv_read_file;  
begin
    $display($time, " << CONV read mem_pool >>");
    conv_read_file = $fopen("/home/zk/workspace/dpu_dev/project/data/conv_read.txt","r");
    @(posedge clk);
    for(conv_i=0;conv_i<LENGTH;conv_i=conv_i+1) begin 
        $fscanf(conv_read_file, "%h", conv_read_group_id_i);
        $fscanf(conv_read_file, "%h", conv_read_bank_en_i);
        $fscanf(conv_read_file, "%h", conv_read_addr_i);
        $fscanf(conv_read_file, "%h", conv_read_data_temp);
        $display($time, " CONV read%d grp: %h",   conv_i, conv_read_group_id_i);
        $display($time, " CONV read%d bank: %h",  conv_i, conv_read_bank_en_i);
        @(posedge clk);
        $display($time, " CONV read%d ready? %h", conv_i, conv_read_addr_ready_o);
        while (conv_read_group_id_i!=0&&(conv_read_addr_ready_o!=1)) begin
            @(posedge clk);
        end
        $display($time, " CONV read%d ready? %h", conv_i, conv_read_addr_ready_o);
    end
    conv_read_group_id_i <= 0;
    $fclose(conv_read_file);
end
endtask

// task of misc read request
task MiscRead;
integer misc_i;
integer misc_read_file;  
begin
    $display($time, " << MISC read mem_pool >>");
    misc_read_file = $fopen("/home/zk/workspace/dpu_dev/project/data/misc_read.txt","r");
    @(posedge clk);
    for(misc_i=0;misc_i<LENGTH;misc_i=misc_i+1) begin 
        $fscanf(misc_read_file, "%h", misc_read_group_id_i);
        $fscanf(misc_read_file, "%h", misc_read_bank_en_i);
        $fscanf(misc_read_file, "%h", misc_read_addr_i);
        $fscanf(misc_read_file, "%h", misc_read_data_temp);
        $display($time, " MISC read%d grp: %h",   misc_i, misc_read_group_id_i);
        $display($time, " MISC read%d bank: %h",  misc_i, misc_read_bank_en_i);
        @(posedge clk);
        $display($time, " MISC read%d ready? %h", misc_i, misc_read_addr_ready_o);
        while (misc_read_group_id_i!=0&&(misc_read_addr_ready_o!=1)) begin
            @(posedge clk);
        end
        $display($time, " MISC read%d ready? %h", misc_i, misc_read_addr_ready_o);
    end
    misc_read_group_id_i <= 0;
    $fclose(misc_read_file);
end
endtask

// task of save read request
task SaveRead;
integer save_i;
integer save_read_file;  
begin
    $display($time, " << SAVE read mem_pool >>");
    save_read_file = $fopen("/home/zk/workspace/dpu_dev/project/data/save_read.txt","r");
    @(posedge clk);
    for(save_i=0;save_i<LENGTH;save_i=save_i+1) begin 
        $fscanf(save_read_file, "%h", save_read_group_id_i);
        $fscanf(save_read_file, "%h", save_read_bank_en_i);
        $fscanf(save_read_file, "%h", save_read_addr_i);
        $fscanf(save_read_file, "%h", save_read_data_temp);
        $display($time, " SAVE read%d grp: %h",   save_i, save_read_group_id_i);
        $display($time, " SAVE read%d bank: %h",  save_i, save_read_bank_en_i);
        @(posedge clk);
        $display($time, " SAVE read%d ready? %h", save_i, save_read_addr_ready_o);
        while (save_read_group_id_i!=0&&(save_read_addr_ready_o!=1)) begin
            @(posedge clk);
        end
        $display($time, " SAVE read%d ready? %h", save_i, save_read_addr_ready_o);
    end
    save_read_group_id_i <= 0;
    $fclose(save_read_file);
end
endtask


//*********************************************************************
// read receive tasks define
//*********************************************************************
// task of conv read receive
task ConvReceive;
integer conv_count;
integer conv_receive_file;
begin
    $display($time, " << CONV receive mem_pool >>");
    conv_count = 0;
    conv_receive_file = $fopen("/home/zk/workspace/dpu_dev/project/data/conv_receive.txt", "w");
    for(conv_count=0;conv_count<5;) begin
        @(posedge clk);
        if(conv_read_data_valid_o==1&&conv_read_data_ready_i==1) begin 
            conv_read_data_receive <= conv_read_data_o;
            $fdisplay(conv_receive_file, "%h", conv_read_data_o);
            $display($time, " CONV receive %d",   conv_count);
            conv_count = conv_count + 1;
        end
    end
    $fclose(conv_receive_file);
end
endtask

// task of misc read receive
task MiscReceive;
integer misc_count;
integer misc_receive_file;
begin
    $display($time, " << MISC receive mem_pool >>");
    misc_count = 0;
    misc_receive_file = $fopen("/home/zk/workspace/dpu_dev/project/data/misc_receive.txt", "w");
    for(misc_count=0;misc_count<4;) begin
        @(posedge clk);
        if(misc_read_data_valid_o==1&&misc_read_data_ready_i==1) begin 
            misc_read_data_receive <= misc_read_data_o;
            $fdisplay(misc_receive_file, "%h", misc_read_data_o);
            $display($time, " MISC receive %d",   misc_count);
            misc_count = misc_count + 1;
        end
    end
    $fclose(misc_receive_file);
end
endtask

// task of save read receive
task SaveReceive;
integer save_count;
integer save_receive_file;
begin
    $display($time, " << SAVE receive mem_pool >>");
    save_count = 0;
    save_receive_file = $fopen("/home/zk/workspace/dpu_dev/project/data/save_receive.txt", "w");
    for(save_count=0;save_count<4;) begin
        @(posedge clk);
        if(save_read_data_valid_o==1&&save_read_data_ready_i==1) begin 
            save_read_data_receive <= save_read_data_o;
            $fdisplay(save_receive_file, "%h", save_read_data_o);
            $display($time, " SAVE receive %d",   save_count);
            save_count = save_count + 1;
        end
    end
    $fclose(save_receive_file);
end
endtask


//*********************************************************************
// write and read request
//*********************************************************************
initial  // conv write read port control
begin
    // initial with 0 at the very first
    conv_write_group_id_i <= 0;
    conv_write_bank_en_i  <= 0;
    conv_write_addr_i     <= 0;
    conv_write_data_i     <= 0;
    conv_read_group_id_i <= 0;
    conv_read_bank_en_i  <= 0;
    conv_read_addr_i     <= 0;

    // wait for reset complete
    @(posedge clk);
    while(rst_p) begin
        @(posedge clk);
    end
    #100;
    ConvWrite;
    #100;
    ConvRead;
end

initial  // misc write read port control
begin
    // initial with 0 at the very first
    misc_write_group_id_i <= 0;
    misc_write_bank_en_i  <= 0;
    misc_write_addr_i     <= 0;
    misc_write_data_i     <= 0;
    misc_read_group_id_i <= 0;
    misc_read_bank_en_i  <= 0;
    misc_read_addr_i     <= 0;

    // wait for reset complete
    @(posedge clk);
    while(rst_p) begin
        @(posedge clk);
    end
    #100;
    MiscWrite;
    #100;
    MiscRead;
end  

initial  // load save write read port control
begin
    // initial with 0 at the very first
    load_write_group_id_i <= 0;
    load_write_bank_en_i  <= 0;
    load_write_addr_i     <= 0;
    load_write_data_i     <= 0;
    save_read_group_id_i <= 0;
    save_read_bank_en_i  <= 0;
    save_read_addr_i     <= 0;

    // wait for reset complete
    @(posedge clk);
    while(rst_p) begin
        @(posedge clk);
    end
    #100;
    LoadWrite;
    #100;
    SaveRead;
end


//*********************************************************************
// logic of ready
//*********************************************************************
always @ (*) begin
    conv_read_data_ready_i = 
    ((conv_read_data_valid_o==1 && conv_write_group_id_i==0) ||
     (conv_read_data_valid_o==1 && conv_write_ready_o==1)) ? 
     1 : 0;
    misc_read_data_ready_i = 
    ((misc_read_data_valid_o==1 && misc_write_group_id_i==0) ||
     (misc_read_data_valid_o==1 && misc_write_ready_o==1)) ? 
     1 : 0;
    save_read_data_ready_i = 
    ((save_read_data_valid_o==1 && load_write_group_id_i==0) ||
     (save_read_data_valid_o==1 && load_write_ready_o==1)) ? 
     1 : 0;
end


//*********************************************************************
// receive read data
//*********************************************************************
initial  // conv read data receive
begin
    // initial with 0 at the very first
    conv_read_data_receive <= 0;
    // wait for reset complete
    @(posedge clk);
    while(rst_p) begin
        @(posedge clk);
    end
    ConvReceive;
end

initial  // misc read data receive
begin
    // initial with 0 at the very first
    misc_read_data_receive <= 0;
    // wait for reset complete
    @(posedge clk);
    while(rst_p) begin
        @(posedge clk);
    end
    MiscReceive;
end

initial  // save read data receive
begin
    // initial with 0 at the very first
    save_read_data_receive <= 0;
    // wait for reset complete
    @(posedge clk);
    while(rst_p) begin
        @(posedge clk);
    end
    SaveReceive;
end


//*********************************************************************
// read receive
//*********************************************************************
mem_pool_top INST_test_top(
    .clk        (clk),
    .rst_p      (rst_p),
    // IMAGE read 
    // image read port with Conv
    .conv_read_group_id_i       (conv_read_group_id_i),
    .conv_read_bank_en_i        (conv_read_bank_en_i),
    .conv_read_addr_i           (conv_read_addr_i),
    .conv_read_addr_ready_o     (conv_read_addr_ready_o),
    .conv_read_data_valid_o     (conv_read_data_valid_o),
    .conv_read_data_o           (conv_read_data_o),
    .conv_read_data_ready_i     (conv_read_data_ready_i),
    // image read port with MISC
    .misc_read_group_id_i       (misc_read_group_id_i),
    .misc_read_bank_en_i        (misc_read_bank_en_i),
    .misc_read_addr_i           (misc_read_addr_i),
    .misc_read_addr_ready_o     (misc_read_addr_ready_o),
    .misc_read_data_valid_o     (misc_read_data_valid_o),
    .misc_read_data_o           (misc_read_data_o),
    .misc_read_data_ready_i     (misc_read_data_ready_i),
    // image read port with Save
    .save_read_group_id_i       (save_read_group_id_i),
    .save_read_bank_en_i        (save_read_bank_en_i),
    .save_read_addr_i           (save_read_addr_i),
    .save_read_addr_ready_o     (save_read_addr_ready_o),
    .save_read_data_valid_o     (save_read_data_valid_o),
    .save_read_data_o           (save_read_data_o),
    .save_read_data_ready_i     (save_read_data_ready_i),
    // IMAGE write
    // image write port with Conv
    .conv_write_group_id_i      (conv_write_group_id_i),
    .conv_write_bank_en_i       (conv_write_bank_en_i),
    .conv_write_addr_i          (conv_write_addr_i),
    .conv_write_data_i          (conv_write_data_i),
    .conv_write_ready_o         (conv_write_ready_o),
    // image write port with MISC
    .misc_write_group_id_i      (misc_write_group_id_i),
    .misc_write_bank_en_i       (misc_write_bank_en_i),
    .misc_write_addr_i          (misc_write_addr_i),
    .misc_write_data_i          (misc_write_data_i),
    .misc_write_ready_o         (misc_write_ready_o),
    // image write port with Load
    .load_write_group_id_i      (load_write_group_id_i),
    .load_write_bank_en_i       (load_write_bank_en_i),
    .load_write_addr_i          (load_write_addr_i),
    .load_write_data_i          (load_write_data_i),
    .load_write_ready_o         (load_write_ready_o),
    // WEIGHTS read and write
    // weights(weight&bias) read port with Conv
    .weight_read_en_i           (weight_read_en_i),
    .weight_read_addr_i         (weight_read_addr_i),
    .weight_read_data_o         (weight_read_data_o),
    .bias_read_en_i             (bias_read_en_i),
    .bias_read_addr_i           (bias_read_addr_i),
    .bias_read_data_o           (bias_read_data_o),
    // weights(weight&bias) write port with Load
    .weight_write_en_i          (weight_write_en_i),
    .weight_write_addr_i        (weight_write_addr_i),
    .weight_write_data_i        (/*weight_write_data_i*/),
    .bias_write_en_i            (bias_write_en_i),
    .bias_write_addr_i          (bias_write_addr_i),
    .bias_write_data_i          (/*bias_write_data_i*/)
);

endmodule