;; RK - Evalbot (Cortex M3 de Texas Instrument)
; programme - Pilotage 2 Moteurs Evalbot par PWM tout en ASM (Evalbot tourne sur lui même)



		AREA    |.text|, CODE, READONLY
			
;; The IMPORT command specifies that a symbol is defined in a shared object at runtime.
	IMPORT	MOTEUR_INIT					; initialise les moteurs (configure les pwms + GPIO)

	IMPORT	MOTEUR_DROIT_ON				; activer le moteur droit
	IMPORT  MOTEUR_DROIT_OFF			; déactiver le moteur droit
	IMPORT  MOTEUR_DROIT_AVANT			; moteur droit tourne vers l'avant
	IMPORT  MOTEUR_DROIT_ARRIERE		; moteur droit tourne vers l'arrière
	IMPORT  MOTEUR_DROIT_INVERSE		; inverse le sens de rotation du moteur droit

	IMPORT	MOTEUR_GAUCHE_ON			; activer le moteur gauche
	IMPORT  MOTEUR_GAUCHE_OFF			; déactiver le moteur gauche
	IMPORT  MOTEUR_GAUCHE_AVANT			; moteur gauche tourne vers l'avant
	IMPORT  MOTEUR_GAUCHE_ARRIERE		; moteur gauche tourne vers l'arrière
	IMPORT  MOTEUR_GAUCHE_INVERSE		; inverse le sens de rotation du moteur gauche

; This register controls the clock gating logic in normal Run mode
SYSCTL_PERIPH_GPIO EQU		0x400FE108	; SYSCTL_RCGC2_R (p291 datasheet de lm3s9b92.pdf)

; The GPIODATA register is the data register
GPIO_PORTF_BASE		EQU		0x40025000	; GPIO Port F (APB) base: 0x4002.5000 (p416 datasheet de lm3s9B92.pdf)

; The GPIODATA register is the data register
GPIO_PORTD_BASE		EQU		0x40007000		; GPIO Port D (APB) base: 0x4000.7000 (p416 datasheet de lm3s9B92.pdf)

; The GPIODATA register is the data register
GPIO_PORTE_BASE		EQU		0x40024000	; GPIO Port F (APB) base: 0x4002.5000 (p416 datasheet de lm3s9B92.pdf)

; configure the corresponding pin to be an output
; all GPIO pins are inputs by default
GPIO_O_DIR   		EQU 	0x00000400  ; GPIO Direction (p417 datasheet de lm3s9B92.pdf)

; The GPIODR2R register is the 2-mA drive control register
; By default, all GPIO pins have 2-mA drive.
GPIO_O_DR2R   		EQU 	0x00000500  ; GPIO 2-mA Drive Select (p428 datasheet de lm3s9B92.pdf)

; Digital enable register
; To use the pin as a digital input or output, the corresponding GPIODEN bit must be set.
GPIO_O_DEN  		EQU 	0x0000051C  ; GPIO Digital Enable (p437 datasheet de lm3s9B92.pdf)

; Pul_up
GPIO_I_PUR   		EQU 	0x00000510  ; GPIO Pull-Up (p432 datasheet de lm3s9B92.pdf)

; Broches select
BROCHE4_5			EQU		0x30		; led1 & led2 sur broche 4 et 5

BROCHE6				EQU 	0x40		; bouton poussoir 1

BROCHE7				EQU		0x80		; bouton poussoir 2
	
BROCHE6_7			EQU		0xC0		; bouton poussoir 1 et 2

BROCHE0				EQU		0x01		;bumper droit

BROCHE1				EQU		0x02		;bumper gauche
	
BROCHE1_2			EQU		0x03		;bumper droit et gauche

; blinking frequency
DUREE   			EQU     0x002FFFFF
	
		ENTRY
		EXPORT	__main
				
		


