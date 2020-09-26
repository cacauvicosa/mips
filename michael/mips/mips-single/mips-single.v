module PC (input [31:0] pc_in, input clk, rst, output reg [31:0] pc_out);

  always @(posedge clk) begin
    pc_out <= pc_in;
    if (~rst)
      pc_out <= 0;
  end

endmodule

//----------------------------------------------------
/* DECODE --------------------------------------------
                                                              writedata
       +---------------------------------------------------------|----------------+
       |                               [25:21]                   |                |
       |                            +--------------------+       |                |
       |                            |        +-------+   |       |                |
       |                            |        |       |   |       v                |
       | +--------------------------+ [20:16]| +---+ |   |    +--+---------+      |
       | |                          +--------->+ M | |   |    |            |      |
       | |        +-------------+   | [15:11]  | U | |   +--->+            |      |
       | |        |             |   +--------->+ X | |        |            +--------> data1
       | | 31:26] |             |              +-+-+ +------->+  register  |      |
inst +------------+   control   |                ^            |            |      |
       | |        |             +--- regdst -----+----------->+            +--------> data2
       | |        |             |                             |            |      |
       | |        +-+-+-+-+-+-+-+---regwrite----------------->+------------+      |
       | |          | | | | | |                                                   |
       | |          | | | | | +-----------------------------------------------------> alusrc
       | |          | | | | +-------------------------------------------------------> memread
       | |          | | | +---------------------------------------------------------> memwrite
       | |          | | +-----------------------------------------------------------> memtoreg
       | |          | +-------------------------------------------------------------> branch
       | |          +---------------------------------------------------------------> aluop
       | |                                                                        |
       | |                [15]                                                    |
       | +-------------------------------+                                        |
       | |                               v                                        |
       | |   {16'hFFFF,inst[15:0]}     +---+                                      |
       | +-----------------------------+ A |                                      |
       | |    {16'd0,inst[15:0]}       | N +---------------------------------------> sigext
       | +---------------------------->+ D |                                      |
       +-------------------------------+---+--------------------------------------+--
*/
module decode (input [31:0] inst, writedata, input clk, output [31:0] data1, data2, sigext, output alusrc, memread, memwrite, memtoreg, branch, output [1:0] aluop);
  
  wire branch, memread, memtoreg, MemWrite, regdst, alusrc, regwrite;
  wire [1:0] aluop; 
  wire [4:0] writereg, rs, rt, rd;
  wire [5:0] opcode;

  assign sigext = (inst[15]) ? {16'hFFFF,inst[15:0]} : {16'd0,inst[15:0]};
  assign opcode = inst[31:26];
  assign rs = inst[25:21];
  assign rt = inst[20:16];
  assign rd = inst[15:11];
  
  ControlUnit control (opcode, regdst, alusrc, memtoreg, regwrite, memread, memwrite, branch, aluop);

  assign writereg = (regdst) ? rd : rt;
  
  Register_Bank Registers (clk, regwrite, rs, rt, writereg, writedata, data1, data2); 

endmodule

module ControlUnit (input [5:0] opcode, output regdst, alusrc, memtoreg, regwrite, memread, memwrite, branch, output [1:0] aluop);

  reg [1:0] aluop;
  reg regdst, alusrc, memtoreg, regwrite, memread, memwrite, branch;

  always @(opcode) begin
    regdst   <= 0;
    alusrc   <= 0;
    memtoreg <= 0;
    regwrite <= 0;
    memread  <= 0;
    memwrite <= 0;
    branch   <= 0;
    aluop    <= 0;
    case(opcode) 
      6'd0: begin // R type
        regdst <= 1 ;
        regwrite <= 1 ;
        aluop <= 2 ;
			end
	  6'd4: begin // beq
        branch <= 1 ;
        aluop <= 1 ;
			end
	  6'd8: begin // addi
        alusrc <= 1 ;
        regwrite <= 1 ;
      end
	  6'd35: begin // lw
        alusrc <= 1 ;
        memtoreg <= 1 ;
        regwrite <= 1 ;
        memread <= 1 ;
      end
	  6'd43: begin // sw
        alusrc <= 1 ;
        memwrite <= 1 ;
      end
    endcase
  end

endmodule 

module Register_Bank (input clk, regwrite, input [4:0] read1, read2, writereg, input [31:0] writedata, output reg [31:0] data1, data2);

  integer i;
  reg [31:0] memory [0:31]; // 32 registers de 32 bits cada

  // fill the memory
  initial begin
    for (i = 0; i <= 31; i++) 
      memory[i] <= i;
  end
  
  //data1 <= (regwrite && read1==writereg) ? writedata : memory[read1];
  //data2 <= (regwrite && read2==writereg) ? writedata : memory[read2];
  
  assign data1 = memory[read1];
  assign data2 = memory[read2];
	
  always @(posedge clk) begin
    
    if (regwrite)
      memory[writereg] <= writedata;
  end
  
endmodule

