// FETCH --------------------------------------------
module fetch (
  input zero,
  input rst,
  input clk, 
  input branch,
  output [31:0] inst
);
  
  wire [31:0] signalextended;
  wire [31:0] pc;
  wire [31:0] pc_4;
  wire [31:0] new_pc;
  
  assign signalextended = (inst[15]) ? {16'hFFFF,inst[15:0]} : {16'd0,inst[15:0]};

  assign pc_4 = 4 + pc; // pc+4  Adder
  // new PC Mux
  assign new_pc = (branch & zero) ? pc_4 + signalextended << 2 : pc_4; 

  InstructionMem instruction_memory (
    .rst(rst),
    .addr(pc>>2),
    .inst_out(inst)
  );

  pc program_counter(
    .pc_in(new_pc),
    .clk(clk),
    .rst(rst),
    .pc_out(pc)
  );
  
endmodule

module pc (
  input [31:0] pc_in, 
  input clk, 
  input rst, 
  output reg [31:0] pc_out
);
	
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      pc_out = 0;
    end
    else begin 
      pc_out = pc_in;
    end
  end
endmodule

module InstructionMem (
  input rst,
  input [31:0] addr,
  output [31:0] inst_out
);

  reg [31:0] inst_mem [0:31];

  assign inst_out = inst_mem[addr];

  initial begin
		inst_mem[0] <= 32'h00210820; // 0 add r1,r1,r1    r1=4
		inst_mem[1] <= 32'h00210820; // 4 add r1,r1,r1    r1=8
		inst_mem[2] <= 32'h00210820; // 8 add r1,r1,r1    r1=16
		inst_mem[3] <= 32'h00210820; // 12 add r1,r1,r1   r1=32
		inst_mem[4] <= 32'h8c010000; // 16 lw r1,0(r0)    r1=10
		inst_mem[5] <= 32'h00210820; // 20 add r1,r1,r1   r1=20
		inst_mem[6] <= 32'hac010000; // 24 sw r1,0(r0)    m[0]=20
		inst_mem[7] <= 32'h20010001; // 28 addi r1,r0,1   r1=1
		inst_mem[8] <= 32'h00210820; // 32 add r1,r1,r1   r1=2 
		inst_mem[9] <= 32'h01e1102a; // 36 slt r2, r15, r1 r2 = ( r15 < r1) = 0
		inst_mem[10] <= 32'h1040fffd; // 40 beq r2,r0, -3  pc = 44-4*3= 32 
  end

endmodule
//----------------------------------------------------
// DECODE --------------------------------------------

module decode (
  input [31:0] inst,
  input clk,
  input [31:0] writedata,
  output [31:0] data1, 
  output alusrc,
  output [1:0] aluop,
  output [31:0] data2,
  output memread,
  output memwrite,
  output memtoreg,
  output branch
);
  
  wire branch;
  wire memread;
  wire memtoreg;
  wire [1:0] aluop; 
  wire MemWrite;
  wire regdst;
  wire alusrc;
  wire regwrite;
  wire [4:0] muxRegDst;
  wire [31:0] data2_out;

  assign muxRegDst = (regdst) ?  inst[15:11] : inst[20:16];

  ControlUnit control (
    .opcode(inst[31:26]), 
    .regdst(regdst), 
    .alusrc(alusrc), 
    .memtoreg(memtoreg), 
    .regwrite(regwrite), 
    .memread(memread),
    .memwrite(memwrite), 
    .branch(branch), 
    .aluop(aluop)
  );
  
  Register_Bank Registers (
    .clk(clk),
    .read1(inst[25:21]),
    .read2(inst[20:16]),
    .writereg(muxRegDst),
    .writedata(writedata),
    .regwrite(regwrite),
    .data1(data1),
    .data2(data2)
  );
endmodule

module ControlUnit (
  input [5:0] opcode,
  output regdst, 
  output alusrc, 
  output memtoreg, 
  output regwrite, 
  output memread, 
  output memwrite, 
  output branch, 
  output [1:0] aluop
);

  reg [1:0] aluop;
  reg regdst, alusrc, memtoreg, regwrite, memread, memwrite, branch;

  always @(opcode) begin
    case(opcode) 
      6'd0: begin // R type
        regdst <= 1 ;
        alusrc <= 0 ;
        memtoreg <= 0 ;
        regwrite <= 1 ;
        memread <= 0 ;
        memwrite <= 0 ;
        branch <= 0 ;
        aluop <= 2 ;
			end
			6'd4: begin // beq
        regdst <= 0 ;
        alusrc <= 0 ;
        memtoreg <= 0 ;
        regwrite <= 0 ;
        memread <= 0 ;
        memwrite <= 0 ;
        branch <= 1 ;
        aluop <= 1 ;
			end
			6'd8: begin // addi
        regdst <= 0 ;
        alusrc <= 1 ;
        memtoreg <= 0 ;
        regwrite <= 1 ;
        memread <= 0 ;
        memwrite <= 0 ;
        branch <= 0 ;
        aluop <= 0 ;
      end
			6'd35: begin // lw
        regdst <= 0 ;
        alusrc <= 1 ;
        memtoreg <= 1 ;
        regwrite <= 1 ;
        memread <= 1 ;
        memwrite <= 0 ;
        branch <= 0 ;
        aluop <= 0 ;
      end
			6'd43: begin // sw
        regdst <= 0 ;
        alusrc <= 1 ;
        memtoreg <= 0 ;
        regwrite <= 0 ;
        memread <= 0 ;
        memwrite <= 1 ;
        branch <= 0 ;
        aluop <= 0 ;
      end
			default: begin //nop
        regdst <= 0 ;
        alusrc <= 0 ;
        memtoreg <= 0 ;
        regwrite <= 0 ;
        memread <= 0 ;
        memwrite <= 0 ;
        branch <= 0 ;
        aluop <= 0 ;
      end
    endcase
  end

