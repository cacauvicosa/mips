	wire regwrite_s5;wire [4:0] wrreg_s5;wire [31:0]	wrdata_s5;reg stall_s1_s2;
	reg flush_s1, flush_s2, flush_s3;
	always @(*) begin
	  flush_s1 <= 1'b0;flush_s2 <= 1'b0;flush_s3 <= 1'b0;
	    if (pcsrc | jump_s4) begin
		flush_s1 <= 1'b1;flush_s2 <= 1'b1;flush_s3 <= 1'b1;
	    end
	end
	reg  [31:0] pc;
	wire [31:0] pc4;  // PC + 4
	assign pc4 = pc + 4;
	always @(posedge clk) begin
		if (stall_s1_s2) pc <= pc;
		else if (pcsrc == 1'b1)pc <= baddr_s4;
		else if (jump_s4 == 1'b1)pc <= jaddr_s4;
		else pc <= pc4;
	end
	wire [31:0] pc4_s2;wire [31:0] inst;wire [31:0] inst_s2;
	im #(.NMEM(NMEM), .IM_DATA(IM_DATA))
		im1(.clk(clk), .addr(pc), .data(inst));

	Barrel Fetch .hold(stall_s1_s2), .clear(flush_s1), .in(pc4,inst), .out(*_s2)
	
	wire [5:0]  opcode;wire [4:0]  rs;wire [4:0]  rt;
	wire [4:0]  rd;wire [15:0] imm;wire [4:0]  shamt;
	wire [31:0] jaddr_s2;wire [31:0] seimm;  
	assign opcode   = inst_s2[31:26];assign rs       = inst_s2[25:21];
	assign rt       = inst_s2[20:16];assign rd       = inst_s2[15:11];
	assign imm      = inst_s2[15:0];assign shamt    = inst_s2[10:6];
	assign jaddr_s2 = {pc[31:28], inst_s2[25:0], {2{1'b0}}};
	assign seimm 	= {{16{inst_s2[15]}}, inst_s2[15:0]};
	wire [31:0] data1, data2;
	regm regm1(.clk(clk), .read1(rs), .read2(rt),.data1(data1), .data2(data2),
	.regwrite(regwrite_s5), .wrreg(wrreg_s5),.wrdata(wrdata_s5));
	
	wire [4:0] rs_s3;wire [31:0]	data1_s3, data2_s3;wire [31:0] seimm_s3;
	wire [4:0] 	rt_s3;wire [4:0] 	rd_s3; wire [31:0] pc4_s3;
        Barrel Decode .clear(flush_s2), .hold(1'b0),.in(rs,data1,data2,rt,rd,seimm,pc4_s2,
	regdst, memread, memwrite,memtoreg, aluop, regwrite, alusrc,branch_eq_s2, branch_ne_s2,
	baddr_s2,jump_s2,jaddr_s2),
	 .out(*_s3));	
	wire	regdst;wire	branch_eq_s2;wire	branch_ne_s2;
	wire	memread;wire	memwrite;wire	memtoreg;wire	jump_s2;
	wire [1:0]	aluop;wire	regwrite;wire	alusrc;
	control ctl1(.opcode(opcode), .regdst(regdst),
	.branch_eq(branch_eq_s2), .branch_ne(branch_ne_s2),.memread(memread),
	.memtoreg(memtoreg), .aluop(aluop),.memwrite(memwrite), .alusrc(alusrc),
	.regwrite(regwrite), .jump(jump_s2));
	wire [31:0] seimm_sl2; assign seimm_sl2 = {seimm[29:0], 2'b0};  
	wire [31:0] baddr_s2;assign baddr_s2 = pc4_s2 + seimm_sl2;
	wire regdst_s3,memread_s3,memwrite_s3,memtoreg_s3,regwrite_s3,alusrc_s3;
	wire [1:0] aluop_s3;wire branch_eq_s3, branch_ne_s3; wire [31:0] baddr_s3;
	wire jump_s3;wire [31:0] jaddr_s3;
	wire regwrite_s4,memtoreg_s4,memread_s4,memwrite_s4;

	Barrel Exec .clear(flush_s3), .hold(1'b0), .in({regwrite_s3, memtoreg_s3, memread_s3,
	memwrite_s3,zero_s3,alurslt,wrreg,branch_eq_s3, branch_ne_s3,baddr_s3,jump_s3}),
				.out({*_s4})); // except fw_data2_s3 -> data2_s4
	wire [31:0] alusrc_data2; assign alusrc_data2 = (alusrc_s3) ? seimm_s3 : fw_data2_s3;
	wire [3:0] aluctl;wire [5:0] funct;assign funct = seimm_s3[5:0];
	alu_control alu_ctl1(.funct(funct), .aluop(aluop_s3), .aluctl(aluctl));
	wire [31:0]	alurslt;	reg [31:0] fw_data1_s3;
	always @(*)
	case (forward_a)
			2'd1: fw_data1_s3 = alurslt_s4;
			2'd2: fw_data1_s3 = wrdata_s5;
		 default: fw_data1_s3 = data1_s3;
	endcase
	always @(*)
	case (forward_b)
			2'd1: fw_data2_s3 = alurslt_s4;
			2'd2: fw_data2_s3 = wrdata_s5;
		 default: fw_data2_s3 = data2_s3;
	endcase
	
	alu alu1(.ctl(aluctl), .a(fw_data1_s3), .b(alusrc_data2), .out(alurslt),
								.zero(zero_s3));
	wire zero_s3, zero_s4;wire [31:0]	alurslt_s4;wire [31:0] data2_s4;reg [31:0] fw_data2_s3;
	wire [4:0]	wrreg; wire [4:0]	wrreg_s4;
	assign wrreg = (regdst_s3) ? rd_s3 : rt_s3;
	wire branch_eq_s4, branch_ne_s4; wire [31:0] baddr_s4;
	wire jump_s4;wire [31:0] jaddr_s4;wire memtoreg_s5;

	Barrel Mem .clear(1'b0), .hold(1'b0),.in({regwrite_s4, memtoreg_s4,rdata,alurslt_s4,wrreg_s4}),
				.out(*_s5));
	wire [31:0] rdata;	wire [31:0] rdata_s5;wire [31:0] alurslt_s5;
	dm dm1(.clk(clk), .addr(alurslt_s4[8:2]), .rd(memread_s4), .wr(memwrite_s4),
			.wdata(data2_s4), .rdata(rdata));
	reg pcsrc;
	always @(*) begin
		case (1'b1)
			branch_eq_s4: pcsrc <= zero_s4;
			branch_ne_s4: pcsrc <= ~(zero_s4);
			default: pcsrc <= 1'b0;
		endcase
	end
	assign wrdata_s5 = (memtoreg_s5 == 1'b1) ? rdata_s5 : alurslt_s5;
	reg [1:0] forward_a;	reg [1:0] forward_b;
	always @(*) begin
		if ((regwrite_s4 == 1'b1) && (wrreg_s4 == rs_s3)) begin
			forward_a <= 2'd1;  // stage 4
		end else if ((regwrite_s5 == 1'b1) && (wrreg_s5 == rs_s3)) begin
			forward_a <= 2'd2;  // stage 5
		end else
			forward_a <= 2'd0;  // no forwarding
		if ((regwrite_s4 == 1'b1) & (wrreg_s4 == rt_s3)) begin
			forward_b <= 2'd1;  // stage 5
		end else if ((regwrite_s5 == 1'b1) && (wrreg_s5 == rt_s3)) begin
			forward_b <= 2'd2;  // stage 5
		end else
			forward_b <= 2'd0;  // no forwarding
	end
	always @(*) begin
		if (memread_s3 == 1'b1 && ((rt == rt_s3) || (rs == rt_s3)) ) begin
			stall_s1_s2 <= 1'b1;  // perform a stall
		end else
			stall_s1_s2 <= 1'b0;  // no stall
	end

