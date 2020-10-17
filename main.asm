.386
.model flat, stdcall
option casemap:none

TITLE Windows Application                   (WinApp.asm)

;图标资源定义
IDI_LOGO = 101

; This program displays a resizable application window and
; several popup message boxes.
; Thanks to Tom Joyce for creating a prototype
; from which this program was derived.
; Last update: 9/24/01

include         windows.inc
include         user32.inc
includelib      user32.lib
include         kernel32.inc
includelib      kernel32.lib
include comdlg32.inc 
includelib comdlg32.lib 
include gdi32.inc
includelib gdi32.lib

; 常量定义
WINDOW_WIDTH = 1020
WINDOW_HEIGHT = 740
CLIENT_WIDTH = 1000
CLIENT_HEIGHT = 700
FRIENDS_LIST_WIDTH = 300
CHAT_WINDOW_HEIGHT = 900
CHAT_INPUT_HEIGHT = 50
CHAT_INPUT_WIDTH = 500
CHAT_SEND_BUTTON_WIDTH = 100

BUF_SIZE = 512

; 宏定义
RGB macro red,green,blue
	xor eax,eax
	mov ah,blue
	shl eax,8
	mov ah,green
	mov al,red
endm

; 控件ID定义
LOGIN_BUTTON_ID = 1000
FRIENDS_LIST_ID = 1001
SEND_BUTTON_ID = 1002
SEND_IMAGE_BUTTON_ID = 1003

;==================== DATA =======================
.data

AppLoadMsgTitle BYTE "Application Loaded",0
AppLoadMsgText  BYTE "This window displays when the WM_CREATE "
	            BYTE "message is received",0

PopupTitle BYTE "Popup Window",0
PopupText  BYTE "This window was activated by a "
	       BYTE "WM_LBUTTONDOWN message",0

GreetTitle BYTE "Main Window Active",0
GreetText  BYTE "This window is shown immediately after "
	       BYTE "CreateWindow and UpdateWindow are called.",0

CloseMsg   BYTE "WM_CLOSE message received",0

ErrorTitle  BYTE "Error",0
WindowName  BYTE "ASM Windows App",0
className   BYTE "ASMWin",0

; Define the Application's Window class structure.
MainWin WNDCLASS <NULL,WinProc,NULL,NULL,NULL,NULL,NULL, \
	COLOR_WINDOW,NULL,className>

msg	      MSG <>
winRect   RECT <>
hMainWnd  DWORD ?
hInstance DWORD ?


; 场景 0-登录 1-聊天
SCENE DWORD 0 
; 类名
StaticClassName BYTE "static",0
EditClassName BYTE "edit",0
ButtonClassName BYTE "button",0
ListClassName BYTE "SysListView32",0

; 登录界面
;用户名及密码标签
hUsernameLabel DWORD ?
hPasswordLabel DWORD ?
UsernameLabelText BYTE "Username",0
PasswordLabelText BYTE "Password",0

;用户名及密码输入
hUsernameInput DWORD ?
usernameBuf BYTE BUF_SIZE DUP(0)
hPasswordInput DWORD ?
passwordBuf BYTE BUF_SIZE DUP(0)

;登录按钮
LoginButtonText BYTE "Login",0
hLoginButton DWORD ?

; 好友列表
friendsListText BYTE "Friends",0
hFriendsList DWORD ?
friendName BYTE "zhangzhi",0

; 聊天窗口
message1 BYTE "Hello",0
message2 BYTE "Hi",0

; 聊天输入
hChatInput DWORD ?
; 发送按钮
SendButtonText BYTE "Send",0
hSendButton DWORD ?

; 发送图片按钮
SendImageButtonText BYTE "Send Image",0
hSendImageButton DWORD ?

; 打开图片
fileNameStruct   OPENFILENAME <> 
filterString BYTE "Images",0,"*.bmp",0
fileNameBuf BYTE BUF_SIZE DUP(0)
hBitmap DWORD ?


User STRUCT
	id DWORD ?
User ENDS

