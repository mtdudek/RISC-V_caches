// mem_convertor.v

// This file was auto-generated as a prototype implementation of a module
// created in component editor.  It ties off all data_respondputs to ground and
// ignores all inputs.  It needs to be edited to make it do something
// useful.
// 
// This file will not be automatically regenerated.  You should check it in
// to your version control system if you want to keep it.

`timescale 1 ps / 1 ps
module mem_convertor (
		output wire [31:0] memory_address,         // avalon_master.address
		output wire        memory_read,            //              .read
		input  wire [31:0] memory_readdata,        //              .readdata
		input  wire        memory_waitrequest,     //              .waitrequest
		input  wire        memory_readdatavalid,   //              .readdatavalid

		input  wire [31:0] cache_address,          //  avalon_slave.address
		input  wire [3:0]  cache_burstcount,       //              .burstcount
		output wire        cache_readdatavalid,    //              .readdatavalid
		output wire [63:0] cache_readdata,         //              .readdata
		output wire        cache_waitrequest,      //              .waitrequest
		input  wire        cache_read,             //              .read

		input  wire        clock,                  //         clock.clk
		input  wire        reset                   //         reset.reset
	);
	
	reg read_pending,valid_data,state,want_to_read;
	reg [3:0] bytes_read,bytes_to_read;
	reg [4:0] address_send;
	reg [63:0] data_to_send;
	reg [31:0] address;
	
	assign cache_waitrequest = read_pending;
	assign cache_readdata = data_to_send;
	assign cache_readdatavalid = valid_data;
	assign memory_address = address;
	assign memory_read = want_to_read;
	
	always @(posedge reset or posedge clock) begin
		if(reset) begin
			read_pending <= 1'b0;
			valid_data <= 1'b0;
			bytes_read <= 4'b0000;
			address_send <= 4'b0000;
			state <= 1'b0;
			address_send <= 5'b00000;
          	want_to_read <= 1'b0;
		end
		else begin
            valid_data <= 1'b0;
			if(!read_pending && cache_read) begin
				read_pending <= 1'b1;
				bytes_to_read <= cache_burstcount;
				address <= cache_address;
              	want_to_read <= 1'b1;
              	state <= 1'b0;
			end
			else if (read_pending) begin
				if(!memory_waitrequest && address_send < {bytes_to_read,1'b0}-1 )begin
					address <= address + 4;
					address_send <= address_send + 1;
				end
				else if(!memory_waitrequest && address_send == {bytes_to_read,1'b0}-1 )begin
					want_to_read <= 1'b0;
				end
				if (bytes_to_read == bytes_read) begin
					read_pending <= 1'b0;
					bytes_read <= 4'b0000;
					bytes_read <= 4'b0000;
					address_send <= 5'b00000;
					want_to_read <= 1'b0;
				end
			end
          	if(memory_readdatavalid && read_pending) begin
                if (state == 0) begin
                  	data_to_send [0+:32] <= memory_readdata;
                  	state <= 1;
                end
                else begin
                  	valid_data <= 1'b1;
                  	data_to_send [32+:32] <= memory_readdata;
                  	bytes_read <= bytes_read + 1;
                  	state <= 0;
                end
            end
		end
	end

endmodule
