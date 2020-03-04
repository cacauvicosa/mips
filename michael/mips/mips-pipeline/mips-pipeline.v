module PC (input [31:0] pc_in, input clk, rst, output reg [31:0] pc_out);
  always @(posedge clk) begin
    pc_out <= pc_in;
    if (!rst)
      pc_out <= 0;
  end
endmodule

// pipe1 F -> D
module IFID (input f_clk, f_rst, input [31:0] f_pc, f_inst, output reg [31:0] d_pc, d_inst);
  always @(posedge f_clk) begin
    if (!f_rst) begin
      d_inst <= 0;
      d_pc   <= 0;
    end
    else begin
      d_inst <= f_inst;
      d_pc   <= f_pc;
    end
  end
endmodule

//----------------------------------------------------
// DECODE --------------------------------------------
//----------------------------------------------------
module decode (input d_clk, rst, regwrite, input [31:0] inst, pc, writedata, input [4:0] muxRegDst, output [31:0] e_rd1, e_rd2, e_sigext, e_pc, output [4:0] e_inst1, e_inst2, output [1:0] e_aluop, output e_alusrc, e_regdst, e_regwrite, e_memread, e_memtoreg, e_memwrite, e_branch);
  
  wire [31:0] data1, data2, sig_ext;
  wire [4:0] rs, rt, rd;
  wire [5:0] opcode;
  wire [1:0] aluop;
  wire branch, memread, memtoreg, MemWrite, regdst, alusrc, regwrite;
  
  assign opcode = inst[31:26];
  assign rs = inst[25:21];
  assign rt = inst[20:16];
  assign rd = inst[15:11];

  assign sig_ext = (inst[15]) ? {16'hFFFF,inst[15:0]} : {16'd0,inst[15:0]};

  ControlUnit control (opcode, regdst, alusrc, memtoreg, regwrite_out, memread, memwrite, branch, aluop);

  Register_Bank Registers (d_clk, regwrite, rs, rt, muxRegDst, writedata, data1, data2);

  // PIPE D -> E
  IDEX IDEX (d_clk, rst, regwrite_out, memtoreg, branch, memwrite, memread, regdst, alusrc, aluop, pc, data1, data2, sig_ext, rt, rd, e_regwrite, e_memtoreg, e_branch, e_memwrite, e_memread, e_regdst, e_alusrc, e_aluop, e_pc, e_rd1, e_rd2, e_sigext, e_inst1, e_inst2);

endmodule

// pipe2 D -> E
module IDEX (input d_clk, rst, d_regwrite, d_memtoreg, d_branch, d_memwrite, d_memread, d_regdst, d_alusrc, input [1:0] d_aluop, input [31:0] d_pc, d_rd1, d_rd2, d_sigext, input [4:0] d_inst1, d_inst2, output reg e_regwrite, e_memtoreg, e_branch, e_memwrite, e_memread, e_regdst, e_alusrc, output reg [1:0] e_aluop, output reg [31:0] e_pc, e_rd1, e_rd2, e_sigext, output reg [4:0] e_inst1, e_inst2);
  always @(posedge d_clk) begin
    if (!rst) begin
      e_regwrite <= 0;
      e_memtoreg <= 0;
      e_branch   <= 0;
      e_memwrite <= 0;
      e_memread  <= 0;
      e_regdst   <= 0;
      e_aluop    <= 0;
      e_alusrc   <= 0;
      e_pc       <= 0;
      e_rd1      <= 0;
      e_rd2      <= 0;
      e_sigext   <= 0;
      e_inst1    <= 0;
      e_inst2    <= 0;
    end
    else begin
      e_regwrite <= d_regwrite;
      e_memtoreg <= d_memtoreg;
      e_branch   <= d_branch;
      e_memwrite <= d_memwrite;
      e_memread  <= d_memread;
      e_regdst   <= d_regdst;
      e_aluop    <= d_aluop;
      e_alusrc   <= d_alusrc;
      e_pc       <= d_pc;
      e_rd1      <= d_rd1;
      e_rd2      <= d_rd2;
      e_sigext   <= d_sigext;
      e_inst1    <= d_inst1;
      e_inst2    <= d_inst2;
    end
  end
endmodule

