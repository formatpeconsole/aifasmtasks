format PE console
entry start

include '../INCLUDE/win32a.inc'
include '../INCLUDE/API/wsock32.inc'

; в данной задаче был реализован клиент-сервер с чтением сообщений
; общая логика:
;
; спрашиваем у пользователя, что он хочет запустить
; 1. сервер
; 2. клиент
; 
; затем определяем тип приложения, сохранив значение в server_state
; если пользователь ввел сервер, то, соответственно, server_state будет равен 1
;
; после чего логика приложения разбивается на следующие сценарии:
;
; 1. СЕРВЕР: 
;			\ 
;		 	 - Создает сокет
;				 Ждет клиентов
;			  	   Отправляет сообщение "Success!" клиенту
;
;			  	   Ждет сообщение от клиента
;		      	   Выводит сообщение на экран
;
;	          	 Если клиент написал "exit" -> закрываем сервер
;
;
;
;
;
; 2. КЛИЕНТ:
;			\
;			 - Создает сокет
;		   	     Запрашивает IP-адрес сервера (по умолчанию стоит 127.0.0.1)   <- \   | 
;                                                                            	      |  | идет сюда снова
;				  Если IP не найден или неправильный ------------------------------]  |
;				    Подключается к серверу
;			        Получает сообщение "Success!"
;				    Запрашивает у пользователя сообщение, которое нужно отправить
;				    Отправляет сообщение 
;
;				  Если пользователь ввел "exit" -> закрываем клиент
;
;
;
; таким образом у нас есть полноценное приложение, которое может быть как и клиентом, так и сервером
	
SERVER_PORT=8080
IP_ADDRESS=0; INADDR_ANY
WINSOCK_VERSION=514 ; MAKEWORD(2, 2)
SOMAXCONN=5 ; количество максимальных подключений
IPPROTO_TCP=6 ; тип сокета (TCP)

MSG_LENGTH=256

section '.text' code readable executable
start:
	; выводим сообщение о выборе типа работы приложения на экран
        mov esi, welcome
        call print_text
        call print_newline

        mov esi, mode
        call print_text
        call print_newline

        mov esi, mode_server
        call print_text
        call print_newline

        mov esi, mode_client
        call print_text
        call print_newline

	; запрашиваем у пользователя ввод
        push server_state
        push int_format
        call [scanf]
        add esp, 8

	; если пользователь ввел что угодно, кроме нужных значений
	; то сообщаем об ошибке и выходим из программы
        cmp eax, 0
        jle wrong_input_error

	; если пользователь вышел за пределы (< 0 || > 2)
	; то делаем тоже самое
        cmp [server_state], 0
        jl wrong_input_error

        cmp [server_state], 2
        jg wrong_input_error

	; обновляем server_state при необходимости
        cmp [server_state], 1
        je update_server_state

; если все успешно, то стартуем наше приложение
continue:
        call run_app

        jmp exit_program

wrong_input_error:
        mov esi, wrong_input
        call print_text
        call print_newline
        call print_newline

        jmp exit_program

update_server_state:
        mov byte [is_server], 1
        jmp continue


; сокеты были реализованы при помощи Winsock API
;
; результат создания сокетов будет сохранен в регистры ecx, ebx
; принцип проверки успешности выполнения работает также, как и в 7ой задаче
; (если оба регистры в сумме возвращают 0, то это значит, что сокеты не инцициализированы)
; ========================= [ ИНИЦИАЛИЗАЦИЯ СОКЕТА ] ========================= ;

startup_failed:
        mov esi, wsa_failed
        call print_text
        call print_newline

        mov ecx, 0
        ret

init_winsock:
        mov ecx, 1

	; WSAStartup инициализирует использование Winsock
        invoke WSAStartup, WINSOCK_VERSION, wsa_data
        test eax, eax
		
	; если по какой то причине возникла ошибка
	; то выходим из рутины 
	; и сообщаем об ошибке
        jnz startup_failed

	; в другом случае - все успешно
	; можно идти дальше
        mov esi, ws_init
        call print_text
        call print_newline
        ret

; ============================================================================= ;

socket_startup_failed:
        mov esi, socket_failed
        call print_text
        call print_newline

        mov ebx, 0
        ret

