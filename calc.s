%macro my_print 2
    pushad
    push %2
    push %1
    call printf
    add esp, 8
    popad
%endmacro

%macro FPRINTF 2
    pushad
    push %1
    push format_string
    push dword[%2]
    call fprintf
    add esp, 12
    popad
%endmacro

%macro change_stack_size 1
    mov ebx, ARGN(2)         ; ebx = char** argv
    add ebx, %1                 
    mov ebx, dword [ebx]     ; ebx = argv[1]
    push ebx
    call atoi
    add esp, 4
    mov dword[stack_size] , eax
%endmacro

%macro first_calling_helper 0
    sub ebx, 4
    sub edx, 4
    mov ebx, dword [ebx]
    mov edx, dword[edx]
    push ebx
    push edx
%endmacro

%macro second_calling_helper 0
    sub ebx, 4
    mov ebx, dword [ebx]
    push ebx
%endmacro

%macro ready_to_creat 0
    push ebx
    call create_link
    add esp, 4
  
    mov ebx, [current_link]
    add ebx, 1
    mov [ebx], eax    

    mov dword [current_link], eax
    mov eax, ecx
    pop ebp
    ret 
%endmacro

%macro end_ebx_or_edx 1
    cmp %1, 0
    je carry
    mov ecx, 0
    mov eax, 0
    mov cl , 0
    mov al, DATA (%1)
    popfd
    adc cl, al
    pushfd
    push ebx
    push edx
    push ecx
    call create_link
    add esp, 4
    pop edx
    pop ebx

    mov ecx, [current_link]
    add ecx, 1
    mov [ecx], eax
    mov [current_link], eax
    mov %1, NEXT(%1)
%endmacro

%define STACK_SIZE 5
%define ARGN(n) dword [ebp+8+4*(n-1)]
%define MYPRINT(fmt, va) my_print fmt, va
%define DATA(r) byte [r]
%define NEXT(r) dword [r+1]

section	.rodata			
    format_string: db "%s", 10, 0
    format_decimal: db "%d", 10, 0
    format_octal: db "%o",10, 0
    calc_string:   db "calc: ", 0
    error_pop_string: db  "Error: Insufficient Number of Arguments on Stack" ,10,0
    error_push_string: db "Error: Operand Stack Overflow", 10,0

section .bss
    stack_ebp: resd 1
    stack_esp: resd 1
    buffer: resb 80
    length: resb 1
    first_link_and: resd 1
    second_link_and: resd 1
    buffertoprint: resb 80

section .data
    stack_size: dd STACK_SIZE
    stack_counter: dd 0
    current_link: dd 0
    num_operators: dd 0
    debug_mode: dd 0 

section .text
  align 16
  global main
  extern printf
  extern fprintf 
  extern fflush
  extern malloc 
  extern calloc 
  extern free 
  extern getchar 
  extern fgets 
  extern stdout
  extern stdin
  extern stderr

main:
    push ebp
    mov ebp, esp

    mov eax, dword [stack_size]

    mov ebx, ARGN(1)        ; ebx = int argc
    cmp ebx, 1              ;defult stack size=5, no debug mode
    je cont

    cmp ebx, 3              ;new stack size+debug mode
    je three_arguments

    mov ebx, ARGN(2)         ; ebx = char** argv
    add ebx, 4                 
    mov ebx, dword [ebx]     ; ebx = argv[1]
    mov ebx, dword[ebx]
    cmp bl, '-'
    jne newSize
    mov dword[debug_mode], 1
    jmp cont 
    
    three_arguments:
    mov dword[debug_mode], 1
    mov ebx, ARGN(2)         ; ebx = char** argv
    add ebx, 4                 
    mov ebx, dword [ebx]     ; ebx = argv[1]
    mov ebx, dword[ebx]
    cmp bl, '-'              ; check if the second arg is debug mode
    jne newSize
    change_stack_size 8
    jmp cont

    newSize:
    change_stack_size 4
    
    cont:
    ; at this point eax holds stack size
    shl eax, 2
    push eax
    call malloc
    add esp, 4

    ; at this point eax holds stack pointer
    mov dword [stack_ebp], eax
    mov dword [stack_esp], eax

    call myCalc
    MYPRINT(format_octal, eax)

    pop ebp
    ret	

