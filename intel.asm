;
;====================================================================
;	Trabalho Final : Intel 2019/1
;	Nome: Matheus Antonio Silva de Azambuja
;	Cartao: 00302875
;====================================================================
;
	.model		small
	.stack
CR		equ		0dh
LF		equ		0ah
; --------------------------------------------------------------------------------
; **************************** Constantes do programa ****************************
; --------------------------------------------------------------------------------
; Constantes usadas pelo programa
;
	.data
FileName			db		256 dup (?)		; Nome do arquivo a ser lido
FileBuffer			db		10 dup (?)		; Buffer de leitura do arquivo
FileHandle			dw		0				; Handler do arquivo
FileNameBuffer		db		150 dup (?)
StringTempo			db		10 dup (?)		; Tempo em Ascii
MsgPedeArquivo		db	"Nome do arquivo: ", 0
MsgErroOpenFile		db	"Erro na abertura do arquivo.", CR, LF, 0
MsgErroReadFile		db	"Erro na leitura do arquivo.", CR, LF, 0
MsgInicial			db	"Matheus Azambuja - 00302875", CR, LF, 0
MsgErroConteudo		db	"Erro no conteudo do arquivo", CR, LF, 0
MsgNormalFinal		db	"Programa finalizado normalmente", CR, LF, 0
MsgTerminaEsc		db	"Execucao do programa foi interrompida a pedido do usuario", CR, LF, 0
PonteiroTempo		dw		0				; Ponteiro de StringTempo
TICKS				dw		0				; Ticks atual do programa
TempoInicial		dw		0				; Tempo do sistema
TempoFinal			dw		0				; Tempo de espera para cada print de caracter
FlagTick			dw		0				; Flag que indica se o programa esta alterando o Tick

	.code
	.startup
;
; Inicio do codigo:
Inicio:
; --------------------------------------------------------------------------------
	call	LimpaTela
; --------------------------------------------------------------------------------
	lea		bx, MsgInicial			; Printa o nome do programador(eu rs)
	call	Printf_s
;====================================================================
; ************************ Programa Principal ***********************
;====================================================================
; Chama as funcoes do programa 
; 
Main:
; --------------------------------------------------------------------------------
	call	PegaNomeArq			; Chamada a funcao que pega o nome do arquivo
; --------------------------------------------------------------------------------
	;	if ( (ax=fopen(ah=0x3d, dx->FileName) ) ) {
	;		printf("Erro na abertura do arquivo.\r\n");
	;		Goto(Main);
	;	}
AbreArquivo:
	lea		dx, FileName		; DX = Ponteiro do arquivo
	call 	Fopen				; Abre arquivo
	jnc		AbriuArquivo		; if(Carry != 0)
								;   Goto(Printf_s);
	lea		bx, MsgErroOpenFile	; else
	call	Printf_s			;   (Printa Mensagem de erro de abertura de arquivo);
	
	jmp 	Main				; E pede um novo arquivo
;
; --------------------------------------------------------------------------------
; ************************* Loop de print dos Caracteres *************************
; --------------------------------------------------------------------------------
; Chama interrupcao da INT 21H. Printa os caracteres do arquivo.
; Registradores:
; AH = 3FH
; BX = Handle do arquivo
; CX = 1 (Quantidade de caracteres que devem ser lidos do arquivo por vez)
; 
AbriuArquivo:
	mov		FileHandle, ax		; Salva handle do arquivo em AX
; --------------------------------------------------------------------------------
	call	LimpaTela
; --------------------------------------------------------------------------------
	mov		TICKS, 1
