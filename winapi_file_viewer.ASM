format PE GUI 4.0
entry start

include '../INCLUDE/win32wx.inc'

; код сообщения при работе с элементами окна
ID_CAPTION     = 101
ID_MESSAGE     = 102

; при нажатии кнопки "Open File" в DialogProc передается сообщение с данным кодом
ID_OPEN_FILE   = 1001

; максимальный размер файла (64кб)
; сделано в целях, чтобы не перегружать буффер
MAX_FILE_SIZE  = 65536

; было использовано WINAPI для реализации просмотра и поиска файлов
; логика следующая:

; 1) инициализируем объект структуры OPENFILENAME 
;    для правильной реализации открытия окна с выбором файлов
; 
; 2) вызываем диалоговое окно с выбором файлов 
;    GetModuleHandle нужен для того, чтобы дескриптор окна был не равен нулю
;
; 3) обрабатываем все сообщения из окна в DialogProc
section '.text' code readable executable
start:
        call initOpenFileStruct

        invoke GetModuleHandle, 0
        invoke DialogBoxParam, eax, 37, HWND_DESKTOP, DialogProc, 0
        or eax,eax
        jz exit
exit:
        invoke ExitProcess,0

;                                                                  ;
;                                                                  ;
; ===================== [ РАБОТА С ФАЙЛАМИ ] ===================== ;
;                                                                  ;
;                                                                  ;

; сделано по документации из winapi
proc initOpenFileStruct
     mov [ofn.lStructSize], sizeof.OPENFILENAME ; размер структуры 
     mov [ofn.lpstrFile], file_name ; буффер, в котором хранится имя и путь файла
     mov [ofn.nMaxFile], MAX_PATH ; максимальный размер пути
     mov [ofn.lpstrFilter], file_filter ; фильтр. какие файлы будут выбраны? здесь фильтруются .txt и .asm
     mov [ofn.nFilterIndex], 1 ; использовать ли фильтр
     mov [ofn.lpstrTitle], choose_file ; название окна (Choose File)
         
     ; параметры для открытия окна
     ; 1) путь должен существовать
     ; 2) файл должен существовать
     ; 3) поиск файла реализован через проводник
     mov [ofn.Flags], OFN_PATHMUSTEXIST+OFN_FILEMUSTEXIST+OFN_EXPLORER 
     ret
endp

; чтение файла по заданному пути
proc readAndShowFile hwnddlg

    ; загружаем файл в память
    invoke CreateFile, file_name, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
    
    ; переносим дескриптор файла в регистр для дальнейшего использования
    ; тк следующие функции результат также возвращают в eax
    mov [file_handle], eax

    ; получаем размер файла
    invoke GetFileSize, [file_handle], 0
        
    ; если размер больше, чем нужно, то закрываем дескриптор
    cmp eax, MAX_FILE_SIZE
    jg write_error
    
    ; записываем кол-во байт, в которые записанны данные из файла
    mov [read_bytes], eax

    ; читаем сам файл, расположенный в памяти на Х байт
    invoke ReadFile, [file_handle], file_buffer, [read_bytes], read_bytes, 0
        
    ; файл не был прочитан - закрываем дескриптор
    test eax, eax
    jz write_error

    ; для поддержки unicode
    ; нужно реализовать конвертацию символов из char в wchar_t
    ; считаем количество символов для записи
    invoke MultiByteToWideChar, CP_UTF8, 0, file_buffer, [read_bytes], 0, 0

    ; после чего копируем их в буффер для записи
    invoke MultiByteToWideChar, CP_UTF8, 0, file_buffer, [read_bytes], temp_buffer, eax

    ; после этого зануляем последние символ
    mov eax, [read_bytes]
    mov word [temp_buffer + eax], 0

    ; закрываем дескриптор файла
    ; и выводим содержимое файла в диалоговое окно
    invoke CloseHandle, [file_handle]
    invoke SetDlgItemText, [hwnddlg], ID_MESSAGE, temp_buffer
    ret

write_error:
    invoke CloseHandle, [file_handle]
    invoke SetDlgItemText, [hwnddlg], ID_MESSAGE, cant_read_file
    ret
