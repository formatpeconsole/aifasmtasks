include '../INCLUDE/win32a.inc'

; для хранения данных был реализован массив из следующих данных:
; 1) имя - буффер на 32 байта
; 2) номер телефона - число на 4 байта

; по ТЗ было сказано, что нужно было сделать примерно 10 максимальных контактов
; в следствие этого был выделен массив, размером 36*10 (размер всех данных в блоке * количество блоков)

; это можно визуализировать через структуру:

; struct contact
;      .name rb 32
;      .number dd ?
; ends

; размер будет 36

; выделенная память в С-подобном языке будет выглядеть как:
; contact contacts[10]

; для записи данных были созданы условия:
;
; условия записи имени:
; 1) только английские заглавные или прописные буквы. никаких цифр, символов, знаков и т.память
; 2) максимальная длина - 31 символ (последний в буффере используется как '\0')
;
; условия для записи номера телефона:
; 1) он должен соотетствовать формату (9 цифр в номере)
; 2) он не должен быть меньше 0

format PE console
entry start

UI_MAX=4

MAX_CONTACTS=10
CONTACTS_SIZE=36
MAX_NAME_LENGTH=32

MIN_NUMBER_AMOUNT=100000000
MAX_NUMBER_AMOUNT=999999999

section '.text' code executable
start:
    mov esi, welcome
    call print_text
    call print_newline

    mov [contact_index], 0

selection_loop:
         mov eax, 0
         mov [index], 0

         mov esi, option
         call print_text
         call print_newline

         mov esi, contact_add
         call print_text
         call print_newline

         mov esi, contact_remove
         call print_text
         call print_newline

         mov esi, contact_view
         call print_text
         call print_newline

         mov esi, leave_program
         call print_text
         call print_newline

         push index
         push option_input
         call [scanf]
         add esp, 8
         call clear_input_buffer

	 ; как и в пятой задаче
	 ; идет проверка на корректность ввода номера
         cmp [index], 0
         jle wrong_input_error

         cmp [index], UI_MAX
         jg wrong_input_error

         cmp [index], UI_MAX
         je exit_program

	 ; здесь уже идут сами действия
         cmp [index], 1
         je add_contact

         cmp [index], 2
         je remove_contact

         cmp [index], 3
         je view_all_contacts

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

;                                                                                              ;
;                                                                                              ;
;                                                                                              ;
;	===================== [ РУТИНЫ ДЛЯ ЗАПИСИ И УДАЛЕНИЯ КОНТАКТОВ ] ===================== ;
;                                                                                              ;
;                                                                                              ;
;                                                                                              ;
;                                                                                              ;
;	================== [ РУТИНЫ ДЛЯ ПРОВЕРКИ КОРРЕКТНОСТИ ВВОДА ИМЕНИ ] ================== ;

; решение было следующим:
; пройтись по всему введеному буфферу и проверить каждый символ на то, является ли он числом или символом
; сначала идет проверка на заглавные буквы - если как таковые есть, то в регистр edi записывается стейт true или false (0/1)
; после чего идет проверка строчных букв, где уже результат валидности записывается в регистр ecx (также true/false или 0/1)
; после чего эти регистры складываются между собой
; например:
; 
;     если есть только прописные буквы:
;        ecx = 1
;        edi = 0
;
;     edi += ecx
;     edi = 1
;
;
;     если есть только строчные буквы:
;        ecx = 0
;        edi = 1
;
;     edi += ecx
;     edi = 1
;
;
;     если есть и то и другое:
;        ecx = 1
;        edi = 1
;
;     edi += ecx
;     edi = 2
;
; если ни один из символов не будет верным (оба регистры равны 0), то и результат будет 0
; и ТОЛЬКО тогда, когда результат будет равен 0, можно сказать, что в буффере были записаны неправильные символы

; вывод сообщения о том, что имя было введено неправильно
wrong_name_error:
        mov esi, wrong_name
        call print_text
        call print_newline

        call clear_input_buffer

	; очистка буфферов, в которые шла запись
	; чтобы начать добавление контакта с самого начала
        mov edi, 0
        mov [buf], 0
        mov [number_buf], 0

        jmp add_contact

