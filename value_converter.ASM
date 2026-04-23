include '../INCLUDE/win32a.inc'

format PE console
entry start

UI_MAX=8

section '.text' code executable
start:
    mov esi, welcome
    call print_text
    call print_newline

; ввод операции было решено сделать в цикле
selection_loop:
         ; перед использованием значений стоит их очистить
         ; это будет полезно также и для завершения предыдущей итерации цикла
         mov eax, 0
         mov [index], 0
         mov [value], 0

         ; выводим возможные варианты конвертации на экран
         mov esi, option
         call print_text
         call print_newline

         mov esi, meters_to_km
         call print_text
         call print_newline

         mov esi, cm_to_meters
         call print_text
         call print_newline

         mov esi, km_to_meters
         call print_text
         call print_newline

         mov esi, inch_to_cm
         call print_text
         call print_newline

         mov esi, celcius_to_kelvin
         call print_text
         call print_newline

         mov esi, celcius_to_fahrenheit
         call print_text
         call print_newline

         mov esi, kilograms_to_grams
         call print_text
         call print_newline

         mov esi, leave_program
         call print_text
         call print_newline

         call print_newline

         ; запрашиваем у пользователя ввод
         push index
         push option_input
         call [scanf]
         add esp, 8
         call clear_input_buffer

         ; если ввод вышел за пределы или он неправильный - начинаем все сначала
         ; (index <= 0 || index > 8)
         cmp [index], 0
         jle wrong_input_error

         cmp [index], UI_MAX
         jg wrong_input_error

         ; выходим из цикла, если пользователь решил выбрать 8 пункт
         cmp [index], UI_MAX
         je exit_program

         mov esi, enter_value
         call print_text
         call print_newline

         ; после чего просим ввод значения у пользователя
         push value
         push value_input
         call [scanf]
         add esp, 8
         call clear_input_buffer

         ; тоже самое
         ; если ввод неправильный - идем в начало цикла
         cmp [value], 0
         je wrong_input_error
         call print_newline
         mov eax, 0

         ; также нужно проверить, ввел ли пользователь правильное число
         ; которое не равно FLT_MAX
         call check_float

         ; теперь уже можно конвертировать значения
         mov eax, [index]
         cmp eax, 1
         je m_to_km

         cmp eax, 2
         je cm_to_m

         cmp eax, 3
         je km_to_m

         cmp eax, 4
         je ch_to_cm

         cmp eax, 5
         je c_to_kv

         cmp eax, 6
         je c_to_fh

         cmp eax, 7
         je kg_to_g

         call print_newline
         jmp selection_loop

wrong_input_error:
        mov esi, wrong_value_text
        call print_text
        call print_newline
        call print_newline

        call clear_input_buffer

        jmp selection_loop

clear_input_buffer:
        clear_loop:
                call [getchar]
                cmp al, 13
                je clear_loop
                cmp al, 10
                je clear_end

                jmp clear_loop
        clear_end:
                ret

; самым простым способом для проверки float 
; является проверка на то, выходит ли оно за пределы FLT_MAX
; 
; проще проверять число по модулю (fabsf(value) >= FLT_MAX)
check_float:
        ; загружаем число в регистр
        fld [value]
		
        ; считаем его модуль
        fabs
		
        ; загружаем константу FLT_MAX
        fld [flt_max]
		
        ; после чего сравниваем оба числа (st1 = flt_max, st0 = value)
        ; здесь также автоматически очищается регистр st1 (fcomip = float compare int pop)
        fcomip st1
		
        ; если по какой то причине число не валидное (value >= flt_max)
        ; то сообщаем об ошибке и начинаем цикл сначала
        jbe wrong_input_error

        ; в другом же случае - очищаем еще один регистр
        fstp st0

        ret

; операции над float были реализованы через использование FPU инструкций
; все числа хранятся в отдельных для этого регистрах (st0, st1....)
m_to_km:
        ; данный принцип использован в других рутинах
        ; для начала загружаем числа в регистры (st0, st1)
        fld [value]
        fld [thousand]
                
        ; т.к числа идут с конца
        ; то в данном случае произойдет деление value на тысячу
        ; записанную как float 
        ; (value = value / 1000)
        fdiv st1, st0

        ; очищаем стек, выгружая число st0 (thousand)
        fstp st0
                
        ; копируем число, записанное в value
        ; в переменную result
        ; после чего также очищаем стек (fstp = float store pop)
        fstp [result]

        ; выводим результат на экран
        mov esi, value_km
        call print_result
        call print_newline

        jmp selection_loop

