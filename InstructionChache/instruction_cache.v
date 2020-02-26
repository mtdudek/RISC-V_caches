// instruction_cache.v

// Created by Maciej Dudek
// RISC-V Instruction cache, with 0 cycle respond
// if accessing same set as instruction before,
// 1 cycle respond if line is in cache but in different set.

// No prefetching at this time
// TO-DO:
// 1. modularize everything
// 2. add simple prefetching
// 3. add eviction buffor


`timescale 1 ps / 1 ps
module instruction_cache #(
		parameter number_of_sets  = 4,
		parameter bits_for_index  = 6,
		parameter bits_for_offset = 6,
		parameter log_of_number_of_sets = 2
		)(
		input  wire        clock,                    //            clock_sink.clk
		input  wire        reset,                    //            reset_sink.reset
		
		output wire [31:0] memory_address,           // access_to_main_memory.address
		output wire        memory_read,              //                      .read
		input  wire [63:0] memory_readdata,          //                      .readdata
		input  wire        memory_waitrequest,       //                      .waitrequest
		output wire [3:0]  memory_burstcount,        //                      .burstcount
		input  wire        memory_readdatavalid,     //                      .readdatavalid
		
		input  wire [31:0] core_inst_address,      	 //       core_interaface.address
		output wire [31:0] core_instruction,         //                      .readdata
		output wire        core_waitrequest,		 //                      .waitrequest
		input  wire        core_read,      			 //                      .read
		output wire  	   core_inst_valid			 //						 .readdatavalid
	);
	 
	parameter bits_for_tag=32-bits_for_index-bits_for_offset;
	parameter single_lane_size =8*(2**bits_for_offset); 
	parameter cache_lane_size = single_lane_size * number_of_sets;
	parameter tags_lane_size = number_of_sets*(bits_for_tag);
	
	wire data_ready;

	wire bypass_hit,cache_hit,cache_notready,start_transfer;
	wire [31:0] bypass_instruction, cache_instruction;
	wire [bits_for_tag-1:0] tag;
	wire [bits_for_index-1:0] index;
	wire [bits_for_offset-1:0] offset;
	wire [single_lane_size-1:0] lane_from_memory;

	assign {tag,index,offset} = core_inst_address;

	//memory transfer module
	instruction_cache_memory #(
		number_of_sets,
		bits_for_index,
		bits_for_offset) 
	memory_interface (
		.clock 					(clock),
		.reset 					(reset),

		.memory_address			(memory_address),      
		.memory_read       		(memory_read),    	   
		.memory_readdata   		(memory_readdata),     
		.memory_waitrequest		(memory_waitrequest),  
		.memory_burstcount 		(memory_burstcount),   
		.memory_readdatavalid	(memory_readdatavalid),
		
		.tag 					(tag),
		.index 					(index),
		.offset 				(offset),
		.lane_from_memory 		(lane_from_memory),
		.data_ready  			(data_ready),
		.start_transfer			(start_transfer),

		.bypass_instruction		(bypass_instruction),
		.bypass_hit				(bypass_hit)
	);

	// cache block module
	instruction_cache_block #(
		number_of_sets,
		bits_for_index,
		bits_for_offset,
		log_of_number_of_sets)
	cache_block (
		.clock 					(clock),
		.reset 					(reset),	

		.tag 					(tag),	 
		.index 					(index),
		.offset 				(offset),

		.core_read				(core_read),      		
   	
		.cache_instruction 		(cache_instruction),        
		.cache_notready 		(cache_notready),		
		.cache_hit 				(cache_hit),
		
		.start_transfer 		(start_transfer),		
		.data_ready				(data_ready),
		.lane_from_memory		(lane_from_memory)
	);

	assign core_waitrequest = cache_notready&!bypass_hit;
	assign core_inst_valid = cache_hit|bypass_hit;
	assign core_instruction = bypass_hit ? bypass_instruction : cache_instruction;

endmodule

