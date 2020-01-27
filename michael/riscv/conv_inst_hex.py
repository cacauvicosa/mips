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

    op = inst[0].lower()
    if (op == "lw"):
        pass
    elif (op == "addi"):
        rd = bin(int(inst[1]))[2:].zfill(5)
        rs1 = bin(int(inst[2]))[2:].zfill(5)
        if (int(inst[3]) < 0): # doing complement 2
            imm = Bits(int=int(inst[3]), length=12).bin
        else: 
            imm = bin(int(inst[3]))[2:].zfill(12)
        binary = "%s%s000%s0010011" % (imm,rs1,rd)

    print_out(binary)