include '../INCLUDE/win32a.inc'

format PE console
entry start

; для реализации динамического массива я использовал следующий подход:
; создается массив размером больше, чем записано изначально элементов (в данном случае 2)
; после чего в него добавляются элементы по одному с начала 
;
; например:
; [0, 0]
; решили добавить 10
;
; что будет в итоге:
; [10, 0]
;
; при добавлении элементов, больше, чем указанный максимальный размер
; массив пересоздается и туда копируются все записанные элементы 
; для сохранения количества элементов, записаных в массив, был добавлен счетчик (buf_index)
;
; в итоге будет создан новый массив, который будет размеров х2 больше, чем был до этого
; почему х2? решил для удобства, не более, т.е теперь при добавлении третьего элемента размер массива будет 4, а не 2
; но стоит также не забывать, что для asm неизвестно, какого размера будут хранится числа
; поэтому размер итогового массива будет 4 * INT_SIZE (sizeof(int), в х32 архитектуре он равен 4)
;
; приведу пример работы:
; [10, 20]
; add_element->30
; 
; создается новый массив:
; [0, 0, 0, 0, 0, 0]
; туда копируются элементы из изначального массива, т.е это будет вот так:
; [10, 20, 0, 0, 0, 0]
; после чего добавляется новый элемент
; [10, 20, 30, 0, 0, 0]
; и таким образом очищается старый буффер, который в итоге переопределен на новый массив, который может вмещать больше чисел

; здесь же хочется спросить, тогда зачем здесь еще счетчик, если размер массива 6, а не 3? 
; ответ простой: чтобы использовать его для операций с ЗАПИСАННЫМИ числами в массиве, а не со всем массивом целиком
; например, при попытке вывести элементы из массива итерации цикла идут не по всему массиву, а по количеству в него записанных элементов
; в данном случае с 0 до 2 (т.к счет идет с нуля)
; например:
;
;         -> будут выведены только эти числа в консоль (Current array: [10, 20, 30])
;        / 
;    --------
;   /   /   /
; [10, 20, 30, 0, 0, 0]
; 
; такой подход обеспечивает более легкий доступ к записанной памяти и реализации операций по работе с массивом
;
;
; также данный подход позволяет эффективно использовать поиск элементов по индексу
; здесь был использован бинарный поиск для нахождения индекса числа, с которым в будущем придется работать
; в данном коде были реализованы операции добавления, удаления и поиска элемента внутри массива

INT_SIZE = 4
INT_MAX = 0x7FFFFFFF

section '.text' code executable
start:
    mov [max_buf_size], 2
    mov [buf_index], 0

    mov esi, welcome
    call print_text
    call print_newline

    call create_array

    mov esi, current_array
    call print_text
    call print_array
    call print_newline

    ; добавление числа в массив
    ; для удобства был выбран регистр edx
    mov edx, 10
    call push_element

    mov edx, 20
    call push_element

    mov edx, 30
    call push_element

    call print_newline

    ; поиск индекса для существующего элемента
    ; для удобства был выбран регистр edi для хранения самого значения
    ; результат (возможный индекс) хранится в ebx
    mov edi, 20
    call find_element_index 

    ; т.к тут до этого был найден индекс, удаление элемента будет произведено
    ; без определения числа, которое должно хранится в ebx
    call erase_element

    ; в этих же случаях будет удаление по индексу 0
    mov ebx, 0
    call erase_element

    mov ebx, 0
    call erase_element

    call print_newline

    ; в этом случае можно посмотреть
    ; как будет работать бинарный поиск
    ; для этого были добавлены рандомные значения в массив
    mov edx, 56
    call push_element

    mov edx, -12
    call push_element

    mov edx, 20
    call push_element
        
    mov edx, 100
    call push_element
        
    mov edx, -100
    call push_element
        
    call print_newline

    ; из-за особенности работы алгоритма потребуется отсортировать массив
    ; перед тем, как искать элемент
    call sort_array
    call print_newline

    ; вызов бинарного поиска
    ; результат хранится в том же регистре
    ; в котором хранит значение линейный поиск (EBX)
    mov edi, 56
    call find_element_index_binary
     
    ; теперь можно удалить элемент, найденный по индексу
    call erase_element
    call print_newline

    jmp exit_program
    ret

exit_program:
        call destroy_array

        push any_key
        call [printf]
        add esp, 4

        push 0
        call [_getch]
        ret
                
