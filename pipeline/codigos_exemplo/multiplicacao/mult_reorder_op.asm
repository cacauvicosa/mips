lw $t3,8($zero) # t3 = m[8]
addi $t1,$zero,0 # t1 resultado = 0
lw $t2,4($zero) # t2 = m[4]
nop
loop: beq $t3,$zero,fim # $t3 == 0
addi $t3,$t3,-1 # t3 --
add $t1,$t1,$t2 # m = t2+....
nop
beq $zero,$zero,loop # soma mais um termo
fim: sw $t1,0($zero) # grava resultado