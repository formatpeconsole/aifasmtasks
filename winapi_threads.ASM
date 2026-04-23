format PE console
entry start

include '../INCLUDE/win32a.inc'

; максимальное количество чисел в массиве (10
MAX_SIZE=10

; размер хранимого числа типа int в байтах
INT_SIZE=4

; время ожидания в милисекундах (1 секунда)
PAUSE_MS=1000

INFINITE=0xFFFFFFFF

; здесь идет сортировка массива и счет суммы всех чисел
; в массив изначально записаны числа [ 1, 3, 5, 10, 8, 9, 7, -6, 11, 14 ]

; логика потоков следующая:
; создается два потока для работы с массивом (сортировка и счет суммы)
;
; что делает поток сортировки:
;	проверяется, занят ли мьютекс другим потоком 
;	сортируется массив
; 	поток останавливается на секунду (нужно для демонстрации того, что один поток ждет другой)
;	идет уведомление о том, что поток завершил свою работу через евент
;
;
; что делает поток счета суммы:
; 	===> ЖДЕТ, ПОКА поток сортировки выполнит свою работу
;		  [+] 
;			\ 
;			 \
;			  ждет, пока мьютекс освободится (т.к массив сортировки это уже сделал, то можно идти дальше)
;		      выполняет счет суммы всех чисел в массиве через цикл
;			  выводит числа на экран
;		 
;


section '.text' code readable executable
start:
        mov esi, welcome
        call print_text
        call print_newline

        ;==================== [ СОЗДАНИЕ МЬЮТЕКСА ] ====================;
        mov esi, creating_mutex
        call print_text

        invoke CreateMutex, 0, 0, 0
        test eax, eax
        jz print_error

        mov [mutex], eax
        call print_success
        ;===============================================================;

        ;==================== [ СОЗДАНИЕ ПОТОКОВ ] =====================;
		
	; создаем поток сортировки
        mov esi, creating_sort_thread
        call print_text

        invoke CreateThread, 0, 0, sortingThread, 0, 0, 0
		
	; если по какой то причине произошла ошибка, то выходим из программы
        test eax, eax
        jz print_error

        mov [sort_thread], eax
        call print_success

	; создаем обработчик событий для потока сортировки
        mov esi, creating_sort_event
        call print_text

        invoke CreateEvent, 0, 0, 0, 0
        test eax, eax
        jz print_error
        mov [sorted_event], eax
        call print_success

	; создание потока счета суммы идет по тому же принципу
	; что и создание потока сортировки массива
        mov esi, creating_sum_thread
        call print_text

        invoke CreateThread, 0, 0, calcSumThread, 0, 0, 0
        test eax, eax
        jz print_error

        mov [sum_thread], eax
        call print_success

        mov esi, creating_sum_event
        call print_text

        invoke CreateEvent, 0, 0, 0, 0
        test eax, eax
        jz print_error
        mov [calculated_sum_event], eax
        call print_success
        ;===============================================================;

        ; ----------------------------------------------- ;

        ;==================== [ ОЖИДАНИЕ РЕЗУЛЬТАТА ] ====================;
        mov esi, waiting_threads
        call print_text
        call print_newline

	; т.к сумма в потоке считается только ПОСЛЕ того, как поток сотировки завершит свою работу
	; ждем, пока он завершит свою работу, уведомив нас об этом через событие 
        invoke WaitForSingleObject, [calculated_sum_event], INFINITE
        call print_success
        call print_newline
        ;===============================================================;

	; после чего можно освобождать память
	; выделенную под работу с потоками
        invoke CloseHandle, sort_thread
        invoke CloseHandle, sum_thread
        invoke CloseHandle, [sorted_event]
        invoke CloseHandle, [calculated_sum_event]
        invoke CloseHandle, mutex

        jmp exit_program

proc calcSumThread lParam
     ; ждем, пока поток сортировки завершит свою работу
     invoke WaitForSingleObject, [sorted_event], INFINITE
	 
     ; ждем, пока освободиться мьютекс
     invoke WaitForSingleObject, mutex, INFINITE

     ; считаем сумму через цикл
     mov ebx, 0
     calc_sum_loop:
                cmp ebx, MAX_SIZE
                jge exit_sum_loop

		; не забываем, что здесь хранятся числа типа INT_SIZE
		; поэтому шаг по массиву будет i*INT_SIZE (4)
                mov eax, [numbers+ebx*INT_SIZE]
                add [numbers_sum], eax

                inc ebx
                jmp calc_sum_loop

     ; завершаем счет
     exit_sum_loop:
		; очищаем регистр счета
                mov ebx, 0
				
		; выводим сумму на экран
                mov eax, [numbers_sum]
                mov esi, sum_is
                call print_text
                call print_newline
				
		; освобождаем поток
                invoke ReleaseMutex, mutex
				
		; уведомляем о событии, записав значение в calculated_sum_event
                invoke SetEvent, [calculated_sum_event]
				
		; после чего можно спокойно завершить работу
                invoke ExitThread, 0
                ret
     ret
endp

; принцип ожидания тот же самый, что и в первом потоке
proc sortingThread lParam
     invoke WaitForSingleObject, mutex, INFINITE

     mov eax, 0
     mov ebx, 0
     mov ecx, 0
     mov edx, 0

     mov esi, 0
     mov edi, 0

     ; сортируем массив пузырьком (алгоритм взят из третьей задачи)
     sort_first_loop:
                cmp ebx, MAX_SIZE-1
                jge exit_sort_loop

                sort_second_loop:
                        mov ecx, MAX_SIZE
                        sub ecx, ebx
                        sub ecx, 1

                        cmp edi, ecx
                        jge continue_first_loop

                        mov eax, [numbers+edi*INT_SIZE]
                        mov edx, [numbers+edi*INT_SIZE+INT_SIZE]

                        cmp eax, edx
                        jg swap

                        continue_second_loop:
                                inc edi
                                jmp sort_second_loop

                        swap:
                                mov [numbers+edi*INT_SIZE], edx
                                mov [numbers+edi*INT_SIZE+INT_SIZE], eax
                                mov eax, 0
                                mov edx, 0
                                jmp continue_second_loop


                        continue_first_loop:
                                inc ebx
                                mov edi, 0
                                jmp sort_first_loop

     exit_sort_loop:
		; поток "Засыпает" на одну секунду
                invoke Sleep, PAUSE_MS
				
		; после чего сортированный массив выводится на экран
                call print_array

		; теперь можно спокойно завершать работу 
		; и сообщить о том, что сортировка завершена 

                invoke ReleaseMutex, mutex
                invoke SetEvent, [sorted_event]
                invoke ExitThread, 0
                ret

     ret
endp

print_error:
        mov esi, error_message
        call print_text
        call print_newline

        jmp exit_program

print_success:
        mov esi, done_message
        call print_text
        call print_newline
        ret

print_array:
        mov ebx, 0
        print_loop:
                cmp ebx, MAX_SIZE
                jge exit_loop

                mov eax, [numbers+ebx*INT_SIZE]
                mov esi, text_format
                call print_text
                inc ebx
                jmp print_loop
        ret

exit_loop:
        call print_newline
        mov ebx, 0
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

exit_program:
        push any_key
        call [printf]
        add esp, 4

        push 0
        call [_getch]
        ret

section '.data' data readable writeable
        numbers dd 1, 3, 5, 10, 8, 9, 7, -6, 11, 14
        numbers_sum dd ?
        sort_thread dd ?
        sum_thread dd ?
        sorted_event dd ?
        calculated_sum_event dd ?
        mutex dd ?

section '.rdata' data readable
        welcome db 'Welcome to multi-threaded array tasks!',0
        any_key db 'Press any key to exit', 0

        creating_mutex db 'Creating mutex... ', 0
        creating_sort_thread db 'Creating sorting thread... ', 0
        creating_sort_event db 'Creating sorting event...', 0

        creating_sum_thread db 'Creating sum calculation thread... ', 0
        creating_sum_event db 'Creating sum calculation event...', 0

        waiting_threads db 'Waiting for threads gets finished...', 0

        done_message db '[+] Done!', 0
        error_message db '[-] Error occured! Please try again!', 0

        sum_is db 'Sum of numbers is: %d',0

        text_format db '%d ', 0
        newline db 13,10 ; '\n'

section '.idata' import data readable writeable
    library kernel,'KERNEL32.DLL',\
          user,'USER32.DLL',\
          msvcrt, 'msvcrt.dll'

    import kernel,\
          WaitForSingleObject, 'WaitForSingleObject',\
          CloseHandle, 'CloseHandle',\
          CreateThread, 'CreateThread',\
          CreateMutex, 'CreateMutexA',\
          ReleaseMutex, 'ReleaseMutex',\
          CreateEvent, 'CreateEventA',\
          SetEvent, 'SetEvent',\
          ExitThread, 'ExitThread',\
          Sleep, 'Sleep'

    import msvcrt, printf, 'printf', _getch,'_getch',\
          scanf,'scanf',malloc,'malloc',free,'free',\
          memcpy,'memcpy',memset,'memset',getchar,'getchar',\
          strncmp,'strncmp'


