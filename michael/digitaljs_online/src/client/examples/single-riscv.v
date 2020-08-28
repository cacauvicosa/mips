module fetch (input zero, rst, clk, branch, input [31:0] sigext, output [31:0] inst);
  
  wire [31:0] pc, pc_4, new_pc;

  assign pc_4 = 4 + pc; // pc+4  Adder
  assign new_pc = (branch & zero) ? pc_4 + sigext : pc_4; // new PC Mux

  PC program_counter(new_pc, clk, rst, pc);

  reg [31:0] inst_mem [0:31];

  assign inst = inst_mem[pc[31:2]];

  initial begin
    // Exemplos
    inst_mem[0] <= 32'h00000000; // nop
    inst_mem[1] <= 32'h00500113; // addi x2, x0, 5  ok
    inst_mem[2] <= 32'h00210233; // add  x4, x2, x2  ok
    //inst_mem[1] <= 32'h00202223; // sw x2, 8(x0) ok
    //inst_mem[1] <= 32'h0050a423; // sw x5, 8(x1) ok
    //inst_mem[2] <= 32'h0000a003; // lw x1, x0(0) ok
    //inst_mem[1] <= 32'hfff00113; // addi x2,x0,-1 ok
    //inst_mem[2] <= 32'h00318133; // add x2, x3, x3 ok
    //inst_mem[3] <= 32'h40328133; // sub x2, x5, x3 ok
  end
  
endmodule

module PC (input [31:0] pc_in, input clk, rst, output reg [31:0] pc_out);

  always @(posedge clk) begin
    pc_out <= pc_in;
    if (~rst)
      pc_out <= 0;
  end

endmodule

module decode (input [31:0] inst, writedata, input clk, output [31:0] data1, data2, ImmGen, output alusrc, memread, memwrite, memtoreg, branch, output [1:0] aluop, output [9:0] funct);
  
  wire branch, memread, memtoreg, MemWrite, alusrc, regwrite;
  wire [1:0] aluop; 
  wire [4:0] writereg, rs1, rs2, rd;
  wire [6:0] opcode;
  wire [9:0] funct;
  wire [31:0] ImmGen;

  assign opcode = inst[6:0];
  assign rs1    = inst[19:15];
  assign rs2    = inst[24:20];
  assign rd     = inst[11:7];
  assign funct = {inst[31:25],inst[14:12]};

  ControlUnit control (opcode, inst, alusrc, memtoreg, regwrite, memread, memwrite, branch, aluop, ImmGen);
  
  Register_Bank Registers (clk, regwrite, rs1, rs2, rd, writedata, data1, data2); 

endmodule

