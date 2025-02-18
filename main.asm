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
include wsock32.inc
includelib wsock32.lib


includelib      msvcrt.lib
printf          PROTO C :ptr sbyte, :VARARG
scanf           PROTO C :ptr sbyte, :VARARG
sscanf          PROTO C :ptr byte,:ptr sbyte,:VARARG
sprintf         PROTO C :ptr byte,:ptr sbyte,:VARARG
srand           PROTO C :dword
rand            PROTO C
time	        PROTO C :ptr dword



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
MESSAGE_HEIGHT = 40
IMAGE_WIDTH = 100
IMAGE_HEIGHT = 100

BUF_SIZE = 512
SCROLL_BAR_WIDTH = 20

User STRUCT
	id DWORD -1
	username BYTE BUF_SIZE DUP(0)
User ENDS


Client STRUCT
	clientSocket DWORD -1;
	user User<>
Client ENDS


BZero MACRO buf:=<buf>,bufSize:=<BUF_SIZE>
	INVOKE RtlZeroMemory,addr buf,bufSize
ENDM

Recv MACRO
	.while TRUE
		lea ebx,responseBuf
		add ebx,base
		invoke recv,client.clientSocket,ebx,1,0
		lea ebx,responseBuf
		add ebx,base
		mov eax,[ebx]
		inc base
		.if eax== 0dh
			lea ebx,responseBuf
			add ebx,base
			invoke recv,client.clientSocket,ebx,1,0
			lea ebx,responseBuf
			add ebx,base
			mov eax,[ebx]
			inc base
			.if eax== 0ah
				;invoke MessageBox,hWnd,addr responseBuf,addr WindowName,MB_OK
				.break
			.endif
		.endif
	.endw
	mov base,0;
ENDM

Debug MACRO buf:=<buf>
	INVOKE MessageBox,hWnd,addr buf,addr WindowName,MB_OK
ENDM

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
TIMER_ID = 1004
USERS_LIST_ID = 1005
REGISTER_BUTTON_ID = 1006

;==================== DATA =======================
.data
; 客户端常量
client Client<>
hHeap DWORD ?
base DWORD 0
debounceControl DWORD 0
addFriendIcon BYTE " + ",0
addFriendText BYTE "Add",0

; WSAData init
wsaData WSADATA <>
wVersion WORD 0202h

; logs print format
debugFormat BYTE "DEBUG!!",0dh,0ah,0
debugStrFormat BYTE "DEBUG %s",0dh,0ah,0
debugNumFormat BYTE "DEBUG %d",0dh,0ah,0

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
WindowName  BYTE "Chatty",0
className   BYTE "ASMWin",0
chatClassName BYTE "CHATWIN",0

localIP BYTE "127.0.0.1",0

; Define the Application's Window class structure.
MainWin WNDCLASS <NULL,WinProc,NULL,NULL,NULL,NULL,NULL, \
	COLOR_WINDOW,NULL,className>

ChatMainWin WNDCLASS <NULL,ChatWinProc,NULL,NULL,NULL,NULL,NULL,COLOR_WINDOW,NULL,chatClassName>

msg	      MSG <>
winRect   RECT <>
hMainWnd  DWORD ?
hChatMainWnd DWORD -1
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

; 注册按钮
RegisterButtonText BYTE "Register",0
hRegisterButton DWORD ?

;登录按钮
LoginButtonText BYTE "Login",0
hLoginButton DWORD ?

; 好友列表
friendsListText BYTE "Friends",0
usersListText BYTE "Users",0
hFriendsList DWORD -1
hUsersList DWORD ?
friends User 50 DUP(<>)
users User 50 DUP(<>)

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

; command constants
REGISTER_COMMAND BYTE "REGISTER",0
LOGIN_COMMAND BYTE "LOGIN",0
SEND_TEXT_COMMAND BYTE "TEXT",0
SEND_IMAGE_COMMAND BYTE "IMAGE",0
GET_FRIENDS_COMMAND BYTE "FRIENDS",0
ADD_FRIEND_COMMAND BYTE "ADDFRIEND",0
GET_MESSAGES_COMMAND BYTE "MESSAGES",0
GET_USERS_COMMAND BYTE "USERS",0
GET_LASTMESSAGES_COMMAND BYTE "LASTMESSAGES",0

; 请求
loginRequestFormat BYTE "LOGIN %s %s",0dh,0ah,0
registerRequestFormat BYTE "REGISTER %s %s",0dh,0ah,0
getFriendsRequestFormat BYTE "FRIENDS",0dh,0ah,0
getMessagesRequestFormat BYTE "MESSAGES %d",0dh,0ah,0
getLastMessagesRequestFormat BYTE "LASTMESSAGES %d",0dh,0ah,0
sendTextRequestFormat BYTE "TEXT %d %s",0dh,0ah,0
sendImageRequestFormat BYTE "IMAGE %d %d",0dh,0ah,0
getUsersRequestFormat BYTE "USERS",0dh,0ah,0
addFriendRequestFormat BYTE "ADDFRIEND %d",0dh,0ah,0

; 响应
successResponse BYTE "SUCCESS",0dh,0ah,0
successResponseLen DWORD 9
failureResponse BYTE "ERROR",0dh,0ah,0
failureResponseLen DWORD 7
friendsNumResponseFormat BYTE "FRIENDS %d",0dh,0ah,0
friendsResponseFormat BYTE "%d %s",0dh,0ah,0
usersNumResponseFormat BYTE "USERS %d",0dh,0ah,0
usersResponseFormat BYTE "%d %s",0dh,0ah,0

