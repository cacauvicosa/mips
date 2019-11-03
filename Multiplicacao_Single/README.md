# codigo para multiplicar
# m[gp] = m[gp+4] * m[gp+8] = t2 * t3 = (t2 + t2 + ...) t3 vezes....

add $t1,$zero,$zero # t1 resultado = 0
lw $t2,4($gp) # t2 = m[gp+4]
lw $t3,8($gp) # t3 = m[gp+8]
loop: add $t1,$t1,$t2 # m = t2+....
addi $t3,$t3,-1 # t3 --
beq $t3,$zero,fim # $t3 == 0
beq $zero,$zero, loop # soma mais um termo
fim: sw $t1,0($gp) # grava resultado

No Verilog do SingleMips iremos fazer GP=0, como a memoria é de 32 de largura
e incrementa de 4 em 4 bytes, teremos m[0] = m[1] + m[2]

O video apresenta o passo a passo da execução
https://youtu.be/3vwSvSVToHo

Usamos o http://digitaljs.tilk.eu/ para simular
O http://www.kurtm.net/mipsasm/index.cgi para gerar o hexadecimal
O https://www.browserling.com/tools/merge-lists para fazer um merge de colunas 
para incluir o hexadecimal rapidamente no Verilog. O exemplo já esta com o arquivo 
gerado. Você pode elaborar outros exemplos.