;                                                                                      ;
;                                                                                      ;
; ================ [ ОПЕРАЦИИ, СВЯЗАННЫЕ С РАБОТОЙ С САМИМ МАССИВОМ ] ================ ;
;                                                                                      ;
;                                                                                      ;
;                                                                                      ;
create_array:
        ; создание массивом с изначальным размером (2 * sizeof(int))
        mov eax, [max_buf_size]
        imul eax, INT_SIZE
                
        ; теперь итоговый размер массива равен нужному (8 байт для хранения двух чисел числа типа int) 
        mov [max_buf_size], eax

        ; malloc используется для выделения памяти, указатель на память хранит в регистре eax
        push eax
        call [malloc]
        add esp, 4

        ; поэтому запись указателя на буффер идет из регистра
        mov [buf], eax

        mov eax, 0
        ret

destroy_array:
        ; указатель на массив передается в регистр для функции free
        ; т.к тут __cdecl calling convertion
        ; то можно взять любой регистр и переместить сюда буффер
        ; для удобства я взал регистр eax
        mov eax, [buf]

        push eax
        call [free]
        add esp, 4

        ; после того, как работа выполнена
        ; можно почистить память и указатели
        ; чистим регистр для дальнейшего использования
        mov eax, 0
        mov [buf], 0
        mov [tmp_buf], 0
        ret
                
;                                                                                                                  ;
;                                                                                                                  ;
; ================ [ ОПЕРАЦИИ, СВЯЗАННЫЕ С ДОБАВЛЕНИЕМ, ПОИСКОМ И УДАЛЕНИЕМ ЭЛЕМЕНТОВ В МАССИВЕ ] ================ ;
;                                                                                                                  ;
;                                                                                                                  ;
;                                                                                                                  ;
;                                                                                                                  ;
;                                                                                                                  ;
;                                                                                                                  ;
; ========================================= [ СОРТИРОВКА МАССИВА ] =============================================== ;
;                                                                                                                  ;
;                                                                                                                  ;

; алгоритм сортировки был взят из третьей задачи (сортировка пузырьком)
sort_array:
        ; очищаем регистры перед использованием в двух циклах
        ; перед тем, как начать цикл, нужно задать значения переменным
        mov eax, 0
        mov ebx, 0
        mov ecx, 0
        mov edx, 0

        mov esi, sorting_array
        call print_text
        call print_newline

        mov esi, 0
        mov edi, 0

        sort_loop:
                ; перед тем, как продолжать цикл, нужно проверить, прошел ли первый итератор все шаги (i -> ebx)
                ; если нет - идем дальше
                mov eax, [buf_index]
                dec eax

                cmp ebx, eax
                jge exit_sort_loop
                second_loop:
                      ; задаем максиальную длину цикла (LENGTH-ebx-1)
                      ; чтобы не выйти за пределы массива внутри подцикла
                      mov ecx, [buf_index]
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
                      mov eax, [buf]
                      mov eax, [eax+edi*INT_SIZE]
                                          
                      mov edx, [buf]
                      mov edx, [edx+edi*INT_SIZE+INT_SIZE]

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
                        mov ecx, [buf]
                        mov [ecx+edi*INT_SIZE], edx
                        mov [ecx+edi*INT_SIZE+INT_SIZE], eax

                        ; очищаем регистры и продолжаем подцикл
                        mov eax, 0
                        mov edx, 0
                        jmp continue_second_loop

                ; в подцикле действия закончились, увеличиваем шаг в основном цикле
                ; и идем сравнивать числа по новой
                continue_first_loop:
                        inc ebx
                        mov edi, 0
                        jmp sort_loop

; очищаем все регистры, что были использованы
exit_sort_loop:
        ; выводим отсортированный массив на экран
        mov esi, current_array
        call print_text
        call print_array
        call print_newline

        mov eax, 0
        mov ebx, 0
        mov ecx, 0
        mov edx, 0

        mov esi, 0
        mov edi, 0
        ret

;
; ========================== [ РУТИНЫ ДЛЯ ДОБАВЛЕНИЯ ИЛИ УДАЛЕНИЯ ЭЛЕМЕНТА ИЗ МАССИВА ] ========================== ;
;                                                                                                                  ;
;                                                                                                                  ;
;                                                                                                                  ;
;                                                                                                                  ;
; ========================================= [ ДОБАВЛЕНИЕ ЭЛЕМЕНТА ] ============================================== ;
; данная рутина относится к рутине push_element
; была написана выше чисто для удобства

