// RISC-V SiMPLE SV -- Toplevel
// BSD 3-Clause License
// (c) 2017-2019, Arthur Matos, Marcus Vinicius Lamar, Universidade de Brasília,
//                Marek Materzok, University of Wrocław

`include "config.sv"
`include "constants.sv"

module toplevel (
    input  clock,
    input  reset,

    output [31:0] bus_read_data,
    output [31:0] bus_address,
    output [31:0] bus_write_data,
    output [3:0]  bus_byte_enable,
    output        bus_read_enable,
    output        bus_write_enable,
    output        bus_wait_req,
    output        bus_valid,

    output [31:0] inst,
    output [31:0] pc,
    output        inst_read_enable,
    output        inst_wait_req,
    output        inst_valid,

    output [31:0] cache_adress_to_mem,
    output cache_reads,
    output [63:0] data_to_cache,
    output waitrequest_to_cache,
    output [3:0] burstcount_cache,
    output data_to_cache_valid
);

    riscv_core riscv_core (
        .clock                  (clock),
        .reset                  (reset),
        
        .inst_data              (inst),
        .pc                     (pc),
        .inst_read_enable       (inst_read_enable),
        .inst_wait_req          (inst_wait_req),
        .inst_valid             (inst_valid),

        .bus_address            (bus_address),
        .bus_read_data          (bus_read_data),
        .bus_write_data         (bus_write_data),
        .bus_wait_req           (bus_wait_req),
        .bus_valid              (bus_valid),
        .bus_read_enable        (bus_read_enable),
        .bus_write_enable       (bus_write_enable),
        .bus_byte_enable        (bus_byte_enable)
    );
///*
    //interconnect

        //mem_convertor-memory

        wire [31:0] address_to_mem_,data_from_mem_;
        wire readmem,memrequest,readvalidmem;

    instruction_cache #(4,6,6,2) cache_sim (
        .clock                  (clock),
        .reset                  (reset),
        
        .memory_address         (cache_adress_to_mem),
        .memory_read            (cache_reads),
        .memory_readdata        (data_to_cache),
        .memory_waitrequest     (waitrequest_to_cache),
        .memory_burstcount      (burstcount_cache),
        .memory_readdatavalid   (data_to_cache_valid),
        
        .core_inst_address      (pc),   
        .core_instruction       (inst),   
        .core_waitrequest       (inst_wait_req),    
        .core_read              (inst_read_enable),
        .core_inst_valid        (inst_valid)

    );


    mem_convertor mem_converter(
        .memory_address         (address_to_mem_),         
        .memory_read            (readmem),          
        .memory_readdata        (data_from_mem_),    
        .memory_waitrequest     (memrequest),  
        .memory_readdatavalid   (readvalidmem), 
        
        .cache_address          (cache_adress_to_mem),     
        .cache_burstcount       (burstcount_cache),  
        .cache_readdatavalid    (data_to_cache_valid),   
        .cache_readdata         (data_to_cache),         
        .cache_waitrequest      (waitrequest_to_cache),          
        .cache_read             (cache_reads),       
        
        .clock                  (clock),
        .reset                  (reset)
    );

    example_text_memory_bus text_memory_bus (
        .clock                  (clock),
        .reset                  (reset),
        .read_enable            (readmem),
        .wait_req               (memrequest),
        .valid                  (readvalidmem),
        .address                (address_to_mem_),
        .read_data              (data_from_mem_)
    );
//*/
/*
    example_text_memory_bus text_memory_bus (
        .clock                  (clock),
        .reset                  (reset),
        .read_enable            (inst_read_enable),
        .wait_req               (inst_wait_req),
        .valid                  (inst_valid),
        .address                (pc),
        .read_data              (inst)
    );
*/
    example_data_memory_bus data_memory_bus (
        .clock                  (clock),
        .reset                  (reset),
        .address                (bus_address),
        .wait_req               (bus_wait_req),
        .valid                  (bus_valid),
        .read_data              (bus_read_data),
        .write_data             (bus_write_data),
        .read_enable            (bus_read_enable),
        .write_enable           (bus_write_enable),
        .byte_enable            (bus_byte_enable)
    );
    
endmodule