messagesNumResponseFormat BYTE "MESSAGES %d",0dh,0ah,0
textResponseFormat BYTE "TEXT %d %s",0dh,0ah,0
imageResponseFormat BYTE "IMAGE %d %d",0dh,0ah,0

; 提示信息
loginSuccessInfo BYTE "Login Successful",0
loginErrorInfo BYTE "Login Error",0
registerSuccessInfo BYTE "Register Successful",0

toNumFormat BYTE "%d",0
toStrFormat BYTE "%s",0
toNumStrFormat BYTE "%d %s",0

; 文本消息地址
messages DWORD 100 DUP(-1)

; 打开图片
fileNameStruct   OPENFILENAME <> 
filterString BYTE "Images",0,"*.bmp;*.png",0
fileNameBuf BYTE BUF_SIZE DUP(0)
hBitmap DWORD ?

FAKE_FILENAME BYTE "blpzkzeouy.png",0

Image struct 
	imageName BYTE BUF_SIZE DUP(0)
	height    DWORD -1
Image ends

Text struct
	content BYTE BUF_SIZE DUP(0)
	height DWORD -1
Text ends

sendImages Image 20 DUP(<>)
recvImages Image 20 DUP(<>)
sendTexts Text 50 DUP(<>)
recvTexts Text 50 DUP(<>)

currentMessageHeight DWORD 0

; 当前接收者
receiverId DWORD -1

; 当前滚动高度
scrollPosition DWORD 0

; 聊天框界面
hChatWindow DWORD ?


; 是否连接成功
connectError DWORD 0
connectErrorInfo BYTE "connect error, please close the client and try again",0

; 
FAKE_SEED DWORD 0


;=================== CODE =========================
.code
generateRandomImageName PROC buf:ptr BYTE
	local count:sdword
	mov count,10

	invoke time,NULL
	invoke srand,eax
		
	.while count>=1
		invoke rand
		mov edx,0
		mov ecx,26
		div ecx
		mov eax,edx
		add eax,61h
		
		mov ecx,buf

		mov edx,count
		mov ebx,10
		sub ebx,edx
		mov [ecx+ebx],al

		dec count
	.endw

	invoke srand,FAKE_SEED

	mov count,10
	.while count>=1
		invoke rand
		mov edx,0
		mov ecx,26
		div ecx
		mov eax,edx
		add eax,61h
		
		mov ecx,buf
		add ecx,10

		mov edx,count
		mov ebx,10
		sub ebx,edx
		mov [ecx+ebx],al

		dec count
	.endw

	inc FAKE_SEED

	inc ebx
	mov eax,02eh
	mov [ecx+ebx],eax

	inc ebx
	mov eax,062h
	mov [ecx+ebx],eax

	inc ebx
	mov eax,06dh
	mov [ecx+ebx],eax

	inc ebx
	mov eax,070h
	mov [ecx+ebx],eax

	ret
generateRandomImageName ENDP

addFriend PROC hWnd:DWORD,userId:DWORD
	local friendId:DWORD
	local requestBuf[BUF_SIZE]:BYTE
	local responseBuf[BUF_SIZE]:BYTE

	BZero requestBuf

	mov edx,0
	mov eax,offset users
	.while edx< userId
		add eax,sizeof User
		inc edx
	.endw

	assume eax: ptr User
	push [eax].id
	pop friendId

	invoke sprintf,addr requestBuf,addr addFriendRequestFormat,friendId
	invoke lstrlen,addr requestBuf
	mov ebx,eax
	invoke send,client.clientSocket,addr requestBuf,ebx,0

	invoke recv,client.clientSocket,addr responseBuf,BUF_SIZE,0
	ret
addFriend ENDP

initFriend PROC friendIdAddr:PTR DWORD,friendNameAddr:ptr byte
	mov eax,offset friends
	assume eax:ptr User
	.WHILE TRUE
		.if [eax].id == -1
			mov ebx,friendIdAddr
			push [ebx]
			pop [eax].id

			invoke lstrcpy,addr [eax].username,friendNameAddr

			assume eax:nothing
			.BREAK
		.else
			add eax,sizeof User
		.endif
	.ENDW
	ret
initFriend ENDP

initUser PROC userIdAddr:PTR DWORD,userNameAddr:ptr byte
	mov eax,offset users
	assume eax:ptr User
	.WHILE TRUE
		.if [eax].id == -1
			mov ebx,userIdAddr
			push [ebx]
			pop [eax].id

			invoke lstrcpy,addr [eax].username,userNameAddr

			assume eax:nothing
			.BREAK
		.else
			add eax,sizeof User
		.endif
	.ENDW
	ret
initUser ENDP

