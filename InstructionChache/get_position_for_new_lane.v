// get_position_for_new_lane.v

// Created by Maciej Dudek

`timescale 1 ps / 1 ps

module get_position_for_new_lane #(
		parameter number_of_sets = 4,
		parameter log_of_number_of_sets = 2
		)(
		output [log_of_number_of_sets-1:0] position,
		input [number_of_sets-1:0] valids,
		input [number_of_sets-2:0] LRUtable
	);
		
	wire [log_of_number_of_sets-1:0] inner_bus [0:number_of_sets+1];
	wire [number_of_sets-2:0] inner_bus2 [0:log_of_number_of_sets];
	wire [log_of_number_of_sets-1:0] possition2;

	assign inner_bus[number_of_sets]={log_of_number_of_sets{1'b1}};
	assign inner_bus2[0] = LRUtable;

	genvar i;
	generate
		for (i=number_of_sets-1;i>=0;i=i-1) begin:looping
			assign inner_bus[i] = valids[i] ? inner_bus[i+1] : i;
		end

		for (i=1; i<log_of_number_of_sets+1; i= i + 1) begin: looping2
			assign possition2[log_of_number_of_sets-i] = 
					inner_bus2[i-1][(number_of_sets-1)/(2**i)];
			if (i<log_of_number_of_sets) begin
          		assign 	inner_bus2[i][0+:((number_of_sets-2)/(2**i))] = !inner_bus2[i-1][((number_of_sets-2)/(2**i))] ? 
          			inner_bus2[i-1][0+:((number_of_sets-2)/(2**i))] : 
          			inner_bus2[i-1][((number_of_sets-2)/(2**i))+1+:((number_of_sets-2)/(2**i))];
          	end
		end
	endgenerate
	assign position = &valids ? possition2 : inner_bus[0];
endmodule
