addi $t1,$zero,0 # t1 resultado = 0
lw $t2,4($zero) # t2 = m[4]
lw $t3,8($zero) # t3 = m[8]
nop
nop
nop
loop: add $t1,$t1,$t2 # m = t2+....
addi $t3,$t3,-1 # t3 --
nop
nop
nop
beq $t3,$zero,fim # $t3 == 0
nop
nop
nop
beq $zero,$zero,loop # soma mais um termo
nop
nop
nop
fim: sw $t1,0($zero) # grava resultado