myCalc:
    push ebp
    mov ebp, esp

    main_loop:
    push calc_string                       
    call printf             
    add esp, 4   

    call getInput
    movzx edx, byte[buffer] 
    cmp edx, 'q'
    je .free_loop
    cmp edx, '+'    
    je call_add_operator 
    cmp edx, 'p'
    je call_popandprint_operator  
    cmp edx, 'd' 
    je call_dup_operator  
    cmp edx, '&'    
    je call_and_operator 
    cmp edx, 'n'       
    je call_n_operator

    mov ecx, dword[stack_counter]
    cmp ecx, dword[stack_size]
    je error_full_stack
    call addNumber
    
    jmp main_loop

    .free_loop:
    mov ecx, dword[stack_ebp]
    mov edx, dword[stack_esp]
    cmp ecx, edx
    je .free_stack
    sub edx, 4
    mov edx, dword[edx]
    push edx
    call free_operand
    add esp, 4
    jmp .free_loop

    .free_stack:
    mov ebx, dword[stack_ebp]
    pushad
    push ebx
    call free
    add esp, 4
    popad

    mov eax, dword[num_operators]
    pop ebp
    ret

    error_empty_stack:
    pushad
    push error_pop_string     ;push string to stuck
    call printf             
    add esp, 4
    popad
    jmp main_loop

    error_full_stack:
    pushad
    push error_push_string     ;push string to stuck
    call printf             
    add esp, 4
    popad
    jmp main_loop

    call_add_operator:
    inc dword[num_operators]
    mov ebx, dword [stack_esp]
    mov edx, dword[stack_esp]
    sub edx, 4
    cmp edx, dword[stack_ebp]
    je error_empty_stack

    first_calling_helper
    call add_operator
    add esp, 8
    jmp main_loop

    call_popandprint_operator:
    inc dword[num_operators]
    mov ebx, dword [stack_esp]
    cmp ebx, dword[stack_ebp]
    je error_empty_stack

    second_calling_helper
    call popandprint_operator
    add esp, 4
    jmp main_loop

    call_dup_operator:
    inc dword[num_operators]
    mov ebx, dword [stack_esp]
    cmp ebx, dword[stack_ebp]
    je error_empty_stack
    mov ecx, dword[stack_counter]
    cmp ecx, dword[stack_size]
    je error_full_stack
    
    second_calling_helper
    call dup_operator
    add esp, 4
    jmp main_loop

    call_and_operator:
    inc dword[num_operators]
    mov ebx, dword [stack_esp]
    mov edx, dword[stack_esp]
    sub edx, 4
    cmp edx, dword[stack_ebp]
    je error_empty_stack

    first_calling_helper
    call and_operator
    add esp, 8 
    jmp main_loop

    call_n_operator:
    inc dword[num_operators]
    mov ebx, dword [stack_esp]
    cmp ebx, dword[stack_ebp]
    je error_empty_stack

    second_calling_helper
    call n_operator
    add esp,4
    jmp main_loop        

addNumber:

;each operand in the operand stack is stored as a linked list of bytes.
;we take the 3 bits of each octal digit (without the zeros),
;from the far right to the far left, and each 8 bits we put in a link

    push ebp
    mov ebp, esp

    cmp dword[debug_mode],1
    jne cont_addNumber
    FPRINTF buffer,stderr

    cont_addNumber:
    mov dword [current_link],0
    call strLength
    mov [length], al

    mov ecx, buffer
    movzx ebx, byte[length]
    add ecx, ebx
    dec ecx

    cmp ecx, buffer
    jl .return

    .loop:
    push ecx  ;address of the current char
    call A
    add esp,4
    mov ecx, eax
    cmp ecx, buffer
    jl .return

    push ecx
    call B
    add esp,4
    mov ecx,eax
    cmp ecx, buffer
    jl .return

    push ecx
    call C
    add esp,4
    mov ecx,eax
    cmp ecx, buffer
    jl .return
    jmp .loop

    .return:
    add dword [stack_esp],4
    inc dword [stack_counter]
    pop ebp
    ret