/* EXECUTE STAGE -------------------------------------
          +-------------------------------------+
in1     +-----------------------+               |
          |                     |               |
alusrc  +--------------+        |               |
          |            v        |               |
          |          +-+-+      |   +---------+ |
in2     +----------->+ M |      +-->+         | |
          |          | U +----+     |         +-----> zero
sigext  +---+------->+ X |    +---->+   ALU   | |
          | |        +---+          |         +-----> aluout
          | |                 +---->+         | |
          | | [5:0] +------+  |     +---------+ |
          | +------>+      |  |                 |
          |         |  ALU +--+                 |
aluop   +---------->+ CTRL |                    |
          |         |      |                    |
          |         +------+                    |
          +-------------------------------------+
*/
module execute (input [31:0] in1, in2, sigext, input alusrc, input [1:0] aluop, output zero, output [31:0] aluout);

  wire [31:0] alu_B;
  wire [3:0] aluctrl;

  assign alu_B = (alusrc) ? sigext : in2 ;

  //Unidade Lógico Aritimética
  ALU alu (aluctrl, in1, alu_B, aluout, zero);

  alucontrol alucontrol (aluop, sigext[5:0], aluctrl);

endmodule

module alucontrol (input [1:0] aluop, input [5:0] funct, output reg [3:0] alucontrol);
   
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

module ALU (input [3:0] alucontrol, input [31:0] A, B, output reg [31:0] aluout, output zero);
  
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

/* MEMORY STAGE ----------------------------------------
                       memread
                         +
              +----------|------------+
              |          v            |
              |  +-------+---------+  |
              |  |                 |  |
 addr     +----->+                 |  |
              |  |     MEMORY      |  |
              |  |                 +---->  readdata
writedata +----->+                 |  |
              |  |                 |  |
              |  +-------+---------+  |
              |          ^            |
              +----------|------------+
                         +
                       memwrite
*/
module memory (input [31:0] addr, writedata, input memread, memwrite, clk, output [31:0] readdata);

  integer i;
  reg [31:0] memory [0:127]; 
  
  // fill the memory
  initial begin
    for (i = 0; i <= 127; i++) 
      memory[i] <= i;
  end

  assign readdata = (memread) ? memory[addr[31:2]] : 0;

  always @(posedge clk) begin
    if (memwrite)
      memory[addr[31:2]] <= writedata;
	end
endmodule

/* WRITE-BACK -----------------------------------
              memtoreg
                +
          +-----|----+
          |     v    |
          |   +-+-+  |
readdata +--->+ M |  |
          |   | U +----> writedata
aluout   +--->+ X |  |
          |   +---+  |
          +----------+
*/

module writeback (input [31:0] aluout, readdata, input memtoreg, output reg [31:0] write_data);
  always @(memtoreg) begin
    write_data <= (memtoreg) ? readdata : aluout;
  end
endmodule

/*--------------------- FETCH -----------------+
       +---------------------------------------+
       |        +---+                          |
  zero +------->+ A |                          |
       |        | N +----------------+         |
branch +------->+ D |                |         |
       |        +---+                |         |
       |               +---+         |         |
sigext +-------------->+ A |         |         |
       |               | D |         v         |
       |      +---+ +->+ D +--+    +-+-+       |
       | 4 +->+ A | |  +---+  +--->+ M |       |
       |      | D | |              | U +----+  |
       |   +->+ D +-+------------->+ X |    |  |
       |   |  +---+                +---+    |  |
       |   |                                |  |
       |   |  +-----------------------------+  |
       |   |  |                                |
       |   |  |  +----+      +----------+      |
       |   |  |  |    |      |          |      |
       |   |  +--+ PC +--+---+   inst   +-----------> inst
       |   |     |    |  |   |   mem    |      |
       |   |     +----+  |   |          |      |
       |   |             |   +----------+      |
       |   +-------------+                     |
       +---------------------------------------+
*/       
module fetch (input zero, rst, clk, branch, input [31:0] sigext, output [31:0] inst);
  
  wire [31:0] pc, pc_4, new_pc;

  assign pc_4 = 4 + pc; // pc+4  Adder
  assign new_pc = (branch & zero) ? pc_4 + sigext : pc_4; // new PC Mux

  PC program_counter(new_pc, clk, rst, pc);

  reg [31:0] inst_mem [0:31];

  assign inst = inst_mem[pc[31:2]];

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
module mips (input clk, rst, output [31:0] writedata);
  
  wire [31:0] inst, sigext, data1, data2, aluout, readdata;
  wire zero, memread, memwrite, memtoreg, branch, alusrc;
  wire [1:0] aluop;
  
  // FETCH STAGE
  fetch fetch (zero, rst, clk, branch, sigext, inst);
  
  // DECODE STAGE
  decode decode (inst, writedata, clk, data1, data2, sigext, alusrc, memread, memwrite, memtoreg, branch, aluop);   
  
  // EXECUTE STAGE
  execute execute (data1, data2, sigext, alusrc, aluop, zero, aluout);

  // MEMORY STAGE
  memory memory (aluout, data2, memread, memwrite, clk, readdata);

  // WRITEBACK STAGE
  writeback writeback (aluout, readdata, memtoreg, writedata);

endmodule