module ControlUnit (input [5:0] opcode, output reg regdst, alusrc, memtoreg, regwrite_out, memread, memwrite, branch, output reg [1:0] aluop);

  always @(opcode) begin
    case(opcode) 
      6'd0: begin // R type
        regdst <= 1 ;
        alusrc <= 0 ;
        memtoreg <= 0 ;
        regwrite_out <= 1 ;
        memread <= 0 ;
        memwrite <= 0 ;
        branch <= 0 ;
        aluop <= 2 ;
			end
			6'd4: begin // beq
        regdst <= 0 ;
        alusrc <= 0 ;
        memtoreg <= 0 ;
        regwrite_out <= 0 ;
        memread <= 0 ;
        memwrite <= 0 ;
        branch <= 1 ;
        aluop <= 1 ;
			end
			6'd8: begin // addi
        regdst <= 0 ;
        alusrc <= 1 ;
        memtoreg <= 0 ;
        regwrite_out <= 1 ;
        memread <= 0 ;
        memwrite <= 0 ;
        branch <= 0 ;
        aluop <= 0 ;
      end
			6'd35: begin // lw
        regdst <= 0 ;
        alusrc <= 1 ;
        memtoreg <= 1 ;
        regwrite_out <= 1 ;
        memread <= 1 ;
        memwrite <= 0 ;
        branch <= 0 ;
        aluop <= 0 ;
      end
			6'd43: begin // sw
        regdst <= 0 ;
        alusrc <= 1 ;
        memtoreg <= 0 ;
        regwrite_out <= 0 ;
        memread <= 0 ;
        memwrite <= 1 ;
        branch <= 0 ;
        aluop <= 0 ;
      end
			default: begin //nop
        regdst <= 0 ;
        alusrc <= 0 ;
        memtoreg <= 0 ;
        regwrite_out <= 0 ;
        memread <= 0 ;
        memwrite <= 0 ;
        branch <= 0 ;
        aluop <= 0 ;
      end
    endcase
  end

endmodule 

module Register_Bank (input clk, regwrite, input [4:0] read1, read2, writereg, input [31:0] writedata, output [31:0] data1, data2);

  integer i;
  reg [31:0] memory [0:31]; // 32 registers de 32 bits cada

  // fill the memory
  initial begin
    for (i = 0; i <= 31; i++) 
      memory[i] = i;
  end

  assign data1 = (regwrite && read1==writereg) ? writedata : memory[read1];
  assign data2 = (regwrite && read2==writereg) ? writedata : memory[read2];
	
  always @(posedge clk) begin
    if (regwrite)
      memory[writereg] <= writedata;
  end
  
endmodule

// EXECUTE STAGE -------------------------------------
//execute execute (clk, rst, e_alusrc, e_regdst, e_regwrite, e_memread, e_memtoreg, e_memwrite, e_branch, e_rd1, e_rd2, sig_ext, e_pc, e_inst1, e_inst2, e_aluop, m_alures, m_addres, m_muxRegDst, m_branch, m_zero, m_regwrite, m_memtoreg, m_memread, m_memwrite);
module execute (input e_clk, rst, e_alusrc, e_regdst, e_regwrite, e_memread, e_memtoreg, e_memwrite, e_branch, input [31:0] e_in1, e_in2, e_sigext, e_pc, input [4:0] e_inst20_16, e_inst15_11, input [1:0] e_aluop, output [31:0] m_alures, m_addres, m_rd2, output [4:0] m_muxRegDst, output m_branch, m_zero, m_regwrite, m_memtoreg, m_memread, m_memwrite);

  wire [31:0] alu_B, e_addres, e_aluout;
  wire [3:0] aluctrl;
  wire [4:0] e_muxRegDst;
  wire e_zero;

  Add Add (e_pc, e_sigext, e_addres);

  assign alu_B = (e_alusrc) ? e_sigext : e_in2 ;

  //Unidade Lógico Aritimética
  ALU alu (aluctrl, e_in1, alu_B, e_aluout, e_zero);

  alucontrol alucontrol (e_aluop, e_sigext[5:0], aluctrl);
  
  assign e_muxRegDst = (e_regdst) ? e_inst15_11 : e_inst20_16;

  // PIPE E -> M
  EXMEM EXMEM (e_clk, rst, e_regwrite, e_memtoreg, e_branch, e_zero, e_memread, e_memwrite, e_addres, e_aluout, alu_B, e_muxRegDst, m_regwrite, m_memtoreg, m_zero, m_memread, m_memwrite, m_branch, m_addres, m_alures, m_rd2, m_muxRegDst);
  
endmodule

module Add (input [31:0] pc, shiftleft2, output [31:0] add_result);
  assign add_result = pc + (shiftleft2 << 2);
endmodule

