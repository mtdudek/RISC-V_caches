// instruction_cache_block.v

// Created by Maciej Dudek

module instruction_cache_block #(
		parameter number_of_sets  = 4,
		parameter bits_for_index  = 6,
		parameter bits_for_offset = 6,
		parameter log_of_number_of_sets = 2,
		parameter bits_for_tag=32-bits_for_index-bits_for_offset,
		parameter single_lane_size =8*(2**bits_for_offset)
	)(
		input  wire								clock,
		input  wire								reset,	

		input  wire [bits_for_tag-1:0] 		 	tag,	 
		input  wire [bits_for_index-1:0]	 	index,
		input  wire [bits_for_offset-1:0]	   	offset,

		input  wire        						core_read,      		
   	
		output wire [31:0] 						cache_instruction,        
		output wire        						cache_notready,		
		output wire  	   						cache_hit,
		
		output wire 	   						start_transfer,		
		input  wire		   						data_ready,
		input  wire [single_lane_size-1:0]		lane_from_memory
	);

	parameter cache_lane_size = single_lane_size * number_of_sets;
	parameter tags_lane_size = number_of_sets*(bits_for_tag);

	integer i;

	reg [tags_lane_size-1:0] MEM_T [0:2**bits_for_index-1];
	reg [tags_lane_size-1:0] active_lane_tags; 

	reg [cache_lane_size-1:0] MEM [0:2**bits_for_index-1];
	reg [cache_lane_size-1:0] active_lane;
	reg [number_of_sets-1:0] valid_lanes [0:2**bits_for_index-1] ;
	
	wire [cache_lane_size-1:0] new_data_lane;
	wire [tags_lane_size-1:0] new_tag_lane;

	reg  [bits_for_tag-1:0] tag_t;
	
	wire [log_of_number_of_sets-1:0] lane_add,lane_to_replace;

	reg [number_of_sets-2:0] LRU [0:2**bits_for_index-1];
	wire [number_of_sets-2:0] new_LRU;
	reg [number_of_sets-2:0] active_LRU;
	
	wire hit,index_hit,tag_hit;
	reg [bits_for_index-1:0] active_index;
	
	reg miss_recovery;

	assign index_hit = ~|(active_index^index);
	assign hit = index_hit & tag_hit;
	assign cache_notready = (~hit | miss_recovery);
	assign cache_hit = hit;

	assign start_transfer = miss_recovery;

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
			if (data_ready) begin
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