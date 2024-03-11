; These libraries are necessary to call C functions
includelib ucrt.lib
includelib legacy_stdio_definitions.lib

ExitProcess PROTO

; Tell the assembler that we will need to call these functions
EXTERN printf: PROC

.data
	; Define two arrays of 64 bit numbers - the arrays will be 8 numbers long
	x dq 5, 7, 2, -3, 4, 15, 7, 8
	y dq 1, 0, -1, 4, 5, 2, -3, 4

	; Define our two variables
	x_mean dq 0
	y_mean dq 0

	; Define the string for printf
	; The newline character \n is 10 in decimal
	; The null terminator is 0 in decimal
	myString db "x_mean = %d", 10, "y_mean = %d", 0

.code
; meanArray uses a custom calling convention (i.e. NOT x64 Windows):
;	rcx is the memory address of the first number in the array
;	rdx is the length of the array (how many 64 bit numbers there are)
; We will return the mean of the array in rax, rounded down.
meanArray PROC
	; I want to use rbx and r8, but I don't want to erase the values of them
	;	if they're being used by the calling code, so I'll save them first.
	push rbx
	push r8
	; The value of rdx will also be changed during my function, so I will
	;	save this register as well
	push rdx

	; rax contains the running total of the array
	; rbx is my loop counter
	mov rax, 0
	mov rbx, 0

meanArrayLoop:
	; r8 contains the current element of the array
	mov r8, [rcx + rbx * 8]

	; Add it to our running total
	add rax, r8

	inc rbx
	cmp rbx, rdx
	jnz meanArrayLoop

	; Division in x64 assembly is a little weird - we're dividing a 128 bit
	;	number, with the upper 64 bits in RDX and the lower 64 bits in RAX.
	;	So, I need to make sure that RDX is 0. I'll move its value to r8.
	mov r8, rdx
	mov rdx, 0
	; Divide the running total by the length of the array to get the mean
	;	RAX <- quotient, RDX <- remainder
	; https://www.felixcloutier.com/x86/idiv
	idiv r8

	; The quotient is already stored in RAX, so my return value is ready

	; Make sure you pop the registers in reverse order! LIFO
	pop rdx
	pop r8
	pop rbx
	ret
meanArray ENDP

mainCRTStartup PROC

	; Find x_mean
	mov rcx, offset x
	mov rdx, 8
	call meanArray
	mov x_mean, rax

	; Find y_mean
	mov rcx, offset y
	mov rdx, 8
	call meanArray
	mov y_mean, rax

	; Call C's printf function like so: 
	;	printf("x_mean = %d\ny_mean = %d", x_mean, y_mean)
	;
	;	rcx is the address of the string we're passing in
	;	rdx is the first integer (that fills in the first %d)
	;	r8 is the second integer (that fills in the second %d)
	mov rcx, offset myString
	mov rdx, x_mean
	mov r8, y_mean

	; Allocate 32 bytes of shadow space
	sub rsp, 32

	; Add padding
	sub rsp, 8

	call printf

	; Clean up the stack
	add rsp, 40

	mov ecx, 0
	call ExitProcess
mainCRTStartup ENDP

END