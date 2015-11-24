;======================================================================|
; Practica 4, FUNDAMENTOS DE MICROPROCESADORES, ITESO.     |
; AUTORES:                                                             |
;       -ALEJANDRO WALLS        is693215@iteso.mx                      |
;       -MARIO EUGENIO ZU�IGA   ie693110@iteso.mx                      |
;======================================================================|

;P3            Serial
;P2.0 - 2.3    Salida Decoder Teclado
;P2.7          Senal E de LCD
;P2.6          Senal RS de LCD
;P1            Datos LCD

; use command 01 for clearing display
; use command 80 for first line of display
; use command C0 for second line of display

                T2CON EQU 0C8H               ;T2CON registry location
                RCAP2H EQU 0CBH              ;reload value for t2 location high
                RCAP2L EQU 0CAH              ;reload value for t2 location low

                T2H EQU 0CDH                 ;timer 2 value high
                T2L EQU 0CCH                 ;timer 2 value low

                INTERRUPTS EQU 10100101b        ;Interrupt flags, Global, Timer2, Button1, Button0

                TICKCOUNT_1 EQU 3AH             ;Tick counter for refreshing displays
                BUTTON_COUNT EQU 3BH             ;Tick counter for buttons
                SECOND_COUNT EQU 3CH         ;Tick counter for seconds 1
                CHARACTER_COUNT EQU 3DH         ;Tick counter for seconds 2
                DEBOUNCER_COUNT EQU  3EH        ;Counter for debouncer, 20 ms

                REGISTER_SELECT EQU P2.7        ;RS LCD select signal
                RW_ENABLE EQU P2.6              ;read write enable LCD signal
                LCD_DATA EQU P1                 ;LCD data bus

                GREEN_LED EQU P3.6

                KEYPAD_VALUE EQU 30H            ;value of the key pressed

                ;SUBROUTINE PARAMETERS
                ;====================================================================
                SEND_COMMAND_PARAM EQU 31H                                           ;
                SEND_DATA_PARAM EQU 32H                                              ;
                SEND_SERIAL_PARAM EQU 33H
                ;====================================================================
				
				;Table for values:
				;====================================================================
				TABLE_START EQU 34H
                
                ;Flags
                IS_NEXT_LINE EQU 20H.1          ;indicates if the LCD is already on the next line   

                ORG     0000H                   ;RESET INTERRUPT
                JMP     START                   ;go to start on reset

                ORG     0003H                   ;EXT0 INTERRUPT SWITCH BUTTON
                JMP     EXT0IRS

                ORG     0013H                   ;EXT1 INTERRUPT EDIT BUTTON
                ;JMP     EXT1IRS

                ORG     002BH                   ;T2 INTERRUPT
                JMP     T2IRS                   ;Go to interrupt routine

                ORG     0040H
START:          CLR     RW_ENABLE               ;(E) read write enable on 0
                CLR     REGISTER_SELECT         ;(RS) register select on 0
                
                MOV     IE, #INTERRUPTS         ;enable global interrupt, enable timer 2 interrupt, enable ext1, enable ext0
                
                MOV     IP, #00100000b          ;enable highest priority for timer 2
                
                MOV     T2CON, #00000000b       ;reset T2 settings
                MOV     SCON,  #01000000b       ;set serial control settings
                
                ;Set timer 1 config
                MOV     TMOD,  #00100000b       ;set timer 1 to 8bit auto reload
                MOV     ACC, PCON               ;Get current pcon config
                SETB    ACC.7                   ;enable PCON.7 (double the baudrate)    
                MOV     PCON, ACC               ;set PCON again
                MOV     TH1, 253d               ;set baudrate to 19200 256 - ((Crystal/192)/Baud) = 256 - (11059000/192)/19200 = 256 - 3 - 253
                
                

                MOV     TICKCOUNT_1, #0d            ;reset tick count for all counters
                MOV     DEBOUNCER_COUNT, #0d
                MOV     BUTTON_COUNT, #2d
                MOV     SECOND_COUNT, #0d
                MOV     CHARACTER_COUNT, #0d
                
                CLR     IS_NEXT_LINE                 ;set is_next_line to false
				
				MOV		TABLE_START, #60H			;set value of table start to 60H
                

                SETB    GREEN_LED

                MOV     RCAP2H, #76                 ;Load F830H into reload value (65536 - 46079) = 19,457, 50ms tick
                MOV     RCAP2L, #01                 ; ^

                MOV     T2H, #76                    ;start timer at reload value
                MOV     T2L, #01                    ;

                MOV     SEND_DATA_PARAM, #00H
                MOV     SEND_COMMAND_PARAM, #00H

                MOV     T2CON, #00000100b           ;Start T2
				
				ACALL 	INIT_TABLE
				
				MOV		R0, #40H					;move 40H to R0 to use as pointer

                MOV     SEND_COMMAND_PARAM, #01H    ;clear display command
                ACALL   SEND_COMMAND

                MOV     SEND_COMMAND_PARAM, #0FH    ;initialize display
                ACALL   SEND_COMMAND

                JMP     $                           ;wait for interrupts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;TRIGGERS;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Triggered every T2 interrupt