; порверка заглавных букв (результат записан в edi)
check_false:
        mov edi, 0
        ret

check_capital:
        cmp eax, 65 ; 'A'
        jl check_false; < 'A'

        cmp eax, 90 ; 'Z'
        jg check_false; > 'Z'

        mov edi, 1
        ret

; проверка строчных букв (результат записан в ecx)
check_lower_false:
        mov ecx, 0
        ret

check_lowercase:
        cmp eax, 97 ; 'a'
        jl check_lower_false ; < 'a'

        cmp eax, 122 ; 'z'
        jg check_lower_false ; > 'z'

        mov ecx, 1
        ret

; проверка корректности ввода имени
check_name:
        mov eax, 0
        mov ebx, 0

        mov ecx, 1
        mov edi, 1

	; проход по каждому символу
        name_loop:
                cmp ebx, 32
                jge exit_name_loop

	        ; если вышли за пределы буффера (последний символ равен 0)
                movzx eax, byte [buf+ebx]
                cmp eax, 0
                je exit_name_loop

	        ; проверяем символ на заглавные и прописные буквы
                call check_capital
                call check_lowercase

                add edi, ecx

                cmp edi, 0
                je wrong_name_error

                inc ebx
                jmp name_loop

exit_name_loop:
        mov eax, 0
        mov ebx, 0
        mov ecx, 0
        mov edi, 0
        ret

;	================== [ РУТИНЫ ДЛЯ ПРОВЕРКИ ОСТАЛЬНЫХ ДАННЫХ ] ================== ;
wrong_phone_error:
        mov esi, wrong_number
        call print_text
        call print_newline

        call clear_input_buffer

        mov edx, 0
        mov edi, 0
        mov [buf], 0
        mov [number_buf], 0

        jmp add_contact

; слишком много контактов
contacts_overflow:
        mov esi, too_much
        call print_text
        call print_newline
        call print_newline

        call clear_input_buffer
        jmp selection_loop

;	================== [ РУТИНЫ ДЛЯ ДОБАВЛЕНИЯ И УДАЛЕНИЯ КОНТАКТОВ ] ================== ;

; общий принцип записи и удаления был взят из 4ой задачи, но был немного модифицирован
; вместо метки INVALID просто идет сдвиг данных
; находящихся после блока, который нужно удалить

add_contact:
	; проверка на то, было ли уже записано 10 контактов
	; если да, то выходим из цикла записи
        cmp [contact_index], MAX_CONTACTS
        jge contacts_overflow

	; просим пользователя ввести имя
        mov esi, enter_name
        call print_text

        push buf
        push contact_name
        call [scanf]
        add esp, 8

	; очищаем буффер на случай, если пользователь введет что то на подобии 121r23r_r12r1r21r
	; если данные будут не валидны - то буфер очистится и в памяти ничего не останется
        call clear_input_buffer

	; проверяем имя на валидность
        call check_name

	; просим пользователя ввести номер телефона
        mov esi, enter_number
        call print_text

        push number_buf
        push contact_number
        call [scanf]
        add esp, 8

	; делаем ту-же самую процедуру для защиты от 234123r123rr213123z2131r
        call clear_input_buffer

	; проверяем формат номера
	; если число имеет меньше 9 цифр, либо же больше 10
	; то мы выходим из записи и сообщаем об ошибке
        cmp [number_buf], MIN_NUMBER_AMOUNT
        jle wrong_phone_error

        cmp [number_buf], MAX_NUMBER_AMOUNT
        jge wrong_phone_error

        call print_newline

	; данные прошли проверку
	; теперь копируем их в массив блоков
		
	; получаем индекс
	; с которого нужно начать записывать контакт
	; не забываем, что индекс будет равен i * CONTACTS_SIZE (1 * 36, например)
        mov eax, [contact_index]
        imul eax, CONTACTS_SIZE

	; загружаем адрес блока из массива 
	; равносильно &contacts[index] в C-подобном языке
        lea edi, [contacts + eax]

	; производим копирование данных в блок
	; первым идет копирование имени
		
	; размер у буффера что в блоке, что в вводе равен 32 байтам
	; поэтому копируем целиком и полностью
        push 32
        push buf
        push edi
        call [memcpy]
        add esp, 12

	; после чего копируем число, записанное в буффер
	; копирование будет приосходит в блок по адресу buf+MAX_NAME_LENGTH
	; т.е копирование по адресу, перед которым находится буффер с именем контакта
        mov ecx, [number_buf]
        mov [edi+MAX_NAME_LENGTH], ecx

	; сообщаем об этом в консоль
        mov esi, contact_added
        call print_text
        call print_newline

        call print_newline

	; чистим все регистры и буфферы для дальнейгешо использования в цикле
        mov [buf], 0
        mov [number_buf], 0
        mov eax, 0
        mov ecx, 0
        mov esi, 0
        mov edi, 0

	; увеличиваем кол-во записанных контактов
        inc [contact_index]

        jmp selection_loop


