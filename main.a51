;======================================================================|
; Practica 4, FUNDAMENTOS DE MICROPROCESADORES, ITESO.     |
; AUTORES:                                                             |
;       -ALEJANDRO WALLS        is693215@iteso.mx                      |
;       -MARIO EUGENIO ZUÑIGA   ie693110@iteso.mx                      |
;======================================================================|

;P3            Serial
;P2.0 - 2.3    Salida Decoder Teclado
;P2.7          Senal E de LCD
;P2.6          Senal RS de LCD
;P1            Datos LCD 
                
                T2CON EQU 0C8H               ;T2CON registry location
                RCAP2H EQU 0CBH              ;reload value for t2 location high
                RCAP2L EQU 0CAH              ;reload value for t2 loaction low
                    
                T2H EQU 0CDH                 ;timer 2 value high
                T2L EQU 0CCH                 ;timer 2 value low
                        
                INTERRUPTS EQU 10100101b        ;Interrupt flags, Global, Timer2, Button1, Button0
                    
                TICKCOUNT_1 EQU 3AH             ;Tick counter for refreshing displays
                BUTTON_COUNT EQU 3BH             ;Tick counter for buttons
                TICKCOUNT_250_1 EQU 3CH         ;Tick counter for seconds 1
                TICKCOUNT_250_2 EQU 3DH         ;Tick counter for seconds 2
                DEBOUNCER_COUNT EQU  3EH        ;Counter for debouncer, 20 ms 

                REGISTER_SELECT EQU P2.7        ;RS LCD select signal
                RW_ENABLE EQU P2.6              ;read write enable LCD signal
                LCD_DATA EQU P1                 ;LCD data bus
                
                GREEN_LED EQU P3.6
                    
                KEYPAD_VALUE EQU 40H            ;value of the key pressed
                 
                ;SUBROUTINE PARAMETERS    
                ;====================================================================
                SEND_COMMAND_PARAM EQU 50H                                           ; 
                SEND_DATA_PARAM EQU 51H                                              ;
                ;====================================================================
                
                ORG     0000H                   ;RESET INTERRUPT
                JMP     START                   ;go to start on reset
                
                ORG     0003H                   ;EXT0 INTERRUPT SWITCH BUTTON
                JMP     EXT0IRS             
                
                ORG     0013H                   ;EXT1 INTERRUPT EDIT BUTTON
                ;JMP     EXT1IRS             
                
                ORG     002BH                   ;T2 INTERRUPT
                JMP     T2IRS                   ;Go to interrupt routine                

                ORG     0040H
START:          CLR     RW_ENABLE
                CLR     REGISTER_SELECT
                MOV     IE, #INTERRUPTS         ;enable global interrupt, enable timer 2 interrupt, enable ext1, enable ext0
                MOV     IP, #00100000b          ;enable highest priority for timer 2
                MOV     T2CON, #00000000b       ;reset T2 settings
                
                MOV     TICKCOUNT_1, #0d            ;reset tick count for all counters
                MOV     DEBOUNCER_COUNT, #0d
                mov     BUTTON_COUNT, #2d

                SETB    GREEN_LED
                
                MOV     RCAP2H, #76                 ;Load F830H into reload value (65536 - 46079) = 19,457, 50ms tick
                MOV     RCAP2L, #01                 ; ^
                
                MOV     T2H, #76                    ;start timer at reload value
                MOV     T2L, #01                    ;
                
                MOV     SEND_DATA_PARAM, #00H
                MOV     SEND_COMMAND_PARAM, #00H
                
                MOV     T2CON, #00000100b           ;Start T2
                
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
EXIT_EXT1IRS:   POP     ACC                ; load status after interrupt
                POP     PSW
                SETB    EX0                ; reenable ext0 interrupt
                SETB    EX1                ; reenable ext1 interrupt
                RETI

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;ROUTINES;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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

BUTTON_PRESSED: DJNZ    BUTTON_COUNT, REG_BUTTON             ; if the count is not zero, save the button value
                MOV     A, KEYPAD_VALUE                      ; if it is zero, send the value to screen
                SWAP    A
                MOV     KEYPAD_VALUE, A                      ; move keypad value to Acc for nibble swap
                MOV     KEYPAD_VALUE, #LOW(P2)               ; load value of keypad into next 4 bits
                MOV     BUTTON_COUNT, #2d                    ; reset button count
                MOV     SEND_DATA_PARAM, KEYPAD_VALUE        ; set parameter value
                ACALL   SEND_DATA                            ; send data to LCD 
                JMP     BP_EXIT                              ; exit
REG_BUTTON:     MOV     KEYPAD_VALUE, #LOW(P2)               ; save 
BP_EXIT:        RET


END
