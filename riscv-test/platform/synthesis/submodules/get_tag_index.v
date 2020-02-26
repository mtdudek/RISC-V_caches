`timescale 1 ps / 1 ps

module get_tag_index #(
		parameter bits_for_tag = 20,
		parameter number_of_sets = 4,
		parameter log_of_number_of_sets = 2
		)(
		output [log_of_number_of_sets-1:0] pos, 
		output good, 
		input [bits_for_tag-1:0] tag,
		input [bits_for_tag*number_of_sets-1:0] tag_set,
		input [number_of_sets-1:0] valid_lanes
	);
	
	genvar i,j;
	wire [number_of_sets-1:0] h;
	wire [number_of_sets-1:0] inner_bus [log_of_number_of_sets-1:0];
	
	generate
		for(i=0;i<number_of_sets;i=i+1) begin:is_valid
			assign h[i] = ~(|(tag^tag_set[i*bits_for_tag+:bits_for_tag])) & valid_lanes[i];
		end
		
		for (i = log_of_number_of_sets-1 ; i >= 0; i = i - 1) begin:outside_loop
			for (j = 0 ; j < 2**(log_of_number_of_sets - i-1) ; j = j + 1) begin:inside_loop
				assign inner_bus[i][j] = |h[2**i+2*j*(2**i)+:2**i];
			end
			assign pos[i] = |inner_bus[i][0+:2**(log_of_number_of_sets-i-1)];
		end
		
	endgenerate
	
	assign good = |h;
					
endmodule