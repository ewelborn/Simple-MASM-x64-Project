; These libraries are necessary to call C functions
includelib ucrt.lib
includelib legacy_stdio_definitions.lib

ExitProcess PROTO

; Tell the assembler that we will need to call these functions
EXTERN printf: PROC
EXTERN malloc: PROC
EXTERN rand: PROC

.data
	; Create two points for our arrays
	x dq 0
	y dq 0

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

	sub rsp, 16

	; Clear xmm0
	mov [rsp], rax
	mov [rsp + 8], rax
	movdqu xmm0, [rsp]

meanArrayLoop:
	; Load the next 16 64-bit numbers into some xmm registers
	movdqu xmm1, [rcx + rbx * 8]
	add rbx, 2
	movdqu xmm2, [rcx + rbx * 8]
	add rbx, 2
	movdqu xmm3, [rcx + rbx * 8]
	add rbx, 2
	movdqu xmm4, [rcx + rbx * 8]
	add rbx, 2

	movdqu xmm5, [rcx + rbx * 8]
	add rbx, 2
	movdqu xmm6, [rcx + rbx * 8]
	add rbx, 2
	movdqu xmm7, [rcx + rbx * 8]
	add rbx, 2
	movdqu xmm8, [rcx + rbx * 8]
	add rbx, 2

	paddq xmm0, xmm1
	paddq xmm0, xmm2
	paddq xmm0, xmm3
	paddq xmm0, xmm4
	paddq xmm0, xmm5
	paddq xmm0, xmm6
	paddq xmm0, xmm7
	paddq xmm0, xmm8

	cmp rbx, rdx
	jnz meanArrayLoop

	; Take the two running totals and add them together to get the final result
	movdqu [rsp], xmm0
	add rax, [rsp]
	add rax, [rsp + 8]

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
	add rsp, 16
	pop rdx
	pop r8
	pop rbx
	ret
meanArray ENDP

mainCRTStartup PROC

	; Generate the x and y arrays (length is 2^28)
	mov rcx, 268435456
	call generateRandomNumbers
	mov x, rax

	mov rcx, 268435456
	call generateRandomNumbers
	mov y, rax

	; Find x_mean
	mov rcx, x
	mov rdx, 268435456
	call meanArray
	mov x_mean, rax

	; Find y_mean
	mov rcx, y
	mov rdx, 268435456
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

; generateRandomNumbers uses a custom calling convention (i.e. NOT x64 Windows):
;	rcx is the length of the array (how many 64 bit numbers you need to generate)
; We will return the pointer to the array in rax
generateRandomNumbers PROC
	mov r15, rcx

	; Multiply the length of the array by 8 to get the total number
	;	of bytes required for our 64 bit numbers
	shl rcx, 3

	sub rsp, 40
	call malloc

	; This is the address of our new block in memory
	mov r14, rax

randomNumberLoop:
	; NOTE: Could use rand() from C, but we choose to use rdrand instead, as it
	;	gives us "more random" numbers from the CPU's thermal noise.
	; call rand

	rdrand rax

	; Split into 8 1-byte numbers and move them into the array
	;	This optimization speeds up the function 4x on my machine.
	;	Generating 268435456 numbers went from almost 5 seconds to less than 1 second.
	;	The numbers are smaller, but we don't need huge numbers anyways.
	dec r15
	cmp r15, 0
	jl randomNumberLoop_SKIP

	mov rbx, rax
	mov rcx, 0FF00000000000000h
	and rbx, rcx
	shr rbx, 56 
	mov [r14 + r15 * 8], bl

	dec r15
	cmp r15, 0
	jl randomNumberLoop_SKIP

	mov rbx, rax
	mov rcx, 0FF000000000000h
	and rbx, rcx
	shr rbx, 48 
	mov [r14 + r15 * 8], bl

	dec r15
	cmp r15, 0
	jl randomNumberLoop_SKIP

	mov rbx, rax
	mov rcx, 0FF0000000000h
	and rbx, rcx
	shr rbx, 40 
	mov [r14 + r15 * 8], bl

	dec r15
	cmp r15, 0
	jl randomNumberLoop_SKIP

	mov rbx, rax
	mov rcx, 0FF00000000h
	and rbx, rcx
	shr rbx, 32 
	mov [r14 + r15 * 8], bl

	dec r15
	cmp r15, 0
	jl randomNumberLoop_SKIP

	mov rbx, rax
	mov rcx, 0FF000000h
	and rbx, rcx
	shr rbx, 24 
	mov [r14 + r15 * 8], bl

	dec r15
	cmp r15, 0
	jl randomNumberLoop_SKIP

	mov rbx, rax
	mov rcx, 0FF0000h
	and rbx, rcx
	shr rbx, 16 
	mov [r14 + r15 * 8], bl

	dec r15
	cmp r15, 0
	jl randomNumberLoop_SKIP

	mov rbx, rax
	mov rcx, 0FF00h
	and rbx, rcx
	shr rbx, 8 
	mov [r14 + r15 * 8], bl

	dec r15
	cmp r15, 0
	jl randomNumberLoop_SKIP

	mov rbx, rax
	mov rcx, 0FFh
	and rbx, rcx
	mov [r14 + r15 * 8], bl

	cmp r15, 0
	jne randomNumberLoop

randomNumberLoop_SKIP:
	mov rax, r14
	add rsp, 40
	ret
generateRandomNumbers ENDP

END