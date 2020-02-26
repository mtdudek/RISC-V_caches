`timescale 1 ps / 1 ps

module update_position#(
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
	