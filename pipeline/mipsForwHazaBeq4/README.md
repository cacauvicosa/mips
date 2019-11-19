MIPS Pipeline em Verilog com Unidade de Hazard para Load, unidade de Forwarding e BEQ no 4 estágio.
Código desenvolvido por https://github.com/jmahler/mips-cpu.

Documentação com explicações disponíveis em 
https://docs.google.com/presentation/d/e/2PACX-1vTl4fxlJFZXNVaToEmzhHt1Svg1sREU4JHDny7Wepr2bVTlaYBXCy-6LSoPnJ9XyDiuTcDxk25-rXFO/pub?start=false&loop=false&delayms=3000

Compilar com 

iverilog cpu.v tb.v

Os arquivos im_data, dm_data e rm_data tem a memória de instruções, de dados e banco de registradores inicial.
Através de um comando monitor, os sinais mais importantes dos 5 estágios do pipeline são mostrados ciclo a ciclo. 

A versão cpu_p4_4.v tem uma unidade de Forward para BEQ que foi adaptado para executar no segundo estágio.

