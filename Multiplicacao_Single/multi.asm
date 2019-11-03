# codigo para multiplica
# m[gp] = m[gp+4] * m[gp+8] = t2 * t3 = (t2 + t2 + ...) t3 vezes....

add $t1,$zero,$zero # t1 resultado = 0
lw $t2,4($gp) # t2 = m[gp+4]
lw $t3,8($gp) # t3 = m[gp+8]
loop: add $t1,$t1,$t2 # m = t2+....
addi $t3,$t3,-1 # t3 --
beq $t3,$zero,fim # $t3 == 0
beq $zero,$zero, loop # soma mais um termo
fim: sw $t1,0($gp) # grava resultado