endp

;                                                                  ;
;                                                                  ;
;                                                                  ;
; ================= [ ОБРАБОТЧИК КОМАНД С ОКНА ] ================= ;
;                                                                  ;
;                                                                  ;
;                                                                  ;
proc DialogProc hwnddlg,msg,wparam,lparam
        push ebx esi edi
                
        ; если тип сообщения WM_COMMAND
        ; то можно обработать данные
        cmp [msg],WM_COMMAND
        je .wmcommand
        cmp [msg],WM_CLOSE
        je .wmclose
        xor eax,eax
        jmp .finish
                
        ; по документации WINAPI код кнопки лежит в LOWORD
        ; сравниваем
        ; код = BN_CLICKED << 16 + IDCLOSE
  .wmcommand:
        ; если нужно закрыть программу
        cmp [wparam],BN_CLICKED shl 16 + IDCLOSE
        je .wmclose
                
        ; если нужно открыть файл то идем дальше
        ; если нет - ничего не делаем
        cmp [wparam],BN_CLICKED shl 16 + ID_OPEN_FILE
        jne .processed

        ; вызываем открытие файла из проводника
        invoke GetOpenFileName, ofn
        test eax, eax
        jz .processed

        ; читаем файл по указанному пути и выводим содержимое в диалоговое окно
        push [hwnddlg]
        call readAndShowFile
        add esp, 4

        jmp .processed

  .wmclose:
        invoke EndDialog,[hwnddlg],0
  .processed:
        mov eax,1
  .finish:
        pop edi esi ebx
        ret
endp

section '.data' readable writeable
        ofn OPENFILENAME

        file_handle dd ?
        read_bytes dd ?

        temp_buffer rw MAX_FILE_SIZE
        file_buffer rw MAX_FILE_SIZE

        choose_file du 'Choose File', 0
        cant_read_file du 'Error in file reading! Make sure that path is EN or file size less than 64KB!',0
        file_name rw MAX_PATH
        file_filter  du 'text files',0,'*.txt',0
              du 'asm files',0,'*.asm',0

section '.idata' import data readable writeable
        library kernel,'KERNEL32.DLL',\
                user,'USER32.DLL', \
                comdlg32,'COMDLG32.DLL'

        import kernel,\
                GetModuleHandle,'GetModuleHandleA',\
                ExitProcess,'ExitProcess',\
                CreateFile, 'CreateFileW',\
                ReadFile, 'ReadFile',\
                GetFileSize, 'GetFileSize',\
                CloseHandle, 'CloseHandle',\
                MultiByteToWideChar,'MultiByteToWideChar'

        import user,\
               DialogBoxParam,'DialogBoxParamW',\
               SetDlgItemText, 'SetDlgItemTextW',\
               MessageBox,'MessageBoxW',\
               EndDialog,'EndDialog'

        import comdlg32,\
                GetOpenFileName,'GetOpenFileNameW'

section '.rsrc' resource data readable
        directory RT_DIALOG,dialogs

        resource dialogs,\
                 37,LANG_ENGLISH+SUBLANG_DEFAULT,demonstration

        dialog demonstration,'File viewer',70,70,300,200,WS_CAPTION+WS_POPUP+WS_SYSMENU+DS_MODALFRAME
               dialogitem 'BUTTON','Open File',ID_OPEN_FILE,10,10,45,15,WS_VISIBLE+WS_TABSTOP+BS_DEFPUSHBUTTON
               dialogitem 'STATIC','&File contents:',-1,10,40,70,8,WS_VISIBLE
               dialogitem 'EDIT','',ID_MESSAGE,10,50,280,130,WS_VISIBLE+WS_BORDER+WS_HSCROLL+WS_VSCROLL+WS_TABSTOP+ES_MULTILINE+ES_READONLY+ES_AUTOHSCROLL+ES_AUTOVSCROLL
               dialogitem 'BUTTON','Exit program',IDCLOSE,60,10,45,15,WS_VISIBLE+WS_TABSTOP+BS_PUSHBUTTON
        enddialog