contact_list_empty:
        mov esi, empty_contact_list
        call print_text
        call print_newline
        call print_newline

        jmp selection_loop
		
not_found_contact:
        mov esi, contact_not_found
        call print_text
        call print_newline
        call print_newline
        jmp selection_loop

; уданеие контакта реализовано следующим образом:
; каждый раз, когда находится нужный контакт по имени
; все элементы, которые были добавлены ПОСЛЕ этого контакта, смещаются на шаг влево
; после чего удаляемый контакт стирается
remove_contact:
	; контактов нет - удалять нечего
	; выводим сообщение об этом
        cmp [contact_index], 0
        jle contact_list_empty

	; просим пользователя ввести имя контакта
        mov esi, enter_name
        call print_text

        push buf
        push contact_name
        call [scanf]
        add esp, 8

	; проходимся по всем контактам
        mov ebx, 0
        mov ecx, 0
        find_contact_loop:
		; прошли через все блоки но так и не нашли ничего
		; можно выйти из цикла и сообщить об этом
                cmp ebx, [contact_index]
                jge not_found_contact

		; индекс доступа к каждому блоку 
		; i * CONTACTS_SIZE (36)
                mov eax, ebx
                imul eax, CONTACTS_SIZE

		; загружаем данные из контакта
                lea edi, [contacts+eax]

		; после чего сравниваем строки
		; чтобы не было такого, что ищется подстрока в условном "testTESTtest"
		; при вводе пользователем "test" или "TEST"
		; было решено использовать сравнение строки во всем буффере
		; поэтому нужно указывать длину
                push MAX_NAME_LENGTH
                push edi
                push buf
                call [strncmp]
                add esp, 12

		; если результат, записанный в eax 
		; равен 0 (строка найдена)
		; то можно приступить к удалению
                cmp eax, 0
                je remove_found

		; в противном случае идем дальше по списку
                inc ebx
                jmp find_contact_loop

remove_found:
	; индекс был уже использован
	; начинаем сначала
        mov eax, ebx
        remove_shift_loop:
		; берем индекс + 1
		; где находится блок
		; который нужно скопировать в предыдущее место
                mov ecx, eax
                inc ecx
				
		; если дошли до предела по всем валидным блокам
                cmp ecx, [contact_index]
                jge remove_done

		; не забываем, что размер блока равен CONTACTS_SIZE
		; и каджый блок находится по адресу contacts + i * CONTACTS_SIZE
                imul ecx, CONTACTS_SIZE
		imul eax, CONTACTS_SIZE
				
		; загружаем блок, который нужно скопировать
                lea esi, [contacts + ecx]

                ; загружаем блок, куда нужно скопировать данные
		; на этом месте находится невалидный 
				
		; после первой итерации будут скопированы остальные блоки
                lea edi, [contacts + eax]

		; производим копирование
                push CONTACTS_SIZE
                push esi
                push edi
                call [memcpy]
                add esp, 12

		; идем дальше по циклу для копирования остальных блоков
                inc eax
                jmp remove_shift_loop

