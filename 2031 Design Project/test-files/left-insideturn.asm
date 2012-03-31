	;; Inside turn state
lIT:	CALL		INITP
lITlp:	LOAD		ONE
	OUT		LCD
	LOAD		IT_OS		;Set the wheel speeds
	OUT		RVELCMD
	LOAD		IT_IS
	OUT		LVELCMD
	IN		LPOSLOW		;Get the new positions
	SHIFT		&B11000		;and shift (recall if fifth
	STORE		LP		;bit is 0 then left shift, v-v)
	IN		LPOSHIGH
	SHIFT		&B01000
	OR		LP
	STORE		LP		
	IN		RPOSLOW		;Right wheel
	SHIFT		&B11000
	STORE		RP
	IN		RPOSHIGH
	SHIFT		&B01000
	OR		RP		
	SUB		RP_0		;See if have travelled enough to
	ADD		LP		;stop turning. Recall that RP is
	SUB		LP_0		;actually neg. if right wheel has
	SUB		NTY		;moved forward.
	OUT		SEVENSEG2
	;; do some LED stuff
	JNEG		lITlp
	JUMP		lFORW
	
		
		

