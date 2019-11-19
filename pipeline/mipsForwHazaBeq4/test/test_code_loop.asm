
#
# t4 = t3 * t2 = (t3 + t3 + t3 ....+ t3) 
#                      t2 times
#
#
#
# mips-linux-gnu-as -O0 -mips32 -o test_code_loop.elf test_code_loop.asm
# mips-linux-gnu-objcopy  -O binary --only-section=.text test_code_loop.elf test_code_loop.text
# bin2hex test_code_loop.asm test_code_loop.hex

addi $t2,$zero, 3
addi $t3,$zero, 4
addi $t4,$t3, 0
addi $t2,$t2, -1
loop:
beq $t2,$zero,done
add $t4,$t4,$t3
addi $t2,$t2, -1
beq $t1,$t1, loop
done:
addi $t4,$t4,0