remove_done:
	; уменьшаем количество добавленных контактов
	; раз был удален один из них
        dec [contact_index]
		
        mov esi, contact_removed
        call print_text
        call print_newline
        call print_newline
        jmp selection_loop

;	================== [ РУТИНЫ ДЛЯ ПРОСМОТРА КОНТАКТОВ ] ================== ;
; тут просто идет просмотр всех данных со всех блоков
; смотрим блоки в границе [0, contact_index] 
; т.к в остальных случаях может находиться мусор
; ибо записи блоков больше не было

exit_view_loop:
        call print_newline
        jmp selection_loop

view_all_contacts:
	; контактов нет - выводим сообщение и выходим из цикла
        cmp [contact_index], 0
        jle contact_list_empty

        mov ebx, 0

        mov esi, contact_list
        call print_text
        call print_newline

	; идем по циклу
        view_contact_loop:
                cmp ebx, [contact_index]
                jge exit_view_loop

                ; принцип получения данных в блоках такой же, как и в других рутинах
                mov eax, ebx
                imul eax, CONTACTS_SIZE

                ; загружаем адрес массива по индексу
				
                ; технически в начале каждого блока лежит указатель на буффер
                ; длинной в 32 байта
                ; в котором лежит имя контакта
                lea edi, [contacts+eax]
                mov esi, edi

                ; получаем адрес номера телефона
                ; он расположен после блока с именем контакта
                ; dword взят т.к это число типа int
                ; что занимает 4 байта в х32 архитектуре
                mov edx, dword [edi+MAX_NAME_LENGTH]

                ; увеличиваем индекс для следующей итерации
                inc ebx

                ; выводим данные на экран
                ; данные формата:
                ; 1. Alex = 123465789
                ; 2. Lena - 147852369
                push edx
                push esi
                push ebx
                push contact_item
                call [printf]
                add esp, 16

                call print_newline

                jmp view_contact_loop

        jmp selection_loop

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
        index dd ?
        contact_index dd ?
        contact_counter dd ?
        contacts rb CONTACTS_SIZE * MAX_CONTACTS

        buf rb 32
        number_buf dd ?

section '.rdata' data readable
        welcome db 'Welcome to phonebook!',0
        option db 'Choose option: ', 0
        contact_add db '1. Add contact', 0
        contact_remove db '2. Remove contact', 0
        contact_view db '3. View contacts', 0
        leave_program db '4. Exit', 0

        option_input db '%d', 0

        contact_name db '%31s', 0
        contact_number db '%d', 0

        enter_name db 'Enter name: ', 0
        wrong_name db 'Name is wrong! Press enter to continue', 0

        enter_number db 'Enter number. Format - [1XXXXXXXX]: ', 0
        wrong_number db 'Number is wrong! Press enter to continue', 0

        wrong_value_text db 'Entered value is wrong! Press enter to continue', 0

        too_much db 'Too much contacts! Please try again',0

        contact_added db 'Contact added!', 0
        entered_name db 'Current name is: %s', 0
        entered_number db 'Current number is: %d', 0

        contact_not_found db 'Contact not found!', 0
        contact_removed db 'Contact removed!', 0

        contact_list db 'Current contact list:', 0
        empty_contact_list db 'Contact list is empty!', 0
        contact_item db '%d. %s - %d', 0

        value_input db '%f', 0
        debug_str db '%s', 0

        any_key db 'Press any key to exit', 0
        newline db 13,10 ; '\n'

section '.idata' data readable import
    library msvcrt, 'msvcrt.dll'
    import msvcrt, printf, 'printf', _getch,'_getch',\
           scanf,'scanf',malloc,'malloc',free,'free',\
           memcpy,'memcpy',memset,'memset',getchar,'getchar',\
           strncmp,'strncmp'