endmodule 

module Register_Bank (
	input clk,
	input [4:0] read1,
	input [4:0] read2,
	input [4:0] writereg,
	input [31:0] writedata,
	input regwrite,
	output [31:0] data1,
	output [31:0] data2
);

  reg [31:0] memory [0:31]; // 32 registers de 32 bits cada

  initial begin 
    memory[0] <= 0; 
    memory[1] <= 2; 
    memory[2] <= 4; 
    memory[3] <= 6; 
    memory[4] <= 8;
    memory[5] <= 10; 
    memory[6] <= 12; 
    memory[7] <= 14; 
    memory[8] <= 16; 
    memory[9] <= 18;
    memory[10] <= 20; 
    memory[11] <= 22; 
    memory[12] <= 24; 
    memory[13] <= 26; 
    memory[14] <= 28;
    memory[15] <= 30; 
    memory[16] <= 32; 
    memory[17] <= 34; 
    memory[18] <= 36; 
    memory[19] <= 38;
    memory[20] <= 40; 
    memory[21] <= 42; 
    memory[22] <= 44; 
    memory[23] <= 46; 
    memory[24] <= 48;
    memory[25] <= 50; 
    memory[26] <= 52; 
    memory[27] <= 54; 
    memory[28] <= 56; 
    memory[29] <= 58;
    memory[30] <= 60; 
    memory[31] <= 62;
  end

  assign data1 = memory[read1]; 
  assign data2 = memory[read2];
	
  always @(posedge clk) begin
    //if (regwrite) begin
      memory[writereg] <= (regwrite) ? writedata :  memory[writereg];
    //end
  end
  
endmodule

// EXECUTE STAGE -------------------------------------
module execute (
  input [31:0] inst,
  input [31:0] in1,
  input alusrc, 
  input [1:0] aluop,
  input [31:0] in2,
  output zero,
  output [31:0] aluout
);

  wire [31:0] signalextended;
  wire [31:0] alu_B;
  wire [3:0] aluctrl;

  assign signalextended = (inst[15]) ? {16'hFFFF,inst[15:0]} : {16'd0,inst[15:0]};
  assign alu_B = (alusrc) ? signalextended : in2 ;

  //Unidade Lógico Aritimética
  ALU alu (
    .alucontrol(aluctrl),
    .A(in1),
    .B(alu_B), 
    .aluout(aluout), 
    .zero(zero)
  );

  alucontrol alucontrol (
    .aluop(aluop),
    .funct(inst[5:0]),
    .alucontrol(aluctrl)
  );

endmodule

module alucontrol (
  input [1:0] aluop,
  input [5:0] funct,
  output [3:0] alucontrol
);

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

module ALU(
  input [3:0] alucontrol,
  input [31:0] A,
  input [31:0] B,
  output [31:0] aluout,
  output zero
);

  reg [31:0] aluout;
  
  assign zero = (aluout == 0); // Zero recebe um valor lógico caso aluout seja igual a zero.
  
  always @(alucontrol, A, B) begin
      case (alucontrol)//verifica qual o valor do controle para determinar o que fazer com a saída
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

// MEMORY STAGE ----------------------------------------
module memory (
  input [31:0] addr,
  input [31:0] writedata,
  input memread,
  input memwrite,
  input clk, 
  output [31:0] readdata
);

  reg [31:0] memory [0:127]; 

  assign readdata = (memread) ? memory[addr] : 0;

  always @(posedge clk) begin
      memory[addr] <= (memwrite) ? writedata : memory[addr];
	end
endmodule

// WRITE-BACK -----------------------------------
module writeback (
  input [31:0] aluout, 
  input memtoreg,
  input [31:0] readdata, 
  output [31:0] write_data
);
  assign write_data = (memtoreg) ? readdata : aluout;
endmodule

// TOP -------------------------------------------
module mips (
  input clk,
  input rst, 
  output [31:0] res4
);
  
  wire [31:0] inst;
  wire [31:0] res_data1;
  wire [31:0] res_data2;
  wire [31:0] res;
  wire [31:0] res2;
  wire zero;
  wire memread;
  wire memwrite;
  wire memtoreg;
  wire branch;
  wire alusrc;
  wire [1:0] aluop;
  
  // FETCH STAGE
  fetch fetch (
    .clk(clk), 
    .rst(rst),
    .branch(branch), 
    .zero(zero),
    .inst(inst)
  );
  
  // DECODE STAGE
  decode decode (
    .inst(inst), 
    .writedata(res4),
    .clk(clk), 
    .data1(res_data1), 
    .data2(res_data2),
    .memread(memread),
    .memwrite(memwrite),
    .aluop(aluop),
    .memtoreg(memtoreg),
    .branch(branch),
    .alusrc(alusrc)
  );
  
  // EXECUTE STAGE
  execute execute (
    .in1(res_data1), 
    .in2(res_data2),
    .inst(inst),
    .alusrc(alusrc),
    .aluop(aluop),
    .aluout(res),
    .zero(zero)
  );

  // MEMORY STAGE
  memory memory (
    .memread(memread),
    .memwrite(memwrite),
    .addr(res), 
    .writedata(res_data2),
    .clk(clk),
    .readdata(res2)
  );

  // WRITEBACK STAGE
  writeback writeback (
    .memtoreg(memtoreg),
    .readdata(res2), 
    .aluout(res), 
    .write_data(res4)
  );
  
endmodule