initUsersList PROC hWnd:DWORD
	LOCAL lvc:LV_COLUMN
	LOCAL lvi:LV_ITEM
	local responseBuf[BUF_SIZE]:BYTE
	local usersNum:DWORD
	local userId:DWORD
	local userName[BUF_SIZE]:DWORD
	local count:DWORD

	BZero responseBuf

	invoke CreateWindowEx, NULL, addr ListClassName, NULL, LVS_REPORT+WS_CHILD+WS_VISIBLE+WS_VSCROLL,0,CLIENT_HEIGHT/2,300,CLIENT_HEIGHT/2,hWnd, USERS_LIST_ID, hInstance, NULL
    mov hUsersList, eax

	mov lvc.imask,LVCF_TEXT+LVCF_WIDTH
	mov lvc.pszText,offset addFriendText
	mov lvc.lx,50
	invoke SendMessage,hUsersList, LVM_INSERTCOLUMN, 0, addr lvc

	mov lvc.imask,LVCF_TEXT+LVCF_WIDTH
	mov lvc.pszText,offset usersListText
	mov lvc.lx,250
	invoke SendMessage,hUsersList, LVM_INSERTCOLUMN, 1, addr lvc

	invoke lstrlen,addr getUsersRequestFormat

	invoke send,client.clientSocket,addr getUsersRequestFormat,eax,0

	Recv
	;invoke recv,client.clientSocket,addr responseBuf,BUF_SIZE-1,0

	invoke lstrlen,addr responseBuf

	invoke sscanf,addr responseBuf,addr usersNumResponseFormat,addr usersNum

	mov ecx,1
	
	.while ecx <= usersNum
		push ecx
		BZero responseBuf
		BZero userName

		Recv
		;invoke recv,client.clientSocket,addr responseBuf,BUF_SIZE-1,0

		;Debug responseBuf

		invoke sscanf,addr responseBuf,addr usersResponseFormat,addr userId,addr userName

		invoke initUser,addr userId,addr userName
		pop ecx
		inc ecx
	.endw

	mov eax,offset users
	assume eax:ptr User
	mov count,0
	.while TRUE
		.if [eax].id != -1

			mov lvi.imask,LVIF_TEXT+LVIF_PARAM
			;mov ecx,[eax].id
			push count
			pop lvi.iItem
			mov lvi.iSubItem,0
			lea ebx,addFriendIcon
			mov lvi.pszText,ebx
			push eax
			invoke SendMessage,hUsersList, LVM_INSERTITEM,0, addr lvi
			pop eax

			mov lvi.iSubItem,1
			lea ebx,[eax].username
			mov lvi.pszText,ebx
			push eax
			invoke SendMessage,hUsersList,LVM_SETITEMTEXT,count, addr lvi

			inc count
			pop eax

			add eax,sizeof User
		.else
			.break
		.endif
	.endw

	INVOKE InvalidateRect,hChatMainWnd, NULL, FALSE
	INVOKE InvalidateRect,hWnd, NULL, FALSE

	ret
initUsersList ENDP

clearFriends PROC
	mov eax,offset friends
	assume eax:ptr User
	.WHILE TRUE
		.if [eax].id != -1
			push -1
			pop [eax].id

			push eax
			BZero [eax].username
			pop eax
			add eax,sizeof User
		.else
			.BREAK
		.endif
	.ENDW
	ret
clearFriends ENDP

; 初始化好友列表
initFriendsList PROC hWnd:DWORD
	LOCAL lvc:LV_COLUMN
	LOCAL lvi:LV_ITEM
	local responseBuf[BUF_SIZE]:BYTE
	local friendsNum:DWORD
	local friendId:DWORD
	local friendName[BUF_SIZE]:DWORD

	BZero responseBuf

	.if hFriendsList != -1
		invoke DestroyWindow,hFriendsList
		invoke clearFriends
	.endif

	invoke CreateWindowEx, NULL, addr ListClassName, NULL, LVS_REPORT+WS_CHILD+WS_VISIBLE+WS_VSCROLL, 0,0,300,CLIENT_HEIGHT/2,hWnd, FRIENDS_LIST_ID, hInstance, NULL
    mov hFriendsList, eax

	mov lvc.imask,LVCF_TEXT+LVCF_WIDTH
	mov lvc.pszText,offset friendsListText
	mov lvc.lx,300
	invoke SendMessage,hFriendsList, LVM_INSERTCOLUMN, 0, addr lvc

	invoke lstrlen,addr getFriendsRequestFormat

	invoke send,client.clientSocket,addr getFriendsRequestFormat,eax,0

	Recv
	;invoke recv,client.clientSocket,addr responseBuf,BUF_SIZE-1,0

	invoke lstrlen,addr responseBuf

	invoke sscanf,addr responseBuf,addr friendsNumResponseFormat,addr friendsNum

	mov ecx,1
	.while ecx <= friendsNum
		push ecx
		BZero responseBuf
		BZero friendName

		Recv
		;invoke recv,client.clientSocket,addr responseBuf,BUF_SIZE-1,0

		;Debug responseBuf

		invoke sscanf,addr responseBuf,addr friendsResponseFormat,addr friendId,addr friendName

		invoke initFriend,addr friendId,addr friendName
		pop ecx
		inc ecx
	.endw

	mov eax,offset friends
	assume eax:ptr User
	.while TRUE
		.if [eax].id != -1
			mov lvi.imask,LVIF_TEXT+LVIF_PARAM
			mov ecx,[eax].id
	
			mov lvi.iItem,ecx
			mov lvi.iSubItem,0
			lea ebx,[eax].username
			mov lvi.pszText,ebx
			push eax
			invoke SendMessage,hFriendsList, LVM_INSERTITEM,0, addr lvi
			pop eax
			add eax,sizeof User
		.else
			.break
		.endif
	.endw

	INVOKE InvalidateRect,hChatMainWnd, NULL, FALSE
	INVOKE InvalidateRect,hWnd, NULL, FALSE

	ret
initFriendsList ENDP

addSendText PROC bufAddr:DWORD,height:DWORD
	mov eax,offset sendTexts
	.WHILE TRUE
		assume eax:ptr Text
		mov ebx,[eax].height
		.if ebx==-1
			push eax
			invoke lstrcpy,addr [eax].content,bufAddr
			pop eax
			
			push height
			pop [eax].height
			.BREAK
		.else
			add eax,sizeof Text
		.endif
	.endw
	ret
addSendText ENDP

addRecvText PROC bufAddr:DWORD,height:DWORD
	mov eax,offset recvTexts
	.WHILE TRUE
		assume eax:ptr Text
		mov ebx,[eax].height
		.if ebx==-1
			push eax
			invoke lstrcpy,addr [eax].content,bufAddr
			pop eax
			
			push height
			pop [eax].height
			.BREAK
		.else
			add eax,sizeof Text
		.endif
	.endw
	ret
