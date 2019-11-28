`ifndef _control
`define _control

module control(
		input  wire	[5:0]	opcode,opcode1,
		output reg			branch_eq, branch_ne,
		output reg [1:0]	aluop,
		output reg			memread, memwrite,
		output reg	regdst, regwrite, regwrite1, alusrc);

	always @(*) begin
		/* defaults */
		aluop[1:0]	<= 2'b10;
		alusrc		<= 1'b0;
		branch_eq	<= 1'b0;
		branch_ne	<= 1'b0;
		memread		<= 1'b0;
		memwrite	<= 1'b0;
		regdst		<= 1'b1;
		regwrite	<= 1'b1;
		regwrite1	<= 1'b0;

		case (opcode1)
			6'b100011: begin	/* lw */
				memread  <= 1'b1;
				regwrite1 <= 1'b1;
			end
			6'b101011: begin	/* sw */
				memwrite <= 1'b1;
			end
		endcase
		case (opcode)
			6'b001000: begin	/* addi */
				regdst   <= 1'b0;
				aluop[1] <= 1'b0;
				alusrc   <= 1'b1;
			end
			6'b000100: begin	/* beq */
				branch_eq <= 1'b1;
				regwrite  <= 1'b0;
			end
			6'b000101: begin	/* bne */
				branch_ne <= 1'b1;
				regwrite  <= 1'b0;
			end
			6'b000000: begin	/* add */
			end
		endcase
	end
endmodule

`endif
