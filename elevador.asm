MOTOR_PASSO EQU 2000H ; Motor de passo está ligado na porta Y1
MOTOR_CC EQU 6000H ; Motor CC está ligado na porta Y3

A13 EQU P2.5 ; A
A14 EQU P2.6 ; B
A15 EQU P2.7 ; C

; IN1   IN2   EFEITO com EN=1s
;  0     0        parado
;  0     1        direito
;  1     0        reverso
;  1     1        parado

ORG 00H
LJMP INICIO

ORG 03H ; Interrupção 0: P3.2, Escolha de andar
    LCALL ANDAR
    CLR RD ; liga o teclado de novo
    RETI

ORG 30H
INICIO: MOV SP,#2FH
        MOV IE,#10000001B
            ; Bit 7: Enable ALL
            ; Bit 0: Enable External Interrupt 0 (Pino P3.2)
        SETB IT0 ; Interrupt 0 Type - Transição
        MOV TMOD,#00100001B
            ; Bit 5: Timer 1 no modo 2 (recarga automática)
            ; Bit 0: Timer 0 no modo 1
        MOV SCON,#01000000B
            ; Bit 7: SM0=0
            ; Bit 6: SM1=1
                ; Modo 1 = UART de 8 Bits
        MOV TH1,#0F4H ; esses valores de recarga são tabelados
        MOV TL1,#0F4H ; Baud Rate de 2,4K bits por segundo, recarga = 0F4H
        SETB TR1 ; Dispara o timer 1

        MOV A,#0
        MOV P1,#00000001B; Leds

        LCALL LIGA_TECLA ; Ligo o teclado pq ele vai enviar a interrupção
        MOV DPTR,#MSG_0
        LCALL MANDAR_MSG ; Transmite via serial que o elevador tá no térreo
        SJMP $ ; Espera a interrupção 0, enviada pelo teclado

    ANDAR: JB P0.3,MAIOR_Q_7
           MOV 10H,A ; Andar atual no endereço 10H
           MOV A,P0  ; Andar desejado em A
           CJNE A,10H,DIFERENTE ; Sai se os andares forem iguais
           MOV A,10H ; Coloca de volta o andar atual
MAIOR_Q_7: NOP
           RET
DIFERENTE: LCALL DESLIGA_TECLA
           LCALL LIGA_MOTOR_CC
           JC DESCER ; Se carry=1: desejado<atual -> elevador desce
           LCALL MOTOR_CC_DIR ; Se carry=0: desejado>atual -> elevador sobe
           LCALL SOBE
           LCALL DESLIGA_MOTOR_CC
           LCALL ABRE_PORTA
           LCALL LIGA_TECLA
           RET
   DESCER: LCALL MOTOR_CC_REV
           LCALL DESCE
           LCALL DESLIGA_MOTOR_CC
           LCALL ABRE_PORTA
           LCALL LIGA_TECLA
           RET

TRANSMITE: CJNE A,#00000000B,AND1
           MOV DPTR,#MSG_0
           LCALL MANDAR_MSG
           RET
     AND1: CJNE A,#00000001B,AND2
           MOV DPTR,#MSG_1
           LCALL MANDAR_MSG
           RET
     AND2: CJNE A,#00000010B,AND3
           MOV DPTR,#MSG_2
           LCALL MANDAR_MSG
           RET
     AND3: CJNE A,#00000011B,AND4
           MOV DPTR,#MSG_3
           LCALL MANDAR_MSG
           RET
     AND4: CJNE A,#00000100B,AND5
           MOV DPTR,#MSG_4
           LCALL MANDAR_MSG
           RET
     AND5: CJNE A,#00000101B,AND6
           MOV DPTR,#MSG_5
           LCALL MANDAR_MSG
           RET
     AND6: CJNE A,#00000110B,AND7
           MOV DPTR,#MSG_6
           LCALL MANDAR_MSG
           RET
     AND7: CJNE A,#00000111B,SAIR
           MOV DPTR,#MSG_7
           LCALL MANDAR_MSG
     SAIR: NOP
           RET

     SOBE: PUSH ACC  ; Andar desejado está em A. Salvo esse valor
           XCH A,10H ; Andar atual em A e andar desejado em 10H
           MOV R1,A  ; Põe o andar atual em R1
LOOP_SOBE: MOV A,P1  ; Andar atual em A só que no formato de LED
           LCALL ATRASO_5S
           RL A      ; Sobe: motor em sentido horário
           MOV P1,A  ; Coloca nos LEDs
           INC R1    ; Aumenta o andar
           MOV A,R1  ; Coloca o valor do andar aumentado em A
           LCALL TRANSMITE
           CJNE A,10H,LOOP_SOBE ; Verifica se já chegou
           POP ACC
           RET

     DESCE: PUSH ACC  ; Andar desejado está em A. Salvo esse valor
            XCH A,10H ; Andar atual em A e andar desejado em 10H
            MOV R1,A  ; Põe o andar atual em R1
LOOP_DESCE: MOV A,P1  ; Andar atual em A só que no formato de LED
            LCALL ATRASO_5S
            RR A      ; Sobe: motor em sentido horário
            MOV P1,A  ; Coloca nos LEDs
            DEC R1    ; Diminui o andar
            MOV A,R1  ; Coloca o valor do andar diminuído em A
            LCALL TRANSMITE
            CJNE A,10H,LOOP_DESCE ; Verifica se já chegou
            POP ACC
            RET

