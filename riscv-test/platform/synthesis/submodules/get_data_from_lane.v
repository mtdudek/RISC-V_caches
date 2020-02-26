`timescale 1 ps / 1 ps

module get_data_from_lane#(
		parameter log_of_number_of_sets = 2,
		parameter bits_for_offset = 3,
		parameter cache_lane_size = 8*(2**bits_for_offset)*(2**log_of_number_of_sets)
		)( 
		output wire [31:0] data,
		input wire [bits_for_offset-1:0] offset,
		input wire [log_of_number_of_sets-1:0] pos,
		input wire [cache_lane_size-1:0] lane
	);
	
		parameter single_lane_size = 8*(2**bits_for_offset);

	genvar i,j;
	wire [cache_lane_size-1:0] inner_bus [0:log_of_number_of_sets+1];
		wire [8*(2**bits_for_offset)-1:0] inner_bus2 [0:bits_for_offset+1];
	assign inner_bus[log_of_number_of_sets] = lane;

	generate
		for (i=log_of_number_of_sets-1;i>=0;i=i-1) begin:lane_loop
          assign inner_bus[i] = pos[i] ? inner_bus[i+1][(single_lane_size*(2**i))+:(single_lane_size*(2**i))] :
														inner_bus[i+1][0+:(single_lane_size*(2**i))] ;
		end
      assign inner_bus2[bits_for_offset]=inner_bus[0][0+:(8*(2**bits_for_offset))];
		
		for (i=bits_for_offset-1;i>=2;i=i-1) begin:data_loop
          assign inner_bus2[i] = offset[i] ? inner_bus2[i+1][(8*2**i)+:(8*(2**i))] : inner_bus2[i+1][0+:(8*(2**i))] ;
		end
      
	endgenerate
	assign data = inner_bus2[2][0+:32];
		
endmodule
