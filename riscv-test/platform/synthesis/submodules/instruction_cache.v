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
	parameter burst_size = single_lane_size/64;
	
	reg [number_of_sets-1:0] valid_lanes [0:2**bits_for_index-1] ;
	reg [tags_lane_size-1:0] MEM_T [0:2**bits_for_index-1];
	reg [cache_lane_size-1:0] MEM [0:2**bits_for_index-1];
	reg [number_of_sets-2:0] LRU [0:2**bits_for_index-1];
	reg [cache_lane_size-1:0] active_lane;
	
	reg [single_lane_size-1:0] new_lane;
	reg [burst_size-1:0] burst_state;
	reg [1:0] transfer_state;
	reg reading;
	
	reg data_ready;
	
	wire [bits_for_offset-1:0] offset;
	wire [bits_for_index-1:0] index;
	wire [bits_for_tag-1:0] tag;
	
	wire [log_of_number_of_sets-1:0] lane_add,lane_to_replace;
	wire [number_of_sets-2:0] new_LRU;
	
	wire hit,index_hit,tag_hit;
	
	reg miss_recovery;
	reg [bits_for_index-1:0] active_index;
	reg [tags_lane_size-1:0] active_lane_tags; 
	reg [number_of_sets-2:0] active_LRU;
	
	//control path
	
	integer i;

	assign {tag,index,offset} = core_inst_address;
	assign index_hit = ~|(active_index^index);
	assign hit = index_hit & tag_hit;
	assign core_waitrequest = ~hit | miss_recovery;
	assign core_inst_valid = hit;
	
	always @(posedge reset or posedge clock) begin
		if (reset) begin
			reading <= 1'b0;
			transfer_state <= 2'h0;
			data_ready <= 1'b0;
			miss_recovery <= 1'b0;
			active_index <= 0;
		end
		else if (!hit && core_read) begin
			if (!index_hit)
				active_index <= index;
			else if (!miss_recovery) begin
				miss_recovery <= 1'b1;
				transfer_state <= 1;
			end
		end
		else begin	
			if (transfer_state == 0) 
				data_ready <= 0;
			else if (transfer_state == 1) begin
				reading <= 1'b1;
				burst_state <= 0;
				if (!memory_waitrequest) transfer_state <= 2;
			end
			else if (transfer_state == 2) begin
				reading <= 1'b0;
				if (memory_readdatavalid) begin
					burst_state <= burst_state + 1;
				end
				if (burst_state == burst_size) begin
					transfer_state <= 3;
				end
			end
			else if (transfer_state == 3) begin
				data_ready <= 1;
				miss_recovery <= 1'b0;
				transfer_state <= 0;
			end
		end
	end
	
	get_position_for_new_lane #(number_of_sets,log_of_number_of_sets) get_LRU (lane_to_replace,valid_lanes[active_index],active_LRU);
	
	update_position #(number_of_sets,log_of_number_of_sets) update_LRU (new_LRU,lane_to_replace,active_LRU);

	get_tag_index #(bits_for_tag,number_of_sets,log_of_number_of_sets) 
		varify_tags (lane_add,tag_hit,tag,active_lane_tags,valid_lanes[active_index]);

	
	//data path
	
	assign memory_burstcount = burst_size;
	assign memory_address = {tag,index,{bits_for_offset{1'b0}}};
	assign memory_read = reading;
	
	always @(posedge clock or posedge reset) begin
		if(reset) begin
			for (i=0;i<(1<<bits_for_index);i=i+1) begin
				valid_lanes[i] <= {number_of_sets{1'b0}};
			end
		end
		else if (!hit && core_read) begin
			if (!index_hit)begin
				active_lane_tags <= MEM_T[index];
				MEM_T[active_index] <= active_lane_tags;
				MEM[active_index] <= active_lane;
				active_lane <= MEM [index];
				LRU[active_index] <= active_LRU;
				active_LRU <= LRU[active_index];
			end
			else if (data_ready) begin
				valid_lanes[active_index][lane_to_replace] <= 1'b1;
				active_lane_tags[lane_to_replace*(bits_for_tag)+:bits_for_tag] <= tag;
			end
		end
		else if (hit && core_read) begin
			active_LRU <= new_LRU;
		end
		else begin
			if (transfer_state == 2) begin
				if (memory_readdatavalid) begin
					new_lane[64*burst_state+:64] <= memory_readdata;
				end
			end
			else if (transfer_state == 3) begin
				active_lane[single_lane_size*lane_to_replace+:single_lane_size] <= new_lane;
			end
		end
	end
	
	get_data_from_lane #(log_of_number_of_sets,bits_for_offset,cache_lane_size) 
						cache_access(core_instruction,offset,lane_add,active_lane);

endmodule