; пересоздаем массив с большим размером и копируем туда все созданные элементы 
realloc_array:
        ; теперь размер умножен на 2, т.е равен 16
        ; после чего для хранения всех чисел типа int он умножается на sizeof(int) (4)
        mov eax, [max_buf_size]
        imul eax, 2
        imul eax, INT_SIZE

        ; массив увеличен, теперь он равен 64
        mov [max_buf_size], eax

        ; выделяем память под новый буффер
        push eax
        call [malloc]
        add esp, 4

        ; для удобства был создан дополнительный указатель на временный буфер
        ; чтобы не терять данные при пересоздании или копировании
        mov [tmp_buf], eax
        mov eax, 0

        ; теперь копируем ВСЕ числа из старого буфера в новый
        ; все, что вышло за пределы, будет заполнено нулями
        push [max_buf_size]
        push [buf]
        push [tmp_buf]
        call [memcpy]
        add esp, 12

        ; очищаем старый буфер
        push [buf]
        call free
        add esp, 4

        ; архитектура не позволяет перемещать с указателя на указатель напрямую
        ; поэтому снова используем eax, чтобы передать указатель на новый буффер
        mov eax, [tmp_buf]
        mov [buf], eax
        mov eax, 0

        ; теперь очищаем указатель временного буфера, т.к данные были направлены на основной
        mov [tmp_buf], 0

        ; после чего записываем новый элемент в буффер
        jmp continue_pushing

        ret

; добавить элемент в массив
push_element:
        ; если размер БОЛЬШЕ или РАВЕН максимальному количеству записываемых элементов
        ; то идем и увеличиваем буфер перед тем, как добавить туда число
        mov eax, [max_buf_size]
        cmp [buf_index], eax
        jge realloc_array

; если количество элементов не превышено
; или уже был пересоздан буфер
; то можно записать новый элемент
continue_pushing:
        ; новый элемент будет записан по индексу 
        ; в аргументах перед вызовом функций значение элемента хранится в регистре edx
        ; поэтому копирование идет из него же
        mov eax, [buf]
        mov ecx, [buf_index]
        mov [eax+ecx*INT_SIZE], edx
        inc [buf_index]

        ; тут просто идут логи о том, что элемент был записан
        mov eax, edx
        mov esi, pushing_element
        call print_text
        call print_newline
                
        ; очистка регистров, они уже были использованы
        mov eax, 0

        mov ecx, 0
        mov edx, 0

        ; выводим текущий массив со всеми элементами
        mov esi, current_array
        call print_text
        call print_array
        call print_newline

        ret

; ======================================== [ УДАЛЕНИЕ ЭЛЕМЕНТА ] ======================================== ;
; был использован следующий подход:
;
; для начала нужно найти индекс элемента, который нужно удалить:
; для этого есть несколько вариантов:
;       1) пользователь указывает его сам
;       2) используется бинарный поиск, который возвращает в регистр индекс элемента
;      который нужно удалить
;
; самое главное: ИНДЕКС ЭЛЕМЕНТА ВСЕГДА ХРАНИТСЯ В РЕГИСТРЕ EBX!!!
;
; после того, как был найден элемент, приосходит следующее:
; данный элемент в массиве помечается как INT_MAX, т.е невалидный
; после чего в уже новый массив копируются только ТЕ числа, которые не были помечены как удаленные
;
; например:
; [10, 20, 30]
; нужно удалить элемент 20
;
; после поиска индекса будет следующий результат:
; [10, 0x7FFFFFFF, 30]
;
; который в новый массив скопируется как:
; [10, 30]
; после чего уже новый массив можно использовать для дальнейших операций


; ============================== [ САМИ РУТИНЫ ] ============================== ;

; данные две рутины относятся к erase_element
; если массив уже был очищен (в нем 0 элементов), то он будет удаления
; если нет, то идет удаление массива по описанному ниже методу
; после чего идет копирование элементов

; массив пуст, освобождаем его и предупреждаем об этом в текстовом сообщении
free_array:
        mov esi, empty_array
        call print_text
        call print_newline

        call destroy_array

        call print_array
        ret
        
; копирование элементов после удаления
copy_end:
        mov eax, 0
        mov ebx, 0
        mov ecx, 0
        mov edx, 0

        ; после чего указатель на буффер меняется и теперь основной буффер, используемый для массива 
        ; хранит в себе ВСЕ валидные числа
        mov ebx, [tmp_buf]
        mov [buf], ebx

        ; очистка указателя
        mov [tmp_buf], 0
                
        ; обновление количества правильно записанных элементов
        mov [buf_index], edi

        ; вывод массива на экран
        mov esi, current_array
        call print_text
        call print_array
        call print_newline

        ret

