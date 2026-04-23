include '../INCLUDE/win32a.inc'

format PE console
entry start

; константа - длина массива
LENGTH equ 10

section '.text' code executable
start:
    mov esi, welcome
    call print_text
    call print_newline

    ; проверка на длину массива
    mov ecx, LENGTH
    cmp ecx, 2
    jl wrong_size_error

    mov eax, LENGTH
    mov esi, filling
    call print_text
    add esp, 4

    call fill_array

    call print_newline

    ; вывод несортированного массива
    mov esi, unsorted
    call print_text
    call print_newline
    call print_array
    call print_newline

    mov esi, sorting
    call print_text

    call print_newline

    ; сортировка массива
    call sort_array

    ; вывод сортированного массива
    mov esi, sorted
    call print_text
    call print_newline
    call print_array
    call print_newline

    jmp exit_program
    ret

; неверный размер массива (меньше 2)
wrong_size_error:
        mov esi, wrong_size
        call print_text
        call print_newline

        jmp exit_program
        ret

exit_program:
        push any_key
        call [printf]
        add esp, 4

        push 0
        call [_getch]
        ret

fill_array:
        mov eax, 0
        fill_loop:
                ; рандом число аля ((i ^ 5) * 2) - 5
                mov ebx, eax
                xor ebx, 5
                imul ebx, 2
                sub ebx, 5

                ; кладем число в буффер
                ; т.к за условный размер числа было взято 4 байта, то нужно переходить по массиву
                ; с шагом в index * 4 (sizeof int)
                ; т.к данный массив является массивом из 10 4-байтных чисел
                mov [buf+eax*4], ebx

                inc eax
                cmp eax, LENGTH
                jle fill_loop

        mov ebx, 0
        ret

print_array:
        mov ebx, 0
        print_loop:
                ; логика для чтения символов похожа, что и в fill_array
                ; получаем доступ к переменным с шагом в index * 4 (sizeof int)

                mov eax, [buf+ebx*4]
                mov esi, syntax
                call print_text

                inc ebx

                cmp ebx, LENGTH
                jne print_loop
        mov eax, 0
        mov ebx, 0
        ret


; в данном коде была использована сортировка пузырьком
; принцип сортировки устроен таким образом:
;     buf [ 3 9 7 -3 -5 ]
;          [3 > 9] ?
;     
;          если нет, то идем дальше:
;     
;     buf [ 3 9 7 -3 -5 ]
;            [9 > 7] ?
;     
;          да, оно больше, меняем местами:
;              buf, где лежит [9] = [7]
;              buf, где лежит [7] = [9]
;     
;     в итоге в массиве это выглядит вот так:
;     
;              * эти числа были поменяны местами
;             / \
;     buf [ 3 9 7 -3 -5 ]
;     
;     и таким образом благодаря двойному циклу мы идем и смотрим данный массив по кругу
;     на наличие несортированных элементов по порядку
;     после чего повторяем процедуру, описанную выше
;     
;     принцип шагов устроен следующим образом:
;     i = идем по самому массиву
;     j = идем еще раз, по тому же массиву внутри цикла i, от шага i до предела, равного длине массива -1
;         это нужно для того, чтобы была возможность нормально получать текущее число по шагу цикла и следующее
;     
;        *i  -> -> -> -> ->
;           *j -> -> -> -> ->
;     buf [ 3 9 7 -3 -5]
;     
;     в итоге алгоритм сортировки может быть реализован, получив числа в следующим образом:
;     
;                            * - не забываем, что размер числа равен 4 байтам
;                           /
;       9 = j (buf_addr + 1*4)
;       7 = j (buf_addr + 2*4)
;   

sort_array:
        ; очищаем регистры перед использованием в двух циклах
        ; перед тем, как начать цикл, нужно задать значения переменным
        mov eax, 0
        mov ebx, 0
        mov ecx, 0
        mov edx, 0

        mov esi, 0
        mov edi, 0

        first_loop:
                ; перед тем, как продолжать цикл, нужно проверить, прошел ли первый итератор все шаги (i -> ebx)
                ; если нет - идем дальше
                cmp ebx, LENGTH-1
                jge exit_loop
                second_loop:
                      ; задаем максиальную длину цикла (LENGTH-ebx-1)
                      ; чтобы не выйти за пределы массива внутри подцикла
                      mov ecx, LENGTH
                      sub ecx, ebx
                      sub ecx, 1

                      ; если итератор j дошел до предела (j >= ecx)
                      ; можно уже идти и перепроверять массив с следующей итерации
                      ; это будет выглядеть так:
                      ; i = 1
                      ; МАКСИМУМ = 10-1-1 (8)
                      ; j = 0 .. 8
                      ;
                      cmp edi, ecx
                      jge continue_first_loop

                      ; записываем текущее число по индексу и следующее число
                      ; следующее после текущего в массиве
                      mov eax, [buf+edi*4]
                      mov edx, [buf+edi*4+4]

                      ; сравниваем числа (a > b)
                      ; если первое число больше, чем второе, то мы должны поменять его местами
                      cmp eax, edx
                      jg swap

                      continue_second_loop:
                          inc edi
                          jmp second_loop

                      ; меняем числа местами
                      ; eax = edx
                      ; edx = eax
                      swap:
                        mov [buf+edi*4], edx
                        mov [buf+edi*4+4], eax

                        ; очищаем регистры и продолжаем подцикл
                        mov eax, 0
                        mov edx, 0
                        jmp continue_second_loop

                ; в подцикле действия закончились, увеличиваем шаг в основном цикле
                ; и идем сравнивать числа по новой
                continue_first_loop:
                        inc ebx
                        mov edi, 0
                        jmp first_loop

; очищаем все регистры, что были использованы
exit_loop:
        mov eax, 0
        mov ebx, 0
        mov ecx, 0
        mov edx, 0

        mov esi, 0
        mov edi, 0
        ret


; после второй задачи пришел к выводу, что рутины, которые повторяются в коде
; лучше выделить в отдельный блок и использовать регистры в качестве хранения аргументов для них
print_text:
        ; второй аргумент, даже если ему ничего не присвоено, будет равен 0
        ; будем считать, что не влияет на поведение программы
        push eax
        push esi
        call [printf]
        add esp, 8

        ; значение было использовано, лучше его очистить
        mov esi, 0
        mov eax, 0
        ret

; вывод '\n' в консоль
print_newline:
        mov esi, newline
        call print_text
        ret

section '.data' data readable writeable
        buf rd LENGTH

section '.rdata' data readable
        welcome db 'welcome to array sorter!',0
        wrong_size db 'error: wrong array size!',0
        filling db 'filling array with length: %d',0
        unsorted db 'unsorted array: ',0
        sorted db 'sorted array: ',0
        sorting db 'sorting....',0
        syntax db '%d ',0
        any_key db 'press any key to exit',0
        newline db 13,10,10 ; '\n'

section '.idata' data readable import
    library msvcrt, 'msvcrt.dll'
    import msvcrt, printf, 'printf', _getch,'_getch', scanf,'scanf'
