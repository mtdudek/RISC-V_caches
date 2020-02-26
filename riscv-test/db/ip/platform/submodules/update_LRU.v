// update_LRU.v

// Created by Maciej Dudek

`timescale 1 ps / 1 ps

module update_LRU#(
		parameter number_of_sets = 4,
		parameter log_of_number_of_sets = 2
	)(
		output [number_of_sets-2:0] LRUtable,
		input [log_of_number_of_sets-1:0] position,
		input [number_of_sets-2:0] old_LRUtable
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
			update_LRU #(number_of_sets/2,log_of_number_of_sets-1) 
					l(left,position[0+:log_of_number_of_sets-1],lt),
					r(right,position[0+:log_of_number_of_sets-1],rt);
			assign LRUtable = position[log_of_number_of_sets-1] ? 
							{right,1'b0,lt} : 
							{rt,1'b1,left};
		end
		else begin
			wire [(number_of_sets-2)/2-1:0] left,right;
			wire [(number_of_sets-2)/2-1:0] lt,rt;
			wire nu;
			assign {rt,nu,lt} = old_LRUtable;
			update_LRU #(number_of_sets/2,log_of_number_of_sets-1)
					l(left,position[0+:log_of_number_of_sets-1],lt),
					r(right,position[0+:log_of_number_of_sets-1],rt);
			assign LRUtable = position[log_of_number_of_sets-1] ? 
							{right,1'b0,lt} : 
							{rt,1'b1,left};
		end
	endgenerate
endmodule
	