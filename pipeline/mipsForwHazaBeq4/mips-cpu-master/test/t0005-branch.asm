Lw  r3, 8 (r1) ; r3 ← B
Lw r4, 8(r1);  r4 = s ← B
Lw r2,0(r1);   r2 ← A
Subi r2,r2,1; A ← A -1
LOOP :  Beq r2,r0,FIM  if A = 0 pula FIM
              Add r4,r4,r3;   s ← s + B
		   Subi r2,r2,1;    A ← A -1 
              Jal LOOP
FIM  sw r4,16(r1) ;   C ← r4 = multiplicação

#
# t4 = t3 * t2 = (t3 + t3 + t3 ....+ t3) 
#                      t2 times
addi $t2,$zero, 3
addi $t3,$zero, 4
addi $t4,$t3, 0

#
# t0005-branch.asm
#
# Perform branches (beq, bne) which would create hazards
# and see if they are handled correctly.
#

# initial values
addi $t0, $zero, 1
addi $t1, $zero, 2

# increment $t0 so it equals $t1
addi $t0, $t0, 1

beq $t0, $t1, skip1

# these shouldn't get added
#  If they do, the third hex digit will be 1
addi $t0, $t0, 256
addi $t1, $t1, 256

skip1:

add $t0, $t0, $t1  # 2 + 2 = 4
add $t1, $t0, $t1  # 4 + 2 = 6

bne $t0, $t1, skip2

# these shouldn't get added
#  If they do, the fourth hex digit will be 1
addi $t0, $t0, 4096
addi $t1, $t1, 4096

skip2:

# $t0 = 4, $t1 = 6

# so the values show up in the dump
add $t0, $zero, $t0
add $t1, $zero, $t1