create_socket:
        mov ebx, 1

	; создаем сокет
	; который будет использовать IPv4 адресацию
	; в режиме TCP
        invoke socket, AF_INET, SOCK_STREAM, IPPROTO_TCP
		
	; после чего записывем указатель на него 
	; результат функци хранится в eax
        mov [sock], eax

	; по какой то причине сокет не создался
	; пишем сообщение об ошибке и выходим из рутины
	; (для отладки можно использовать WSAGetLastError)
        cmp [sock], -1
        je socket_startup_failed

        mov esi, socked_init
        call print_text
        call print_newline
        ret

; ============================================================================= ;

; ===================== [ РУТИНЫ, СВЯЗАННЫЕ С СЕРВЕРОМ ] ====================== ;

bind_error:
        mov esi, bind_failed
        call print_text
        call print_newline

        mov ecx, 0
        ret

listen_error:
        mov esi, listen_failed
        call print_text
        call print_newline

        mov ecx, 0
        ret

start_server:
        mov ecx, 1

	; заполняем структуру с адресацией
	; IP_ADDRESS=0 
	; в таком случае сервер слушает IP-Адрес на всех свободных интерфейсах
	; по умолчанию это localhost (127.0.0.1)
        mov [server_addr.sin_family], AF_INET
        mov [server_addr.sin_addr], IP_ADDRESS

	; порт хранится как число типа short
	; для получения его в корректном формате
	; происходит сдвиг верних и нижних байт местами
	; чтобы число в итоге выглядело следующим образом:
	; 8080 (0x1F90) -> 0x901F
	; после чего помещаем его в структуру
	
	; фактически htons делает тоже самое
	; и результат будет такой же (0x901F)
        mov ax, SERVER_PORT
        xchg ah, al
        mov word [server_addr.sin_port], ax

	; после заполнения структуры можно привязать сокет к конкретному адресу
        invoke bind, [sock], server_addr, sizeof.sockaddr_in
		
	; сообщаем об ошибке, если что то пошло не так
        cmp eax, -1
        je bind_error

	; после привязки слушаем подключения по данному сокету
        invoke listen, [sock], SOMAXCONN
        cmp eax, -1
        je listen_error

        mov esi, listening_on_port
        call print_text
        call print_newline

        ret

accept_error:
        mov esi, accept_failed
        call print_text
        call print_newline

        mov ecx, 0
        ret

accept_client:
        mov ecx, 1

	; ждем подключения клиента к серверу по заранее прописанному адресу
		
	; в ebx записывается длина структуры 
	; которая хранит в себе информацию об IP-Адресе
        mov ebx, 0
        invoke accept, [sock], server_addr, ebx

	; при неуспешном подключении 
	; сообщаем об ошибке и выходим из рутины
        cmp eax, -1
        je accept_error

	; после чего записываем указатель на client_socket 
        mov [client_sock], eax

        mov esi, client_connect
        call print_text
        call print_newline

        ret
		
; ============================================================================= ;
; ===================== [ ОБРАБОТКА СООБЩЕНИЙ КЛИЕНТА ] ======================= ;

send_error:
        mov esi, send_failed
        call print_text
        call print_newline

        jmp exit_program

finish_message:
	; функция recv возвращает длину сообщения в байтах
	; и сохраняет результат в eax
	; поэтому последний символ сообщения будет занулен 
        mov [recvbuf+eax], 0

	; после того, как сообщение было обработано
	; можно спокойно вывести его на экран
	; и идти дальше по циклу
        mov eax, recvbuf
        mov esi, message_recieved
        call print_text
        call print_newline
        jmp continue_recieve

quit_server_loop:
        mov ebx, 0
        ret

; сообщения обрабатываются в цикле
; логика была описана в комментарии выше
server_loop:
        mov ebx, 1

        recieve_loop:
		; отправляем сообщение "Success!"
		; длина сообщения - 8
		; т.к последний символ равен '\0'
                invoke send, [client_sock], message_server, 8, 0
				
		; если не получилось отправить
		; то выходим из цикла
                cmp eax, -1
                je send_error

		; после отправки сообщения 
		; получаем то, что прислал нам клиент после ввода
                invoke recv, [client_sock], recvbuf, MSG_LENGTH, 0
				
		; при получении сообщения
		; переходим в рутину
		; которая выводит содержимое в консоль
                cmp eax, 0
                jg finish_message

                continue_recieve:
			; если пользователь ввел сообщение "exit"
			; то выходим из цикла
			; и прерываем любую работу с клиентами
                        push MSG_LENGTH
                        push exit_code
                        push recvbuf
                        call [strncmp]
                        add esp, 12

                        cmp eax, 0
                        je quit_server_loop

			; в другом случае продолжаем работать с клиентом
                        jmp recieve_loop