;=================== CODE =========================
.code
; 初始化好友列表
initFriendsList PROC hWnd:DWORD
	LOCAL lvc:LV_COLUMN
	LOCAL lvi:LV_ITEM

	invoke CreateWindowEx, NULL, addr ListClassName, NULL, LVS_REPORT+WS_CHILD+WS_VISIBLE, 0,0,300,CLIENT_HEIGHT,hWnd, FRIENDS_LIST_ID, hInstance, NULL
    mov hFriendsList, eax

	mov lvc.imask,LVCF_TEXT+LVCF_WIDTH
	mov lvc.pszText,offset friendsListText
	mov lvc.lx,300
	invoke SendMessage,hFriendsList, LVM_INSERTCOLUMN, 0, addr lvc

	mov lvi.imask,LVIF_TEXT+LVIF_PARAM
	mov lvi.iItem,0
	mov lvi.iSubItem,0
	mov lvi.pszText,offset friendName
	invoke SendMessage,hFriendsList, LVM_INSERTITEM,0, addr lvi

	mov lvi.imask,LVIF_TEXT+LVIF_PARAM
	mov lvi.iItem,1
	mov lvi.iSubItem,0
	mov lvi.pszText,offset friendName
	invoke SendMessage,hFriendsList, LVM_INSERTITEM,0, addr lvi

	mov lvi.imask,LVIF_TEXT+LVIF_PARAM
	mov lvi.iItem,2
	mov lvi.iSubItem,0
	mov lvi.pszText,offset friendName
	invoke SendMessage,hFriendsList, LVM_INSERTITEM,0, addr lvi
	ret
initFriendsList ENDP

initChatWindow PROC hWnd:DWORD,friendId:DWORD
	INVOKE CreateWindowEx,NULL,addr StaticClassName,addr message1,
	  WS_VISIBLE OR WS_CHILD OR SS_CENTERIMAGE,FRIENDS_LIST_WIDTH,0,CLIENT_WIDTH-FRIENDS_LIST_WIDTH,40,hWnd,NULL,hInstance,NULL
	 
	INVOKE CreateWindowEx,NULL,addr StaticClassName,addr message2,
	  WS_VISIBLE OR WS_CHILD OR SS_CENTERIMAGE OR SS_RIGHT,FRIENDS_LIST_WIDTH,50,CLIENT_WIDTH-FRIENDS_LIST_WIDTH,40,hWnd,NULL,hInstance,NULL

	ret
initChatWindow ENDP

initChatInput PROC hWnd:DWORD
	INVOKE CreateWindowEx,NULL,addr EditClassName,NULL,
	  WS_CHILD OR WS_VISIBLE OR WS_BORDER OR ES_AUTOVSCROLL OR ES_MULTILINE ,FRIENDS_LIST_WIDTH,CLIENT_HEIGHT-CHAT_INPUT_HEIGHT,CHAT_INPUT_WIDTH,CHAT_INPUT_HEIGHT,hWnd,NULL,hInstance,NULL
	  mov hChatInput,eax
	ret
initChatInput ENDP

initChatSendButton PROC hWnd:DWORD
	INVOKE CreateWindowEx,NULL,addr ButtonClassName,addr SendButtonText,
	  WS_CHILD OR WS_VISIBLE OR WS_BORDER OR BS_FLAT ,CLIENT_WIDTH-2*CHAT_SEND_BUTTON_WIDTH,CLIENT_HEIGHT-CHAT_INPUT_HEIGHT,CHAT_SEND_BUTTON_WIDTH,CHAT_INPUT_HEIGHT,hWnd,SEND_BUTTON_ID,hInstance,NULL
	  mov hSendButton,eax
	ret
initChatSendButton ENDP

initChatSendImageButton PROC hWnd:DWORD
	INVOKE CreateWindowEx,NULL,addr ButtonClassName,addr SendImageButtonText,
	  WS_CHILD OR WS_VISIBLE OR WS_BORDER OR BS_FLAT ,CLIENT_WIDTH-CHAT_SEND_BUTTON_WIDTH,CLIENT_HEIGHT-CHAT_INPUT_HEIGHT,CHAT_SEND_BUTTON_WIDTH,CHAT_INPUT_HEIGHT,hWnd,SEND_IMAGE_BUTTON_ID,hInstance,NULL
	  mov hSendButton,eax
	ret

initChatSendImageButton ENDP