addRecvText ENDP

addSendImage PROC bufAddr:DWORD,height:DWORD
	mov eax,offset sendImages
	.WHILE TRUE
		assume eax:ptr Image
		mov ebx,[eax].height
		.if ebx== -1
			push eax
			invoke lstrcpy,addr [eax].imageName,bufAddr
			pop eax
			
			push height
			pop [eax].height
			.BREAK
		.else
			add eax,sizeof Image
		.endif
	.endw
	ret
addSendImage ENDP

addRecvImage PROC bufAddr:DWORD,height:DWORD
	mov eax,offset recvImages
	.WHILE TRUE
		assume eax:ptr Image
		mov ebx,[eax].height
		.if ebx== -1
			push eax
			invoke lstrcpy,addr [eax].imageName,bufAddr
			pop eax
			
			push height
			pop [eax].height
			.BREAK
		.else
			add eax,sizeof Image
		.endif
	.endw
	ret
addRecvImage ENDP

clearSendTexts PROC
	mov eax,offset sendTexts
	.WHILE TRUE
		assume eax:ptr Text
		mov ebx,[eax].height
		.if ebx== -1
			.BREAK
		.else
			mov [eax].height,-1
			add eax,sizeof Text
		.endif
	.endw
	ret
clearSendTexts ENDP

clearRecvTexts PROC
	mov eax,offset recvTexts
	.WHILE TRUE
		assume eax:ptr Text
		mov ebx,[eax].height
		.if ebx== -1
			.BREAK
		.else
			mov [eax].height,-1
			add eax,sizeof Text
		.endif
	.endw
	ret
clearRecvTexts ENDP

clearSendImages PROC
	mov eax,offset sendImages
	.WHILE TRUE
		assume eax:ptr Image
		mov ebx,[eax].height
		.if ebx== -1
			.BREAK
		.else
			mov [eax].height,-1
			add eax,sizeof Image
		.endif
	.endw
	ret
clearSendImages ENDP

clearRecvImages PROC
	mov eax,offset recvImages
	.WHILE TRUE
		assume eax:ptr Image
		mov ebx,[eax].height
		.if ebx== -1
			.BREAK
		.else
			mov [eax].height,-1
			add eax,sizeof Image
		.endif
	.endw
	ret
clearRecvImages ENDP


initChatWindow PROC hWnd:DWORD,friendId:DWORD
	local getMessagesRequestBuf[BUF_SIZE]:BYTE
	local responseBuf[BUF_SIZE]:BYTE
	local commandType[BUF_SIZE]:BYTE
	local row:DWORD
	local messageAddr:DWORD
	local imageSize:DWORD
	local imageBuf[BUF_SIZE]:BYTE
	local imageName[BUF_SIZE]:BYTE
	local fileHandle:DWORD
	local hasReceivedSize:DWORD
	local message:DWORD
	local bytesWrite:DWORD
	local content[BUF_SIZE]:BYTE
	local isRecv:DWORD

	BZero commandType
	mov row,0

	mov edx,0
	mov eax,offset friends
	.while edx<friendId
		add eax,sizeof User
		inc edx
	.endw

	assume eax: ptr User
	mov ebx,[eax].id
	.if ebx == receiverId
		jmp initChatWindowExit
	.endif

	mov currentMessageHeight,0
	push [eax].id
	pop receiverId

	invoke clearSendTexts
	invoke clearRecvTexts
	invoke clearSendImages
	invoke clearRecvImages

	BZero getMessagesRequestBuf
	invoke sprintf,addr getMessagesRequestBuf,addr getMessagesRequestFormat,receiverId

	invoke lstrlen,addr getMessagesRequestBuf
	mov ecx,eax

	invoke send,client.clientSocket,addr getMessagesRequestBuf,ecx,0

	BZero responseBuf

	Recv
	;invoke recv,client.clientSocket,addr responseBuf,BUF_SIZE-1,0

	invoke sscanf,addr responseBuf,addr messagesNumResponseFormat,addr row


	mov ecx,1
	.while ecx <= row
		push ecx
		BZero responseBuf

		;Recv
		;invoke recv,client.clientSocket,addr responseBuf,BUF_SIZE-1,0
		;invoke MessageBox,hWnd,addr responseBuf,addr WindowName,MB_OK
		Recv
		;invoke recv,client.clientSocket,addr responseBuf,BUF_SIZE-1,0

		BZero commandType
		invoke sscanf,addr responseBuf,addr toStrFormat,addr commandType

		invoke lstrcmp,addr commandType,addr SEND_TEXT_COMMAND

		.if eax==0
				BZero content

				invoke sscanf,addr responseBuf,addr textResponseFormat,addr isRecv,addr content

				.if isRecv == 0
					invoke addSendText,addr content,currentMessageHeight
				.else
					invoke addRecvText,addr content,currentMessageHeight
				.endif
				
				mov eax,currentMessageHeight
				add eax,MESSAGE_HEIGHT
				mov currentMessageHeight,eax
		.else
			BZero imageName
			invoke generateRandomImageName,addr imageName
			invoke sscanf,addr responseBuf,addr imageResponseFormat,addr isRecv,addr imageSize

			;create image file
			invoke CreateFile,addr imageName,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL OR FILE_FLAG_WRITE_THROUGH,0
			mov fileHandle,eax

			; start recv image content
			mov hasReceivedSize,0
			mov eax,imageSize

			.WHILE hasReceivedSize < eax
				push eax
				mov ebx,hasReceivedSize
				mov ecx,eax
				sub ecx,ebx
				.if ecx > BUF_SIZE - 1
					mov ecx,BUF_SIZE -1
				.endif
				invoke recv,client.clientSocket,addr imageBuf,ecx,0
				add hasReceivedSize,eax
				mov ebx,eax
				invoke WriteFile,fileHandle,addr imageBuf,ebx,addr bytesWrite,NULL
				pop eax
			.endw
			invoke CloseHandle,fileHandle

			.if isRecv == 0
				invoke addSendImage,addr imageName,currentMessageHeight
			.else
				invoke addRecvImage,addr imageName,currentMessageHeight
			.endif

			mov eax,currentMessageHeight
			add eax,IMAGE_HEIGHT
			mov currentMessageHeight,eax
		.endif
		pop ecx
		inc ecx
	.endw

	mov ebx,currentMessageHeight
	add ebx,150
	mov ecx,CLIENT_HEIGHT
	sub ebx,ecx
	invoke SetScrollRange,hChatMainWnd, SB_VERT, 0,ebx , TRUE;
	INVOKE InvalidateRect,hChatMainWnd, NULL, FALSE
	INVOKE InvalidateRect,hWnd, NULL, FALSE

