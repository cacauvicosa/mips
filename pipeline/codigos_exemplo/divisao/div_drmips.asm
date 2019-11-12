li $t4,0
lw $t3,8($zero)
lw $t2,0($zero)
# Divisao t3/t2
loop: sub $t3,$t3,$t2 # t3 = t3 - t2
sgt $t5,$t3,$zero # t5 = 1, se t3 for negativo e acabou a divisao
beq $t5,$zero, fim # t5 <> 0 ?
addi $t4,$t4,1 # t4 = divisao = t4++
beq $zero,$zero, loop # subtrai mais uma vez t2 de t3...até t3  ficar 0 ou negativo
fim: sw $t4,4($gp)