module ControlUnit (input [6:0] opcode, input [31:0] inst, output reg alusrc, memtoreg, regwrite, memread, memwrite, branch, output reg [1:0] aluop, output reg [31:0] ImmGen);

  always @(opcode) begin
    alusrc   <= 0;
    memtoreg <= 0;
    regwrite <= 0;
    memread  <= 0;
    memwrite <= 0;
    branch   <= 0;
    aluop    <= 0;
    ImmGen   <= 0; 
    case(opcode) 
      7'b0110011: begin // R type == 51
        regwrite <= 1;
        aluop    <= 2;
			end
		  7'b1100011: begin // beq == 99
        branch   <= 1;
        aluop    <= 1;
        ImmGen   <= {{19{inst[31]}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};
			end
			7'b0010011: begin // addi == 19
        alusrc   <= 1;
        regwrite <= 1;
        ImmGen   <= {{20{inst[31]}},inst[31:20]};
      end
			7'b0000011: begin // lw == 3
        alusrc   <= 1;
        memtoreg <= 1;
        regwrite <= 1;
        memread  <= 1;
        ImmGen   <= {{20{inst[31]}},inst[31:20]};
      end
			7'b0100011: begin // sw == 35
        alusrc   <= 1;
        memwrite <= 1;
        ImmGen   <= {{20{inst[31]}},inst[31:25],inst[11:7]};
      end
    endcase
  end

endmodule 

module Register_Bank (input clk, regwrite, input [4:0] read_reg1, read_reg2, writereg, input [31:0] writedata, output [31:0] read_data1, read_data2);

  integer i;
  reg [31:0] memory [0:31]; // 32 registers de 32 bits cada

  // fill the memory
  initial begin
    for (i = 0; i <= 31; i++) 
      memory[i] <= i;
  end

  assign read_data1 = (regwrite && read_reg1==writereg) ? writedata : memory[read_reg1];
  assign read_data2 = (regwrite && read_reg2==writereg) ? writedata : memory[read_reg2];
	
  always @(posedge clk) begin
    if (regwrite)
      memory[writereg] <= writedata;
  end
  
endmodule

module execute (input [31:0] in1, in2, ImmGen, input alusrc, input [1:0] aluop, input [9:0] funct, output zero, output [31:0] aluout);

  wire [31:0] alu_B;
  wire [3:0] aluctrl;
  
  assign alu_B = (alusrc) ? ImmGen : in2 ;

  //Unidade Lógico Aritimética
  ALU alu (aluctrl, in1, alu_B, aluout, zero);

  alucontrol alucontrol (aluop, funct, aluctrl);

endmodule

module alucontrol (input [1:0] aluop, input [9:0] funct, output reg [3:0] alucontrol);
  
  wire [7:0] funct7;
  wire [2:0] funct3;

  assign funct3 = funct[2:0];
  assign funct7 = funct[9:3];

  always @(aluop) begin
    case (aluop)
      0: alucontrol <= 4'd2; // ADD to SW and LW
      1: alucontrol <= 4'd6; // SUB to branch
      default: begin
        case (funct3)
          0: alucontrol <= (funct7 == 0) ? /*ADD*/ 4'd2 : /*SUB*/ 4'd6; 
          2: alucontrol <= 4'd7; // SLT
          6: alucontrol <= 4'd1; // OR
          //39: alucontrol <= 4'd12; // NOR
          7: alucontrol <= 4'd0; // AND
          default: alucontrol <= 4'd15; // Nop
        endcase
      end
    endcase
  end
endmodule

module ALU (input [3:0] alucontrol, input [31:0] A, B, output reg [31:0] aluout, output zero);
  
  assign zero = (aluout == 0); // Zero recebe um valor lógico caso aluout seja igual a zero.
  
  always @(alucontrol, A, B) begin
      case (alucontrol)
        0: aluout <= A & B; // AND
        1: aluout <= A | B; // OR
        2: aluout <= A + B; // ADD
        6: aluout <= A - B; // SUB
        //7: aluout <= A < B ? 32'd1:32'd0; //SLT
        //12: aluout <= ~(A | B); // NOR
      default: aluout <= 0; //default 0, Nada acontece;
    endcase
  end
endmodule

module memory (input [31:0] address, writedata, input memread, memwrite, clk, output [31:0] readdata);

  integer i;
  reg [31:0] memory [0:127]; 
  
  // fill the memory
  initial begin
    for (i = 0; i <= 127; i++) 
      memory[i] <= i;
  end

  assign readdata = (memread) ? memory[address[31:2]] : 0;

  always @(posedge clk) begin
    if (memwrite)
      memory[address[31:2]] <= writedata;
	end
endmodule

module writeback (input [31:0] aluout, readdata, input memtoreg, output reg [31:0] write_data);
  always @(memtoreg) begin
    write_data <= (memtoreg) ? readdata : aluout;
  end
endmodule

// TOP -------------------------------------------
module mips (input clk, rst, output [31:0] writedata);
  
  wire [31:0] inst, sigext, data1, data2, aluout, readdata;
  wire zero, memread, memwrite, memtoreg, branch, alusrc;
  wire [9:0] funct;
  wire [1:0] aluop;
  
  // FETCH STAGE
  fetch fetch (zero, rst, clk, branch, sigext, inst);
  
  // DECODE STAGE
  decode decode (inst, writedata, clk, data1, data2, sigext, alusrc, memread, memwrite, memtoreg, branch, aluop, funct);   
  
  // EXECUTE STAGE
  execute execute (data1, data2, sigext, alusrc, aluop, funct, zero, aluout);

  // MEMORY STAGE
  memory memory (aluout, data2, memread, memwrite, clk, readdata);

  // WRITEBACK STAGE
  writeback writeback (aluout, readdata, memtoreg, writedata);

endmodule
