; было выбрано решать задачи под win32 архитектуру для простоты использования
; чисто технически архитектура будет влиять на кол-во регистров, кол-во вмещаемой памяти и на calling convertion
; что, например, в данной задаче, не играет никакой роли

; программа делится на несколько секций:
; .text - где расположен сам код программы
; .data - отвечающая за переменные, которые будут использованы в дальнейшем
; .rdata - используемая для хранения каких-либо данных (например, текст или константы)
; .idata - хранящая в себе таблицу импортов (в данном случае импорты из DLL библиотек), которые используются в коде

include '../INCLUDE/win32a.inc'

format PE console
entry start

section '.text' code executable
start:
        ; вывод текста идет через вызов С функции из библиотеки
        ; т.к она принимает аргументы со стека, то приходится пушить значение

        ; подобный алгоритм будет использован везде, где нужно записать текст в консоль
        push welcome
        call [printf]
        add esp, 4; очистка стека

        call separate_text

        ; аргументы добавляются с конца из-за работы стека по принципу LIFO
        push number
        push syntax
        call [scanf]
        add esp, 8

        call check_if_valid

        ; после проверки числа на валидность идет возврат в start
        ; если число не равно 1 (т.е проверка не прошла и равна false), то идет выход из программы
        cmp eax, 1
        jne exit

        ; после чего идет проверка на четность, только после которой идет выход из программы
        call even_or_odd
        jmp exit

separate_text:
        push newline
        call [printf]
        add esp, 4
        ret

; данная проверка работает только на числа
; если же были переданы символы, то результат у числа будет всегда равен нулю
check_if_valid:
        ; для сохранения результата на валидацию лучше сохранить где-либо значение об этом (а-ля true/false)
        
        ; изначально значение всегда равно true, но если число не подоходит под условия задачи (>= 1 && <= 100), то значение поменяется на 0 (т.е false)
        mov eax, 1

        cmp dword [number], 1
        jl number_is_invalid ; jl = jump less, число меньше 1
                
        cmp dword [number], 100
        jg number_is_invalid ; jg = jump greater, число больше 100
        ret

number_is_invalid:
        ; задаем значение 0 (false) для использования в дальнейшем
        mov eax, 0

        push wrong_input
        call [printf]
        add esp, 4
        ret

even_or_odd:
        ; test используется для четности-нечетности, т.к все четные числа в битовой записи заканчиваются нулем
        ; а т.к test выполняет логическое И между операндами и записывает результат таблицы в флаг
        ; то результат идет через проверку наличия значения внутри флага
        test dword [number], 1

        jz is_even ; число четное, если флаг, используемый в таблице истинности, равен 0
        jnz is_odd ; если нет, то число нечетное
        ret

is_even:
        push even
        call [printf]
        add esp, 4
        ret

is_odd:
        push odd
        call [printf]
        add esp, 4
        ret

exit:
        call separate_text

        push any_key
        call [printf]
        add esp, 4

        push 0
        call [_getch]
        ret

section '.data' data readable writeable
        number dd ?

section '.rdata' data readable
        syntax db '%d',0
        welcome db 'hi! please enter your number:',0
        any_key db 'press any key to exit',0
        leaving db 'leaving....',0
        even db 'number is even!',0
        odd db 'number is odd!',0
        wrong_input db 'wrong input! please try again!',0
        newline db 13,10,10

section '.idata' data readable import
    library msvcrt, 'msvcrt.dll'
    import msvcrt, printf, 'printf', _getch,'_getch', scanf,'scanf'