__main	

		; ;; Enable the Port F & D peripheral clock 		(p291 datasheet de lm3s9B96.pdf)
		; ;;									
		ldr r6, = SYSCTL_PERIPH_GPIO
		;; RCGC2
        mov r0, #0x00000038  					;; Enable clock sur GPIO D et F où sont branchés les leds (0x28 == 0b101000)
		; ;;														 									      (GPIO::FEDCBA)
        str r0, [r6]
		
		; ;; "There must be a delay of 3 system clocks before any GPIO reg. access  (p413 datasheet de lm3s9B92.pdf)
		nop	   									;; tres tres important....
		nop	   
		nop	   				;; pas necessaire en simu ou en debbug step by step...
		
		
		; Configure les PWM + GPIO
		BL	MOTEUR_INIT	

		;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^CONFIGURATION LED

        ldr r6, = GPIO_PORTF_BASE+GPIO_O_DIR    ;; 1 Pin du portF en sortie (broche 4 : 00010000)
        ldr r0, = BROCHE4_5 	
        str r0, [r6]
		
		ldr r6, = GPIO_PORTF_BASE+GPIO_O_DEN	;; Enable Digital Function 
        ldr r0, = BROCHE4_5		
        str r0, [r6]
		
		ldr r6, = GPIO_PORTF_BASE+GPIO_O_DR2R	;; Choix de l'intensité de sortie (2mA)
        ldr r0, = BROCHE4_5			
        str r0, [r6]
		
		mov r2, #0x000       					;; pour eteindre LED
		
		
		;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^CONFIGURATION bumper droit et gauche

		ldr r7, = GPIO_PORTE_BASE+GPIO_I_PUR	;; Pul_up 
        ldr r0, = BROCHE1_2	
        str r0, [r7]
		
		ldr r7, = GPIO_PORTE_BASE+GPIO_O_DEN	;; Enable Digital Function 
        ldr r0, = BROCHE1_2	
        str r0, [r7]     
		
		
		;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^CONFIGURATION Switcher 1 et 2

		ldr r7, = GPIO_PORTD_BASE+GPIO_I_PUR	;; Pul_up 
        ldr r0, = BROCHE6_7
        str r0, [r7]
		
		ldr r7, = GPIO_PORTD_BASE+GPIO_O_DEN	;; Enable Digital Function 
        ldr r0, = BROCHE6_7	
        str r0, [r7]     
		
		ldr r7, = GPIO_PORTD_BASE + (BROCHE6_7<<2)  ;; @data Register = @base + (mask<<2) ==> Switcher
		

		;phase de mise en grille
		; Activer les deux moteurs droit et gauche

PLACEMENT
		BL MOTEUR_INIT
		BL	MOTEUR_DROIT_ON
		BL	MOTEUR_GAUCHE_ON
		; Evalbot avance droit devant
		BL	MOTEUR_DROIT_AVANT
		BL	MOTEUR_GAUCHE_AVANT
		BL	WAITmg
		
		BL	WAITstart
		
		b	PLACEMENT

		;phase de course
loop	
		mov r3, #0		;; Allume LED1&2 portF broche 4&5 : 00110000		
		ldr r6, = GPIO_PORTF_BASE + (BROCHE4_5<<2)  ;; @data Register = @base + (mask<<2) ==> LED1
		str r3, [r6]		;mov	r3, #0x000
		; Activer les deux moteurs droit et gauche
		BL	MOTEUR_DROIT_ON
		BL	MOTEUR_GAUCHE_ON
		; Evalbot avance droit devant
		BL	MOTEUR_DROIT_AVANT
		BL	MOTEUR_GAUCHE_AVANT
		
		BL	WAIT
		
		b	loop
		
BD_actif
		
		BL	MOTEUR_DROIT_ARRIERE
		BL	MOTEUR_GAUCHE_ARRIERE
		BL	WAITar
		BL	MOTEUR_DROIT_OFF
		BL	MOTEUR_GAUCHE_ARRIERE
		BL	WAITtourne
		b	loop
		
BG_actif
		
		BL	MOTEUR_DROIT_ARRIERE
		BL	MOTEUR_GAUCHE_ARRIERE
		BL	WAITar
		BL	MOTEUR_GAUCHE_OFF
		BL	MOTEUR_DROIT_ARRIERE
		BL	WAITtourne
		b	loop
		
CELEBRATION
		; allumer la led broche 4 et 5 (BROCHE4_5)
		mov r3, #BROCHE4_5		;; Allume LED1&2 portF broche 4&5 : 00110000		
		ldr r6, = GPIO_PORTF_BASE + (BROCHE4_5<<2)  ;; @data Register = @base + (mask<<2) ==> LED1
		str r3, [r6]		;; Allume LED1&2 portF broche 4&5 : 00110000 (contenu de r3)
		BL	MOTEUR_GAUCHE_OFF
		BL	MOTEUR_DROIT_ON
		BL	WAITcelebration
		BL	MOTEUR_GAUCHE_ON
		BL	MOTEUR_DROIT_OFF
		BL	WAITcelebration
		b	CELEBRATION
		
