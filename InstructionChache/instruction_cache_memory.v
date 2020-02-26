// instruction_cache_memory.v

// Created by Maciej Dudek

`timescale 1 ps / 1 ps

module instruction_cache_memory #(
		parameter number_of_sets  = 4,
		parameter bits_for_index  = 6,
		parameter bits_for_offset = 6,
		parameter bits_for_tag=32-bits_for_index-bits_for_offset,
		parameter single_lane_size =8*(2**bits_for_offset)
		)(
		input  wire        clock,                    
		input  wire        reset,                    
		
		output wire [31:0] memory_address,           
		output wire        memory_read,             
		input  wire [63:0] memory_readdata,         
		input  wire        memory_waitrequest,      
		output wire [3:0]  memory_burstcount,        
		input  wire        memory_readdatavalid,    
		
		input  wire [bits_for_tag-1:0] 		tag,
		input  wire [bits_for_index-1:0] 	index,
		input  wire [bits_for_offset-1:0]	offset,
		output wire [single_lane_size-1:0]	lane_from_memory,
		output wire data_ready,
		input  wire start_transfer,

		output wire [31:0] bypass_instruction,
		output wire bypass_hit
	);
	 
	
	parameter burst_size = single_lane_size/64;

	reg [single_lane_size-1:0] new_lane;
	reg [burst_size-1:0] burst_state;
	reg [2:0] burst_count;
	reg [1:0] transfer_state;
	reg read, transfer_over;

	reg [bits_for_tag-1:0] transfer_tag;
	reg [bits_for_index-1:0] transfer_index;

	wire [bits_for_offset-4:0] offset2;
	wire [2:0] offset1;
	wire index_hit,tag_hit;

	// memory transfer logic

	assign memory_burstcount = (2**bits_for_offset)/8;
	assign memory_address = {tag,index,offset2,{3'b000}};
	assign memory_read = read;

	assign lane_from_memory = new_lane;
	assign data_ready = transfer_over;

	assign {offset2,offset1} = offset;

	always @(posedge reset or posedge clock) begin
		if (reset) begin
			read <= 1'b0;
			transfer_state <= 2'h0;
			burst_count <= 0;
			transfer_over <= 0;
		end
		else begin 
			if (transfer_state == 0) begin
				if(start_transfer) begin
					read <= 1'b1;
					burst_state <= 0;
					burst_count <= offset2;
					transfer_state <= 1;
					transfer_tag <= tag;
					transfer_index <= index;
				end
			end
			else if (transfer_state == 1) begin
				if (!memory_waitrequest) begin
					read <= 1'b0;
					transfer_state <= 2;
				end
			end
			else if (transfer_state == 2) begin
				if (&burst_state)begin
					transfer_state <= 3;
					transfer_over <= 1;
				end
				if (memory_readdatavalid) begin
					burst_state[burst_count] <= 1'b1;
					burst_count <= burst_count + 1;
				end
			end
			else if (transfer_state == 3) begin
				transfer_over <= 0;
				transfer_state <= 0;
			end
		end
	end

	//bypass logic

	assign index_hit = ~|(transfer_index^index);
	assign tag_hit = ~|(transfer_tag^tag);
	assign bypass_hit = |transfer_state & index_hit 
						& tag_hit & burst_state[offset2];

	assign bypass_instruction = new_lane[8*offset+:32];

	// memory transfer data path
	always @(posedge clock or posedge reset) begin
		if(reset) begin
		end
		else begin
			if (transfer_state == 2) begin
				if (memory_readdatavalid) begin
					new_lane[64*burst_count+:64] <= memory_readdata;
				end
			end
		end
	end

endmodule

