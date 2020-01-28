from bitstring import Bits

def print_out(binary):
    print("BIN: %d'b%s" %(len(binary),binary))
    hexadecimal = ""
    for i in range(0,len(binary)//4):
        hexadecimal += hex(int(binary[4*i:4*i+4],2))[2:]
    print("HEX: 32'h%s" %hexadecimal)

if __name__ == "__main__":
    
    inst = input("Input intruction: ")
    inst = inst.replace("$t","").replace(",","")
    inst = inst.split(" ")

    opers_type_I = ['addi', 'slti', 'sltiu', 'xori', 'ORI', 'ANDI']

    op = inst[0].lower()
    if (op == "lw"):
        rd = bin(int(inst[1]))[2:].zfill(5)
        rs1 = bin(int(inst[2]))[2:].zfill(5)
        imm = bin(int(inst[3]))[2:].zfill(12)
        binary = "%s%s010%s0000011" % (imm,rs1,rd)
    elif (op == "sw"): # SW rs2, oﬀset(rs1)
        rs2 = bin(int(inst[1]))[2:].zfill(5)
        imm = bin(int(inst[2]))[2:].zfill(12)
        rs1 = bin(int(inst[3]))[2:].zfill(5)
        print(imm)
        binary = "%s%s%s010%s0100011" % (imm[0:7],rs2,rs1,imm[7:12])
    elif (op == "addi"):
        rd = bin(int(inst[1]))[2:].zfill(5)
        rs1 = bin(int(inst[2]))[2:].zfill(5)
        if (int(inst[3]) < 0): # doing complement 2
            imm = Bits(int=int(inst[3]), length=12).bin
        else: 
            imm = bin(int(inst[3]))[2:].zfill(12)
        binary = "%s%s000%s0010011" % (imm,rs1,rd)
    elif (op == "add"):
        rd = bin(int(inst[1]))[2:].zfill(5)
        rs1 = bin(int(inst[2]))[2:].zfill(5)
        rs2 = bin(int(inst[3]))[2:].zfill(5)
        binary = "0000000%s%s000%s0110011" % (rs2,rs1,rd)
    elif (op == "sub"):
        rd = bin(int(inst[1]))[2:].zfill(5)
        rs1 = bin(int(inst[2]))[2:].zfill(5)
        rs2 = bin(int(inst[3]))[2:].zfill(5)
        binary = "0100000%s%s000%s0110011" % (rs2,rs1,rd)

    print_out(binary)