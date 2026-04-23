include '../INCLUDE/win32a.inc'

format PE console
entry start

section '.text' code executable
start:
        push welcome
        call [printf]
        add esp, 4

        call separate_text

        ; записывем значения в буффер из 4 байт (формат %3s)
	; таким образом можно будет определять ввод не только числа, но и символов
	; + можно определить конструкции а-ля "12a", "a12" и тому подобные
	; что в принципе не является вверным вводом
        push buffer
        push syntax
        call [scanf]
        add esp, 8

        call check_if_valid

        ; в функции выше при неверном вводе был записан результат в виде стейта 1 или 0 (true/false)
        ; если сейчас результат 0, то дальше идти смысла нет, можно выходить из программы
        cmp eax, 1
        jne exit

        ; eax был использоан для сохранения результата проверки валидации числа
        ; перед использованием в функции его нужно почистить
        mov eax, 0

        call calculate_factorial
        jmp exit

; выводит '\n' в консоль для переноса текста
separate_text:
        push newline
        call [printf]
        add esp, 4
        ret

; здесь нужно проверить введено число от нуля до 12
; но перед этим необходимо проверить правильность ввода цифр вместо символов
check_if_valid:
        ; для проверки ввода получаем символы, которые ввел пользователь
        ; в данном случае берутся первые два символа
        mov esi, buffer
        mov al, [esi]
        mov bl, [esi+1]
        mov dl, [esi+2]

        ; если было введено одно число (от 0 до 9), то буффер дальше будет пустым
        ; нет смысла идти дальше
        ; NOTE: после проверки число будет записано в value, его тоже нужно проверить
        cmp bl, 0
        je check_one_digit

        ; идем проверять две цифры
        jmp check_two_digits

        ret

; число ли это? (< 0 || > 9)
; ebx выступает также в роли стейта (1 = true, 0 = false)
check_is_digit:
        mov ebx, 1

        cmp edx, 0
        jl return_false
        cmp edx, 9
        jg return_false
        ret

return_false:
        mov ebx, 0
        ret

check_one_digit:
        ; преобрвазование символов в цифры (char - '0')
        sub al, '0'

        movzx eax, al
        mov [first_digit], eax

        ; если валидации пройдены - стейт не поменяется и будет равен 1 (true)
        mov eax, 1

        ; проверяем число на валидность
        ; при этом используя edx как аргумент, в котором будет храниться число
        mov edx, [first_digit]
        call check_is_digit
        mov edx, 0

        ; число не проходит валидацию, нет смысла считать что то дальше
        cmp ebx, 1
        jne invalid_input

        call make_number_from_digit
        call check_total_value

        ret

make_number_from_digit:
        ; записываем число в регистр
        ; после чего в value передаем значение из этого регистра
        ; [] = разыменовать указатель и прочитать данные из регистра ebx
        mov ebx, [first_digit]
        mov [value], ebx
                
        ; очищаем регистр: значение оттуда больше не нужно
        mov ebx, 0
        ret

check_two_digits:
        ; преобрвазование символов в цифры (char - '0')
        sub al, '0'
        sub bl, '0'

        ; если что то записано после числа от 0 до 12 (цифра или символ), то идти дальше смысла нет
        cmp dl, 0
        jne invalid_input

	; movzx - скопировать значение в регистр без знака
	; здесь он используется для передачи цифры в first/second digit
	; которые занимают 4 байта
        movzx eax, al
        mov [first_digit], eax

        movzx eax, bl
        mov [second_digit], eax

        ; тоже самое, что и при обработке однозначного числа
        ; если валидации пройдены - записываем дефолтный стейт как 1 (true)
        mov eax, 1

        ; принцип такой же, как и в проверке однозначного числа
        ; проверяем первое число
        mov edx, [first_digit]
        call check_is_digit
        mov edx, 0

        cmp ebx, 1
        jne invalid_input

        ; после чего проверяем второе
        mov edx, [second_digit]
        call check_is_digit
        mov edx, 0

        cmp ebx, 1
        jne invalid_input

        call make_number_from_digits
        call check_total_value

        ret

make_number_from_digits:
        ; принцип хранения в памяти +- тот же, что и в получении числа с одной цифры
        ; формула будет следующей
        ; value = first_digit * 10 + second_digit
                
        ; записываем число в регистр
        mov ebx, [first_digit]
                
        ; ebx *= 10
        imul ebx, 10
                
        ; ebx += second_digit
        add ebx, [second_digit]
                
        ; записываем число в value 
        mov [value], ebx

        mov ebx, 0
        ret

; проверяем итоговое значение, полученное со строки (>= 0 && <= 12)
check_total_value:
        cmp [value], 0
        jl invalid_input
        cmp [value], 12
        jg invalid_input
        ret

invalid_input:
        mov eax, 0

        push wrong_input
        call [printf]
        add esp, 4

        ret

; факториал был реализован через цикл
; фактически идет расчет а-ля result *= iter внутри цикла for (iter = 1; iter <= number; ++iter)
calculate_factorial:
        ; перед этим необходимо провести валидацию
        ; факториал 0 всегда равен 1
        cmp dword [value], 0
        mov [result], 1
        je print_factorial

; тело цикла
calc:
        ; умножение при помощи команды mul использует регистры
        ; т.к числа особо большие (т.е занимают 4 байта памяти)
        ; то было принято решение использовать регистры eax, ebx
        mov eax, [result]
        mov ebx, [iter]

        ; умножение через imul идет так
        ; eax = eax * ebx
        imul eax, ebx

        ; поэтому в перменную result записывается значение, сохраненное в регистре eax
        mov [result], eax

        ; итерация цикла увеличилась на 1
        inc [iter]

        ; из-за особенностей архитектуры невозможно проверить сразу две ячейки памяти напрямую
        ; поэтому iter будет передано в один из использованных регистров (например, eax)
        mov eax, [iter]

        ; дошел ли итератор, положенный в eax, до конца? (равен ли он числу, которое ввел пользователь?)
        ; если да, то цикл оборвется и пойдет вызов print_factorial
        cmp eax, [value]

        ; если нет
        ; то идем в начало цикла через метку calc
        jle calc ; jle = jump less equal, т.е число меньше или равно тому, что было задано, что также определяется через результат флага, будет ли он 0 или 1

print_factorial:
        push dword [result]
        push output
        call [printf]
        add esp, 8
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
        value dd ?
        iter dd 1
        result dd 1
        buffer rd 4

        first_digit dd 0
        second_digit dd 0

section '.rdata' data readable
        syntax db '%3s',0
        welcome db 'hi! please enter your number:',0
        any_key db 'press any key to exit',0
        leaving db 'leaving....',0
        output db  'factorial is: %d',0
        wrong_input db 'wrong input! please try again!',0
        newline db 13,10,10

section '.idata' data readable import
    library msvcrt, 'msvcrt.dll'
    import msvcrt, printf, 'printf', _getch,'_getch', scanf,'scanf'