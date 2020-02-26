// data_cache.v

// Created by Maciej Dudek
// RISC-V Data cache, with 1 cycle read respond
// if accessing data inside cache and 
// data is aligned to 64 Bytes, 2 cycle 
// if data inside cache but access not aligned.
// Write option is controlled by parameter write_back
// if 0 changes are made in cache and passed 
// onward, if 1 changes are stored only in cache.

// No prefetching at this time
// TO-DO:
// 1. modularize everything
// 2. add simple prefetching
// 3. add ediction buffor

`timescale 1 ps / 1 ps
module data_cache #(
		parameter number_of_sets        = 4,
		parameter bits_for_index        = 6,
		parameter bits_for_offset       = 6,
		parameter log_of_number_of_sets = 2,
		parameter write_back            = 0
	) (
		input  wire        reset,                     //       reset.reset
		input  wire        clock,                     //       clock.clk

		input  wire [31:0] core_data_address,         //   core_data.address
		input  wire [3:0]  core_data_byteenable,      //            .byteenable
		output wire [31:0] core_data_readdata,        //            .readdata
		input  wire        core_data_read,            //            .read
		output wire        core_data_readdatavalid,   //            .readdatavalid
		output wire        core_data_waitrequest,     //            .waitrequest
		input  wire [31:0] core_data_writedata,       //            .writedata
		input  wire        core_data_write,           //            .write

		output wire [31:0] memory_data_address,       // memory_data.address
		output wire [7:0]  memory_data_byteenable,    //            .byteenable
		output wire        memory_data_read,          //            .read
		input  wire [63:0] memory_data_readdata,      //            .readdata
		input  wire        memory_data_readdatavalid, //            .readdatavalid
		output wire [3:0]  memory_data_burstcount,    //            .burstcount
		input  wire        memory_data_waitrequest,   //            .waitrequest
		output wire        memory_data_write,         //            .write
		output wire [63:0] memory_data_writedata      //            .writedata
	);

	parameter bits_for_tag=32-bits_for_index-bits_for_offset;
	parameter single_lane_size =8*(2**bits_for_offset); 
	parameter cache_lane_size = single_lane_size * number_of_sets;
	parameter tags_lane_size = number_of_sets*(bits_for_tag);
	parameter burst_size = single_lane_size/64;

	// memory block

	reg [number_of_sets-1:0] valid_lanes [0:2**bits_for_index-1];
	reg [number_of_sets-2:0] LRUtable [0:2**bits_for_index-1];
	reg [number_of_sets-1:0] dirty_lanes [0:2**bits_for_index-1];
	reg [tags_lane_size-1:0] MEM_T [0:2**bits_for_index-1];
	reg [cache_lane_size-1:0] MEM [0:2**bits_for_index-1];

	// nets

	wire [31:0] address1,address2;
	wire [bits_for_offset-1:0] offset1,offset2;
	wire [bits_for_index-1:0] index1,index2;
	wire [bits_for_tag-1:0] tag1,tag2;
	wire [bits_for_offset-1:0] diff;
	wire [31:0] data;
	wire [1:0] pos;
	wire [bits_for_index-1:0] active_index;
	wire [bits_for_tag-1:0] tag;
	wire tag_hit;
	wire [log_of_number_of_sets-1:0] lane_add,lane_to_replace;
	wire [number_of_sets-2:0] updated_LRU1,updated_LRU2;

	// calling state

	reg [bits_for_offset-1:0] r_diff;
	reg [31:0] add1,add2;
	reg [31:0] r_data;
	reg [1:0] r_pos;

	// control path registers

	reg data_valid,data_ready;
	reg  [2:0] control_state;
	reg  [3:0] transfer_state;

	// data path registers

	reg [31:0] data_to_send;
	reg [1:0] writting_done;
	reg [cache_lane_size-1:0] line [1:0];
	reg wrtie_to_memory;

	//memory transfer

	reg [3:0] burstcount,burst_state;
	reg [7:0] byteenable;
	reg read,write;
	reg [31:0] memory_address;
	reg [63:0] memory_data;

	// assign nets

	assign address1 = control_state == 0 ? core_data_address : add1;
	assign address2 = control_state == 0 ? core_data_address + pos : add2;
	assign diff = control_state == 0 ? index2 - index1 : r_diff;
	assign data = control_state == 0 ? core_data_writedata : r_data; 
	assign pos = control_state == 0 ? pos : r_pos;

	assign {tag1,index1,offset1} = address1;
	assign {tag2,index2,offset2} = address2;

	assign active_index = control_state[0] ? index1 : index2;
	assign tag = control_state[0] ? tag1 : tag2;


	get_tag_index #(bits_for_tag,number_of_sets,log_of_number_of_sets) 
		varify_tags (lane_add,tag_hit,tag,MEM_T[active_index],valid_lanes[active_index]);

	get_highest_bit_on how_many_bytes(core_data_byteenable,pos);

	get_position_for_new_lane_data #(number_of_sets,log_of_number_of_sets) 
		get_LRU (lane_to_replace,valid_lanes[active_index],LRUtable[active_index]);

	update_position #(number_of_sets,log_of_number_of_sets)
		up_LRU1 (lane_add,LRUtable[active_index],updated_LRU1),
		up_LRU2 (lane_to_replace,LRUtable[active_index],updated_LRU2);

	// control path
	integer i,j;

	// core outputs

	assign core_data_waitrequest = (control_state != 0);
	assign core_data_readdatavalid = data_valid;
	assign core_data_readdata = data_to_send;

	// memory outputs

	assign memory_data_address = memory_address;
	assign memory_data_byteenable = byteenable;
	assign memory_data_burstcount = burstcount;
	assign memory_data_read = read;
	assign memory_data_writedata = memory_data;
	assign memory_data_write = write;

	always @(posedge clock or posedge reset) begin
		if(reset) begin
			data_valid <= 1'b0;
			control_state <= 3'b000;
			transfer_state <= 4'h0;
			data_ready <= 1'b0;
			read <= 1'b0;
			write <= 1'b0;
			burst_state <= 4'h0;
		end 
		else begin
			if (control_state == 0) begin
				data_valid <= 1'b0;
				if (memory_data_address[30+:2] == 3 ) begin
					transfer_state <= 9;
					control_state <= 6;
				end
				else if (core_data_read && index1==index2 && tag_hit) begin
					data_valid <= 1'b1;
				end
				else if (core_data_read && tag_hit) begin
					control_state <= 1;
				end
				else if (core_data_read) begin
					if (write_back && dirty_lanes[index2][lane_to_replace])
						transfer_state <= 5;
					else
						transfer_state <= 7;
					control_state <= 2;
				end
				else if (core_data_write && index1==index2 && tag_hit) begin
					control_state <= 6;
				end
				else if (core_data_write && tag_hit) begin
					control_state <= 5;
				end
				else if (core_data_write) begin
					if (write_back && dirty_lanes[index2][lane_to_replace])
						transfer_state <= 5;
					else
						transfer_state <= 7;
					control_state <= 4;
				end
			end
			else if (control_state == 1) begin
				if(tag_hit) begin
					data_valid <= 1'b1;
					control_state <= 0;
				end
				else begin
					control_state <= 3;
					if (write_back && dirty_lanes[index2][lane_to_replace])
						transfer_state <= 1;
					else
						transfer_state <= 3;
				end
			end
			else if (control_state == 2) begin
				if (data_ready) begin
					if(index1 == index2) begin
						control_state <= 0;
						data_valid <= 1'b1;
					end
					else begin
						control_state <= 1;
					end
				end
			end
			else if (control_state == 3) begin
				if (data_ready) begin
					control_state <= 0;
					data_valid <= 1'b1;
				end
			end
			else if (control_state == 4) begin
				if (data_ready) begin
					if(index1 == index2) begin
						if(!write_back)
							control_state <= 6;
					end
					else begin
						control_state <= 5;
					end
				end
			end
			else if (control_state == 5) begin
				if(tag_hit) begin
					if(!write_back)
						control_state <= 6;
				end
				else begin
					control_state <= 7;
					if (write_back && dirty_lanes[index2][lane_to_replace])
						transfer_state <= 1;
					else
						transfer_state <= 3;
				end
			end
			else if (control_state == 6) begin
				if(!wrtie_to_memory)
					control_state <= 0;
				if (!write_back)begin
					transfer_state <= 9;
				end
			end
			else if (control_state == 7) begin
				if (data_ready) begin
					if(!write_back)
						control_state <= 6;
				end
			end

			if (transfer_state == 0)begin
				read <= 1'b0;
				write <= 1'b0;
				data_ready <= 1'b0;
			end
			else if (transfer_state == 1)begin
				write <= 1'b1;
				burstcount <= 4'h8;
				byteenable <= 8'hff;
				burst_state <= 1;
				if(!memory_data_waitrequest) transfer_state <= 2;
			end
			else if (transfer_state == 2)begin
				if (burstcount == burst_state) begin
					transfer_state <= 3;
					write <= 1'b0;
				end
				else if (!memory_data_waitrequest) begin
					burst_state <= burst_state + 1;
				end
			end
			else if (transfer_state == 3)begin
				read <= 1'b1;
				burst_state <= 0;
				memory_address <= {tag1,index1,{bits_for_offset{1'b0}}};
				if (!memory_data_waitrequest) transfer_state <= 4;
			end
			else if (transfer_state == 4)begin
				read <= 1'b0;
				if (memory_data_readdatavalid) begin
					burst_state <= burst_state + 1;
				end
				if (burst_state == burst_size) begin
					data_ready <= 1'b1;
					transfer_state <= 0;
				end
			end
			else if (transfer_state == 5)begin
				write <= 1'b1;
				burstcount <= 4'h8;
				byteenable <= 8'hff;
				burst_state <= 1;
				if(!memory_data_waitrequest) transfer_state <= 6;
			end
			else if (transfer_state == 6)begin
				if (burstcount == burst_state) begin
					transfer_state <= 7;
					write <= 1'b0;
				end
				else if (!memory_data_waitrequest) begin
					burst_state <= burst_state + 1;
				end
			end
			else if (transfer_state == 7)begin
				read <= 1'b1;
				burst_state <= 0;
				if (!memory_data_waitrequest) transfer_state <= 8;
			end
			else if (transfer_state == 8)begin
				read <= 1'b0;
				if (memory_data_readdatavalid) begin
					burst_state <= burst_state + 1;
				end
				if (burst_state == burst_size) begin
					data_ready <= 1'b1;
					transfer_state <= 0;
				end
			end
			else if (transfer_state == 9) begin
				write <= 1'b1;
				burstcount <= 1'h1;
				if (pos == 0)
					byteenable <= 8'h01;
				else if (pos == 1)
					byteenable <= 8'h03;
				else if (pos == 3)
					byteenable <= 8'h0f;
				if(!memory_data_waitrequest) transfer_state <= 0;
			end
		end
	end

	// data path

	always @(posedge clock or posedge reset) begin
		if(reset) begin
			for (i=0;i<(2**bits_for_index);i=i+1) begin
				valid_lanes[i] <= {number_of_sets{1'b0}};
				LRUtable[i] <= {(number_of_sets-1){1'b0}};
				if(write_back) dirty_lanes[i] <= {number_of_sets{1'b0}};
			end
			data_to_send <= 32'h00000000;
			writting_done <= 2'b11;
			wrtie_to_memory <= 1'b0;
		end 
		else begin
			if (control_state == 0) begin
				add1 <= address1;
				add2 <= address2;
				r_pos <= pos;
				r_diff <= diff;
				r_data <= data;
				if (memory_data_address[30+:2] == 3 ) begin
					wrtie_to_memory <= 1'b1;
				end
				else if (core_data_read && tag_hit) begin
					if (index1==index2) begin
						for (i = 0 ;i < 4; i = i + 1) begin
							if (i <= diff)
								data_to_send[8*i+:8] <= MEM[index2][lane_add*single_lane_size+8*(offset1+i)+:8];
						end
					end
					else begin
						for (i = 0 ;i < 4; i = i + 1) begin
							if (i<=offset2)
								data_to_send[8*(diff+i)+:8] <= MEM[index2][lane_add*single_lane_size+8*i+:8];
						end
					end
					LRUtable[active_index] <= updated_LRU1;
				end
				else if (core_data_write && tag_hit) begin
					if (index1==index2) begin
						writting_done[1] <= 1'b0;
						line[1] <= MEM[index2];
						if (diff == 0)
							line[1][lane_add*single_lane_size+8*offset1+:8] <= data[8*i+:8];		
						else if (diff == 1)
							line[1][lane_add*single_lane_size+8*offset1+:16] <= data[8*i+:16];	
						else if (diff == 3)
							line[1][lane_add*single_lane_size+8*offset1+:32] <= data[8*i+:32];	
					end
					else begin
						writting_done[1] <= 1'b0;
						line[1] <= MEM[index2];
						for (i = 0; i < 4; i = i + 1) begin
							if (i <= offset2)
							line[1][lane_add*single_lane_size+8*i+:8] <= data[8*(diff+i)+:8];
						end
					end
					LRUtable[active_index] <= updated_LRU1;
				end
			end
			else if (control_state == 1) begin
				if(tag_hit) begin
					for (i = 0 ;i < 3; i = i + 1) begin
						if (i<diff)
							data_to_send[8*i+:8] <= MEM[index1][lane_add*single_lane_size+8*(offset1+i)+:8];
					end
					LRUtable[active_index] <= updated_LRU1;
				end
			end
			else if (control_state == 2) begin
				if (data_ready) begin
					valid_lanes[index2][lane_to_replace] <= 1'b1;
					if(write_back)
						dirty_lanes[index2][lane_to_replace] <= 1'b0;
					MEM_T[index2][lane_to_replace*(bits_for_tag)+:bits_for_tag] <= tag;
					if (index1==index2) begin
						for (i = 0 ;i < 4; i = i + 1) begin
							if (1<=diff)
								data_to_send[8*i+:8] <= MEM[index2][lane_add*single_lane_size+8*(offset1+i)+:8];
						end
					end
					else begin
						for (i = 0 ;i < 4; i = i + 1) begin
							if (i<=offset2)
								data_to_send[8*(diff+i)+:8] <= MEM[index2][lane_add*single_lane_size+8*i+:8];
						end
					end
					LRUtable[active_index] <= updated_LRU2;
				end
			end
			else if (control_state == 3) begin
				if (data_ready) begin
					valid_lanes[index1][lane_to_replace] <= 1'b1;
					if(write_back)
						dirty_lanes[index1][lane_to_replace] <= 1'b0;
					MEM_T[index1][lane_to_replace*(bits_for_tag)+:bits_for_tag] <= tag;
					for (i = 0 ;i < 3; i = i + 1) begin
						if (i<diff)
							data_to_send[8*i+:8] <= MEM[index1][lane_add*single_lane_size+8*(offset1+i)+:8];
					end
					LRUtable[active_index] <= updated_LRU2;
				end
			end
			else if (control_state == 4) begin
				if (data_ready) begin
					valid_lanes[index2][lane_to_replace] <= 1'b1;
					if (write_back)
						dirty_lanes[index2][lane_to_replace] <= 1'b0;
					MEM_T[index2][lane_to_replace*(bits_for_tag)+:bits_for_tag] <= tag;
					if (index1==index2) begin
						writting_done[1] <= 1'b0;
						line[1] <= MEM[index2];
						if (diff == 0)
							line[1][lane_add*single_lane_size+8*offset1+:8] <= data[8*i+:8];		
						else if (diff == 1)
							line[1][lane_add*single_lane_size+8*offset1+:16] <= data[8*i+:16];	
						else if (diff == 3)
							line[1][lane_add*single_lane_size+8*offset1+:32] <= data[8*i+:32];	
						if(!write_back)
							wrtie_to_memory <= 1'b1;
					end
					else begin
						writting_done[1] <= 1'b0;
						line[1] <= MEM[index2];
						for (i = 0; i < 4; i = i + 1) begin
							if (i <= offset2)
							line[1][lane_add*single_lane_size+8*i+:8] <= data[8*(diff+i)+:8];
						end
					end
					LRUtable[active_index] <= updated_LRU2;
				end
			end
			else if (control_state == 5) begin
				if(tag_hit) begin
					writting_done[0] = 1'b0;
					line[0] = MEM[index1];
					for (i = 0 ;i < 3; i = i + 1) begin
						if (i < diff)
						line[0][lane_add*single_lane_size+8*(offset1+i)+:8] <= data [8*i+:8];
					end
					LRUtable[active_index] <= updated_LRU1;
					if(!write_back)
						wrtie_to_memory <= 1'b1;
				end
			end
			else if (control_state == 6) begin
				if(!writting_done[0]) begin
					MEM[index1] <= line[0];
					writting_done[0] = 1'b1;
				end
				else if (!writting_done[1]) begin
					MEM[index2] <= line[1];
					writting_done[1] = 1'b1;
				end
			end
			else if (control_state == 7) begin
				if (data_ready) begin
					valid_lanes[index1][lane_to_replace] <= 1'b1;
					if (write_back)
						dirty_lanes[index1][lane_to_replace] <= 1'b0;
					MEM_T[index1][lane_to_replace*(bits_for_tag)+:bits_for_tag] <= tag;
					writting_done [0] = 1'b0;
					line[0] <= MEM[index1];
					for (i = 0 ;i < 3; i = i + 1) begin
						if (i < diff)
						line[0][lane_add*single_lane_size+8*(offset1+i)+:8] <= data [8*i+:8];
					end
					LRUtable[active_index] <= updated_LRU2;
					if(!write_back)
						wrtie_to_memory <= 1'b1;
				end
			end

			if (transfer_state == 0)begin
			end
			else if (transfer_state == 1)begin
				memory_address <= {MEM_T[index1][lane_to_replace*bits_for_tag+:bits_for_tag],
									index1,{bits_for_index{1'b0}}};
				memory_data <= MEM[index1][lane_to_replace*single_lane_size+:64];
			end
			else if (transfer_state == 2)begin
				if (burstcount == burst_state) begin
				end
				else if (!memory_data_waitrequest) begin
					memory_data <= MEM[index1][lane_to_replace*single_lane_size+64*burst_state+:64];
				end
			end
			else if (transfer_state == 3)begin
				memory_address <= {tag1,index1,{bits_for_offset{1'b0}}};
			end
			else if (transfer_state == 4)begin
				if (memory_data_readdatavalid) begin
					MEM[index1][lane_to_replace*single_lane_size+burst_state*64+:64] <=
					memory_data_readdata;
				end
			end
			else if (transfer_state == 5)begin
				memory_address <= {MEM_T[index2][lane_to_replace*bits_for_tag+:bits_for_tag],
									index2,{bits_for_index{1'b0}}};
				memory_data <= MEM[index2][lane_to_replace*single_lane_size+:64];
			end
			else if (transfer_state == 6)begin
				if (burstcount == burst_state) begin
				end
				else if (!memory_data_waitrequest) begin
					memory_data <= MEM[index2][lane_to_replace*single_lane_size+64*burst_state+:64];
				end
			end
			else if (transfer_state == 7)begin
				memory_address <= {tag2,index2,{bits_for_offset{1'b0}}};
			end
			else if (transfer_state == 8)begin
				if (memory_data_readdatavalid) begin
					MEM[index2][lane_to_replace*single_lane_size+burst_state*64+:64] <=
					memory_data_readdata;
				end
			end
			else if (transfer_state == 9)begin
				memory_address <= core_data_address;
				memory_data[0+:32] <= data;
			end
		end
	end

endmodule


module get_highest_bit_on(
		input [3:0] bit_vector,
		output [1:0] possition
	);
	wire [1:0] inner_bus [4:0];

	assign inner_bus[0] = 2'b00;
	
	genvar i;
	generate
		for (i=0;i<4;i=i+1) begin:looping
			assign inner_bus[i+1] = bit_vector[i] ? i : inner_bus[i];
		end
	endgenerate
	
	assign possition = inner_bus[4];
endmodule

module get_position_for_new_lane_data #(
		parameter number_of_sets = 4,
		parameter log_of_number_of_sets = 2
		)(
		output [log_of_number_of_sets-1:0] position,
		input [number_of_sets-1:0] valids,
		input [number_of_sets-2:0] LRUtable
	);
		
	wire [log_of_number_of_sets-1:0] inner_bus [0:number_of_sets+1];
	wire [number_of_sets-1:0] inner_bus2 [0:log_of_number_of_sets+1];
	wire [log_of_number_of_sets-1:0] possition2;

	assign inner_bus[number_of_sets]={log_of_number_of_sets{1'b1}};
	assign inner_bus2[0] = LRUtable;

	genvar i;
	generate
		for (i=number_of_sets-1;i>=0;i=i-1) begin:looping
			assign inner_bus[i] = valids[i] ? inner_bus[i+1] : i;
		end

		for (i=1; i<log_of_number_of_sets; i= i + 1) begin: looping2
			assign possition2[log_of_number_of_sets-i] = inner_bus2[i-1][(number_of_sets-1)/(2**i)];
          	assign 	inner_bus2[i][0+:(number_of_sets-1)/(2**i)] = !inner_bus2[i-1][(number_of_sets-1)/(2**i)] ? 
          			inner_bus2[i-1][0+:(number_of_sets-1)/(2**i)+1] : 
          			inner_bus2[i-1][(number_of_sets-1)/(2**i)+1+:(number_of_sets-1)/(2**i)+1];
		end
	endgenerate
	assign position = &valids ? possition2 : inner_bus[0];
endmodule

module update_position#(
		parameter number_of_sets = 4,
		parameter log_of_number_of_sets = 2
	)(
		input [log_of_number_of_sets-1:0] position,
		input [number_of_sets-2:0] old_LRUtable,
		output [number_of_sets-2:0] LRUtable
	);

	generate
		if (number_of_sets == 2) begin
			assign LRUtable = !position[0];
		end
		else if (number_of_sets == 4)begin
			wire left,right;
			wire lt,rt,nu;
			wire [number_of_sets-2:0] test1,test2;
			assign {rt,nu,lt} = old_LRUtable;
			update_position #(number_of_sets/2,log_of_number_of_sets-1) 
					l(position[0+:log_of_number_of_sets-1],lt,left),
					r(position[0+:log_of_number_of_sets-1],rt,right);
			assign test1 = {lt,1'b0,right};
			assign test2 = {left,1'b1,rt};
			assign LRUtable = position[log_of_number_of_sets-1] ? test1 : test2 ;
		end
		else begin
			wire [(number_of_sets-2)/2-1:0] left,right;
			wire [(number_of_sets-2)/2-1:0] lt,rt;
			wire nu;
			assign {rt,nu,lt} = old_LRUtable;
			update_position #(number_of_sets/2,log_of_number_of_sets-1) 
					l(position[0+:log_of_number_of_sets-1],lt,left),
					r(position[0+:log_of_number_of_sets-1],rt,right);
			assign LRUtable = position[log_of_number_of_sets-1] ? {lt,1'b0,right}:{left,1'b1,rt};
		end
	endgenerate
endmodule
	