module alucontrol (input [1:0] aluop, input [5:0] funct, output [3:0] alucontrol);

  reg [3:0] alucontrol;
   
  always @(aluop or funct) begin
    case (aluop)
      0: alucontrol <= 4'd2; // ADD para sw e lw
      1: alucontrol <= 4'd6; // SUB para branch
      default: begin
        case (funct)
          32: alucontrol <= 4'd2; // ADD
          34: alucontrol <= 4'd6; // SUB
          36: alucontrol <= 4'd0; // AND
          37: alucontrol <= 4'd1; // OR
          39: alucontrol <= 4'd12; // NOR
          42: alucontrol <= 4'd7; // SLT
          default: alucontrol <= 4'd15; // Nada acontece
        endcase
      end
    endcase
  end
endmodule

module ALU (input [3:0] alucontrol, input [31:0] A, B, output [31:0] aluout, output zero);

  reg [31:0] aluout;
  
  // Zero recebe um valor lógico caso aluout seja igual a zero.
  assign zero = (aluout == 0); 
  
  always @(alucontrol, A, B) begin
    //verifica qual o valor do controle para determinar o que fazer com a saída
    case (alucontrol)
      0: aluout <= A & B; // AND
      1: aluout <= A | B; // OR
      2: aluout <= A + B; // ADD
      6: aluout <= A - B; // SUB
      7: aluout <= A < B ? 32'd1:32'd0; //SLT
      12: aluout <= ~(A | B); // NOR
      default: aluout <= 0; //default 0, Nada acontece;
    endcase
  end
endmodule

// pipe2 E -> M
// pipe2 E -> M
module EXMEM (input e_clk, rst, e_regwrite, e_memtoreg, e_branch, e_zero, e_memread, e_memwrite, input [31:0] e_addres, e_alures, e_rd2, input [4:0] e_muxRegDst, output reg m_regwrite, m_memtoreg, m_zero, m_memread, m_memwrite, m_branch, output reg [31:0] m_addres, m_alures, m_rd2, output reg [4:0] m_muxRegDst);
  always @(posedge e_clk) begin
    if (!rst) begin
      m_regwrite  <= 0;
      m_memtoreg  <= 0;
      m_addres    <= 0;
      m_zero      <= 0;
      m_alures    <= 0;
      m_rd2       <= 0;
      m_muxRegDst <= 0;
      m_memread   <= 0;
      m_memwrite  <= 0;
      m_branch    <= 0;
    end
    else begin
      m_regwrite  <= e_regwrite;
      m_memtoreg  <= e_memtoreg;
      m_addres    <= e_addres;
      m_zero      <= e_zero;
      m_alures    <= e_alures;
      m_rd2       <= e_rd2;
      m_muxRegDst <= e_muxRegDst;
      m_memread   <= e_memread;
      m_memwrite  <= e_memwrite;
      m_branch    <= e_branch;
    end
  end
endmodule

// MEMORY STAGE ----------------------------------------
module memory (input m_clk, rst, m_branch, m_zero, m_regwrite, m_memtoreg, m_memread, m_memwrite, input [31:0] m_alures, writedata, input [4:0] m_muxRegDst, output [31:0] w_readdata, w_alures, output w_memtoreg, w_regwrite, pc_src, output [4:0] w_muxRegDst);

  wire [31:0] m_readdata;
  reg [31:0] memory [0:127]; 
  integer i;

  // fill the memory
  initial begin
    for (i = 0; i <= 127; i++) 
      memory[i] = i;
  end

  assign pc_src = (m_zero & m_branch) ? 1 : 0; 

  assign m_readdata = (m_memread) ? memory[m_alures[31:2]] : 0;

  always @(posedge m_clk) begin
    if (m_memwrite)
      memory[m_alures[31:2]] = writedata;
  end

  // pip4 M -> W
  MEMWB MEMWB (m_clk, rst, m_regwrite, m_memtoreg, m_readdata, m_alures, m_muxRegDst, w_readdata, w_alures, w_muxRegDst, w_regwrite, w_memtoreg); 

endmodule

// pip3 M -> W
module MEMWB (input m_clk, rst, m_regwrite, m_memtoreg, input [31:0] m_readData, m_alures, input [4:0] m_muxRegDst,output reg [31:0] w_readData, w_alures, output reg [4:0] w_muxRegDst, output reg w_regwrite, w_memtoreg);
  always @(posedge m_clk) begin
    if (!rst) begin
      w_readData  <= 0;
      w_alures    <= 0;
      w_regwrite  <= 0;
      w_memtoreg  <= 0;
      w_muxRegDst <= 0;
    end
    else begin
      w_readData  <= m_readData;
      w_alures    <= m_alures;
      w_regwrite  <= m_regwrite;
      w_memtoreg  <= m_memtoreg;
      w_muxRegDst <= m_muxRegDst;
    end
  end