setup_server:
	; если при инициализации сервера возникают какие-либо проблемы
	; то выходим отсюда и завершаем программу
        call start_server
        cmp ecx, 0
        je exit_program
        mov ecx, 0

        call accept_client
        cmp ecx, 0
        je exit_program

        call server_loop
        ret

; ============================================================================= ;

; ===================== [ РУТИНЫ, СВЯЗАННЫЕ С КЛИЕНТОМ ] ====================== ;

ip_address_error:
        mov eax, server_ip
        mov esi, invalid_ip
        call print_text
        call print_newline

        mov ecx, 0
        ret

connect_error:
        mov esi, connect_failed
        call print_text
        call print_newline

        mov ecx, 0
        ret

start_client:
        mov ecx, 1

	; логика заполнения данных для адресации та же
	; что и в реализации сервера
        mov [server_addr.sin_family], AF_INET

        mov ax, SERVER_PORT
        xchg ah, al
        mov word [server_addr.sin_port], ax

        lea eax, [server_addr.sin_addr]
		
	; проверяем IP-Адрес на валидность
        invoke inet_pton, AF_INET, server_ip, eax

	; если адрес некорректный
	; то выходим из рутины
	; и сообщаем об ошибке
        cmp eax, 0
        jle ip_address_error

	; IP-Адрес в порядке можно подключаться
        invoke connect, [sock], server_addr, sizeof.sockaddr_in
		
	; также обрабатываем ошибки, как и в предыдущих рутинах
        cmp eax, -1

        je connect_error

	; если все корректно
	; то сообщаем об этом пользователю
        mov eax, server_ip
        mov esi, client_connect
        call print_text
        call print_newline

        ret
		
; ============================================================================= ;

; ========================= [ ОБРАБОТКА СООБЩЕНИЙ ] =========================== ;

; принцип несколько похож на обработку сообщений с сервером
; главное отличие в порядке
; если сервер сначала отправляет, а потом получает
; то клиент наоборот
; сначала ПОЛУЧАЕТ сообщение, а после чего - отправляет
handle_server_message:
	; зануление последнего байта по принципу такое же
	; как и в реализации серверной части
        mov [recvbuf+eax], 0

	; выводим сообщение на экран
        mov eax, recvbuf
        mov esi, server_message_recieved
        call print_text
        call print_newline

        jmp continue_client_loop

send_to_server_error:
        mov esi, send_failed
        call print_text
        call print_newline

        mov ebx, 0
        jmp messages_loop

quit_client_loop:
        mov ebx, 0
        ret

client_loop:
        mov ebx, 1

        messages_loop:
		; получаем сообщение с сервера
                invoke recv, [sock], recvbuf, MSG_LENGTH, 0
                cmp eax, 0
                jge handle_server_message

        continue_client_loop:
		; просим пользователя ввести сообщение 
		; перед тем, как его отправить
                mov esi, enter_message
                call print_text
                call print_newline

                push message
                push msg_format
                call [scanf]
                add esp, 8

                push message
                call [strlen]
                add esp, 4

		; после чего отправляем сообдщение на сервер
                invoke send, [sock], message, eax, 0
				
		; если что то пошло не так
		; сообщаем об этом пользователю
		; и пытаемся отправить сообщение снова
                cmp eax, -1
                je send_to_server_error

		; если пользователь ввел "exit"
		; то после отправки этого сообщения на сервер
		; проверяем корректность ввода слова у клиента
                push MSG_LENGTH
                push exit_code
                push message
                call [strncmp]
                add esp, 12

		; и после чего завершаем работу
                cmp eax, 0
                je quit_client_loop

                jmp messages_loop


setup_client:
        mov esi, enter_ip
        call print_text
        call print_newline

	; перед тем, как начать работу с сервером
	; обязательно требуем ввод IP-Адреса у пользователя
        push server_ip
        push ip_format
        call [scanf]
        add esp, 8

        call start_client
        cmp ecx, 0
		
	; если он будет некорректный - то просим у пользователя ввести его заново
        je setup_client

	; IP-Адрес введен верно и клиент подключился к серверу
	; можно начинать работу
        call client_loop

        ret