T2IRS:          PUSH    PSW
                PUSH    ACC
                CPL     T2CON.7              ;reset T2 settings
                CPL     T2CON.2              ;
                ACALL   TICK                 ;go to tick routine

EXIT_T2IRS:     POP     ACC                  ;return ACC
                POP     PSW                  ;return PSW
                MOV     IE, #INTERRUPTS      ;enable interruptions again
                MOV     T2CON, #00000100b    ;Start T2
                RETI
;Tick subroutine, called every 50 ms
TICK:           INC TICKCOUNT_1
                INC SECOND_COUNT
                RET

;Triggered every ext0 interrupt
EXT0IRS:        PUSH    PSW
                PUSH    ACC
                CLR     EX0                  ;Disable external0 interrupt
                CLR     EX1                  ;Disable external1 interrupt
                ACALL   BUTTON_PRESSED       ;call button pressed routine
EXIT_EXT0IRS:   POP     ACC
                POP     PSW
                SETB    EX0                  ; reenable ext0 interrupt
                SETB    EX1                  ; reenable ext1 interrupt
                RETI

;Triggered every ext1 interrupt
EXT1IRS:        PUSH    PSW                ; save status before entering interrupt
                PUSH    ACC
                CLR     EX0
                CLR     EX1
                ACALL   SEND_PRESSED
EXIT_EXT1IRS:   POP     ACC                ; load status after interrupt
                POP     PSW
                SETB    EX0                ; reenable ext0 interrupt
                SETB    EX1                ; reenable ext1 interrupt
                RETI

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;ROUTINES;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
INIT_TABLE:		MOV		60H, #31H	;1
				MOV		61H, #32H	;2
				MOV		62H, #33H	;3
				MOV		63H, #41H	;A	
				MOV		64H, #34H	;4
				MOV		65H, #35H	;5
				MOV		66H, #36H	;6
				MOV		67H, #42H	;B
				MOV		68H, #37H	;7
				MOV		69H, #38H	;8
				MOV		6AH, #39H	;9
				MOV		6BH, #43H	;C
				MOV		6CH, #2AH	;*
				MOV		6DH, #30H	;0
				MOV		6EH, #23H	;#
				MOV		6FH, #44H	;D
				RET


;SEND_COMMAND
;TAKES: SEND_COMMAND_PARAM
;RUN Display routine for the LCD display
;================================================================
SEND_COMMAND:   CLR     GREEN_LED                         ; turn on led
                MOV     LCD_DATA, SEND_COMMAND_PARAM      ; write init command to data bus
                CLR     REGISTER_SELECT                   ; make sure RS is 0
                MOV     TICKCOUNT_1, #0d
                SETB    RW_ENABLE                         ; activate write
MOV_AG1:        MOV     A, TICKCOUNT_1
                CJNE    A, #1d, MOV_AG1                   ; wait 50ms
                CLR     RW_ENABLE                         ; deactivate write
                SETB    GREEN_LED
                RET

;SEND_DATA
;TAKES: SEND_DATA_PARAM
;RUN Display routine for the LCD display
;================================================================
SEND_DATA:      CLR     GREEN_LED                         ; turn on led
                MOV     LCD_DATA, SEND_DATA_PARAM         ; write init command to data bus
                SETB    REGISTER_SELECT                   ; make sure RS is 1
                MOV     TICKCOUNT_1, #0d
                SETB    RW_ENABLE                         ; activate write
MOV_AG2:        MOV     A, TICKCOUNT_1
                CJNE    A, #1d, MOV_AG2                   ; wait 50ms
                CLR     RW_ENABLE                         ; deactivate write
                SETB    GREEN_LED
                RET