endmodule

// WRITE-BACK -----------------------------------
module writeback (input [31:0] readdata, aluout, input memtoreg, output [31:0] write_data);
  assign write_data = (memtoreg) ? readdata : aluout;
endmodule

// FETCH --------------------------------------------
module fetch (input rst, clk, pc_src, input [31:0] add_res, output [31:0] d_inst, d_pc);
  
  wire [31:0] pc, new_pc, pc_4;
  wire [31:0] inst;
   
  assign pc_4 = 4 + pc;
  assign new_pc = (pc_src) ? add_res : pc_4;

  PC program_counter(new_pc, clk, rst, pc);

  reg [31:0] inst_mem [0:31];

  assign inst = inst_mem[pc[31:2]];

  // PIPE F -> D
  IFID IFID (clk, rst, pc_4, inst, d_pc, d_inst);

  initial begin
    // Exemplos 
    /*
    inst_mem[0] <= 32'h00000000; // nop
    inst_mem[1] <= 32'h8c010000; // lw r1, 0(r0)   =>   r1 = m[r0+0] 
    inst_mem[2] <= 32'h8c020004; // lw r2, 4(r0)   =>   r2 = m[r0+4] 
    inst_mem[3] <= 32'h00220820; // add r1,r1,r2   =>   r1 = r1 + r2 
    inst_mem[4] <= 32'hac010008; // sw r1, 8(r0)   =>   m[r0+8] = r1
    */

    inst_mem[0] <= 32'h00000000; // nop
    inst_mem[1] <= 32'h200a0005; // addi $t2,$zero,5
    inst_mem[2] <= 32'h200b0007; // addi $t3,$zero,7
    inst_mem[3] <= 32'h200c0002; // addi $t4,$zero,2
    inst_mem[4] <= 32'h200d0003; // addi $t5,$zero,3
    inst_mem[5] <= 32'h014b5020; // add $t2,$t2,$t3
    inst_mem[6] <= 32'h016c5820; // add $t3,$t3,$t4
    inst_mem[7] <= 32'h018c6020; // add $t4,$t4,$t4
    inst_mem[8] <= 32'h01aa6820; // add $t5,$t5,$t2 
  end
endmodule

// TOP -------------------------------------------
module pipemips (input clk, rst, output [31:0] reg_writedata);
 
  wire [31:0] d_inst, d_pc, e_pc, e_rd1, e_rd2, sig_ext, write_data, m_addres, add_res, m_alures, m_readdata, w_readData, w_alures, reg_writedata;
  wire e_regwrite, e_memtoreg, e_branch, e_memwrite, e_memread, e_regdst, e_alusrc, m_regWrite, m_memtoreg, m_zero, m_memread, m_memwrite, w_regwrite, w_memtoreg, m_branch;
  wire [1:0] e_aluop;
  wire [4:0] e_inst1, e_inst2, e_muxRegDst, m_muxRegDst, w_muxRegDst;
  
  // FETCH STAGE
  fetch fetch (rst, clk, pc_src, m_addres, d_inst, d_pc);
  
  // DECODE STAGE
  decode decode (clk, rst, w_regwrite, d_inst, d_pc, reg_writedata, w_muxRegDst, e_rd1, e_rd2, sig_ext, e_pc, e_inst1, e_inst2, e_aluop, e_alusrc, e_regdst, e_regwrite, e_memread, e_memtoreg, e_memwrite, e_branch);
  
  // EXECUTE STAGE
  execute execute (clk, rst, e_alusrc, e_regdst, e_regwrite, e_memread, e_memtoreg, e_memwrite, e_branch, e_rd1, e_rd2, sig_ext, e_pc, e_inst1, e_inst2, e_aluop, m_alures, m_addres, write_data, m_muxRegDst, m_branch, m_zero, m_regwrite, m_memtoreg, m_memread, m_memwrite);

  // MEMORY STAGE
  memory memory (clk, rst, m_branch, m_zero, m_regwrite, m_memtoreg, m_memread, m_memwrite, m_alures, write_data, m_muxRegDst, w_readData, w_alures, w_memtoreg, w_regwrite, pc_src, w_muxRegDst);

  // WRITEBACK STAGE
  writeback writeback (w_readData, w_alures, w_memtoreg, reg_writedata);

endmodule
