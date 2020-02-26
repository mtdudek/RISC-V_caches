`timescale 1 ps / 1 ps
module mem_sim(
	input clk, 	
	input [31:0] address_mem,
	input read_to_mem,
	output [31:0] data_from_mem,
	output readdatavalid_from_mem, 
	output waitrequest_from_mem,

	input [63:0] data_respond,
	input read_mem_valid
);

	// memory simulation
	reg [7:0] mem [0:4198400];
	reg [31:0] in1,in2;
	reg [31:0] data;
	reg rfm,wfm;
	reg [1:0] status;

	assign data_from_mem = data;
	assign readdatavalid_from_mem = rfm;
	assign waitrequest_from_mem = wfm;

	initial begin:mem_setup
		integer i;
		for (i=0;i<4198400;i=i+1) begin
			mem[i]=i;
		end
		data = 0;
		in1 = 0;
		in2 = 0;
		status = 0;
		rfm = 0;
		wfm = 1;
	end

	always@(posedge clk) begin
		rfm<= 0;
		if (!wfm && read_to_mem) begin
			if(!status) begin
				in1 <= {mem[address_mem+3],mem[address_mem+2],mem[address_mem+1],mem[address_mem]};
				data <= {mem[address_mem+3],mem[address_mem+2],mem[address_mem+1],mem[address_mem]};
				rfm <= 1;
			end
			else if (status == 1)begin
				in2 <= {mem[address_mem+3],mem[address_mem+2],mem[address_mem+1],mem[address_mem]};
				data <= {mem[address_mem+3],mem[address_mem+2],mem[address_mem+1],mem[address_mem]};
				rfm<= 1;
			end
			status <= status + 1;
			wfm <= 1;
		end
		else if(wfm && status != 2) begin
			wfm <= 0;
		end 
		else if(status == 2 && read_mem_valid) begin
			if ({in2,in1}!=data_respond) $stop;
			else begin
				status <= 0;
			end
		end
	end

endmodule

module core_sim(
	input clk, 	
	output core_read,
	output [31:0] instruction_address,
	input [31:0] instruction,
	input waitrequest_core,
	input inst_valid
);
	// core simulation

	reg [25:0] ia;
	reg [5:0] offset;
	reg cr;

	assign instruction_address = {ia,offset};
	assign core_read = cr;

	initial begin:core_setup
		cr = 1;
		ia = 26'b00000000010000000000000000;
		offset = 6'b000000;
	end

	always @(posedge clk) begin
		if (ia >= 32'h00400500) $finish;
		if(!waitrequest_core) begin
			offset = offset + 4;
		end
	end

endmodule

module memory_test(
		input  wire        clock,                     
		
		output reg [31:0] memory_address,           
		output reg        memory_read,              
		input  wire [63:0] memory_readdata,          
		input  wire        memory_waitrequest,       
		output reg [3:0]  memory_burstcount,        
		input  wire        memory_readdatavalid     
	);

	reg [1:0] test;

	reg [3:0] cnt;
	reg [2:0] pos;

	reg [64*8-1:0] data_read1,data_read2;

	initial begin:memory_test_setup
		test = 0;
		memory_address = 0;
		memory_read = 0;
		memory_burstcount = 4'b1000;
		pos = 0;
	end

	always @(posedge clock) begin
		if(!test[0])begin
			memory_read = 1;
			cnt = 0;
			test[0] = 1;
		end
		else begin
			if(!memory_waitrequest)
				memory_read = 0;
			if(memory_readdatavalid) begin
				if(!test[1])
					data_read1[pos*64+:64] = memory_readdata;
				else
					data_read2[pos*64+:64] = memory_readdata;
				cnt = cnt +1;
				pos = pos +1;
			end
			if(cnt == memory_burstcount) begin
				test[0] = 0;
				if(test[1]) $stop;
				test[1] = 1;
				memory_address = memory_address + 4;
				pos = 1;
			end
		end
	end

endmodule

module benchmark ();
	
	// simulation

	reg clk,rst;

	// interconect

		// core-cache

		wire [31:0] inst_address,instruction;
		wire waitrequest_core,core_read,inst_valid;

		// cache-memory_convertor
		wire [3:0] burstcount;
		wire [31:0] address_to_data;
		wire [63:0] data_respond;
		wire waitrequest,read_mem_valid,read_request;

		// memory_convertor-mem_sim
		wire [31:0] address_mem;
		wire [31:0] data_from_mem;
		wire readdatavalid_from_mem,waitrequest_from_mem,read_to_mem;
///*

	core_sim core_sim1(
		.clk(clk), 	
		.core_read(core_read),
		.instruction_address(inst_address),
		.instruction(instruction),
		.waitrequest_core(waitrequest_core),
		.inst_valid(inst_valid)
	);

	instruction_cache test_cache (
		.clock(clk),                    		//            clock_sink.clk
		.reset(rst),                    		//            reset_sink.reset
		
		.memory_address(address_to_data), 		// access_to_main_memory.address
		.memory_read(read_request),      		//                      .read
		.memory_readdata(data_respond),        	//                      .readdata
		.memory_waitrequest(waitrequest),		//                      .waitrequest
		.memory_burstcount(burstcount),        	//                      .burstcount
		.memory_readdatavalid(read_mem_valid), 	//                      .readdatavalid
		
		.core_inst_address(inst_address), 		//       core_interaface.address
		.core_instruction(instruction),         //                      .readdata
		.core_waitrequest(waitrequest_core),	//                      .waitrequest
		.core_read(core_read),   				//                      .read
		.core_inst_valid(inst_valid)	    	//						.readdatavalid
	);
//*/
/*
	memory_test mem_test(
		.clock (clk),                     
		
		.memory_address(address_to_data),           
		.memory_read(read_request),              
		.memory_readdata(data_respond),          
		.memory_waitrequest(waitrequest),       
		.memory_burstcount(burstcount),        
		.memory_readdatavalid(read_mem_valid)
	);   
*/
	mem_convertor converter(
		.memory_address(address_mem),
		.memory_read(read_to_mem),
		.memory_readdata(data_from_mem),
		.memory_waitrequest(waitrequest_from_mem),
		.memory_readdatavalid(readdatavalid_from_mem),

		.cache_address(address_to_data),
		.cache_burstcount(burstcount),
		.cache_readdatavalid(read_mem_valid),
		.cache_readdata(data_respond),
		.cache_waitrequest(waitrequest),
		.cache_read(read_request),

		.clock(clk),
		.reset(rst)
	);
		
	mem_sim mem_sim1(
		.clk(clk), 	
		.address_mem(address_mem),
		.read_to_mem(read_to_mem),
		.data_from_mem(data_from_mem),
		.readdatavalid_from_mem(readdatavalid_from_mem), 
		.waitrequest_from_mem(waitrequest_from_mem),

		.data_respond(data_respond),
		.read_mem_valid(read_mem_valid)
	);

	initial begin:sim_setup
		rst = 1;
		clk = 0;
		#1 rst = 0;
	end

	always begin
		#3 clk = 1;
		#3 clk = 0;
	end

endmodule