initChatWindowExit:
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

showMessages PROC hWnd:DWORD
	LOCAL ps:PAINTSTRUCT
	LOCAL hdc:HDC
	LOCAL rect:RECT;
	local contentAddr:DWORD
	local height:DWORD
	LOCAL hMemDC:HDC
	local fileNameAddr:DWORD

	invoke BeginPaint,hWnd,addr ps
	mov    hdc,eax

	mov eax,offset sendTexts
	.while TRUE
		push eax
		assume eax: ptr Text
		lea ecx,[eax].content
		mov contentAddr,ecx
		push [eax].height
		pop height

		.if height == -1
			.break
		.endif
		
		mov eax,height
		sub eax,scrollPosition
		mov height,eax
		invoke SetTextAlign,hdc,TA_RIGHT
		invoke lstrlen,contentAddr
		mov ebx,eax
		invoke TextOut,hdc,CLIENT_WIDTH-FRIENDS_LIST_WIDTH-SCROLL_BAR_WIDTH,height,contentAddr,ebx

		pop eax
		add eax,sizeof Text
	.endw

	mov eax,offset recvTexts
	.while TRUE
		push eax
		assume eax: ptr Text
		lea ecx,[eax].content
		mov contentAddr,ecx
		push [eax].height
		pop height

		.if height == -1
			.break
		.endif

		mov eax,height
		sub eax,scrollPosition
		mov height,eax
		
		invoke SetTextAlign,hdc,TA_LEFT
		invoke lstrlen,contentAddr
		mov ebx,eax
		invoke TextOut,hdc,0,height,contentAddr,ebx

		pop eax
		add eax,sizeof Text
	.endw

	

	mov eax,offset sendImages
	.while TRUE
		push eax
		assume eax: ptr Image
		lea ecx,[eax].imageName
		mov fileNameAddr,ecx
		push [eax].height
		pop height

		.if height == -1
			.break
		.endif
		
		mov eax,height
		sub eax,scrollPosition
		mov height,eax

		invoke lstrcmp,fileNameAddr,addr FAKE_FILENAME

		invoke LoadImage,NULL,fileNameAddr,IMAGE_BITMAP,100,100,LR_LOADFROMFILE
		.if eax == 0
			invoke GetLastError
		.endif
		mov hBitmap,eax
		invoke CreateCompatibleDC,hdc
		mov    hMemDC,eax
		invoke SelectObject,hMemDC,hBitmap
		invoke GetClientRect,hWnd,addr rect
		invoke BitBlt,hdc,600-SCROLL_BAR_WIDTH,height,rect.right,rect.bottom,hMemDC,0,0,SRCCOPY
		invoke DeleteDC,hMemDC
		invoke DeleteObject,hBitmap

		pop eax
		add eax,sizeof Image
	.endw

	mov eax,offset recvImages
	.while TRUE
		push eax
		assume eax: ptr Image
		lea ecx,[eax].imageName
		mov fileNameAddr,ecx
		push [eax].height
		pop height

		.if height == -1
			.break
		.endif

		mov eax,height
		sub eax,scrollPosition
		mov height,eax

		invoke LoadImage,NULL,fileNameAddr,IMAGE_BITMAP,100,100,LR_LOADFROMFILE
		mov hBitmap,eax
		invoke CreateCompatibleDC,hdc
		mov    hMemDC,eax
		invoke SelectObject,hMemDC,hBitmap
		invoke GetClientRect,hWnd,addr rect
		invoke BitBlt,hdc,0,height,rect.right,rect.bottom,hMemDC,0,0,SRCCOPY
		invoke DeleteDC,hMemDC
		invoke DeleteObject,hBitmap

		pop eax
		add eax,sizeof Image
	.endw

	invoke EndPaint,hWnd,addr ps

	ret
showMessages ENDP