; удаление элемента по описанному выше методу
erase_element:
        cmp [buf_index], 0
        je free_array

        mov eax, ebx
        mov esi, deleting_element
        call print_text
        call print_newline

        ; помечаем найденный элемент как INT_MAX
        mov eax, [buf]
        mov dword [eax+ebx*INT_SIZE], INT_MAX

        ; создаем пустой массив, в котором ничего нет
        push max_buf_size
        call [malloc]
        add esp, 4

        mov [tmp_buf], eax

        ; теперь через цикл нужно пройти сквозь все элементы массива, которые нужно перезаписать (от 0 до максимального кол-ва элементов)
        mov eax, 0 ; регистр нужен для записи числа из старого буфера, где невалидное число помечено как INT_MAX
        mov ebx, 0 ; i, итератор цикла по старому массиву 
        mov ecx, 0 ; регистр нужен для записи указателя на новый буффер, в который будут добавлены только валидные числа
        mov edi, 0 ; j, итератор цикла по новому массиву, где только после записи числа он увеличивается на один шаг
        copy_values_loop:
                cmp ebx, [buf_index]
                jge copy_end

                mov eax, [buf]
                mov eax, [eax+ebx*INT_SIZE] ; получаем элемент из массива по индексу 

                ; i++
                inc ebx

                cmp eax, INT_MAX ; buf[i] == INT_MAX, если число такое, то идем снова по циклу
                je copy_values_loop

                ; тут уже идет копирование элементов в новый массив
                ; tmp_buf[j] = buf[i]
                mov ecx, [tmp_buf]
                mov [ecx+edi*INT_SIZE], eax

                ; j++
                inc edi

                jmp copy_values_loop


; ======================================== [ ПОИСК ЭЛЕМЕНТА ПО ИНДЕКСУ ] ======================================== ;

; данная рутина относится к find_element_index
; если индекс не найден 
; то идет вывод текст на экран
not_found:
        mov esi, element_not_found
        call print_text
        call print_newline

        mov eax, 0
        mov ebx, -1
        mov ecx, 0
        mov edx, 0
        mov edi, 0
        jmp exit_program
        ret

; для поиска индекса был использован линейный поиск
find_element_index:
        mov ebx, 0 ; i, до buf_index
        mov edx, [buf_index]

        ; если элементы не были добавлены, то индекс не может быть найден
        ; возвращаем -1
        cmp ebx, edx
        jge not_found
        
        find_loop:
                ; читаем значение из массива по индексу (buf[i])
                mov eax, [buf]
                mov eax, [eax+ebx*INT_SIZE]

                ; если число равно тому, что мы ищем 
                ; то выходим из цикла и сохраняем индекс в ebx
                cmp eax, edi
                je exit_loop

                ; идем дальше, если не нашли
                inc ebx

                cmp ebx, edx
                jl find_loop ; снова запускаем цикл, если не дошли до предела
                jmp not_found ; если число в принципе не было найдено, то выходим из цикла и возвращаем -1
        ret

exit_loop:
        ; выводим итоговый индекс на экран
        ; он хранится в регистре ebx, поэтому добавляем это в стек
                
        ; также добавляем число, которое искалось, оно было записано в регистр edi
        push ebx
        push edi
        push element_found
        call [printf]
        add esp, 12

        call print_newline

        mov eax, 0
        mov ecx, 0
        mov edx, 0

        ret
      
; реализация бинарного поиска элемента   
; СТОИТ ПОМНИТЬ, ЧТО ЭТО РАБОТАЕТ ТОЛЬКО НА СОРТИРОВАННОМ МАССИВЕ!!!!
find_element_index_binary:
        mov ecx, 0 ; минимальный элемент (low)
        mov edx, [buf_index] ; максимальный предел для массива (high) 
        ; он равен (buf_index-1)
        dec edx

        ; по каким то причинам поиск не успешен
        ; либо вышли за пределы
        ; либо элемента просто нет
        cmp ecx, edx
        jg not_found

        first_loop_binary:
                ; считаем середину массива
                                
                ; mid = low
                mov ebx, ecx
                                
                ; mid += high
                add ebx, edx
                                
                ; технически сдвиг числа вправо на 1 бит
                ; преобразует его в число, деленное на два
                shr ebx, 1

                ; читаем число, находящиеся по середине
                mov eax, [buf]
                mov eax, [eax+ebx*INT_SIZE]

                ; равно ли оно тому, что мы ищем?
                ; buf[mid] == number?
                cmp eax, edi
                je exit_loop_binary ; если да, то выходим из цикла

                ; если нет, то урезаем границы поиска
                ; если число больше, чем то, которое надо найти
                ; то урезаем границу справа
                ; если нет - то слева
                cmp eax, edi
                jl change_low ; число меньше, урезаем границу слева

                cmp eax, edi
                jg change_high ; число меньше, урезаем границу слева

