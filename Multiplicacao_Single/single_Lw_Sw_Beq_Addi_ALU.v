module mips(
    input clk, output [31:0] pc
	 );
	 //fios diversos
	 wire regwrite,memread,memwrite,branch;
	 wire regdst, alusrc, memtoreg, zero, and_branch; 
	 wire [31:0] pc_4, data1, data2,readData,alu_B,writedata;
	 wire [31:0] instruction, signalextended, aluout, shiftleft2;
	 wire [31:0] add_pc_branch_target, new_pc;
	 wire [4:0] muxRegDst;
	 wire [3:0] aluctrl;
	 wire [1:0] aluop;	 
	
	 PC prog_counter(clk, new_pc, pc); // PC register
	 assign pc_4 = pc+4; // pc+4  Adder
	 InstructionMem instructionmem( pc>>2, instruction); // Instruction Memory	 
	 assign signalextended = (instruction[15]) ? {16'hFFFF,instruction[15:0]}:{16'd0,instruction[15:0]} ;	
         assign shiftleft2 =  signalextended << 2; // Shift 
         assign add_pc_branch_target = pc_4 + shiftleft2;  // Target PC Adder
         assign and_branch = branch & zero; // AND branch and zero ALU output
         assign new_pc = (and_branch) ? add_pc_branch_target : pc_4; // new PC Mux
         ControlUnit uc(instruction[31:26], regdst, alusrc, memtoreg, regwrite, memread,
			 memwrite, branch, aluop);
         assign muxRegDst = (regdst)?  instruction[15:11]:instruction[20:16]; 
	 Register_Bank register_bank( clk,instruction[25:21],instruction[20:16], muxRegDst, writedata, regwrite,  data1, data2);
	 assign alu_B = (alusrc) ? signalextended:data2 ;
	 AluControl alucontrol(aluop, instruction[5:0],aluctrl); //controle da ALU
	 Alu alu(aluctrl, data1, alu_B, aluout, zero); //Unidade Lógico Aritimética
	 DataMem datamem(clk,memread,memwrite,data2, aluout>>2, readData); //Memória de dados
	 assign writedata = (memtoreg) ? readData:aluout ;
endmodule 



module Register_Bank(
	input clk,
	input [4:0] read1,
	input [4:0] read2,
	input [4:0] writereg,
	input [31:0] writedata,
	input regwrite,
	output [31:0] data1,
	output [31:0] data2
	);

   reg [31:0] Registradores [31:0]; // 32 registradores de 32 bits cada
   
   assign data1 = Registradores[read1]; 
   assign data2 = Registradores[read2];
   
   always @(posedge clk ) 
	begin 
	if (regwrite) 
	  begin
	     Registradores[writereg] <= writedata;
	  end
	end
/* 8-15 t0-t7, 28 gp 
http://www.cs.uwm.edu/classes/cs315/Bacon/Lecture/HTML/ch05s03.html
ti=i & gp=0
*/
integer i;
initial begin
    for (i = 8; i <= 15; i++) 
      Registradores[i] <= i-8;
    Registradores[0] <= 0;
    Registradores[28] <= 0; 
  end

endmodule



module PC(
	input clk,
	input [31:0] pc_in,
	output [31:0] pc);  
	reg [31:0] pc;
always @(posedge clk ) 
begin
  if (clk) pc = pc_in;
end    
initial begin
  pc <= 32'd0;
end
endmodule