sendImage PROC hWnd:DWORD
	local requestBuf[BUF_SIZE]:BYTE
	local responseBuf[BUF_SIZE]:BYTE
	local fileHandle:DWORD
	local imageSize:DWORD
	local imageBuf[BUF_SIZE]:BYTE
	local bytesRead:DWORD

	BZero requestBuf
	BZero responseBuf
	BZero fileNameBuf

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

		invoke CreateFile,addr fileNameBuf,GENERIC_READ,0,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
		mov fileHandle,eax

		invoke GetFileSize,fileHandle,addr imageSize
		mov imageSize,eax

		invoke sprintf,addr requestBuf,addr sendImageRequestFormat,receiverId,imageSize
		invoke lstrlen,addr requestBuf
		invoke send,client.clientSocket,addr requestBuf,eax,0

		.WHILE TRUE
			BZero imageBuf
			invoke ReadFile,fileHandle,addr imageBuf,BUF_SIZE-1,addr bytesRead,NULL

			.if eax==0
				invoke GetLastError
				invoke printf,addr debugNumFormat,eax
			.endif

			invoke send,client.clientSocket,addr imageBuf,bytesRead,0

			mov eax,bytesRead
			.if eax < BUF_SIZE -1
				.BREAK
			.endif
		.ENDW

		invoke addSendImage,addr fileNameBuf,currentMessageHeight

		mov eax,currentMessageHeight
		add eax,IMAGE_HEIGHT
		mov currentMessageHeight,eax

		invoke CloseHandle,fileHandle

		invoke recv,client.clientSocket,addr responseBuf,BUF_SIZE-1,0
	.ENDIF

	mov ebx,currentMessageHeight
	add ebx,150
	mov ecx,CLIENT_HEIGHT
	sub ebx,ecx
	invoke SetScrollRange,hChatMainWnd, SB_VERT, 0,ebx , TRUE;

	INVOKE InvalidateRect,hChatMainWnd, NULL, FALSE
	INVOKE InvalidateRect,hWnd, NULL, FALSE
	ret 
sendImage ENDP

sendText PROC hWnd:DWORD
	local requestBuf[BUF_SIZE]:BYTE
	local responseBuf[BUF_SIZE]:BYTE
	local message[BUF_SIZE]:BYTE

	BZero requestBuf
	BZero responseBuf
	BZero message

	invoke GetWindowText,hChatInput,addr message,BUF_SIZE
	
	invoke sprintf,addr requestBuf,addr sendTextRequestFormat,receiverId,addr message

	invoke lstrlen,addr requestBuf
	mov ebx,eax
	invoke send,client.clientSocket,addr requestBuf,ebx,0

	Recv
	;invoke recv,client.clientSocket,addr responseBuf,BUF_SIZE-1,0

	;INVOKE CreateWindowEx,NULL,addr StaticClassName,addr message,
					;WS_VISIBLE OR WS_CHILD OR SS_CENTERIMAGE OR SS_RIGHT,FRIENDS_LIST_WIDTH,currentMessageHeight,CLIENT_WIDTH-FRIENDS_LIST_WIDTH,MESSAGE_HEIGHT,hWnd,NULL,hInstance,NULL
	invoke addSendText,addr message,currentMessageHeight
	mov eax,currentMessageHeight
	add eax,MESSAGE_HEIGHT
	mov currentMessageHeight,eax

	mov ebx,currentMessageHeight
	mov ecx,CLIENT_HEIGHT
	add ebx,150
	sub ebx,ecx
	invoke SetScrollRange,hChatMainWnd, SB_VERT, 0,ebx , TRUE;

	INVOKE InvalidateRect,hChatMainWnd, NULL, FALSE
	INVOKE InvalidateRect,hWnd, NULL, FALSE
	ret
sendText ENDP

handleLogin PROC hWnd:DWORD
	local loginRequestBuf[BUF_SIZE]:BYTE
	local responseBuf[BUF_SIZE]:BYTE

	BZero loginRequestBuf
	BZero responseBuf

	.if connectError == 1
		invoke MessageBox,hWnd,addr connectErrorInfo,addr WindowName,MB_OK
		jmp handleLoginExit
	.endif

	INVOKE GetWindowText,hUsernameInput,addr usernameBuf,BUF_SIZE
	INVOKE GetWindowText,hPasswordInput,addr passwordBuf,BUF_SIZE

	invoke sprintf,addr loginRequestBuf,addr loginRequestFormat,addr usernameBuf,addr passwordBuf
	
	invoke lstrlen,addr loginRequestBuf
	invoke send,client.clientSocket,addr loginRequestBuf,eax,0

	Recv
	;invoke recv,client.clientSocket,addr responseBuf,BUF_SIZE -1,0

	invoke lstrcmp,addr responseBuf,addr successResponse

	.if eax==0
		INVOKE DestroyWindow,hUsernameInput
		INVOKE DestroyWindow,hPasswordInput
		INVOKE DestroyWindow,hUsernameLabel
		INVOKE DestroyWindow,hPasswordLabel
		INVOKE DestroyWindow,hLoginButton
		INVOKE DestroyWindow,hRegisterButton
		invoke MessageBox,hWnd,addr loginSuccessInfo,addr WindowName,MB_OK

		mov SCENE,1

		; 初始化好友列表
		INVOKE initFriendsList,hWnd
		invoke initUsersList,hWnd

		INVOKE CreateWindowEx, 0, ADDR chatClassName,
					  ADDR WindowName,WS_CHILD + WS_VISIBLE  + WS_VSCROLL,
					 FRIENDS_LIST_WIDTH,0,CLIENT_WIDTH - FRIENDS_LIST_WIDTH,
					  CLIENT_HEIGHT-CHAT_INPUT_HEIGHT,hWnd,NULL,hInstance,NULL
		mov hChatMainWnd,eax

		INVOKE InvalidateRect,hWnd, NULL, FALSE
	.else
		invoke MessageBox,hWnd,addr loginErrorInfo,addr WindowName,MB_OK
	.endif

handleLoginExit:
	ret
handleLogin ENDP


