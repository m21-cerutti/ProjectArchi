#/* $begin seq-all-hcl */
#/* $begin seq-plus-all-hcl */
####################################################################
#  HCL Description of Control for Single Cycle Y86 Processor SEQ   #
#  Copyright (C) Randal E. Bryant, David R. O'Hallaron, 2002       #
####################################################################

####################################################################
#    C Include's.  Don't alter these                               #
####################################################################

quote '#include <stdio.h>'
quote '#include "isa.h"'
quote '#include "sim.h"'
quote 'int sim_main(int argc, char *argv[]);'
quote 'int gen_pc(){return 0;}'
quote 'int main(int argc, char *argv[])'
quote '  {plusmode=0;return sim_main(argc,argv);}'

####################################################################
#    Declarations.  Do not change/remove/delete any of these       #
####################################################################

##### Symbolic representation of Y86 Instruction Codes #############
intsig NOP 	'I_NOP'
intsig HALT	'I_HALT'
intsig RRMOVL	'I_RRMOVL'
intsig IRMOVL	'I_IRMOVL'
intsig RMMOVL	'I_RMMOVL'
intsig MRMOVL	'I_MRMOVL'
intsig OPL	'I_ALU'
intsig IOPL	'I_ALUI'
intsig JXX	'I_JXX'
intsig CALL	'I_CALL'
intsig RET	'I_RET'
intsig PUSHL	'I_PUSHL'
intsig POPL	'I_POPL'
intsig JMEM	'I_JMEM'
intsig JREG	'I_JREG'
intsig LOOP	'I_LOOP'
intsig LEAVE	'I_LEAVE'

##### Symbolic representation of Y86 Registers referenced explicitly #####
intsig RESP     'REG_ESP'    	# Stack Pointer
intsig REBP     'REG_EBP'    	# Frame Pointer
intsig RECX    	'REG_ECX'    	# For loop
intsig RNONE    'REG_NONE'   	# Special value indicating "no register"

##### ALU Functions referenced explicitly                            #####
intsig ALUADD	'A_ADD'		# ALU should add its arguments

##### Signals that can be referenced by control logic ####################

##### Fetch stage inputs		#####
intsig pc 'pc'				# Program counter
##### Fetch stage computations		#####
intsig icode	'icode'			# Instruction control code
intsig ifun	'ifun'			# Instruction function
intsig rA	'ra'			# rA field from instruction
intsig rB	'rb'			# rB field from instruction
intsig valC	'valc'			# Constant from instruction
intsig valP	'valp'			# Address of following instruction

##### Decode stage computations		#####
intsig valA	'vala'			# Value from register A port
intsig valB	'valb'			# Value from register B port

##### Execute stage computations	#####
intsig valE	'vale'			# Value computed by ALU
boolsig Bch	'bcond'			# Branch test

##### Memory stage computations		#####
intsig valM	'valm'			# Value read from memory


####################################################################
#    Control Signal Definitions.                                   #
####################################################################

################ Fetch Stage     ###################################

# Does fetched instruction require a regid byte?
bool need_regids =
	icode in { RRMOVL, OPL, IOPL, IRMOVL, RMMOVL, MRMOVL, JREG, JMEM } || (icode == PUSHL && (ifun == 0 || ifun == 1));

# Does fetched instruction require a constant word?
bool need_valC =
	icode in { IRMOVL, RMMOVL, MRMOVL, JXX, IOPL, LOOP, JMEM} || (icode == CALL && ifun == 2);

bool instr_valid = icode in 
	{ NOP, HALT, RRMOVL, IRMOVL, RMMOVL, MRMOVL,
	       OPL, IOPL, JXX, CALL, RET, PUSHL, POPL, LOOP, JREG, JMEM };

################ Decode Stage    ###################################

## What register should be used as the A source?
int srcA = [
	icode in { RRMOVL, OPL, JREG } || (icode == PUSHL && ifun == 0) || (icode == RMMOVL && ifun == 0 ) : rA;
	icode == JMEM : rB;
	icode == PUSHL && (ifun == 1 || ifun == 3) : RESP;
	1 : RNONE; # Don't need register
];

## What register should be used as the B source?
int srcB = [
	icode in { OPL, IOPL, RMMOVL, MRMOVL } : rB;
	icode in { PUSHL, POPL, CALL, RET } : RESP;
	icode in { LOOP} : RECX;
	1 : RNONE;  # Don't need register
];

## What register should be used as the E destination?
int dstE = [
	icode in { RRMOVL, IRMOVL, OPL, IOPL } : rB;
	icode in { PUSHL, POPL, CALL, RET} : RESP;
	icode in { LOOP } : RECX;
	icode == JREG : rA;
	1 : RNONE;  # Don't need register
];

## What register should be used as the M destination?
int dstM = [
	(icode == MRMOVL && ifun == 1) || (icode == POPL && ifun == 1) : rA;
	1 : RNONE;  # Don't need register
];

################ Execute Stage   ###################################

## Select input A to ALU
int aluA = [
	icode in { RRMOVL, OPL, JREG, JMEM} : valA;
	icode in { IRMOVL, RMMOVL, MRMOVL, IOPL } : valC;
	icode == PUSHL && (ifun == 0 || ifun == 2) : -4;
	icode == PUSHL && (ifun == 1 || ifun == 3) : 4;
	icode in { LOOP } : -1;
	# Other instructions don't need ALU
];

## Select input B to ALU
int aluB = [
	icode in { RMMOVL, MRMOVL, OPL, IOPL, CALL, PUSHL, RET, POPL, LOOP } : valB;
	icode in { RRMOVL, IRMOVL, JREG } : 0;
	icode == JMEM : valC;
	# Other instructions don't need ALU
];

## Set the ALU function
int alufun = [
	icode in { OPL, IOPL } : ifun;
	1 : ALUADD;
];

## Should the condition codes be updated?
bool set_cc = icode in { OPL, IOPL };

################ Memory Stage    ###################################

## Set read control signal
bool mem_read = (icode == PUSHL && (ifun == 1 || ifun == 3)) || (icode == MRMOVL && ifun == 1 || icode==JMEM);

## Set write control signal
bool mem_write = (icode == PUSHL && (ifun == 0 || ifun == 2)) || (icode == RMMOVL && ifun == 0);
 
## Select memory address
int mem_addr = [
	icode in { RMMOVL, MRMOVL, JMEM } || (icode == PUSHL && (ifun == 0 || ifun == 2)) : valE;
	icode == PUSHL && (ifun == 1 || ifun == 3) : valA;
	# Other instructions don't need address
];

## Select memory input data
int mem_data = [
	# Value from register
	(icode == PUSHL && ifun == 0) || (icode == RMMOVL && ifun == 0) : valA;
	# Return PC
	icode == PUSHL && ifun == 2 : valP;
	# Default: Don't write anything
];

################ Program Counter Update ############################

## What address should instruction be fetched at

int new_pc = [
	# Call.  Use instruction constant
	icode == CALL && ifun == 2 : valC;
	# Taken branch.  Use instruction constant
	icode == JXX && Bch : valC;
	icode == JREG : valE;
	icode == JMEM : valM;
	# Completion of RET instruction.  Use value from stack
	icode == RET && ifun == 3 : valM;
	icode == LOOP && valE !=0 : valC;
	# Default: Use incremented PC
	1 : valP;
];
#/* $end seq-plus-all-hcl */
#/* $end seq-all-hcl */