change_low:
        mov ecx, ebx ; low = mid + 1
        inc ecx
        jmp check_loop

change_high:
        mov edx, ebx ; high = mid - 1
        dec edx
        jmp check_loop

check_loop:
        cmp ecx, edx
        jg not_found
        jmp first_loop_binary

exit_loop_binary:
        ; выводим итоговый индекс на экран
        ; он хранится в регистре ebx, поэтому добавляем это в стек
                
        ; также добавляем число, которое искалось, оно было записано в регистр edi
        push ebx
        push edi
        push element_binary_found
        call [printf]
        add esp, 12

        call print_newline

        mov eax, 0
        mov ecx, 0
        mov edx, 0

        ret
                
; ======================================== [ ВЫВОД МАССИВА НА ЭКРАН ] ======================================== ;

array_empty:
        mov esi, empty_array_error
        call print_text
        call print_newline
        jmp exit_program
        ret

print_array:
        ; если массива не существует - выводим соответствующую ошибку на экран
        cmp [buf], 0
        je array_empty

        ; выводим первую скобку на экран '['
        mov esi, bracket_start
        call print_text

        ; идем по циклу
        mov edi, 0 ; итератор цикла (i)
        print_loop:
              ; если дошли до предела 
              ; ИЛИ же, число равно 0, т.е элементов не было добавлено
              ; рисуем закрывающую скобку и выходим из цикла
              cmp edi, [buf_index]
              jge end_loop

              ; в другом случае - выводим число на экран 
              ; число берется из массива по индексу 
              ; buf[i]
              mov ebx, [buf]
              mov ebx, [ebx+edi*INT_SIZE]

              ; выводим число, которое было взято из массива на экран
              mov eax, ebx
              mov esi, number_in_brackets
              call print_text

              ; идем дальше по циклу
              inc edi

              ; если мы еще не закончили цикл
              ; то добавляем запятую для дальнейших чисел
              ; чтобы был формат а-ля
              ; [10, 
              cmp edi, [buf_index]
              jl add_comma
        
              ; повторяем цикл с самого начала
              jmp print_loop
        ret

add_comma:
        ; вывод запятой на экран ','
        mov esi, bracket_comma
        call print_text
        jmp print_loop
        ret

end_loop:
        ; выводим закрывающую скобку на экран ']'
        mov esi, bracket_end
        call print_text

        mov ebx, 0
        mov ecx, 0
        ret

; ======================================== [ УТИЛИТЫ, ИСПОЛЬЗУЕМЫЕ ДЛЯ ВЫВОДА ТЕКСТА НА ЭКРАН ] ======================================== ;

; вывод текста
; очень часто используется несколько аргументов с форматом, поэтому я сюда добавил push eax
; если нужно больше - добавляем вне этой рутины еще регистры в стек
print_text:
        push eax
        push esi
        call [printf]
        add esp, 8

        mov esi, 0
        mov eax, 0
        ret

; вывод '\n' в консоль
print_newline:
        mov esi, newline
        call print_text
        ret

section '.data' data readable writeable
        buf dd ?
        tmp_buf dd ?
        max_buf_size dd ?
        buf_index dd ?

section '.rdata' data readable
        welcome db 'Welcome to dynamic array generator!',0
        current_array db 'Current array: ',0

        bracket_start db '[',0
        number_in_brackets db '%d',0
        bracket_comma db ', ',0
        bracket_end db ']',0

        added_element db 'Added element: %d',0
        pushing_element db 'Pushing element: %d',0
        deleting_element db 'Deleting element by index %d',0
        element_found db 'Searching element %d: found by index %d',0
        element_binary_found db 'Using binary search for element: %d: found by index %d', 0
        element_not_found db 'Current element not found! Index is -1!', 0

        sorting_array db 'Sorting array....', 0

        empty_array db 'Array is empty! Free memory...',0
        empty_array_error db 'Print array error: array is empty!', 0

        syntax db '%d ',0
        any_key db 'Press any key to exit',0
        newline db 13,10 ; '\n'

section '.idata' data readable import
    library msvcrt, 'msvcrt.dll'
    import msvcrt, printf, 'printf', _getch,'_getch', scanf,'scanf',malloc,'malloc',free,'free',memcpy,'memcpy'