module ControlUnit(
  input [5:0] opcode, //opcode - sinal de entrada para a UC
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
  
  always @(opcode)
    begin
      case(opcode) 
			6'd0: // R type
			  begin
				 regdst <= 1 ;
				 alusrc <= 0 ;
				 memtoreg <= 0 ;
				 regwrite <= 1 ;
				 memread <= 0 ;
				 memwrite <= 0 ;
				 branch <= 0 ;
			
				 aluop <= 2 ;
			  end
			6'd4: // beq
			  begin
				 regdst <= 0 ;
				 alusrc <= 0 ;
				 memtoreg <= 0 ;
				 regwrite <= 0 ;
				 memread <= 0 ;
				 memwrite <= 0 ;
				 branch <= 1 ;
			
				 aluop <= 1 ;
			  end
			6'd8: // addi
			  begin
				 regdst <= 0 ;
				 alusrc <= 1 ;
				 memtoreg <= 0 ;
				 regwrite <= 1 ;
				 memread <= 0 ;
				 memwrite <= 0 ;
				 branch <= 0 ;
				
				 aluop <= 0 ;
			  end
			6'd35: // lw
			  begin
				 regdst <= 0 ;
				 alusrc <= 1 ;
				 memtoreg <= 1 ;
				 regwrite <= 1 ;
				 memread <= 1 ;
				 memwrite <= 0 ;
				 branch <= 0 ;
			
				 aluop <= 0 ;
			  end
			6'd43: // sw
			  begin
				 regdst <= 0 ;
				 alusrc <= 1 ;
				 memtoreg <= 0 ;
				 regwrite <= 0 ;
				 memread <= 0 ;
				 memwrite <= 1 ;
				 branch <= 0 ;
			
				 aluop <= 0 ;
			  end
			default://nop
			  begin
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

module AluControl(
   input [1:0] aluop,
   input [5:0] funct,
   output [3:0] alucontrol
   );
   
reg [3:0] alucontrol;
   
	
   always @(aluop or funct)
    begin
      case (aluop)
			0: alucontrol <= 4'd2; // ADD para sw e lw
			1: alucontrol <= 4'd6; // SUB para branch
			default:
			  begin
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


module Alu(
   input [3:0] alucontrol,
   input [31:0] A,
	input [31:0] B,
   output [31:0] aluout,
   output zero
	);

   reg [31:0] aluout;
   
   assign zero = (aluout == 0); // Zero recebe um valor lógico caso aluout seja igual a zero.
   
   always @(alucontrol, A, B) //Sempre que alguma das entradas variar...
    begin
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


module DataMem(
   input clk,
   input MemRead,
   input MemWrite,
   input [31:0] writeData,
   input [31:0] address,
   output[31:0] readData
	);
	   
reg [31:0] memory [127:0]; 
   assign 	readData = memory[address];
   always @(posedge clk) 
		begin
 		if (MemWrite) 
			begin
			memory[address] <= writeData;
			end
		end
integer i;
initial begin
    for (i = 0; i <= 127; i++) 
      memory[i] = i;
    end
endmodule


module InstructionMem (
  input [31:0] address, // endereço da instrução
  output [31:0] instruction_out//instrução para execução
  );
  
  reg [31:0] inst_mem[31:0];
  
  assign instruction_out = inst_mem[address];
initial begin 
/*  inst_mem[0] <= 32'h8C810004; // lw  r1,4(r4)
  inst_mem[1] <= 32'h8C820008; // lw  r2,8(r4)
  inst_mem[2] <= 32'h00221820; // add r3,r1,r2
  inst_mem[3] <= 32'hAC83000C; // sw r3,12(r4)
*/
  inst_mem[0] <= 32'h00004820 ;
  inst_mem[1] <= 32'h8f8a0004 ;
  inst_mem[2] <= 32'h8f8b0008 ;
  inst_mem[3] <= 32'h012a4820 ;
  inst_mem[4] <= 32'h216bffff ;
  inst_mem[5] <= 32'h11600001 ;
  inst_mem[6] <= 32'h1000fffc ;
  inst_mem[7] <= 32'haf890000 ;
end
/*
Compile Mars code in http://www.kurtm.net/mipsasm/index.cgi
example: 
add $t1,$zero,$zero # t1 resultado = 0
lw $t2,4($gp) # t2 = m[gp+4]
lw $t3,8($gp) # t3 = m[gp+8]
loop: add $t1,$t1,$t2 # m = t2+....
addi $t3,$t3,-1 # t3 --
beq $t3,$zero,fim # $t3 == 0
beq $zero,$zero, loop # soma mais um termo
fim: sw $t1,0($gp) # grava resultado

lembrando que ti=i & gp=0
hexa

00004820
8f8a0004
8f8b0008
012a4820
216bffff
11600001
1000fffc
af890000

merge columns in https://www.browserling.com/tools/merge-lists
  inst_mem[0] <= 32'h
  inst_mem[1] <= 32'h
  inst_mem[2] <= 32'h
  inst_mem[3] <= 32'h
  inst_mem[4] <= 32'h
  inst_mem[5] <= 32'h
  inst_mem[6] <= 32'h
  inst_mem[7] <= 32'h
  inst_mem[8] <= 32'h
  inst_mem[9] <= 32'h
  inst_mem[10] <= 32'h
  inst_mem[11] <= 32'h
  inst_mem[12] <= 32'h
  inst_mem[13] <= 32'h
  inst_mem[14] <= 32'h
  inst_mem[15] <= 32'h

add ; after
result is
  inst_mem[0] <= 32'h 00004820 ;
  inst_mem[1] <= 32'h 8f8a0004 ;
  inst_mem[2] <= 32'h 8f8b0008 ;
  inst_mem[3] <= 32'h 012a4820 ;
  inst_mem[4] <= 32'h 216bffff ;
  inst_mem[5] <= 32'h 11600001 ;
  inst_mem[6] <= 32'h 1000fffc ;
  inst_mem[7] <= 32'h af890000 ;

*/


endmodule

