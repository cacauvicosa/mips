
`ifndef _regr
`define _regr

module regr (
	input clk,
	input clear,
	input wire [N-1:0] in,
	output reg [N-1:0] out);

	parameter N = 1;

	always @(posedge clk) begin
		if (clear)
			out <= {N{1'b0}};
		else
			out <= in;
	end
endmodule

`endif