showImage PROC hWnd:DWORD
	LOCAL ps:PAINTSTRUCT
	LOCAL hdc:HDC
	LOCAL hMemDC:HDC
	LOCAL rect:RECT;

	invoke LoadImage,NULL,addr fileNameBuf,IMAGE_BITMAP,100,100,LR_LOADFROMFILE
    mov hBitmap,eax

	.IF eax == 0
		INVOKE MessageBox, hWnd, ADDR fileNameBuf,
			ADDR WindowName, MB_OK
	.ENDIF

	invoke BeginPaint,hWnd,addr ps
    mov    hdc,eax
    invoke CreateCompatibleDC,hdc
    mov    hMemDC,eax
    invoke SelectObject,hMemDC,hBitmap
    invoke GetClientRect,hWnd,addr rect
    invoke BitBlt,hdc,FRIENDS_LIST_WIDTH,100,100,100,hMemDC,0,0,SRCCOPY
    invoke DeleteDC,hMemDC
    invoke EndPaint,hWnd,addr ps

	ret
showImage ENDP

sendImage PROC hWnd:DWORD
	mov fileNameStruct.lStructSize,sizeof fileNameStruct
	push hWnd 
    pop  fileNameStruct.hwndOwner 
    push hInstance 
    pop  fileNameStruct.hInstance 
	mov fileNameStruct.lpstrFilter,offset filterString
	mov fileNameStruct.lpstrFile,offset fileNameBuf
	mov fileNameStruct.nMaxFile,BUF_SIZE
	INVOKE GetOpenFileName,addr fileNameStruct

	.IF eax == TRUE
		INVOKE MessageBox, hWnd, ADDR fileNameBuf,
			ADDR WindowName, MB_OK
		INVOKE InvalidateRect,hWnd, NULL, TRUE
	.ENDIF
	ret 
sendImage ENDP

WinMain PROC
; Get a handle to the current process.
	INVOKE GetModuleHandle, NULL

	mov hInstance, eax
	mov MainWin.hInstance, eax

; Load the program's icon and cursor.
	INVOKE LoadIcon, hInstance, IDI_LOGO
	mov MainWin.hIcon, eax
	INVOKE LoadCursor, NULL, IDC_ARROW
	mov MainWin.hCursor, eax

; Register the window class.
	INVOKE RegisterClass, ADDR MainWin
	.IF eax == 0
	  call ErrorHandler
	  jmp Exit_Program
	.ENDIF

; Create the application's main window.
; Returns a handle to the main window in EAX.
	INVOKE CreateWindowEx, 0, ADDR className,
	  ADDR WindowName,WS_SYSMENU XOR WS_THICKFRAME,
	 100,100,WINDOW_WIDTH,
	  WINDOW_HEIGHT,NULL,NULL,hInstance,NULL
	mov hMainWnd,eax

; If CreateWindowEx failed, display a message & exit.
	.IF eax == 0
	  call ErrorHandler
	  jmp  Exit_Program
	.ENDIF

; Show and draw the window.
	INVOKE ShowWindow, hMainWnd, SW_SHOW
	INVOKE UpdateWindow, hMainWnd

; Begin the program's message-handling loop.
Message_Loop:
	; Get next message from the queue.
	INVOKE GetMessage, ADDR msg, NULL,NULL,NULL

	; Quit if no more messages.
	.IF eax == 0
	  jmp Exit_Program
	.ENDIF

	; Relay the message to the program's WinProc.
	invoke TranslateMessage, ADDR msg
	invoke DispatchMessage, ADDR msg 
    jmp Message_Loop

Exit_Program:
	  INVOKE ExitProcess,0
WinMain ENDP

;-----------------------------------------------------
WinProc PROC,
	hWnd:DWORD, localMsg:DWORD, wParam:DWORD, lParam:DWORD