A:
    push ebp
    mov ebp, esp
    
    mov ecx, dword[ebp+8] 
    mov ebx, 0

    sub byte [ecx], 48
    or ebx, [ecx]               ;3
    dec ecx
    cmp ecx, buffer
    jl .readyToCreat

    sub byte [ecx], 48
    shl byte[ecx], 3            ;3
    or ebx, [ecx]
    dec ecx
    cmp ecx, buffer
    jl .readyToCreat

    sub byte [ecx], 48
    mov edx, 3                   ;2
    and edx, [ecx]
    shl edx, 6
    or ebx, edx

    mov edx, 4
    and edx, [ecx]
    
    cmp edx,0
    jne .readyToCreat
    dec ecx
    cmp ecx, buffer
    jl .readyToCreat
    inc ecx

    .readyToCreat:    
    push ebx
    call create_link
    add esp, 4

    cmp dword [current_link], 0
    je .firstLink
    mov ebx, [current_link]
    add ebx, 1
    mov [ebx], eax
    jmp .return

    .firstLink:
    pushad
    mov ebx, dword[stack_esp]
    mov dword[ebx], eax ; at this point [ebx] holds the adress of the first link
    popad

    .return:
    mov [current_link], eax
    mov eax, ecx
    pop ebp
    ret 

B:
    push ebp
    mov ebp, esp

    mov ecx, dword[ebp+8]
    mov ebx, 0
    
    mov edx,4               ;1
    and edx, [ecx]
    shr edx, 2
    or ebx,edx
    dec ecx

    cmp ecx, buffer
    jl .readyToCreat

    sub byte [ecx], 48
    shl byte[ecx], 1        ;3
    or ebx, [ecx]
    dec ecx
    cmp ecx, buffer
    jl .readyToCreat

    sub byte [ecx], 48
    shl byte [ecx], 4       ;3
    or ebx, [ecx]
    dec ecx
    cmp ecx, buffer
    jl .readyToCreat
    
    sub byte [ecx], 48
    mov edx, 1              ;1
    and edx, [ecx]
    shl edx, 7
    or ebx, edx

    mov edx, 6
    and edx, [ecx]
    
    cmp edx, 0
    jne .readyToCreat
    dec ecx
    cmp ecx, buffer
    jl .readyToCreat
    inc ecx

    .readyToCreat:
    ready_to_creat          ;macro

C:
    push ebp
    mov ebp, esp
    
    mov ecx, dword[ebp+8]
    mov ebx, 0
   
    mov edx, 6             ;2
    and edx, [ecx]
    shr edx, 1
    or ebx, edx
    dec ecx
    cmp ecx, buffer
    jl .readyToCreat
    sub byte [ecx], 48
    
    shl byte[ecx], 2        ;3
    or ebx, [ecx]
    dec ecx
    cmp ecx, buffer
    jl .readyToCreat
    sub byte [ecx], 48
    
    shl byte [ecx], 5       ;3
    or ebx, [ecx]
    dec ecx
    
   .readyToCreat:
    ready_to_creat          ;macro
    

getInput:
    push ebp
    mov ebp, esp
    
    push dword [stdin]            
    push 80                 
    push  buffer               
    call fgets
    add esp, 12

    pop ebp
    ret

create_link:
    push ebp
    mov ebp, esp
    
    push ecx
    push 5
    call malloc
    add esp, 4
    pop ecx

    mov ebx, dword[ebp+8]
    mov DATA(eax), bl
    mov NEXT(eax), 0
    pop ebp
    ret

; operators

add_operator:
    push ebp
    mov ebp, esp
    mov edx, dword [ebp+8] 
    mov ebx, dword [ebp+12]

    mov dword[first_link_and], edx
    mov dword[second_link_and], ebx
    mov dword[current_link], 0
    clc
    pushfd

    .loop:
    cmp ebx, 0  ;points to the next link
    je .end_ebx
    cmp edx, 0
    je .end_edx

    mov ecx, 0
    mov eax, 0   
    mov cl, DATA(ebx)
    mov al, DATA (edx)
    popfd
    adc cl, al
    pushfd
    push ebx
    push edx
    push ecx
    call create_link
    add esp, 4
    pop edx
    pop ebx

    cmp dword [current_link], 0 
    je .firstLink
    mov ecx, [current_link]
    add ecx, 1
    mov [ecx], eax
    mov [current_link], eax
    mov ebx, NEXT(ebx)
    mov edx, NEXT(edx)
    jmp .loop

    .firstLink:
    pushad
    mov ecx, dword[stack_esp]
    sub ecx, 8
    mov dword[ecx], eax ; at this point [ecx] holds the adress of the first link
    popad
    mov [current_link], eax
    mov ebx, NEXT(ebx)
    mov edx, NEXT (edx)
    jmp .loop

    .end_ebx:
    end_ebx_or_edx edx
    jmp .end_ebx
    
    .end_edx:
    end_ebx_or_edx ebx
    jmp .end_edx

    carry:
    popfd
    mov ecx, 0
    mov eax, 0

    mov cl, 0
    mov al, 0
    adc cl, al
    pushfd
    cmp ecx, 0
    je .return
    push edx
    push ebx
    push ecx
    call create_link
    add esp, 4
    pop ebx
    pop edx

     
    mov ecx,[current_link]
    add ecx, 1
    mov [ecx], eax
    mov [current_link], eax
    
    
    .return: 
    push dword[first_link_and]
    call free_operand
    add esp, 4
    push dword[second_link_and]
    call free_operand
    add esp, 4
    
    cmp dword[debug_mode],1
    jne .cont_return
    mov eax, dword[stack_esp]
    mov eax, dword[eax]
    push eax
    call print_convertion
    add esp, 4
    FPRINTF eax, stderr
    
    .cont_return:
    inc dword [stack_counter]
    mov eax, dword[stack_esp]
    mov eax, dword[eax]
    add dword[stack_esp], 4
    popfd
    pop ebp
    ret 