; BUTTON PRESSED ROUTINE
; SENDS THE DIRECT VALUE OF THE KEY PRESSED TO THE DISPLAY
; ===============================================================
BUTTON_PRESSED: MOV     A, P2  			                     ; save value of keypressed into A
				ANL		A, #0Fh								 ; do bitwise and with 0F to get only important 4 bits
				MOV		KEYPAD_VALUE, A					     ; move value of A into keypad_value
				MOV		A, TABLE_START					     ; move value of table start to A (50H at moment of writing)
				ADD		A, KEYPAD_VALUE					     ; add registered keypad value to A
				MOV		R1, A							     ; move value to R0 so we can use as pointer and get table value
                MOV     SEND_DATA_PARAM, @R1		         ; set parameter value to value pointed by R0 value
                ACALL   DISPLAY_CHECK                        ; check if cursor needs moving
                ACALL   SEND_DATA                            ; send data to LCD
				MOV		A, @R1								 ; get the value sent to the LCD, move to A
				MOV		@R0, A								 ; send that value to the location pointed by R0
				INC		R0									 ; increment pointer
                ACALL   WAIT_500MS                           ; wait 500ms for the hell of it 
BP_EXIT:        RET

; DISPLAY CHECK ROUTINE
; Check the display, if a new line is needed, moves the cursor to new line,
; if both lines are full, clear screen.
; uses CHARACTER_COUNT
DISPLAY_CHECK:  INC     CHARACTER_COUNT                     ;new character added to screen
                MOV     A, CHARACTER_COUNT                  ;move for comparison
                CJNE    A, #16d, DC_EXIT                    ;if the cursor doesnt need moving, continue as usual
                MOV     CHARACTER_COUNT, #0d                ;reset character line count
                JBC     IS_NEXT_LINE, CLR_DISP              ;if its already on the next line, clear display
                SETB    IS_NEXT_LINE                        ;set isnextline to true
                MOV     SEND_COMMAND_PARAM, #40H            ;send command for moving cursor to next line
                ACALL   SEND_COMMAND
				ACALL	WAIT_500MS
                JMP     DC_EXIT
CLR_DISP:       MOV     SEND_COMMAND_PARAM, #01H            ;send command for clearing screen and returning cursor    
                ACALL   SEND_COMMAND
				MOV		R0, #40H							;reset R0 pointer
DC_EXIT:        RET

; ALT INPUT ROUTINE
; SENDS HEXADECIMAL VALUE TO THE DISPLAY
; ===============================================================
ALT_INPUT:      DJNZ    BUTTON_COUNT, REG_BUTTON             ; if the count is not zero, save the button value
                MOV     A, KEYPAD_VALUE                      ; if it is zero, send the value to screen
                SWAP    A
                MOV     KEYPAD_VALUE, A                      ; move keypad value to Acc for nibble swap
                MOV     KEYPAD_VALUE, #LOW(P2)               ; load value of keypad into next 4 bits
                MOV     BUTTON_COUNT, #2d                    ; reset button count
                MOV     SEND_DATA_PARAM, KEYPAD_VALUE        ; set parameter value
                ACALL   SEND_DATA                            ; send data to LCD
                JMP     AI_EXIT                              ; exit
REG_BUTTON:     MOV     KEYPAD_VALUE, #LOW(P2)               ; save
AI_EXIT:        RET

; WAIT 500 MS ROUTINE
; WAITS 500 MS, ALL OTHER ROUTINES STOPPED, EXCEPT TIMER
; ================================================================
WAIT_500MS:     MOV     SECOND_COUNT, #0d                    ;reset counter
RCK:            MOV     A, SECOND_COUNT
                CJNE    A, #20d, RCK                         ;count to 20 for 1s 
                RET                                          ;return
                
                
;SEND PRESSED ROUTINE || Send Push button has been pressed, interrupt enabled.
;sends all data from LCD display to serial, suing send_serial routine
;=================================================================
SEND_PRESSED:   MOV     TICKCOUNT_1, #0d
SPRCK:          MOV     A, TICKCOUNT_1
                CJNE    A, 2d, SPRCK                ;debounce button
                
				
				
                RET
                
                
; SEND SERIAL DATA SUBROUTINE
; SENDS BYTE STORED IN SEND_SERIAL_PARAM
; ================================================================
SEND_SERIAL:    SETB    TI                                  ;set flag on
                MOV     SBUF, SEND_SERIAL_PARAM             ;move value to serial buffer
                CLR     TI
                JNB     TI, $                               ;jump if byte is not done sending
                RET


END