; здесь идет все по аналогии
; 1 m = 100 cm
;
; x = 100 cm
; m = x / 100
cm_to_m:
        fld [value]
        fld [hundred]
        fdiv st1, st0

        fstp st0
        fstp [result]

        mov esi, value_m
        call print_result
        call print_newline
        jmp selection_loop

; 1 km = 1000 m
; 
; x = 1 km
; m = x * 1000
km_to_m:
        fld [value]
        fld [thousand]
        fmul st0, st1

        fstp st1
        fstp [result]

        mov esi, value_m
        call print_result
        call print_newline

        jmp selection_loop

; 1 inch = 2.54 cm
; 
; x = 100 inches 
; cm = 100 * 2.54
ch_to_cm:
        fld [value]
        fld [inches]
        fmul st1, st0

        fstp st0
        fstp [result]

        mov esi, value_cm
        call print_result
        call print_newline

        jmp selection_loop

; 1 kv = 273.15
;
; x = 100 c
; kv = 100 + 273.15
c_to_kv:
        fld [value]
        fld [kelvin]
        fadd st1, st0

        fstp st0
        fstp [result]

        mov esi, value_kv
        call print_result
        call print_newline
        jmp selection_loop

; 1 c = 33.8 fh
;
; x = 100 c
; fh = 100 * 1.8 + 32
c_to_fh:
        fld [value]
        fld [fahrenheit_first]
        fmul st1, st0
        fstp st0

        fld [fahrenheit_second]
        fadd st1, st0

        fstp st0
        fstp [result]

        mov esi, value_fh
        call print_result
        call print_newline
        jmp selection_loop

; 1 kg = 1000 g
;
; x = 1 kg
; g = 1 * 1000
kg_to_g:
        fld [value]
        fld [thousand]
        fmul st1, st0

        fstp st0
        fstp [result]

        mov esi, value_g
        call print_result
        call print_newline
        jmp selection_loop

print_result:
        ; загружаем число в стек
        fld [result]
                
        ; резервируем место для числа в стеке, чтобы в итоге вывести его в запись
        ; т.е двигаем stack poiner на 8 байт и зануляем все
        ; что было записано до этого
        sub esp, 8

        ; после чего загружаем число в стек
        ; а после очищаем регистры, хранящие числа с плавающей точкой
        ; fstp = float store pop
        fstp qword [esp]
        push esi
        call [printf]
        add esp, 12

        fstp st0
        mov esi, 0

        call print_newline
        ret

exit_program:
        push any_key
        call [printf]
        add esp, 4

        push 0
        call [_getch]
        ret

print_text:
        push eax
        push esi
        call [printf]
        add esp, 8

        mov esi, 0
        mov eax, 0
        ret

print_newline:
        mov esi, newline
        call print_text
        ret

section '.data' data readable writeable
        value dd 1
        result dd ?
        index dd ?
        thousand dd 1000.0
        hundred dd 100.0
        inches dd 2.54
        kelvin dd 273.15
        fahrenheit_first dd 1.8
        fahrenheit_second dd 32.0
        flt_max dd 0x7F7FFFFF

section '.rdata' data readable
        welcome db 'Welcome to numbers converter!',0
        option db 'Choose option: ', 0
        meters_to_km db '1. Meters to kilometers', 0
        cm_to_meters db '2. Cantimeters to meters', 0
        km_to_meters db '3. Kilometers to meters', 0
        inch_to_cm db '4. Inch to cantimeters', 0
        celcius_to_kelvin db '5. Celcius to kelvin', 0
        celcius_to_fahrenheit db '6. Celcius to fahrenheit', 0
        kilograms_to_grams db '7. Kilograms to grams', 0
        leave_program db '8. Exit', 0

        option_input db '%d', 0

        enter_value db 'Enter value: ', 0
        wrong_value_text db 'Entered value is wrong! Press enter to continue', 0

        value_input db '%f', 0

        value_km db 'Result is: %.3fkm', 0
        value_m db 'Result is: %.3fm', 0
        value_cm db 'Result is: %.3fcm', 0
        value_kv db 'Result is: %.2fK', 0
        value_fh db 'Result is: %.2fF',0
        value_g db 'Result is: %.2fg', 0

        any_key db 'Press any key to exit', 0
        newline db 13,10 ; '\n'

section '.idata' data readable import
    library msvcrt, 'msvcrt.dll'
    import msvcrt, printf, 'printf', _getch,'_getch', scanf,'scanf',malloc,'malloc',free,'free',memcpy,'memcpy',getchar,'getchar'