popandprint_operator:
    push ebp
    mov ebp, esp
    mov ecx, dword [ebp+8] ; adress of the first link
    push ecx
    call print_convertion
    add esp, 4
    mov ebx, eax
    
    FPRINTF ebx, stdout

    .return:
    mov ecx, dword [ebp+8]
    push ecx 
    call free_operand
    add esp, 4
    pop ebp
    ret 

dup_operator:
    push ebp
    mov ebp, esp
    mov ecx, dword [ebp+8]
    mov dword[current_link], 0

    .loop:
    cmp ecx, 0
    je .return
    movzx edx, DATA(ecx)
    push edx
    call create_link
    add esp, 4

    cmp dword [current_link], 0
    je .firstLink
    mov ebx, [current_link]
    add ebx, 1
    mov [ebx], eax
    mov [current_link], eax
    mov ecx, NEXT(ecx)
    jmp .loop

    .firstLink:
    pushad
    mov ebx, dword[stack_esp]
    mov dword[ebx], eax ; at this point [ebx] holds the adress of the first link
    popad
    mov [current_link], eax
    mov ecx, NEXT(ecx)
    jmp .loop

    .return:
    inc dword [stack_counter]
    add dword [stack_esp], 4
    pop ebp
    ret 

and_operator:
    push ebp
    mov ebp, esp
    mov edx, dword [ebp+8] 
    mov ebx, dword [ebp+12]

    mov dword[first_link_and], edx
    mov dword[second_link_and], ebx
    mov dword[current_link], 0

    .loop:
    cmp ebx, 0
    je .return
    cmp edx, 0
    je .return

    movzx ecx, DATA(ebx)
    movzx eax, DATA (edx)
    and ecx, eax
    push ebx
    push edx
    push ecx
    call create_link
    add esp, 4
    pop edx
    pop ebx

    cmp dword [current_link], 0
    je .firstLink
    mov ecx, [current_link]
    add ecx, 1
    mov [ecx], eax
    mov [current_link], eax
    mov ebx, NEXT(ebx)
    mov edx, NEXT(edx)
    jmp .loop

    .firstLink:
    pushad
    mov ecx, dword[stack_esp]
    sub ecx, 8
    mov dword[ecx], eax ; at this point [ecx] holds the adress of the first link
    popad
    mov [current_link], eax
    mov ebx, NEXT(ebx)
    mov edx, NEXT (edx)
    jmp .loop

    .return: 
    push dword[first_link_and]
    call free_operand
    add esp, 4
    push dword[second_link_and]
    call free_operand
    add esp, 4

    cmp dword[debug_mode], 1
    jne .cont_return
    mov eax, dword[stack_esp]
    mov eax, dword[eax]
    push eax
    call print_convertion
    add esp, 4
    FPRINTF eax, stderr
    .cont_return:
    inc dword [stack_counter]
    add dword[stack_esp], 4
    pop ebp
    ret 

