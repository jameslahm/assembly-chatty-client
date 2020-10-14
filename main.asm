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

include windows.inc 
include user32.inc 
include kernel32.inc 
includelib user32.lib 
includelib kernel32.lib 

; 常量定义
WINDOW_WIDTH = 1000
WINDOW_HEIGHT = 700

; 空间ID定义
LOGIN_BUTTON_ID = 1000

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

; 类名
StaticClassName BYTE "static",0
EditClassName BYTE "edit",0
ButtonClassName BYTE "button",0

; 登录界面
;用户名及密码标签
hUsernameLabel DWORD ?
hPasswordLabel DWORD ?
UsernameLabelText BYTE "Username",0
PasswordLabelText BYTE "Password",0

;用户名及密码输入
hUsernameInput DWORD ?
hPasswordInput DWORD ?

;登录按钮
LoginButtonText BYTE "Login",0
hLoginButton DWORD ?


;=================== CODE =========================
.code
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
	  INVOKE MessageBox, hWnd, ADDR PopupText,
	    ADDR PopupTitle, MB_OK
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
	  mov LoginButton,eax

	  jmp WinProcExit
	.ELSEIF eax == WM_CLOSE		; close window
	  ;INVOKE MessageBox, hWnd, ADDR CloseMsg,
	    ;ADDR WindowName, MB_OK
	  INVOKE PostQuitMessage,0
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