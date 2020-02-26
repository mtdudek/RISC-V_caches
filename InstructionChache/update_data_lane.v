// update_data_lane.v

// Created by Maciej Dudek

`timescale 1 ps / 1 ps

module update_data_lane #(
		parameter number_of_sets = 4,
		parameter bits_for_offset = 6,
		parameter log_of_number_of_sets = 2,
		parameter single_lane_size = 8*(2**bits_for_offset),
		parameter cache_lane_size = single_lane_size * number_of_sets
	)(
		output [cache_lane_size-1:0] new_data_lane,
		input [cache_lane_size-1:0] old_data_lane,
		input [single_lane_size-1:0] data,
		input [log_of_number_of_sets-1:0] pos
	);

	genvar  i;
	generate
		for (i = 0; i<number_of_sets ;i = i+1) begin: loop
			assign new_data_lane[i*single_lane_size+:single_lane_size] = i == pos ?
				data : old_data_lane[i*single_lane_size+:single_lane_size];
		end
	endgenerate
endmodule 