initClient PROC
	local @sock_addr:sockaddr_in

	invoke WSAStartup,wVersion,addr wsaData

	invoke socket,AF_INET,SOCK_STREAM,IPPROTO_TCP
	.if eax == INVALID_SOCKET
		invoke WSAGetLastError
		invoke printf ,addr debugNumFormat,eax
	.ENDIF


	mov client.clientSocket,eax
	invoke RtlZeroMemory,addr @sock_addr,sizeof @sock_addr

	PORT = 5000
	invoke htons,PORT
	mov @sock_addr.sin_port,ax
	mov @sock_addr.sin_family,AF_INET
	invoke inet_addr,addr localIP
	mov @sock_addr.sin_addr,eax
	invoke connect,client.clientSocket,addr @sock_addr,sizeof @sock_addr

	.if eax !=0
		mov connectError,1
	.endif

	ret
initClient ENDP

WinMain PROC
	invoke initClient
	INVOKE GetProcessHeap
	mov hHeap,eax
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
	INVOKE RegisterClass,addr ChatMainWin
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

getLastMessages PROC hWnd:DWORD
	local getLastMessagesRequestBuf[BUF_SIZE]:BYTE
	local responseBuf[BUF_SIZE]:BYTE
	local commandType[BUF_SIZE]:BYTE
	local row:DWORD
	local messageAddr:DWORD
	local imageSize:DWORD
	local imageBuf[BUF_SIZE]:BYTE
	local imageName[BUF_SIZE]:BYTE
	local fileHandle:DWORD
	local hasReceivedSize:DWORD
	local message:DWORD
	local bytesWrite:DWORD
	local content[BUF_SIZE]:BYTE
	local isRecv:DWORD

	BZero commandType
	mov row,0

	BZero getLastMessagesRequestBuf
	invoke sprintf,addr getLastMessagesRequestBuf,addr getLastMessagesRequestFormat,receiverId

	invoke lstrlen,addr getLastMessagesRequestBuf
	mov ecx,eax

	invoke send,client.clientSocket,addr getLastMessagesRequestBuf,ecx,0

	BZero responseBuf
	Recv
	;invoke recv,client.clientSocket,addr responseBuf,BUF_SIZE-1,0

	invoke sscanf,addr responseBuf,addr messagesNumResponseFormat,addr row

	mov ecx,1
	.while ecx <= row
		push ecx
		BZero responseBuf

		Recv
		;invoke recv,client.clientSocket,addr responseBuf,BUF_SIZE-1,0

		BZero commandType
		invoke sscanf,addr responseBuf,addr toStrFormat,addr commandType

		invoke lstrcmp,addr commandType,addr SEND_TEXT_COMMAND

		.if eax==0
				BZero content

				invoke sscanf,addr responseBuf,addr textResponseFormat,addr isRecv,addr content

				invoke addRecvText,addr content,currentMessageHeight

				;INVOKE CreateWindowEx,NULL,addr StaticClassName,message,
					;WS_VISIBLE OR WS_CHILD OR SS_CENTERIMAGE,FRIENDS_LIST_WIDTH,currentMessageHeight,CLIENT_WIDTH-FRIENDS_LIST_WIDTH,MESSAGE_HEIGHT,hWnd,NULL,hInstance,NULL
				
				mov eax,currentMessageHeight
				add eax,MESSAGE_HEIGHT
				mov currentMessageHeight,eax

		.else
			BZero imageName
			invoke generateRandomImageName,addr imageName
			invoke sscanf,addr responseBuf,addr imageResponseFormat,addr isRecv,addr imageSize

			;create image file
			invoke CreateFile,addr imageName,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL OR FILE_FLAG_WRITE_THROUGH,0
			mov fileHandle,eax

			; start recv image content
			mov hasReceivedSize,0
			mov eax,imageSize

			.WHILE hasReceivedSize < eax
				push eax
				mov ebx,hasReceivedSize
				mov ecx,eax
				sub ecx,ebx
				.if ecx > BUF_SIZE - 1
					mov ecx,BUF_SIZE -1
				.endif
				invoke recv,client.clientSocket,addr imageBuf,ecx,0
				add hasReceivedSize,eax
				mov ebx,eax
				invoke WriteFile,fileHandle,addr imageBuf,ebx,addr bytesWrite,NULL
				pop eax
			.endw
			invoke CloseHandle,fileHandle

			invoke addRecvImage,addr imageName,currentMessageHeight
			mov eax,currentMessageHeight
			add eax,IMAGE_HEIGHT
			mov currentMessageHeight,eax

		.endif
		pop ecx
		inc ecx
	.endw

	mov ebx,currentMessageHeight
	add ebx,150
	mov ecx,CLIENT_HEIGHT
	sub ebx,ecx
	invoke SetScrollRange,hChatMainWnd, SB_VERT, 0,ebx , TRUE;
	INVOKE InvalidateRect,hChatMainWnd, NULL, FALSE
	INVOKE InvalidateRect,hWnd, NULL, FALSE
	ret
getLastMessages ENDP

handleRegister PROC hWnd:DWORD
	local registerRequestBuf[BUF_SIZE]:BYTE
	local responseBuf[BUF_SIZE]:BYTE

	BZero registerRequestBuf
	BZero responseBuf

	.if connectError == 1
		invoke MessageBox,hWnd,addr connectErrorInfo,addr WindowName,MB_OK
		jmp handleRegisterExit
	.endif

	INVOKE GetWindowText,hUsernameInput,addr usernameBuf,BUF_SIZE
	INVOKE GetWindowText,hPasswordInput,addr passwordBuf,BUF_SIZE
			

	invoke sprintf,addr registerRequestBuf,addr registerRequestFormat,addr usernameBuf,addr passwordBuf
	
	invoke lstrlen,addr registerRequestBuf
	invoke send,client.clientSocket,addr registerRequestBuf,eax,0

	Recv
	;invoke recv,client.clientSocket,addr responseBuf,BUF_SIZE -1,0

	invoke lstrcmp,addr responseBuf,addr successResponse

	.if eax==0
		invoke MessageBox,hWnd,addr registerSuccessInfo,addr WindowName,MB_OK
	.endif


	INVOKE InvalidateRect,hWnd, NULL, FALSE