ABRE_PORTA: MOV DPTR,#MOTOR_PASSO
            PUSH ACC
            MOV A,#00010001b
            MOV R6,#90 ; 90 passos de 4 graus cada = 360 graus
      POR1: MOVX @DPTR,A
            LCALL ATRASO
            RL A
            INC DPTR
            DJNZ R6,POR1
            LCALL ATRASO_5S
            MOV R6,#90 ; 90 passos de 4 graus cada = 360 graus
      POR2: MOVX @DPTR,A
            LCALL ATRASO
            RR A
            INC DPTR
            DJNZ R6,POR2
            POP ACC
            RET

LIGA_MOTOR_CC: SETB A13 ; P2.5 = A
               SETB A14 ; P2.6 = B
               CLR A15  ; P2.7 = C
               SETB RD  ; P3.7 = E1 = not (RD and WR)
               CLR WR   ; P3.6 = E2 = E3 = 0
               ; A=1,B=1,C=0,E1=1,E2=0,E3=0
               ; Com esses valores, Y3=0, então MCC=0
               ; Com MCC=0, LE do 74HC573 é 1 (CC ativo)
               MOV DPTR,#MOTOR_CC
               PUSH ACC
               MOV A,#00010000B
               MOVX @DPTR,A
               POP ACC
               RET

LIGA_MOTOR_PASSO: SETB A13 ; P2.5 = A
                  CLR A14  ; P2.6 = B
                  CLR A15  ; P2.7 = C
                  SETB RD  ; P3.7 = E1 = not (RD and WR)
                  CLR WR   ; P3.6 = E2 = E3 = 0
                  ; A=1,B=0,C=0,E1=1,E2=0,E3=0
                  ; Com esses valores, Y1=0, então MP=0
                  ; Com MP=0, LE do 74HC573 é 1 (PASSO ativo)
                  RET

LIGA_TECLA: CLR A13  ; P2.5 = A
            CLR A14  ; P2.6 = B
            SETB A15 ; P2.7 = C
            SETB RD  ; P3.7 = E1 = not (RD and WR)
            CLR WR   ; P3.6 = E2 = E3 = 0
            ; A=0,B=0,C=1,E1=1,E2=0,E3=0
            ; Com esses valores, Y4=0, então TECLA=0
            ; Com TECLA=0, LE do 74HC573 é 1 (teclado ativo)
            RET

DESLIGA_TECLA: CLR RD
               RET

MOTOR_CC_DIR: MOV DPTR,#MOTOR_CC
              PUSH ACC
              MOV A,#00010010B
              MOVX @DPTR,A
              POP ACC
              RET

MOTOR_CC_REV: MOV DPTR,#MOTOR_CC
              PUSH ACC
              MOV A,#00010001B
              MOVX @DPTR,A
              POP ACC
              RET

DESLIGA_MOTOR_CC: MOV DPTR,#MOTOR_CC
                  PUSH ACC
                  MOV A,#00000000B
                  MOVX @DPTR,A
                  POP ACC
                  RET

MANDAR_MSG: MOV R7,#0
            PUSH ACC       ; salva os valores anteriores do A na pilha
        V1: MOV A,R7       ; acumulador recebe R7
            MOVC A,@A+DPTR ; A recebe o conteúdo da posição A+DPTR da MSG
            CJNE A,#0FFH,ENVIA ; Se A não for fim da MSG, envia
            POP ACC        ; recupera os valores anteriores de A
            RET
     ENVIA: MOV SBUF,A ; Inicia a trasmissão
            JNB TI,$   ; Aguarda a trasmissão de todos os bits
                       ; quando acabar, o hardware vai tornar TI=1
            CLR TI     ; Preciso limpar TI manualmente
            INC R7     ; incrementa o lugar que DPTR aponta
            SJMP V1

ATRASO_5S: MOV R0,#100 ; 20 * 5 = 100 -> 5 segundos
      AT5: NOP
           LCALL TH_TL
           SETB TR0    ; Dispara o temporizador
           JNB TF0,$   ; Loop de espera do fim da contagem
           CLR TF0
           DJNZ R0,AT5 ; Se R0-1 não for zero, volta pra AT1
           CLR TR0     ; Interrompe o temporizador
           RET

ATRASO: MOV R2,#200
    V3: MOV R3,#200
        DJNZ R3,$
        DJNZ R2,V3
        RET

TH_TL: MOV TH0,#HIGH(19455) 
       MOV TL0,#LOW(19455)
       RET
       ; contagem do temporizador vai até 65535
       ; cada período do temporizador é 1,085 us
       ; cada segundo é 1000 ms
       ; vou gerar 50 ms e contar 20 vezes (50 ms * 20 = 1 seg)
       ; 46080 * 1,085 us = 50 ms
       ; contagem vai começar em 65535 - 46080 = 19455

MSG_0: DB 'Pavimento Terreo', 0DH, 0FFH ; ODH é o código ASCII para mudar linha
MSG_1: DB 'Pavimento 1', 0DH, 0FFH
MSG_2: DB 'Pavimento 2', 0DH, 0FFH
MSG_3: DB 'Pavimento 3', 0DH, 0FFH
MSG_4: DB 'Pavimento 4', 0DH, 0FFH
MSG_5: DB 'Pavimento 5', 0DH, 0FFH
MSG_6: DB 'Pavimento 6', 0DH, 0FFH
MSG_7: DB 'Pavimento 7', 0DH, 0FFH

END



