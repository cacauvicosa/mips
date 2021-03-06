/*
 * regm - register memory
 *
 * A 32-bit register memory.  Two registers can be read at once. The
 * variables `read1` and `read2` specify which registers to read.  The
 * output is placed in `data1` and `data2`.
 *
 * If `regwrite` is high, the value in `wrdata` will be written to the
 * register in `wrreg`.
 *
 * The register at address $zero is treated special, it ignores
 * assignment and the value read is always zero.
 *
 * If the register being read is the same as that being written, the
 * value being written will be available immediately without a one
 * cycle delay.
 *
 */

`ifndef _regm
`define _regm

`ifndef DEBUG_CPU_REG
`define DEBUG_CPU_REG 0
`endif

module regm(
		input wire			clk,
		input wire  [4:0]	read1, read2,
		input wire  [4:0]	read11, read12,
		output wire [31:0]	data1, data2,
		output wire [31:0]	data11, data12,
		input wire		regwrite,regwrite1,
		input wire	[4:0]	wrreg,wrreg1,
		input wire	[31:0]	wrdata,wrdata1);

	parameter NMEM = 20;   // Number of memory entries,
							// not the same as the memory size
	parameter RM_DATA = "rm_data.txt";  // file to read data from

	reg [31:0] mem [0:31];  // 32-bit memory with 32 entries

	initial begin
		$readmemh(RM_DATA, mem, 0, NMEM-1);
	end


	reg [31:0] _data1, _data2;
	reg [31:0] _data11, _data12;

	initial begin
		if (`DEBUG_CPU_REG) begin
			$display("     $v0,      $v1,      $t0,      $t1,      $t2,      $t3,      $t4,      $t5,      $t6,      $t7");
			$monitor("%x, %x, %x, %x, %x, %x, %x, %x, %x, %x",
					mem[2][31:0],	/* $v0 */
					mem[3][31:0],	/* $v1 */
					mem[8][31:0],	/* $t0 */
					mem[9][31:0],	/* $t1 */
					mem[10][31:0],	/* $t2 */
					mem[11][31:0],	/* $t3 */
					mem[12][31:0],	/* $t4 */
					mem[13][31:0],	/* $t5 */
					mem[14][31:0],	/* $t6 */
					mem[15][31:0],	/* $t7 */
				);
		end
	end

	always @(*) begin
		if (read1 == 5'd0)
			_data1 = 32'd0;
		else if ((read1 == wrreg) && regwrite)
			_data1 = wrdata;
		else
			_data1 = mem[read1][31:0];
	end

	always @(*) begin
		if (read2 == 5'd0)
			_data2 = 32'd0;
		else if ((read2 == wrreg) && regwrite)
			_data2 = wrdata;
		else
			_data2 = mem[read2][31:0];
	end

	assign data1 = _data1;
	assign data2 = _data2;

	always @(*) begin
		if (read11 == 5'd0)
			_data11 = 32'd0;
		else if ((read11 == wrreg1) && regwrite1)
			_data11 = wrdata1;
		else
			_data11 = mem[read11][31:0];
	end

	always @(*) begin
		if (read12 == 5'd0)
			_data12 = 32'd0;
		else if ((read12 == wrreg1) && regwrite1)
			_data12 = wrdata1;
		else
			_data12 = mem[read12][31:0];
	end

	assign data11 = _data11;
	assign data12 = _data12;



	always @(posedge clk) begin
		if (regwrite && wrreg != 5'd0) begin
			// write a non $zero register
			mem[wrreg] <= wrdata;
		end
	end

	always @(posedge clk) begin
		if (regwrite1 && wrreg1 != 5'd0) begin
			// write a non $zero register
			mem[wrreg1] <= wrdata1;
		end
	end


endmodule

`endif
