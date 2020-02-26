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
		output wire  	   core_inst_valid,			 //						 .readdatavalid
		output wire 	   debug 
	);
	 
	parameter bits_for_tag=32-bits_for_index-bits_for_offset;
	parameter single_lane_size =8*(2**bits_for_offset); 
	parameter cache_lane_size = single_lane_size * number_of_sets;
	parameter tags_lane_size = number_of_sets*(bits_for_tag);
	
	reg [number_of_sets-1:0] valid_lanes [0:2**bits_for_index-1] ;
	reg [tags_lane_size-1:0] MEM_T [0:2**bits_for_index-1];
	reg [cache_lane_size-1:0] MEM [0:2**bits_for_index-1];
	reg [number_of_sets-2:0] LRU [0:2**bits_for_index-1];
	reg [cache_lane_size-1:0] active_lane;
	
	wire [single_lane_size-1:0] lane_from_memory;
	wire [cache_lane_size-1:0] new_data_lane;
	wire [tags_lane_size-1:0] new_tag_lane;

	wire [bits_for_offset-1:0] offset;
	wire [bits_for_index-1:0] index;
	wire [bits_for_tag-1:0] tag;
	reg  [bits_for_tag-1:0] tag_t;
	
	wire [log_of_number_of_sets-1:0] lane_add,lane_to_replace;
	wire [number_of_sets-2:0] new_LRU;
	
	wire hit,index_hit,tag_hit;
	wire data_ready;
	
	reg miss_recovery;
	reg [bits_for_index-1:0] active_index;
	reg [tags_lane_size-1:0] active_lane_tags; 
	reg [number_of_sets-2:0] active_LRU;

	integer i;

	wire bypass_hit;
	wire [31:0] bypass_instruction, cache_instruction;

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
		.start_transfer			(miss_recovery),

		.bypass_instruction		(bypass_instruction),
		.bypass_hit				(bypass_hit)
	);

	// hit/miss logic

	assign {tag,index,offset} = core_inst_address;
	assign index_hit = ~|(active_index^index);
	assign hit = index_hit & tag_hit;
	assign core_waitrequest = (~hit | miss_recovery)&!bypass_hit;
	assign core_inst_valid = hit|bypass_hit;

	assign debug = data_ready;

	always @(posedge reset or posedge clock) begin
		if (reset) begin
			miss_recovery <= 1'b0;
			active_index <= 0;
		end
		else begin 
			if (!hit && core_read) begin
				if (!index_hit && !miss_recovery)
					active_index <= index;
				else if (!miss_recovery) begin
					miss_recovery <= 1'b1;
					tag_t <= tag;
				end
			end
			if (data_ready) begin
				miss_recovery <= 1'b0;
			end
		end
	end
	
	// miss/hit data path

	assign core_instruction = bypass_hit ? bypass_instruction : cache_instruction;

	always @(posedge clock or posedge reset) begin
		if(reset) begin
			for (i=0;i<(1<<bits_for_index);i=i+1) begin
				valid_lanes[i] <= {number_of_sets{1'b0}};
			end
		end
		else begin
			if (!hit && core_read) begin
				if (!index_hit && !miss_recovery)begin
					active_lane_tags <= MEM_T[index];
					active_lane <= MEM [index];
					LRU[active_index] <= active_LRU;
					active_LRU <= LRU[active_index];
				end
			end
			else if (hit && core_read) begin
				active_LRU <= new_LRU;
			end
			else if (data_ready) begin
				valid_lanes[active_index][lane_to_replace] <= 1'b1;
				
				active_lane <= new_data_lane;
				MEM[active_index] <= new_data_lane;

				active_lane_tags <= new_tag_lane;
				MEM_T[active_index] <= new_tag_lane;
				active_LRU <= new_LRU;
			end
		end
	end
	
	get_position_for_new_lane #(number_of_sets,log_of_number_of_sets) 
		get_lane_to_replace (lane_to_replace, valid_lanes[active_index], active_LRU);
	
	update_LRU #(number_of_sets,log_of_number_of_sets) 
		get_new_LRU (new_LRU, lane_add, active_LRU);

	get_tag_index #(bits_for_tag,number_of_sets,log_of_number_of_sets) 
		get_lane_add_and_tag_hit (lane_add, tag_hit, tag, active_lane_tags, valid_lanes[active_index]);

	get_data_from_lane #(log_of_number_of_sets,bits_for_offset,cache_lane_size) 
		access_lane(cache_instruction, offset, lane_add,active_lane);

	update_tag_lane #(number_of_sets, bits_for_tag, log_of_number_of_sets) 
		get_new_tag_lane (new_tag_lane,active_lane_tags,tag_t,lane_to_replace);

	update_data_lane #(number_of_sets, bits_for_offset, log_of_number_of_sets)
		get_new_data_lane (new_data_lane,active_lane,lane_from_memory,lane_to_replace);

endmodule