; ============================================================================= ;

; ========================== [ ЗАКРЫТИЕ СОКЕТОВ ] ============================= ;
skip_cleanup:
        jmp exit_program

cleanup:
	; если была ошибка при инициализации сокетов
	; то и клиентский, и серверный сокет
	; не имеет смысла закрывать
        cmp [client_sock], -1
        je skip_cleanup

        invoke closesocket, [client_sock]

        cmp [sock], -1
        je skip_cleanup

        invoke closesocket, [sock]

	; после закрытия сокетов можно выгружать Winsock из процесса 
        invoke WSACleanup

	; после чего перейти к завершению программы
        jmp exit_program

; ============================================================================= ;
; ========================== [ СТАРТ ПРИЛОЖЕНИЯ ] ============================= ;
run_app:
	; первым делом идет инициализация Winsock
        call init_winsock
        call create_socket

	; если уже НА ЭТОМ этапе что то пошло не так
	; то можно завершать работу и закрывать программу
        add ecx, ebx
        cmp ecx, 0
        je exit_program

	; очищаем регистры для дальнейшего использования
        mov ecx, 0
        mov ebx, 0

	; от выбора пользователя зависит
	; каким образом будет работать приложение
        cmp byte [is_server], 1
		
	; в данном случае будет запущен сервер
        je setup_server

	; в другом же случае будет запущен клиент
        jmp setup_client

	; если все корректно завершилось - можно заершать работу с сокетами
        add ecx, ebx
        cmp ecx, 0
        je cleanup
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
        is_server db 0
        server_state dd ?
        server_ip rb 16
        message rb MSG_LENGTH
        recvbuf rb MSG_LENGTH

        wsa_data WSADATA
        sock dd ?
        client_sock dd ?
        server_addr sockaddr_in

section '.rdata' data readable
        welcome db 'Welcome to client-server app!',0
        any_key db 'Press any key to exit', 0

        mode db 'Select mode:', 0
        mode_server db '1. Server', 0
        mode_client db '2. Client', 0

        wrong_input db 'Wrong input! Please try again', 0
        enter_ip db 'Enter IP (port is 8080 by default):',0
        enter_message db 'Enter message to server (write exit to stop): ', 0

        message_recieved db 'Recieved message: %s',0
        server_message_recieved db 'Recieved message from server: %s',0
        message_server db 'Success!', 0

        wsa_failed db 'WSAStartup failed', 0
        ws_init db '[+] Inited winsock', 0

        socket_failed db 'Failed to create socket', 0
        socked_init db '[+] Socked created', 0

        bind_failed db 'Bind failed', 0
        listen_failed db 'Listen failed', 0

        listening_on_port db 'Server is listening on port 8080', 0

        invalid_ip db 'Invalid ip address %s at port 8080', 0
        server_connect db 'Connected to server: %s:8080', 0
        client_connect db 'Client connected!', 0

        connect_failed db 'Connect failed', 0
        send_failed db 'Send failed', 0
        accept_failed db 'Accept failed', 0

        int_format db '%d', 0
        ip_format db '%s', 0
        msg_format db '%255s', 0

        server_port db '8080', 0
        exit_code db 'exit', 0

        newline db 13,10 ; '\n'

section '.idata' import data readable writeable
    library kernel,'KERNEL32.DLL',\
          user,'USER32.DLL',\
          ws2_32,'WS2_32.DLL',\
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

    import ws2_32,\
          WSAStartup,'WSAStartup',\
          WSACleanup,'WSACleanup',\
          WSAGetLastError,'WSAGetLastError',\
          socket,'socket',\
          bind,'bind',\
          listen,'listen',\
          accept,'accept',\
          connect,'connect',\
          send,'send',\
          recv,'recv',\
          closesocket,'closesocket',\
          inet_pton,'inet_pton',\
          htons,'htons'

    import msvcrt, printf, 'printf', _getch,'_getch',\
          scanf,'scanf',malloc,'malloc',free,'free',\
          memcpy,'memcpy',memset,'memset',getchar,'getchar',\
          strncmp,'strncmp',strlen,'strlen'