handleRegisterExit:
	ret
handleRegister ENDP

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

	  mov ebx,currentMessageHeight
	  add ebx,150
	  mov ecx,CLIENT_HEIGHT
	  sub ebx,ecx
	  invoke SetScrollRange,hChatMainWnd, SB_VERT, 0,ebx , TRUE;

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
	  INVOKE CreateWindowEx,NULL,addr ButtonClassName,addr RegisterButtonText,
	  WS_CHILD OR WS_VISIBLE OR WS_BORDER OR BS_FLAT ,400,300,200,40,hWnd,REGISTER_BUTTON_ID,hInstance,NULL
	  mov hRegisterButton,eax

	  INVOKE CreateWindowEx,NULL,addr ButtonClassName,addr LoginButtonText,
		WS_CHILD OR WS_VISIBLE OR WS_BORDER OR BS_FLAT ,150,300,200,40,hWnd,LOGIN_BUTTON_ID,hInstance,NULL
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
			invoke handleLogin,hWnd
		.elseif bx == REGISTER_BUTTON_ID
			invoke handleRegister,hWnd
		.ELSEIF bx == SEND_IMAGE_BUTTON_ID
			INVOKE sendImage,hWnd

		.elseif bx == SEND_BUTTON_ID
			invoke sendText,hWnd
		.ENDIF
		;jmp WinProcExit
	.ELSEIF eax == WM_PAINT
		.IF SCENE == 1
			;invoke showMessages,hWnd
				;INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
			INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
		.ELSE
			;INVOKE showImage,hWnd
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
				
				.if edx == -1
					INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
					jmp WinProcExit
				.endif

				push edx
				.if receiverId == -1
					invoke SetTimer,hWnd,TIMER_ID,4000,NULL
				.endif

				.if receiverId == -1
					INVOKE initChatInput,hWnd
					INVOKE initChatSendButton,hWnd
					INVOKE initChatSendImageButton,hWnd
				.endif

				pop edx
				INVOKE initChatWindow,hWnd,edx

			.ELSE
				INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
				jmp WinProcExit
			.ENDIF
		.elseif ebx == USERS_LIST_ID
			mov ecx,lParam
			mov edx,(NMITEMACTIVATE ptr [ecx]).hdr.code
			.IF edx == NM_DBLCLK
				mov edx,(NMITEMACTIVATE ptr [ecx]).iItem
				invoke addFriend,hWnd,edx
				invoke initFriendsList,hWnd
			.ELSE
				INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
				jmp WinProcExit
			.ENDIF
		.ELSE
			INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
			jmp WinProcExit
		.ENDIF
		jmp WinProcExit
	.ELSEIF eax == WM_TIMER
		mov eax,wParam
		.if eax == TIMER_ID
			;INVOKE MessageBox, hWnd, ADDR CloseMsg,
			;ADDR WindowName, MB_OK
			invoke getLastMessages,hWnd
		.endif
	.ELSE		; other message?
	  INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
	  jmp WinProcExit
	.ENDIF

WinProcExit:
	ret
WinProc ENDP

ChatWinProc PROC,
	hWnd:DWORD, localMsg:DWORD, wParam:DWORD, lParam:DWORD
; The application's message handler, which handles
; application-specific messages. All other messages
; are forwarded to the default Windows message
; handler.
;-----------------------------------------------------
	mov eax, localMsg

	.IF eax == WM_LBUTTONDOWN		; mouse button
	  jmp ChatWinProcExit
	.ELSEIF eax == WM_CREATE		; create window
	.ELSEIF eax == WM_PAINT
		.IF SCENE == 1
			invoke showMessages,hWnd
				;INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
		.ELSE
			;INVOKE showImage,hWnd
			INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
		.ENDIF
		jmp ChatWinProcExit
	.elseif eax == WM_VSCROLL
		mov ebx,wParam
		push scrollPosition
		.if bx  == SB_LINEUP
			sub scrollPosition,10
			mov debounceControl,10
		.elseif bx == SB_LINEDOWN
			add scrollPosition,10
			mov debounceControl,10
		.elseif bx == SB_PAGEUP
			sub scrollPosition,100
			mov debounceControl,10
		.elseif bx == SB_PAGEDOWN
			add scrollPosition,100
			mov debounceControl,10
		.elseif bx==SB_THUMBTRACK
			shr ebx,16
			mov scrollPosition,ebx
			inc debounceControl
		.elseif bx ==SB_THUMBPOSITION
			;INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
			mov debounceControl,10
		.endif

		invoke GetScrollPos,hChatMainWnd,SB_VERT
		.if eax!= scrollPosition
			invoke SetScrollPos,hChatMainWnd, SB_VERT, scrollPosition , TRUE
			pop ecx
			mov edx,scrollPosition
			sub ecx,edx

			;invoke ScrollWindow,hChatMainWnd, 0, ecx, NULL, NULL;
			
			.if debounceControl >= 10
				invoke InvalidateRect,hChatMainWnd,NULL,TRUE
				;invoke UpdateWindow,hChatMainWnd
				mov debounceControl,0
			.endif
		.endif

		
		
		jmp ChatWinProcExit
	.ELSE		; other message?
	  INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
	  jmp ChatWinProcExit
	.ENDIF

ChatWinProcExit:
	ret
ChatWinProc ENDP

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