n_operator:
    push ebp
    mov ebp, esp

    mov ecx, 0             ;counter
    mov ebx, dword[ebp+8]
    
    .loop:
    cmp ebx, 0
    je .return
    inc ecx
    mov ebx, NEXT(ebx)
    jmp .loop

    .return:
    pushad
    mov ebx, dword[stack_esp]
    sub ebx, 4
    mov ebx, dword[ebx]
    push ebx
    call free_operand
    add esp, 4
    popad

    push ecx
    call create_link
    add esp, 4
    mov edx, dword[stack_esp]
    mov dword[edx], eax

    cmp dword[debug_mode], 1
    jne .cont_return
    mov eax, dword[stack_esp]
    mov eax, dword[eax]
    push eax
    call print_convertion
    add esp, 4
    FPRINTF eax, stderr
    
    .cont_return:
    add dword [stack_esp], 4
    inc dword [stack_counter]
   
    pop ebp
    ret
 
free_operand:
    push ebp
    mov ebp, esp

    mov ebx, dword [ebp+8]
    .loop:
    cmp ebx, 0
    je .return
    mov ecx, NEXT(ebx)

    pushad
    push ebx
    call free
    add esp, 4
    popad

    mov ebx, ecx
    jmp .loop

    .return:
    dec dword [stack_counter]
    sub dword [stack_esp], 4
    pop ebp
    ret


; int atoi(char* str);
atoi:
	push ebp
	mov ebp, esp

    mov ebx, ARGN(1)            ; ebx = char* str
    mov eax, 0

    .loop:                      ; convert string to int (octal)
    movzx ecx, byte [ebx]
    cmp ecx, 0
    je .return

    sub ecx, '0'
    shl eax, 3
    add eax, ecx
    inc ebx
    jmp .loop

    .return:
    pop ebp
    ret

strLength:
    push ebp
    mov ebp, esp

    mov ecx, buffer
    mov eax, -1

    .loop:
    inc eax
    mov ebx, ecx
    add ebx, eax
    movzx edx, byte [ebx]
    cmp edx, 10 
    je .return
    jmp .loop

    .return:
    pop ebp
    ret   

print_convertion:
    push ebp
    mov ebp, esp
    mov ecx, dword [ebp+8]
    mov ebx, buffertoprint
    add ebx, 79
    mov byte[ebx], 0
    dec ebx

    .loop:
    cmp ecx, 0
    je print
    mov dl, DATA(ecx)
    
    mov dh, 7               ;3
    and dh ,dl
    add dh, 48
    mov byte[ebx], dh
    dec ebx

    shr dl, 3               ;3
    mov dh, 7
    and dh, dl
    add dh, 48
    mov byte[ebx], dh
    dec ebx

    shr dl, 3               ;2
    mov dh, 3
    and dh, dl
    mov ecx, NEXT(ecx)
    cmp ecx, 0
    jne .cont1
    add dh, 48
    mov byte[ebx], dh
    dec ebx
    jmp print
    
    .cont1:
    mov dl, DATA(ecx)       ;1
    shl dl, 2
    and dl, 4
    or dh, dl
    add dh, 48
    mov byte[ebx], dh
    dec ebx

    mov dl, DATA(ecx)       ;3
    shr dl, 1
    mov dh, 7
    and dh, dl
    add dh, 48
    mov byte[ebx], dh
    dec ebx

    shr dl, 3               ;3
    mov dh, 7
    and dh, dl
    add dh, 48
    mov byte[ebx], dh
    dec ebx

    shr dl, 3               ;1
    mov dh, 1
    and dh, dl
    mov ecx, NEXT(ecx)
    cmp ecx, 0
    jne .cont2
    add dh, 48
    mov byte[ebx], dh
    dec ebx
    jmp print
    
    .cont2:
    mov dl, DATA(ecx)       ;2
    shl dl, 1
    and dl, 6
    or dh, dl
    add dh, 48
    mov byte[ebx], dh
    dec ebx

    mov dl, DATA(ecx)       ;3
    shr dl, 2
    mov dh, 7
    and dh, dl
    add dh, 48
    mov byte[ebx], dh
    dec ebx

    shr dl, 3               ;3
    mov dh, 7
    and dh, dl
    add dh, 48
    mov byte[ebx], dh
    dec ebx
    mov ecx, NEXT(ecx)
    jmp .loop

    print:                      ;printing without leading zeros
    inc ebx
    mov edx, buffertoprint
    add edx, 78
    cmp ebx, edx
    je .continue
    cmp byte[ebx], 48
    je print

    .continue:
    mov eax, ebx
    pop ebp
    ret 
