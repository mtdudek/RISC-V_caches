// update_tag_lane.v

// Created by Maciej Dudek

`timescale 1 ps / 1 ps

module update_tag_lane #(
		parameter number_of_sets = 4,
		parameter bits_for_tag = 20,
		parameter log_of_number_of_sets = 2
	)(
		output [number_of_sets*bits_for_tag-1:0] new_tag_lane,
		input [number_of_sets*bits_for_tag-1:0] old_tag_lane,
		input [bits_for_tag-1:0] tag,
		input [log_of_number_of_sets-1:0] pos
	);

	genvar  i;
	generate
		for (i = 0; i<number_of_sets ;i = i+1) begin: loop
			assign new_tag_lane [i*bits_for_tag+:bits_for_tag] = (i == pos)?
				tag : old_tag_lane[i*bits_for_tag+:bits_for_tag];
		end
	endgenerate
endmodule 