; The application's message handler, which handles
; application-specific messages. All other messages
; are forwarded to the default Windows message
; handler.
;-----------------------------------------------------
	mov eax, localMsg

	.IF eax == WM_LBUTTONDOWN		; mouse button
	  jmp WinProcExit
	.ELSEIF eax == WM_CREATE		; create window
	  ; 创建用户名标签
	  INVOKE CreateWindowEx,NULL,addr StaticClassName,addr UsernameLabelText,
	  WS_VISIBLE OR WS_CHILD OR SS_CENTERIMAGE OR SS_RIGHT,10,100,200,40,hWnd,NULL,hInstance,NULL
	  mov hUsernameLabel,eax

	  ; 创建用户名输入
	  INVOKE CreateWindowEx,NULL,addr EditClassName,NULL,
	  WS_CHILD OR WS_VISIBLE OR WS_BORDER OR ES_AUTOHSCROLL ,300,100,200,40,hWnd,NULL,hInstance,NULL
	  mov hUsernameInput,eax

	  ; 创建密码标签
	  INVOKE CreateWindowEx,NULL,addr StaticClassName,addr PasswordLabelText,
	  WS_VISIBLE OR WS_CHILD OR SS_CENTERIMAGE OR SS_RIGHT,10,200,200,40,hWnd,NULL,hInstance,NULL
	  mov hPasswordLabel,eax

	  ; 创建密码输入
	  INVOKE CreateWindowEx,NULL,addr EditClassName,NULL,
	  WS_CHILD OR WS_VISIBLE OR WS_BORDER OR ES_PASSWORD OR  ES_AUTOHSCROLL ,300,200,200,40,hWnd,NULL,hInstance,NULL
	  mov hPasswordInput,eax

	  ; 创建按钮
	  INVOKE CreateWindowEx,NULL,addr ButtonClassName,addr LoginButtonText,
	  WS_CHILD OR WS_VISIBLE OR WS_BORDER OR BS_FLAT ,300,300,200,40,hWnd,LOGIN_BUTTON_ID,hInstance,NULL
	  mov hLoginButton,eax

	  jmp WinProcExit
	.ELSEIF eax == WM_CLOSE		; close window
	  ;INVOKE MessageBox, hWnd, ADDR CloseMsg,
	    ;ADDR WindowName, MB_OK
	  INVOKE PostQuitMessage,0
	  jmp WinProcExit
	.ELSEIF eax == WM_COMMAND
		mov ebx,wParam
		.IF bx == LOGIN_BUTTON_ID
			INVOKE GetWindowText,hUsernameInput,addr usernameBuf,BUF_SIZE
			INVOKE GetWindowText,hPasswordInput,addr passwordBuf,BUF_SIZE
			
			INVOKE DestroyWindow,hUsernameInput
			INVOKE DestroyWindow,hPasswordInput
			INVOKE DestroyWindow,hUsernameLabel
			INVOKE DestroyWindow,hPasswordLabel
			INVOKE DestroyWindow,hLoginButton

			mov SCENE,1

			; 初始化好友列表
			INVOKE initFriendsList,hWnd
		.ELSEIF bx == SEND_IMAGE_BUTTON_ID
			INVOKE sendImage,hWnd
		.ENDIF
		jmp WinProcExit
	.ELSEIF eax == WM_PAINT
		.IF SCENE == 1
			push eax
			INVOKE lstrlen,addr fileNameBuf
			.IF eax != 0
				INVOKE showImage,hWnd
			.ELSE
				INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
			.ENDIF
			pop eax
		.ELSE
			INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
		.ENDIF
		jmp WinProcExit
	.ELSEIF eax == WM_NOTIFY
		mov ebx,wParam
		.IF ebx == FRIENDS_LIST_ID
			mov ecx,lParam
			mov edx,(NMITEMACTIVATE ptr [ecx]).hdr.code
			.IF edx == NM_DBLCLK
				mov edx,(NMITEMACTIVATE ptr [ecx]).iItem
				INVOKE initChatWindow,hWnd,edx
				INVOKE initChatInput,hWnd
				INVOKE initChatSendButton,hWnd
				INVOKE initChatSendImageButton,hWnd
			.ELSE
				INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
				jmp WinProcExit
			.ENDIF
		.ELSE
			INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
			jmp WinProcExit
		.ENDIF
		jmp WinProcExit
	.ELSE		; other message?
	  INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
	  jmp WinProcExit
	.ENDIF

WinProcExit:
	ret
WinProc ENDP

;---------------------------------------------------
ErrorHandler PROC
; Display the appropriate system error message.
;---------------------------------------------------
.data
pErrorMsg  DWORD ?		; ptr to error message
messageID  DWORD ?
.code
	INVOKE GetLastError	; Returns message ID in EAX
	mov messageID,eax

	; Get the corresponding message string.
	INVOKE FormatMessage, FORMAT_MESSAGE_ALLOCATE_BUFFER + \
	  FORMAT_MESSAGE_FROM_SYSTEM,NULL,messageID,NULL,
	  ADDR pErrorMsg,NULL,NULL

	; Display the error message.
	INVOKE MessageBox,NULL, pErrorMsg, ADDR ErrorTitle,
	  MB_ICONERROR+MB_OK

	; Free the error message string.
	INVOKE LocalFree, pErrorMsg
	ret
ErrorHandler ENDP

END WinMain