B_actif_depart

		BL	MOTEUR_GAUCHE_OFF
		BL	MOTEUR_DROIT_OFF
		
		b	WAITstart

SW1_actif
		
		BL	MOTEUR_DROIT_OFF
		BL	MOTEUR_GAUCHE_OFF
		BL	WAIToff
		b	SW1_actif
		
SW2_actif
		ldr	r1, =0xFAAAAA
		; allumer la led broche 4 et 5 (BROCHE4_5)
		mov r3, #BROCHE4_5		;; Allume LED1&2 portF broche 4&5 : 00110000		
		ldr r6, = GPIO_PORTF_BASE + (BROCHE4_5<<2)  ;; @data Register = @base + (mask<<2) ==> LED1
		str r3, [r6]		;; Allume LED1&2 portF broche 4&5 : 00110000 (contenu de r3)
wait4	
		subs r1, #1
        bne wait4
		b	loop
		
		;; Boucle d'attente pour la celebration
WAITcelebration
		ldr	r1, =0x1CFFFF
wait6	
		ldr r7, = GPIO_PORTD_BASE + (BROCHE6<<2)
		ldr r10,[r7]
		CMP r10,#0x00
		BEQ	loop
		
		subs r1, #1
        bne wait6
		
		;; retour à la suite du lien de branchement
		BX	LR

		;; Boucle d'attente pour la mise en grille
WAITmg
		ldr r1, =0xAFFFFF 
wait5	
		ldr r7, = GPIO_PORTE_BASE + (BROCHE0<<2)
		ldr r10,[r7]
		CMP r10,#0x00
		BEQ B_actif_depart
		
		ldr r7, = GPIO_PORTE_BASE + (BROCHE1<<2)
		ldr r10,[r7]
		CMP r10,#0x00
		BEQ B_actif_depart

		subs r1, #1
        bne wait5
		b	PLACEMENT
		
		;; Boucle d'attente pour le départ
WAITstart
		ldr r1, =0xAFFFFF 
wait	
		ldr r7, = GPIO_PORTD_BASE + (BROCHE7<<2)
		ldr r10,[r7]
		CMP r10,#0x00
		BEQ SW2_actif

		subs r1, #1
        bne wait
		b	WAITstart
		
		;; Boucle d'attente pour la marche avant
WAIT	ldr r1, =0xFFFFFF 
wait1	
		ldr r7, = GPIO_PORTE_BASE + (BROCHE0<<2)
		ldr r10,[r7]
		CMP r10,#0x00
		BEQ BD_actif
		
		ldr r7, = GPIO_PORTE_BASE + (BROCHE1<<2)
		ldr r10,[r7]
		CMP r10,#0x00
		BEQ BG_actif
		
		ldr r7, = GPIO_PORTD_BASE + (BROCHE6<<2)
		ldr r10,[r7]
		CMP r10,#0x00
		BEQ SW1_actif
		
		ldr r7, = GPIO_PORTD_BASE + (BROCHE7<<2)
		ldr r10,[r7]
		CMP r10,#0x00
		BEQ CELEBRATION

		subs r1, #1
        bne wait1
		
		;; retour à la suite du lien de branchement
		BX	LR
		
;; Boucle d'attente lors la marche arrière
WAITar	ldr r1, =0x0A0FFF
wait2	
		; allumer la led broche 4 et 5 (BROCHE4_5)
		mov r3, #BROCHE4_5		;; Allume LED1&2 portF broche 4&5 : 00110000		
		ldr r6, = GPIO_PORTF_BASE + (BROCHE4_5<<2)  ;; @data Register = @base + (mask<<2) ==> LED1
		str r3, [r6]		;; Allume LED1&2 portF broche 4&5 : 00110000 (contenu de r3)
		
		subs r1, #1
        bne wait2
		
		;; retour à la suite du lien de branchement
		BX	LR

			
;; Boucle d'attente lors la marche arrière
WAITtourne	
		ldr r1, =0x38FFFF
wait3	
		subs r1, #1
        bne wait3
		
		;; retour à la suite du lien de branchement
		BX	LR
		
WAIToff		
		ldr r7, = GPIO_PORTD_BASE + (BROCHE6<<2)
		ldr r10,[r7]
		CMP r10,#0x00
		BEQ	loop
		
		;; retour à la suite du lien de branchement
		BX	LR

		NOP
        END