; --------------------------------------------------------------------------------
	call	AttTempoInicial
	;	while(1) {
DeNovo:
	;		if ( (ax=fread(ah=0x3f, bx=FileHandle, cx=1, dx=FileBuffer)) ) {
	;			printf ("Erro na leitura do arquivo.\r\n");
	;			fclose(bx=FileHandle);
	;			exit(1);
	;		}
	mov		bx, FileHandle
	mov		ah, 3fh
	mov		cx, 1
	lea		dx, FileBuffer
	int		21h
	jnc		TestaFimArquivo
	
	; Se houver erro na leitura do arquivo
	lea		bx, MsgErroReadFile
	call	Printf_s
	
	mov		al, 1				; Codigo usado para comparacao em outros programas
	jmp		CloseAndFinal		; Goto(CloseAndFinal);

TestaFimArquivo:
	;		if (ax==0) {
	;			fclose(bx=FileHandle);
	;			exit(0);
	;		}
	cmp		ax, 0				; if(AX == 0)
	jne		Tempo				; 	Goto(Tempo);
;
; 	Como o arquivo terminou sem erros:
;
	mov		al, 0				; else { AL = 0;
	jmp		CloseAndFinal		; 	Goto(CloseAndFinal);}
;
; ------------------------------------------------------------------
; ****************************** Tempo *****************************
; ------------------------------------------------------------------
; Funcao tempo controla o tempo de exibicao dos caracteres na tela
; Registradores:
; DX = Variavel auxiliar;
; TempoEspera = Tempo do sistema + TICKS;
; TICKS = Tempo para o proximo caracter ser exibido;
; ------------------------------------------------------------------
; ******************** Atualiza tempo do sistema *******************
; ------------------------------------------------------------------
; TICKS = Final - Inicial;
Tempo:
	mov		ah, 0				; Obtem o tempo do sistema e usa como auxiliar de tempo
	int		1ah
	sub		dx, TempoInicial
; 	Fica em loop ate passar todos os ticks
;
; ------------------------------------------------------------------
; ******************** Verifica Teclas Especiais *******************
; ------------------------------------------------------------------
; Trata as teclas com funcionalidades especiais:
; 'r' ou 'R" = Reinicia a exibicao do arquivo atual a partir do primeiro caracter.
; 'n' ou 'N' = Processa um novo arquivo
; 'ESC' = Termina a execucao do programa com uma mensagem.
; Caso contrario, retornar ao fluxo normal de execucao
;
	mov		ah, 0bh
	int		21h
	cmp		al, 0
	jz		PassaTempo

	mov		ah, 0
	int 	16h

	push	ax
	cmp		al, 'r'
	jz		ReiniciaArq
	cmp		al, 'R'
	jz		ReiniciaArq
	pop		ax

	cmp		al, 'n'
	jz		LimpaEMain
	cmp		al, 'N'
	jz		LimpaEMain

	;se a tecla digitada for ESC, termina a execucao
    cmp     al, 27
    jz      TerminaESC
;
PassaTempo:
	cmp		TICKS, dx				; if(DX != TICKS)
	jnz		Tempo					;    Goto(Tempo); }
;
; ------------------------------------------------------------------
; ************************* Exibe Caracter *************************
; ------------------------------------------------------------------
; Chama interrupcao da INT 21H que exibe um caracter na tela
; Registradores:
; AH = 2;
; DL = Ascci do caracter
; Funcao representada em C:
; 	printf("%c", FileBuffer[0]);	// Coloca um caractere na tela
;
ExibeCaracter:
	mov		ah, 2					; AH = 2;
	mov		dl, FileBuffer			; DL = FileBuffer;

	cmp		dl, '#'					; if(DL == '#')
	jz		TrataTicks				;   Goto(TrataTicks);

	cmp		FlagTick, 0				; if(FlagTick != 0)
	jnz		ContinuaTrataTicks		;    Goto(ContinuaTrataTicks);

	int		21h						; Chama a interrupcao 21H (Exibe caracter na tela)

	call	AttTempoInicial
;
;	}		*** FINAL DO WHILE ***
;
	jmp		DeNovo
;
; ------------------------------------------------------------------
; ************************ Reinicia Arquivo ************************
; ------------------------------------------------------------------
; Reinicia o arquivo de entrada do comeco com a INT 21H
; Registadores:
; AH = 42H
; AL = 00H
; BX = FileHandle
; CX = 0
; DX = 0
;
ReiniciaArq:
	mov		ah, 42h
	mov		al, 00h
	mov		bx, FileHandle
	mov		cx, 0
	mov		dx, 0
	int		21H

	mov		FileHandle, ax
	jmp		AbreArquivo  		; Abre o arquivo de novo do comeco
