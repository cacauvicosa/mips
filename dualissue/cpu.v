/*
 * cpu. - five stage MIPS CPU.
 *
 * Many variables (wires) pass through several stages.
 * The naming convention used for each stage is
 * accomplished by appending the stage number (_s<num>).
 * For example the variable named "data" which is
 * in stage 2 and stage 3 would be named as follows.
 *
 * wire data_s2;
 * wire data_s3;
 *	
 * If the stage number is omitted it is assumed to
 * be at the stage at which the variable is first
 * established.
 */

`include "regr.v"
`include "im.v"
`include "regm.v"
`include "control.v"
`include "alu.v"
`include "alu_control.v"
`include "dm.v"

`ifndef DEBUG_CPU_STAGES
`define DEBUG_CPU_STAGES 1
`endif

module cpu(
		input wire clk);

	parameter NMEM = 20;  // number in instruction memory
	parameter IM_DATA = "im_data2.txt";

	wire regwrite_s5,regwrite1_s5;
	wire [4:0] wrreg_s5,wrreg1_s5;
	wire [31:0]	wrdata_s5,wrdata1_s5;
	reg stall_s1_s2;

	// {{{ diagnostic outputs
	initial begin
		if (`DEBUG_CPU_STAGES) begin
			$display("if_pc,    if_instr, id_regrs, id_regrt, ex_alua,  ex_alub,  ex_aluctl, mem_memdata, mem_memread, mem_memwrite, wb_regdata, wb_regwrite");

$monitor("PC=%x|| rs=%d op =%d ||d1=%x d2=%x ||alu4=%x W%x R%x|| wr=%d\n i=%x|| rt=%d pscr=%x ||ALU=%x            || addr=%d          ||wr1=%d\nBA=%x|| rs1=%d op1=%d||rs1=%x im=%x||RD=%x        || clk=%d\ni1=%x|| rt1=%d       ||addr=%x           ||WD=%x\n -----------------------------------------------",
	pc, rs,	opcode,	data1_s3,alusrc_data2,alurslt_s4,memwrite_s4,memread_s4, wrreg_s5,
	inst,rt, pcsrc,	alurslt,mem_address_s4[8:2],wrreg1_s5,		/* if_instr */
	baddr_s2, rs1, opcode1,data11_s3,seimm1_s3,rdata, clock_counter,
	inst1, rt1, mem_address,data12_s4);
		end
	end 


	// }}}

	// {{{ flush control
	reg flush_s1, flush_s2, flush_s3;
	initial  begin
		flush_s1 <= 1'b0;
		flush_s2 <= 1'b0;
		flush_s3 <= 1'b0;
	end
	// }}}

	// {{{ stage 1, IF (fetch)

	reg  [5:0] clock_counter;
	initial begin
		clock_counter <= 6'd1;
	end
        always @(posedge clk) begin
                clock_counter <= clock_counter + 1;
	end

	reg  [31:0] pc;
	initial begin
		pc <= 32'd0;
	end

	wire [31:0] pc8;  // PC + 8
	assign pc8 = pc + 8;

	always @(posedge clk) begin
		if (pcsrc == 1'b1)
			pc <= baddr_s2;
		else
			pc <= pc8;
	end

	// pass PC + 8 to stage 2
	wire [31:0] pc8_s2;
	regr #(.N(32)) regr_pc8_s2(.clk(clk), .clear(flush_s1),
						.in(pc8), .out(pc8_s2));

	// instruction memory
	wire [31:0] inst, inst1; // inst ALU/ADDI/BEQ
				 // inst1  LW or SW
	wire [31:0] inst_s2;
	wire [31:0]  inst1_s2;
	im #(.NMEM(NMEM),.IM_DATA(IM_DATA))
	im1(.addr(pc), .data(inst),.data1(inst1));
	regr #(.N(32)) regr_im_s2(.clk(clk),.clear(1'b0),
		.in({inst}), .out({inst_s2}));
	regr #(.N(32)) regr_im1_s2(.clk(clk),.clear(1'b0),
		.in({inst1}), .out({inst1_s2}));

	// }}}

	// {{{ stage 2, ID (decode)
// inst: ALU, ADDI or BEQ/BNE, Inst1: Lw or Sw
	// decode instruction
	wire [5:0]  opcode,opcode1;
	wire [4:0]  rs,rs1;
	wire [4:0]  rt,rt1;
	wire [4:0]  rd;
	wire [15:0] imm,imm1;
	wire [31:0] seimm,seimm1;  // sign extended immediate
	//
assign seimm 	= {{16{inst_s2[15]}}, inst_s2[15:0]};
assign seimm1 	= {{16{inst1_s2[15]}}, inst1_s2[15:0]};

assign opcode   = inst_s2[31:26];
assign opcode1   = inst1_s2[31:26];
	
assign rs       = inst_s2[25:21]; 
assign rs1       = inst1_s2[25:21];

assign rt       = inst_s2[20:16]; 
assign rt1       = inst1_s2[20:16];

assign rd       = inst_s2[15:11];

assign imm      = inst_s2[15:0];
assign imm1      = inst1_s2[15:0];


// register memory
	wire [31:0] data1, data2;
	wire [31:0] data11, data12;

	regm regm1(.clk(clk), .read1(rs), .read2(rt),
			.data1(data1), .data2(data2),
			.regwrite(regwrite_s5), .wrreg(wrreg_s5),
			.wrdata(wrdata_s5),
			.read11(rs1), .read12(rt1),
			.data11(data11), .data12(data12),
			.regwrite1(regwrite1_s5), .wrreg1(wrreg1_s5),
			.wrdata1(wrdata1_s5));

	// transfer register data to stage 3
	wire [31:0]	data1_s3, data2_s3;
	regr #(.N(64)) reg_s2_mem(.clk(clk), .clear(flush_s2), 
				.in({data1, data2}),
				.out({data1_s3, data2_s3}));

	// transfer register data to stage 3
	wire [31:0]	data11_s3, data12_s3;
	regr #(.N(64)) reg1_s2_mem(.clk(clk), .clear(flush_s2), 
				.in({data11, data12}),
				.out({data11_s3, data12_s3}));




	// transfer seimm, rt, and rd to stage 3
	wire [31:0] seimm_s3,seimm1_s3;
regr #(.N(64)) reg_s2_seimm(.clk(clk), .clear(flush_s2), 
		.in({seimm,seimm1}), .out({seimm_s3,seimm1_s3}));

	wire [4:0] 	rt_s3,rt1_s3;
	wire [4:0] 	rd_s3;
	regr #(.N(15)) reg_s2_rt_rd(.clk(clk), .clear(flush_s2), 
	.in({rt, rd, rt1}), .out({rt_s3, rd_s3, rt1_s3}));



	 // add baddr_s2 = pc8_s2 + 4*im
	// branch address
	wire [31:0] baddr_s2;
	assign baddr_s2 = pc8_s2 + 4*seimm;

	// control (opcode -> ...)
	wire		regdst;
	wire		branch_eq_s2;
	wire		branch_ne_s2;
	wire		memread;
	wire		memwrite;
	wire [1:0]	aluop;
	wire		regwrite,regwrite1;
	wire		alusrc;
	control ctl1(.opcode(opcode),
			.opcode1(opcode1), .regdst(regdst),
				.branch_eq(branch_eq_s2), 
				.branch_ne(branch_ne_s2),
				.memread(memread),
				.aluop(aluop),
				.memwrite(memwrite), 
				.alusrc(alusrc),
				.regwrite(regwrite),
				.regwrite1(regwrite1) );

	
// pcscr
       wire pcsrc;
       assign pcsrc = branch_eq_s2 & (data1==data2) |
			branch_ne_s2 & ~(data1==data2);

	// transfer the control signals to stage 3
	wire		regdst_s3;
	wire		memread_s3;
	wire		memwrite_s3;
	wire [1:0]	aluop_s3;
	wire		regwrite_s3,regwrite1_s3;
	wire		alusrc_s3;
	regr #(.N(8)) reg_s2_control(.clk(clk), .clear(stall_s1_s2),
			.in({regdst, memread, memwrite,
			      aluop, regwrite,
			      regwrite1,alusrc}),
			.out({regdst_s3, memread_s3, 
				memwrite_s3,aluop_s3,
		regwrite_s3, regwrite1_s3,alusrc_s3}));

	// }}}

	// {{{ stage 3, EX (execute)

	// pass through some control signals to stage 4
	wire regwrite_s4;wire regwrite1_s4;
	wire memread_s4;
	wire memwrite_s4;
	regr #(.N(4)) reg_s3(.clk(clk), .clear(flush_s2),
				.in({regwrite_s3,regwrite1_s3 , memread_s3,
						memwrite_s3}),
				.out({regwrite_s4, regwrite1_s4, memread_s4,
						memwrite_s4}));

	// ALU
	// second ALU input can come from an immediate value or data
	wire [31:0] alusrc_data2;
	assign alusrc_data2 = (alusrc_s3) ? seimm_s3 : data2_s3;

	// ALU control
	wire [3:0] aluctl;
	wire [5:0] funct;
	assign funct = seimm_s3[5:0];
	alu_control alu_ctl1(.funct(funct), .aluop(aluop_s3), .aluctl(aluctl));


	// ALU
	wire [31:0]	alurslt; // alu OUT
	
	alu alu1(.ctl(aluctl), .a(data1_s3), 
		.b(alusrc_data2), .out(alurslt));


	// pass ALU result and zero to stage 4
	wire [31:0]	alurslt_s4; // out
	regr #(.N(32)) reg_alurslt(.clk(clk), .clear(flush_s3), 
				.in({alurslt}),
				.out({alurslt_s4}));

	// pass data2 to stage 4
	wire [31:0] data12_s4;
	regr #(.N(32)) reg_data2_s3(.clk(clk), .clear(flush_s3),
				.in(data12_s3), .out(data12_s4));

	// write register
	wire [4:0]	wrreg,wrreg1;
	wire [4:0]	wrreg_s4,wrreg1_s4;
	assign wrreg = (regdst_s3) ? rd_s3 : rt_s3;
	assign wrreg1 = rt1_s3;
	// pass to stage 4
	regr #(.N(10)) reg_wrreg(.clk(clk), .clear(flush_s3), 
		.in({wrreg,wrreg1}), .out({wrreg_s4,wrreg1_s4}));

	wire [31:0] mem_address,mem_address_s4;
	assign mem_address = data11_s3 + seimm1_s3;
        regr #(.N(32)) reg_wrreg1(.clk(clk), .clear(flush_s3), 
		.in(mem_address), .out(mem_address_s4));

		// }}}

	// {{{ stage 4, MEM (memory)

	// pass regwrite and memtoreg to stage 5
	regr #(.N(2)) reg_regwrite_s4(.clk(clk), .clear(1'b0), 
			.in({regwrite_s4, regwrite1_s4}),
				.out({regwrite_s5,regwrite1_s5}));

	// data memory
	wire [31:0] rdata;
	dm dm1(.clk(clk), .addr(mem_address_s4[8:2]), .rd(memread_s4), 
	.wr(memwrite_s4), .wdata(data12_s4), .rdata(rdata));
	// pass read data to stage 5

	wire [31:0] rdata_s5;
	regr #(.N(32)) reg_rdata_s4(.clk(clk), .clear(1'b0),
				.in(rdata),
				.out(rdata_s5));

	// pass alurslt to stage 5
	wire [31:0] alurslt_s5;
	regr #(.N(32)) reg_alurslt_s4(.clk(clk), .clear(1'b0),
				.in(alurslt_s4),
				.out(alurslt_s5));

	// pass wrreg to stage 5
	regr #(.N(10)) reg_wrreg_s4(.clk(clk), .clear(1'b0), 
				.in({wrreg_s4,wrreg1_s4}),
				.out({wrreg_s5,wrreg1_s5}));

	// }}}
			
	// {{{ stage 5, WB (write back)

	assign wrdata_s5 = alurslt_s5; // alu, addi
	assign wrdata1_s5 = rdata_s5 ; // lw 

	// }}}


endmodule

// vim:foldmethod=marker