;
; ------------------------------------------------------------------
; ************************** Trata Ticks ***************************
; ------------------------------------------------------------------
; 
TrataTicks:
	mov		FlagTick, 2			; FlagTick = 2;
	jmp		DeNovo				; Goto(DeNovo);
;
ContinuaTrataTicks:
;
	cmp		dl, 48				; if(DL >= 48){
	jge		TestaNumeroTick		; 	Goto(TestaNumeroTick);

	lea		bx, MsgErroConteudo	; else{
	call	Printf_s			;   printf("Erro no conteudo do arquivo");
	jmp		Main				;   Goto(Main);
;
TestaNumeroTick:
;
	cmp		dl, 57				; if(DL <= 57){
	jle		FuncaoTrataTicks	;   Goto(FuncaoTrataTicks);

	lea		bx, MsgErroConteudo	; else{
	call	Printf_s			;   printf("Erro no conteudo do arquivo");
	jmp		Main				;   Goto(Main);
;
FuncaoTrataTicks:
;
	cmp		FlagTick, 1
	jnz		AddStringTempo

	mov		bx, PonteiroTempo
	jmp		AddStringTempo2

AddStringTempo:
	lea		bx, StringTempo
AddStringTempo2:
	mov		[bx], dl
	inc		bx

ContinuaTick:
	mov		PonteiroTempo, bx

	dec		FlagTick			; if(FlagTick != 0){
								;   FlagTick--;
								;   Goto(DeNovo);
	jnz		DeNovo				; }

	mov		byte ptr[bx], 0
;
; Coloca registradores na Pilha
;
	push	ax

	lea		bx, StringTempo

	call	atoi				; Goto(atoi);
	mov		TICKS, ax			; Valor de TICKS atualizado;
;
; Retira registradores da Pilha
;
	pop		ax

	call	AttTempoInicial

	jmp		DeNovo				; Goto(DeNovo);
; }
LimpaEMain:
	call	LimpaTela
	jmp		Main
; ------------------------------------------------------------------
; *********************** Finaliza Processos ***********************
; ------------------------------------------------------------------
; Chama interrupçao da INT 21H que fecha o arquivo e fecha o programa
; Registradores:
; BX = Handle do arquivo
; AH = 3EH
; 
CloseAndFinal:
; --------------------------------------------------------------------------------
	call	Fclose
; --------------------------------------------------------------------------------
EsperaEnter:
	mov		ah, 08h
	int 	21h

	cmp		al, CR
	jnz		EsperaEnter
; --------------------------------------------------------------------------------
	call	LimpaTela
; --------------------------------------------------------------------------------
	jmp		Main				; Retorna a Main, pedindo novo arquivo
Final:
; --------------------------------------------------------------------------------
	call	Fclose
; --------------------------------------------------------------------------------
	call	LimpaTela
; --------------------------------------------------------------------------------
	lea		bx, MsgNormalFinal
	call	Printf_s
	.exit
;
TerminaESC:
; --------------------------------------------------------------------------------
	call	LimpaTela
; --------------------------------------------------------------------------------
	call	Fclose
; --------------------------------------------------------------------------------
	lea		bx, MsgTerminaEsc
	call	Printf_s
	.exit
; --------------------------------------------------------------------------------
;Funcao: Le o nome do arquivo do teclado
;void PegaNomeArq(void)
;{
;	printf_s("Nome do arquivo: ");
;
;	// L� uma linha do teclado
;	FileNameBuffer[0]=100;
;	gets(ah=0x0A, dx=&FileNameBuffer)
;
;	// Copia do buffer de teclado para o FileName
;	for (char *s=FileNameBuffer+2, char *d=FileName, cx=FileNameBuffer[1]; cx!=0; s++,d++,cx--)
;		*d = *s;
;
;	// Coloca o '\0' no final do string
;	*d = '\0';
;}
;--------------------------------------------------------------------
PegaNomeArq	proc	near

	;	printf_s("Nome do arquivo: ");
	lea		bx, MsgPedeArquivo
	call	Printf_s

	; Testa se o enter foi digitado KBHIT

	;	// Le uma linha do teclado
	;	FileNameBuffer[0]=100;
	;	gets(ah=0x0A, dx=&FileNameBuffer)
	mov		ah, 0ah
	lea		dx, FileNameBuffer
	mov		byte ptr FileNameBuffer, 100
	int		21h
;
;	Trata caso se o usuario nao digitar nenhum nome de arquivo
;   Em caso afirmativo, finaliza o programa normalmente
;   com a mensagem apropriada
;
	cmp		FileNameBuffer+1, 0			; if(FileNameBuffer+1 == '\0'){
	jz		Final						;   Goto(Final);

	;	// Copia do buffer de teclado para o FileName
	;	for (char *s=FileNameBuffer+2, char *d=FileName, cx=FileNameBuffer[1]; cx!=0; s++,d++,cx--)
	;		*d = *s;		
	lea		si, FileNameBuffer+2
	lea		di, FileName
	mov		cl, FileNameBuffer+1
	mov		ch, 0
	mov		ax, ds						; Ajusta ES=DS para poder usar o MOVSB
	mov		es, ax
	rep 	movsb

	;	// Coloca o '\0' no final do string
	;	*d = '\0';
	mov		byte ptr es:[di], 0
	ret
PegaNomeArq	endp
;
;====================================================================
; **************************** Printf_s *****************************
;====================================================================
; Funcionalidade da funcao:
; Escreve uma string em na tela
;		printf_s(char *s -> BX)
;
Printf_s	proc	near
	mov		dl, [bx]
	cmp		dl, 0
	je		ps_1

	push	bx
	mov		ah, 2
	int		21H
	pop		bx

	inc		bx		
	jmp		printf_s
		
ps_1:
	ret							; return;
printf_s	endp
;
;====================================================================
; Funcionalidade: Abre o arquivo cujo nome esta no string apontado por DX
;		boolean fopen(char *FileName -> DX)
; Entrada:   DX -> ponteiro para o string com o nome do arquivo
; Saida  :   BX -> handle do arquivo
;            CF -> 0, se OK
;
Fopen	proc	near
	mov		al, 0
	mov		ah, 3dh
	int		21h
	mov		bx, ax
	ret
Fopen	endp
;
; --------------------------------------------------------------------
; Funcionalidade: Converte um ASCII-DECIMAL para HEXA
; Entrada: (S) -> DS:BX -> Ponteiro para o string de origem
; Saida  : (A) -> AX -> Valor "Hex" resultante
; Algoritmo:
;	A = 0;
;	while (*S!='\0') {
;		A = 10 * A + (*S - '0')
;		++S;
;	}
;	return
; --------------------------------------------------------------------
;
atoi	proc near
		; A = 0;
		mov		ax, 0

atoi_2:
		cmp		byte ptr[bx], 0 	; while (*S! = '\0') {
		jz		atoi_1

		mov		cx, 10				; A = 10 * A
		mul		cx

		mov		ch, 0				; A = A + *S
		mov		cl, [bx]
		add		ax, cx

		sub		ax, '0'				; A = A - '0'

		inc		bx					; ++S
		
		jmp		atoi_2				; }
atoi_1:
		ret							; return
atoi	endp

LimpaTela	proc near
		mov		cx, 25
ContinuaLimpando:
		push 	cx
		mov		ah, 2					; AH = 2;
		mov		dl, CR					; 
		int		21h						; Chama a interrupcao 21H (Exibe caracter na tela)

		mov		ah, 2					; AH = 2;
		mov		dl, LF					; DL = Enter;
		int		21h						; Chama a interrupcao 21H (Exibe caracter na tela)
		pop 	cx

		dec		cx
		cmp		cx, 0
		jnz		ContinuaLimpando

		mov		ah, 02h
		mov		bx, 00h
		mov		dh, 0
		mov		dl, 0
		int		10h

		ret
LimpaTela	endp

Fclose	proc near
	mov		bx, FileHandle		; Fecha o arquivo
	mov		ah, 3eh
	int		21h
	ret
Fclose	endp

AttTempoInicial proc near
	mov		ah, 0				; Obtem o tempo do sistema e usa como auxiliar de tempo
	int		1ah
	mov		TempoInicial, dx	; TempoInicial = DX; Tempo do sistema
	ret
AttTempoInicial endp
;--------------------------------------------------------------------
		end
;--------------------------------------------------------------------