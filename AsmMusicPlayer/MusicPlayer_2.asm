.386

.model	flat, stdcall
option	casemap :none

;include files
INCLUDE	windows.inc
INCLUDE	user32.inc
INCLUDE	kernel32.inc
INCLUDE	comctl32.inc	
INCLUDE	winmm.inc
INCLUDE	comdlg32.inc
INCLUDE	msvcrt.inc
INCLUDE shlwapi.inc
INCLUDE gdi32.inc
INCLUDE gdiplus.inc
INCLUDE wsock32.inc

;include libs
INCLUDELIB shlwapi.lib
INCLUDELIB user32.lib
INCLUDELIB kernel32.lib
INCLUDELIB comctl32.lib
INCLUDELIB winmm.lib
INCLUDELIB msvcrt.lib
INCLUDELIB comdlg32.lib
INCLUDELIB gdi32.lib
INCLUDELIB gdiplus.lib
INCLUDELIB wsock32.lib


; 函数声明
WinProc			PROTO  :DWORD,:DWORD,:DWORD,:DWORD
init			PROTO  :DWORD
end_proc    	PROTO  :DWORD
change_cycle  	PROTO  :DWORD
change_silence  	PROTO  :DWORD
alter_volume		PROTO  :DWORD
show_volume			PROTO  :DWORD
update_timeslider 	PROTO  :DWORD
alter_time			PROTO  :DWORD
switch_next			PROTO  :DWORD
handle_play			PROTO  :DWORD
get_songlength		PROTO  :DWORD
alter_song 			PROTO  :DWORD, :DWORD

LoadLRC				PROTO
OnPlayMusic			PROTO
OnPause				PROTO
OnPrevSong			PROTO
OnNextSong			PROTO

LoadPlayListFromTXT PROTO :DWORD                        ; 加载歌单
SavePlayListToTXT   PROTO :DWORD                        ; 保存歌单
AddSongByDialog     PROTO :DWORD                        ; 通过文件选择对话框选择文件
GetSong             PROTO :DWORD                        ; 获取某个id的歌曲
SetSong             PROTO :DWORD, :PTR BYTE, :PTR BYTE  ; 更改某个id的歌曲
DeleteSong			PROTO :DWORD

; 调试用，合并代码时不需要
ExitProcess          PROTO, dwExitCode:DWORD
printf               PROTO C :ptr sbyte, :VARARG
scanf                PROTO C :ptr sbyte, :VARARG


;歌曲结构体
Song STRUCT
    _name BYTE 300 DUP(0);歌曲名
    _path BYTE 300 DUP(0);歌曲路径
Song ends

; 资源控件常量
; id 1000 以下为控件  以上为图片
.const
	SINGLE_CYCLE EQU 0;单曲循环
	LIST_CYCLE	 EQU 1;列表循环
	RANDOM_CYCLE EQU 2;随机播放

	IDD_DIALOG			EQU 100
	IDC_SoundButton 	EQU 200
	IDC_PlayButton 		EQU 201
	IDC_RecycleButton 	EQU 202
	IDC_NextSongImage 	EQU 301
	IDC_PrevSongImage 	EQU 302
	IDC_SongImage 		EQU 303
	IDC_ImportImage 	EQU 310
	IDC_TrashImage 		EQU 311
	IDC_TimeText 		EQU 400
	IDC_VolumeText 		EQU 401
	IDC_TimeSlider 		EQU 500
	IDC_VolumeSlider 	EQU 501
	IDC_SongList 		EQU 601
	IDC_LyricBoard 		EQU 700
	IDC_Lyrics_edit 	EQU 701
	IDC_lyrics_next1 	EQU 702
	IDC_lyrics_prev1 	EQU 703
	IDC_lyrics_prev2 	EQU 704
	IDC_lyrics_next2 	EQU 705
	ICO_START 			EQU 1000
	ICO_SOUNDOPEN 		EQU 1003
	ICO_SOUNDCLOSE 		EQU 1004
	ICO_LOGO 			EQU 1005
	ICO_PLAYRECYCLE 	EQU 1008
	ICO_PLAYSINGLE 		EQU 1009
	ICO_PLAYRANDOM 		EQU 1010
	ICO_PAUSE 			EQU 1011

.data
	hInstance	dd	?
	mci_cmd BYTE ?; mci控制命令
	mciCmd BYTE 100 DUP(0)
	
	;mci命令
	cmd_setVol BYTE "setaudio PlaySong volume to %d", 0
	mciBasePlayCmd BYTE "open ", 34, "%s", 34, " alias PlaySong", 0
	mciPauseCmd BYTE "pause PlaySong", 0
	mciPlayCmd BYTE "play PlaySong", 0
	mciClose BYTE "close PlaySong", 0
	cmd_setPos BYTE "seek PlaySong to %d", 0
	cmd_getPos BYTE "status PlaySong position", 0
	cmd_pause BYTE "pause PlaySong",0
	cmd_resume BYTE "resume PlaySong",0
	cmd_getLen BYTE "status PlaySong length", 0
	cmd_close BYTE "close PlaySong",0
	
	test_song BYTE "./song/secretbase.mp3", 0
	
	; Index is the current index of the playing song.
	Index WORD 0
	
	dragging 	BYTE 0	;是否正在拖动进度条，0-否，1-是
	cycle_mode 	BYTE 1 ;循环模式，0单曲 1列表 2随机
	have_sound 	BYTE 1 ;是否有声音 1有声音 0无声音
	music_state BYTE 0 ;播放器状态  0停止  1播放  2暂停
	
	; *************************************************************************
    ; *************************************************************************
    ; *************************************************************************
    ; 郑吉源部分 START
    ; *************************************************************************
    ; *************************************************************************
    ; *************************************************************************
    ;---歌曲结构体变量---
    thisSong Song <>                         ; 当前选中的歌曲，最好通过GetSong来修改
    initSong Song <"Name:", "Path:">         ; 用来初始化歌曲
    songMenu Song 100 dup(<"Name:", "Path:">); 便于区分
    ;---歌曲结构体变量---

    ;---歌单信息,将其内容写在文件中---
    songMenuFilename BYTE "\\song.txt",0     ; 歌单保存相对路径
    songMenuFilePath BYTE 200 DUP(0)         ; 歌单保存绝对路径，在Load时赋值
    songMenuSize DWORD 0                     ; 当前歌单大小
    ;---歌单信息---
    
    ;---选择文件对话框---
    openfilename OPENFILENAME <>             ; OPENFILENAME数据结构
    szLoadTitle BYTE 'Select Music', 0       ; 选择框的标题
    szInitDir BYTE '\\', 0                   ; 默认路径
    szOpenFileNames BYTE 4000 DUP(0)         ; 选中文件Buffer，最前面是目录，多个文件以NULL分割
    szFileName BYTE 300 DUP(0)               ; 选中文件的绝对路径
    szPath BYTE 200 DUP(0)                   ; 选中文件的目录路径
    nMaxFile = SIZEOF szOpenFileNames        ; 最大可选择文件
    sep BYTE '\\', 0                         ; 分隔符
    szWarningTitle BYTE 'Warning', 0         ; 警告标题
    szWarning BYTE '请选择要删除的歌曲', 0      ; 警告提示词
                                             ; 可选择文件的类型
    szFilter  BYTE "Music(*.mp3, *.wav)", 0, "*.mp3;*.wav", 0
    ;---选择文件对话框---

    ; 调试使用
    Sfile DD 0 ; stdout(console)
    ByteSent DD 0 ; Byte Count
    formatDWORD BYTE "%d", 0Ah, 0Dh, 0
    formatWORD BYTE "%hd", 0Ah, 0Dh, 0

    str1 BYTE "写入失败！", 0
    str2 BYTE "写入成功！", 0
    ln   BYTE 0Ah, 0Dh, 0
    ; *************************************************************************
    ; *************************************************************************
    ; *************************************************************************
    ; 郑吉源部分 END
    ; *************************************************************************
    ; *************************************************************************
    ; *************************************************************************
  
	;--------当前歌曲信息--------
	total BYTE 32 dup(0)
	total_minute DWORD 0
	total_second DWORD 0

	position BYTE 32 dup(0)
	position_minute DWORD 0
	position_second DWORD 0	

	current_index DWORD 0;当前歌曲在歌单中的下标
	;--------当前歌曲信息--------
	
	;--------格式设置信息--------
	scale_second DWORD 1000		;秒转毫秒用
	scale_minute DWORD 60		;分钟转秒用	
	int_fmt BYTE '%d',0	
	time_fmt BYTE "%d:%d/%d:%d", 0	;时间显示格式
	;--------格式设置信息--------
	;歌词信息
	lyrics BYTE 20000 DUP(?)
	lrctime DWORD 200 DUP(?)
	has_lyrics BYTE 0
	strpoint BYTE ".", 0
	lrcfname BYTE 50 DUP(?)
	lrcext BYTE ".lrc", 0
	hFile DWORD ?
	lrcBuf BYTE 20000 DUP(?)
	actRd DWORD ?
	mxaddr DWORD ?
	lrcSZ DWORD ?
	emptylyric BYTE " ", 0
	nolyric BYTE "暂无歌词", 0
.code
start:

WinMain PROC
	invoke	GetModuleHandle, NULL
	mov	hInstance, eax
	invoke	InitCommonControls
	;从资源文件模板初始化
	invoke	DialogBoxParam, hInstance, IDD_DIALOG, 0, offset WinProc, 0
	invoke	ExitProcess, eax
WinMain ENDP

	
;##################################################
; 主过程函数
;##################################################
WinProc proc hWnd:DWORD, localMsg:DWORD, wParam:DWORD, lParam:DWORD
	LOCAL wc:WNDCLASSEX 
	LOCAL current_slider:DWORD	
	
	.if localMsg == WM_INITDIALOG		;窗口初始化
	    mov   wc.style, CS_HREDRAW or CS_DBLCLKS or CS_VREDRAW
    	invoke  RegisterClassEx, addr wc ;注册窗口
		invoke  init, hWnd
		invoke	LoadIcon,hInstance,ICO_LOGO
		invoke	SendMessage, hWnd, WM_SETICON, 1, eax  ;设置图标
	
	.elseif	localMsg == WM_CLOSE		;退出程序
		invoke  end_proc, hWnd
		
	.elseif localMsg == WM_COMMAND		;TODO  处理按钮动作
		mov eax, wParam
		.if ax == IDC_RecycleButton		; 点击切换播放模式按钮
			invoke change_cycle, hWnd
		.elseif ax == IDC_SoundButton	; 点击静音按钮
			invoke change_silence, hWnd
		.elseif ax == IDC_PlayButton	; 点击开始/暂停按钮
			invoke handle_play, hWnd
		.elseif ax == IDC_ImportImage	; 点击加载本地歌曲
			invoke AddSongByDialog, hWnd
		.elseif ax == IDC_TrashImage	; 点击删除歌单歌曲
			invoke DeleteSong, hWnd
		.elseif ax == IDC_NextSongImage	;点击切换下一首
			invoke OnNextSong
			invoke get_songlength, hWnd
		.elseif ax == IDC_PrevSongImage	; 点击切换上一首
			invoke OnPrevSong
			invoke get_songlength, hWnd
		.endif
		
	.elseif localMsg == WM_HSCROLL       ;TODO  处理进度条
		invoke GetDlgCtrlID,lParam
		mov current_slider,eax	;储存当前滚动控件
		mov ax,WORD PTR wParam
		.if current_slider == IDC_VolumeSlider
			.if ax == SB_THUMBTRACK		;滚动消息
				invoke alter_volume,hWnd
				invoke show_volume, hWnd
			.endif
		.elseif current_slider == IDC_TimeSlider   ;TODO 时间进度条
			.if ax == SB_THUMBTRACK		;滚动中
				mov dragging, 1
			.elseif ax == SB_ENDSCROLL	;滚动结束
				mov dragging, 0
				invoke SendDlgItemMessage, hWnd, IDC_SongList, LB_GETCURSEL, 0, 0	;获取播放列表中选中项目
				.if eax != -1
					invoke alter_time, hWnd
				.endif
			.endif
		.endif
		
	.elseif localMsg == WM_TIMER
		.if music_state == 1
			invoke update_timeslider, hWnd
			;TODO 刷新歌词，检查切换歌曲
			invoke switch_next, hWnd
		.endif
	.endif
	mov eax, 0
	ret
WinProc endp


;##################################################
; 控件初始化
;##################################################
init proc hWnd:DWORD
	;LOCAL hFile: DWORD
	;LOCAL bytes_read: DWORD
	
	; TODO  读取歌单 显示歌单
	invoke LoadPlayListFromTXT, hWnd
	
	;0.2 秒刷新一次
	invoke SetTimer, hWnd, 1, 200, NULL
	
	mov eax, ICO_START
	invoke LoadImage, hInstance, eax,IMAGE_ICON,32,32,NULL
	invoke SendDlgItemMessage,hWnd,IDC_PlayButton, BM_SETIMAGE, IMAGE_ICON, eax
	
	mov eax, ICO_PLAYRECYCLE
	invoke LoadImage, hInstance, eax,IMAGE_ICON,32,32,NULL
	invoke SendDlgItemMessage,hWnd,IDC_RecycleButton, BM_SETIMAGE, IMAGE_ICON, eax
	
	mov eax, ICO_SOUNDOPEN
	invoke LoadImage, hInstance, eax,IMAGE_ICON,32,32,NULL
	invoke SendDlgItemMessage,hWnd,IDC_SoundButton, BM_SETIMAGE, IMAGE_ICON, eax
	
	invoke SendDlgItemMessage, hWnd, IDC_VolumeSlider, TBM_SETRANGEMIN, 0, 0
	invoke SendDlgItemMessage, hWnd, IDC_VolumeSlider, TBM_SETRANGEMAX, 0, 1000
	invoke SendDlgItemMessage, hWnd, IDC_VolumeSlider, TBM_SETPOS, 1, 1000
	ret
init endp


;##################################################
; 退出程序   TODO
;##################################################
end_proc proc hWnd:DWORD
	invoke	EndDialog, hWnd, 0
	invoke  SavePlayListToTXT, hWnd		; 保存歌单
	ret
end_proc endp


;切换歌曲循环状态，（我还没有写关于更改可视化图片的操作）
change_cycle proc hWnd: DWORD
	.if cycle_mode == SINGLE_CYCLE
		mov cycle_mode, LIST_CYCLE
		mov eax, ICO_PLAYRECYCLE
	.elseif cycle_mode == LIST_CYCLE
		mov cycle_mode, RANDOM_CYCLE
		mov eax, ICO_PLAYRANDOM
	.elseif cycle_mode == RANDOM_CYCLE
		mov cycle_mode, SINGLE_CYCLE
		mov eax, ICO_PLAYSINGLE
	.endif
	
	invoke LoadImage, hInstance, eax,IMAGE_ICON,32,32,NULL
	invoke SendDlgItemMessage,hWnd,IDC_RecycleButton, BM_SETIMAGE, IMAGE_ICON, eax;修改按钮
	ret
change_cycle endp

;切换是否为静音
change_silence proc hWnd:DWORD
	.if have_sound == 1
		mov have_sound,0
		mov eax, ICO_SOUNDCLOSE
	.else 
		mov have_sound,1
		mov eax, ICO_SOUNDOPEN
	.endif
	
	invoke LoadImage, hInstance, eax,IMAGE_ICON,32,32,NULL
	invoke SendDlgItemMessage,hWnd,IDC_SoundButton, BM_SETIMAGE, IMAGE_ICON, eax;修改按钮
	invoke alter_volume, hWnd;设置音量
	Ret
change_silence endp

;改变音量
alter_volume proc hWin: DWORD
	;获得音量进度的位置
	invoke SendDlgItemMessage,hWin,IDC_VolumeSlider,TBM_GETPOS,0,0
	.if have_sound == 1
		invoke wsprintf, addr mci_cmd, addr cmd_setVol,eax
	.else
		invoke wsprintf, addr mci_cmd, addr cmd_setVol,0
	.endif
	invoke mciSendString, addr mci_cmd, NULL, 0, NULL
	Ret
alter_volume endp

;改变音量显示的数值
show_volume proc hWin: DWORD
	local temp: DWORD
	;获得音量进度的位置
	invoke SendDlgItemMessage,hWin,IDC_VolumeSlider,TBM_GETPOS,0,0
	;设置显示的音量
	mov temp, 10
	mov edx, 0
	div temp
	invoke wsprintf, addr mci_cmd, addr int_fmt, eax
	invoke SendDlgItemMessage, hWin, IDC_VolumeText, WM_SETTEXT,0,addr mci_cmd
	Ret
show_volume endp


; 根据播放进度刷新进度条和播放时间
update_timeslider proc hWnd: DWORD
	local cur_pos: DWORD
	local curlrc: DWORD
	local x: DWORD
	local mypos: DWORD
	.if music_state == 1	;播放状态
		invoke mciSendString, addr cmd_getPos, addr position, 32, NULL	;获取播放位置
		invoke StrToInt, addr position
		mov cur_pos, eax
		.if dragging == 0	;放开拖拽进度条
			invoke SendDlgItemMessage, hWnd, IDC_TimeSlider, TBM_SETPOS, 1, cur_pos
		.endif

		;刷新时间显示
		mov eax, cur_pos
		mov edx, 0
		div scale_second
		mov mypos, eax
		mov edx, 0
		div scale_minute
		mov position_minute, eax
		mov position_second, edx
		invoke wsprintf, addr mci_cmd, addr time_fmt, position_minute, position_second, total_minute, total_second
		invoke SendDlgItemMessage, hWnd, IDC_TimeText, WM_SETTEXT, 0, addr mci_cmd;修改文字 
		.if has_lyrics == 1
			mov esi, OFFSET lrctime
			mov eax, 0
			mov ebx, DWORD PTR [esi + 4]
			mov ecx, mypos
			.while ebx < ecx
				add esi, 4
				mov ebx, [esi + 4]
				inc eax
				.if eax == lrcSZ - 1
					jmp bklp
				.endif
			.endw
			bklp:
			mov curlrc, eax
			mov x, 100
			mul x
			mov esi, OFFSET lyrics
			add esi, eax
			push esi
			invoke SendDlgItemMessage, hWnd, IDC_Lyrics_edit, WM_SETTEXT, 0, esi
			pop esi
			.if curlrc > 0
				sub esi, 100
				push esi
				invoke SendDlgItemMessage, hWnd, IDC_lyrics_prev1, WM_SETTEXT, 0, esi
				pop esi
				add esi, 100
			.else
				push esi
				invoke SendDlgItemMessage, hWnd, IDC_lyrics_prev1, WM_SETTEXT, 0, ADDR emptylyric
				pop esi
			.endif
			.if curlrc > 1
				sub esi, 200
				push esi
				invoke SendDlgItemMessage, hWnd, IDC_lyrics_prev2, WM_SETTEXT, 0, esi
				pop esi
				add esi, 200
			.else
				push esi
				invoke SendDlgItemMessage, hWnd, IDC_lyrics_prev2, WM_SETTEXT, 0, ADDR emptylyric
				pop esi
			.endif
			mov eax, lrcSZ
			sub eax, curlrc
			.if eax > 1
				add esi, 100
				push esi
				invoke SendDlgItemMessage, hWnd, IDC_lyrics_next1, WM_SETTEXT, 0, esi
				pop esi
				sub esi, 100
			.else
				push esi
				invoke SendDlgItemMessage, hWnd, IDC_lyrics_next1, WM_SETTEXT, 0, ADDR emptylyric
				pop esi
			.endif
			mov eax, lrcSZ
			sub eax, curlrc
			.if eax > 2
				add esi, 100
				push esi
				invoke SendDlgItemMessage, hWnd, IDC_lyrics_next2, WM_SETTEXT, 0, esi
				pop esi
				sub esi, 100
			.else
				push esi
				invoke SendDlgItemMessage, hWnd, IDC_lyrics_next2, WM_SETTEXT, 0, ADDR emptylyric
				pop esi
			.endif
		.else
			invoke SendDlgItemMessage, hWnd, IDC_lyrics_next2, WM_SETTEXT, 0, ADDR emptylyric
			invoke SendDlgItemMessage, hWnd, IDC_lyrics_next1, WM_SETTEXT, 0, ADDR emptylyric
			invoke SendDlgItemMessage, hWnd, IDC_lyrics_prev2, WM_SETTEXT, 0, ADDR emptylyric
			invoke SendDlgItemMessage, hWnd, IDC_lyrics_prev1, WM_SETTEXT, 0, ADDR emptylyric
			invoke SendDlgItemMessage, hWnd, IDC_Lyrics_edit, WM_SETTEXT, 0, ADDR nolyric
		.endif

	.endif
	Ret
update_timeslider endp


; 处理播放按钮逻辑
handle_play proc hWnd:DWORD
	.if music_state == 0   		; 当前为停止
		invoke OnPlayMusic
		invoke get_songlength, hWnd
		mov eax, ICO_PAUSE
	.elseif music_state == 1   ; 当前为播放
		invoke OnPause
		mov eax, ICO_START
	.elseif music_state == 2   ; 当前为暂停
		invoke OnPlayMusic
		mov eax, ICO_PAUSE
	.endif
	
	invoke LoadImage, hInstance, eax,IMAGE_ICON,32,32,NULL
	invoke SendDlgItemMessage,hWnd,IDC_PlayButton, BM_SETIMAGE, IMAGE_ICON, eax
	ret
handle_play endp

;获取当前歌曲长度
get_songlength proc hWnd: DWORD
	invoke mciSendString, addr cmd_getLen, addr total, 32, NULL	;获取当前音乐长度
	invoke StrToInt, addr total
	invoke SendDlgItemMessage, hWnd, IDC_TimeSlider, TBM_SETRANGEMAX, 0, eax	;修改进度条长度
	invoke StrToInt, addr total
	mov edx, 0
	div scale_second
	
	mov edx, 0
	div scale_minute
	mov total_minute, eax
	mov total_second, edx
	ret
get_songlength endp

;修改进度条时间
alter_time proc hWnd: DWORD
	invoke SendDlgItemMessage,hWnd,IDC_TimeSlider,TBM_GETPOS,0,0	;获取当前Slider位置
	invoke wsprintf, addr mci_cmd, addr cmd_setPos, eax
	invoke mciSendString, addr mci_cmd, NULL, 0, NULL
	.if music_state == 1
		mov music_state, 0
		
		mov eax, ICO_START
		invoke LoadImage, hInstance, eax,IMAGE_ICON,32,32,NULL
		invoke SendDlgItemMessage,hWnd,IDC_PlayButton, BM_SETIMAGE, IMAGE_ICON, eax
		invoke mciSendString, addr mciBasePlayCmd, NULL, 0, NULL
	.elseif music_state == 2
		invoke mciSendString, addr mciBasePlayCmd, NULL, 0, NULL
		mov music_state, 1
		
		mov eax, ICO_START
		invoke LoadImage, hInstance, eax,IMAGE_ICON,32,32,NULL
		invoke SendDlgItemMessage,hWnd,IDC_PlayButton, BM_SETIMAGE, IMAGE_ICON, eax
	.endif
	ret
alter_time endp

; 播放结束后根据循环模式进行下一首歌的切换
switch_next proc hWin: DWORD
	local temp: DWORD
	invoke StrToInt, addr total
	mov temp, eax
	invoke StrToInt, addr position
	.if eax >= temp	;结束播放
		.if cycle_mode == SINGLE_CYCLE
			invoke OnPlayMusic
		.elseif cycle_mode == LIST_CYCLE
			invoke SendMessage, hWin, WM_COMMAND, IDC_NextSongImage, 0;
		.elseif cycle_mode == RANDOM_CYCLE
			invoke SendMessage, hWin, WM_COMMAND, IDC_PrevSongImage, 0
		.endif
	.endif
	Ret
switch_next endp

; 改变播放歌曲
alter_song proc hWin:DWORD, newSongIndex: DWORD
	.if music_state != 0
		invoke mciSendString, ADDR cmd_close, NULL, 0, NULL
	.endif

	mov eax, newSongIndex
	mov current_index, eax  ;更新当前index
	invoke OnPlayMusic
	invoke get_songlength, hWin
	Ret
alter_song endp

LoadLRC PROC
	local time: DWORD
	local x: DWORD
	invoke GetSong, current_index
	invoke lstrcpy, ADDR lrcfname, ADDR thisSong._path
	invoke StrRStrI, ADDR lrcfname, NULL, ADDR strpoint
	mov esi, eax
	; invoke lstrcpy, esi, ADDR lrcext
	mov byte ptr [esi + 1], 76
	mov byte ptr [esi + 2], 82
	mov byte ptr [esi + 3], 67
	mov byte ptr [esi + 4], 0
	; invoke MessageBox, 0, OFFSET lrcfname, 0, MB_OK
	invoke CreateFile, ADDR lrcfname, GENERIC_READ, 0, NULL, OPEN_EXISTING,	FILE_ATTRIBUTE_NORMAL, 0
	mov hFile, eax
	.if hFile == INVALID_HANDLE_VALUE
		mov has_lyrics, 0
		ret
	.endif
	mov has_lyrics, 1
	invoke ReadFile, hFile, ADDR lrcBuf, SIZEOF lrcBuf, ADDR actRd, NULL
	mov eax, OFFSET lrcBuf
	add eax, actRd
	mov mxaddr, eax
	mov esi, OFFSET lrcBuf
	; invoke MessageBox, 0, OFFSET lrcfname, 0, MB_OK
	.while byte ptr [esi] != 91
		movzx eax, byte ptr [esi]
		inc esi
	.endw
	inc esi
	movzx eax, byte ptr [esi]
	.while esi < mxaddr
		movzx eax, byte ptr [esi]
		sub eax, 48
		inc esi
		mov x, 10
		mul x
		movzx ebx, byte ptr [esi]
		sub ebx, 48
		inc esi
		add eax, ebx
		inc esi
		mov x, 60
		mul x
		mov time, eax
		movzx ebx, byte ptr [esi]
		sub ebx, 48
		inc esi
		mov eax, ebx
		mov x, 10
		mul x
		movzx ebx, byte ptr [esi]
		sub ebx, 48
		add eax, ebx
		add time, eax
		add esi, 5
		mov eax, lrcSZ
		mov x, 100
		mul x
		mov edi, OFFSET lyrics
		add edi, eax
		.while byte ptr [esi] != 91
			mov bl, byte ptr [esi]
			mov byte ptr [edi], bl
			inc edi
			inc esi
			.if esi > mxaddr
				jmp breakloop
			.endif
		.endw
		breakloop:
		mov BYTE PTR [edi], 0
		mov eax, lrcSZ
		mov x, 4
		mul x
		mov edi, OFFSET lrctime
		add edi, eax
		mov ebx, time
		mov DWORD PTR [edi], ebx
		inc lrcSZ
		inc esi
	.endw
	ret
LoadLRC ENDP

; PlaylistOffset is the address of the playlist directory array. The length of directory is 60.
OnPlayMusic PROC
	; mov al, 60
	; movzx bl, Index
	; mul bl
	; mov esi, PlaylistOffset
	; add esi, eax
	.if music_state != 2
		.if music_state == 4
			invoke mciSendString, ADDR mciClose, 0, 0, 0
		.endif
		invoke LoadLRC
		invoke GetSong, current_index
		invoke wsprintf, ADDR mciCmd, ADDR mciBasePlayCmd, ADDR thisSong._path
		; invoke MessageBox, 0, ADDR mciCmd, 0, MB_OK
		invoke mciSendString, ADDR mciCmd, 0, 0, 0
	.endif

	mov music_state, 1
	invoke mciSendString, ADDR mciPlayCmd, 0, 0, 0
	ret
OnPlayMusic endp

OnPause PROC
	;invoke MessageBox, 0, ADDR mciCmd, 0, MB_OK
	invoke mciSendString, ADDR mciPauseCmd, NULL, 0, NULL
	mov music_state, 2
	ret
OnPause endp

OnPrevSong PROC
	.if current_index != 0
		mov music_state, 4
		dec current_index
		invoke OnPlayMusic
	.endif
	ret
OnPrevSong endp

OnNextSong PROC USES eax
	mov eax, songMenuSize
	.if current_index != eax
		mov music_state, 4
		add current_index, 1
		invoke OnPlayMusic
	.endif
	ret
OnNextSong endp

SetSong PROC,
    index: DWORD,             ; 歌曲编号
    ptrSongName: PTR BYTE,    ; this.name = name;
    ptrSongPath: PTR BYTE     ; this.path = path;
; 歌曲结构体赋值
; 返回: none
;-------------------------------------------------------------------------------------------------------
    mov eax, index
    mov ebx, TYPE Song
    mul ebx
    mov edi, eax
    INVOKE lstrcpy, ADDR (Song PTR songMenu[edi])._name, ptrSongName
    INVOKE lstrcpy, ADDR (Song PTR songMenu[edi])._path, ptrSongPath
    ret
SetSong ENDP

;-------------------------------------------------------------------------------------------------------
GetSong PROC,
    index: DWORD               ; 歌曲编号
; 将某个下标的歌曲赋值给全局变量 thisSong 
; 返回: none
;-------------------------------------------------------------------------------------------------------
    mov eax, index
    mov ebx, TYPE Song
    mul ebx
    mov edi, eax
    INVOKE lstrcpy, ADDR thisSong._name, ADDR (Song PTR songMenu[edi])._name
    INVOKE lstrcpy, ADDR thisSong._path, ADDR (Song PTR songMenu[edi])._path
    ret
GetSong ENDP

;-------------------------------------------------------------------------------------------------------
LoadPlayListFromTXT PROC,
    hWin: DWORD                 ; 窗口句柄
; 从歌单文件读取歌曲
; 返回: none
;-------------------------------------------------------------------------------------------------------

    ; 局部变量
    LOCAL hiFile: DWORD
    LOCAL bytesRead: DWORD
    
    ; 初始化歌单文件绝对路径，否则Save的时候路径会错
    INVOKE GetCurrentDirectory, SIZEOF songMenuFilePath - 20, ADDR songMenuFilePath
    invoke lstrcat, ADDR songMenuFilePath, ADDR songMenuFilename

    ; 打开文件，READ，参数都默认
    INVOKE CreateFile, ADDR songMenuFilePath, GENERIC_READ, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
    mov hiFile, eax

    .IF hiFile == INVALID_HANDLE_VALUE ; 打开文件失败，歌单大小归0
        mov songMenuSize, 0
        JMP RETURN
    .ELSE
        ; 读取头四个字节，读到歌单的大小，如果读取有问题，歌单清零
        INVOKE ReadFile, hiFile, ADDR songMenuSize, SIZEOF songMenuSize, ADDR bytesRead, NULL
        .IF bytesRead != SIZEOF songMenuSize
            mov songMenuSize, 0
        .ELSE
            ; 读取剩余部分
            INVOKE ReadFile, hiFile, ADDR songMenu, SIZEOF songMenu, ADDR bytesRead, NULL
            .IF bytesRead != SIZEOF songMenu
                mov songMenuSize, 0
            .ENDIF
        .ENDIF
    .ENDIF

    ; 将歌单在界面中显示
    mov ecx, 0
    .WHILE ecx < songMenuSize
        push ecx

        INVOKE GetSong, ecx
        INVOKE SendDlgItemMessage, hWin, IDC_SongList, LB_ADDSTRING, 0, ADDR thisSong._name

        pop ecx
        inc ecx
    .ENDW

RETURN:
    ; 关闭文件
    INVOKE CloseHandle, hiFile
    ret
LoadPlayListFromTXT ENDP


;-------------------------------------------------------------------------------------------------------
SavePlayListToTXT PROC,
    hWin: DWORD                 ; 窗口句柄                
; 保存歌曲列表到文件
; 返回: none
;-------------------------------------------------------------------------------------------------------
    ; 局部变量
    LOCAL hiFile: HANDLE
    LOCAL bytesWritten: DWORD

    ; 以写模式打开文件
    INVOKE CreateFile, ADDR songMenuFilePath, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
    mov hiFile, eax
    ; 如果打开失败直接返回
    .IF hiFile == INVALID_HANDLE_VALUE
        ; INVOKE printf, ADDR str1
        ; INVOKE printf, ADDR ln
        JMP RETURN
    .ENDIF
    
    ; 前4个字节写入歌单长度
    INVOKE WriteFile, hiFile, ADDR songMenuSize, SIZEOF songMenuSize, ADDR bytesWritten, NULL
    ; 写入全部歌曲（歌名，路径）
    INVOKE WriteFile, hiFile, ADDR songMenu, SIZEOF songMenu, ADDR bytesWritten, NULL

    ; INVOKE printf, ADDR str2
    ; INVOKE printf, ADDR ln
RETURN:
    INVOKE CloseHandle, hiFile
    ret
SavePlayListToTXT ENDP

;-------------------------------------------------------------------------------------------------------
AddSongByDialog PROC USES eax ebx esi edi,
    hWin: DWORD
; 通过GetOpenFileName打开选择文件对话框，openfilename结构体既包含参数也包含结果
; 返回: none
;-------------------------------------------------------------------------------------------------------
    ; 局部变量
    LOCAL newSongCount: DWORD
	LOCAL index: DWORD
	mov newSongCount, 0

    ; 将openfilename初始化，结构体清零
    mov al, 0
    mov edi, OFFSET openfilename
    mov ecx, SIZEOF openfilename
    cld
    rep stosb

    ; 配置openfilename参数
    ; 参考：http://winapi.freetechsecrets.com/win32/WIN32OPENFILENAME.htm
    mov openfilename.lStructSize, SIZEOF openfilename
    mov eax, hWin
    mov openfilename.hwndOwner, eax
    mov eax, OFN_ALLOWMULTISELECT
    or eax, OFN_EXPLORER
    mov openfilename.Flags, eax
    mov openfilename.lpstrFilter, OFFSET szFilter
    mov openfilename.nMaxFile, nMaxFile
    mov openfilename.lpstrTitle, OFFSET szLoadTitle
    mov openfilename.lpstrInitialDir, OFFSET szInitDir
    mov openfilename.lpstrFile, OFFSET szOpenFileNames

    ; 打开选择文件框
    INVOKE GetOpenFileName, ADDR openfilename

    .IF eax == 1
        ; szPath = 所选文件夹路径
        INVOKE lstrcpyn, ADDR szPath, ADDR szOpenFileNames, openfilename.nFileOffset
        ; 添加分割符
        INVOKE lstrcat, ADDR szPath, ADDR sep

        ; 过掉文件夹名称，esi位于文件名开始处
        mov esi, OFFSET szOpenFileNames
        add si, openfilename.nFileOffset
        mov al, [esi]

        ; 遍历所有多选文件，如果下一个字符是NULL则停止
        .WHILE al != 0                                 ; TODO 文件后缀名未去除
            ; esi为文件名，szFileName为绝对路径

            ; szFileName = szPath + esi
            mov szFileName, 0
            invoke lstrcat, ADDR szFileName, ADDR szPath
            invoke lstrcat, ADDR szFileName, esi

            INVOKE SetSong, songMenuSize, esi, ADDR szFileName
            ; 歌单长度+1, 新歌曲+1
            add songMenuSize, 1                  ; TODO 超过size限制
            add newSongCount, 1

            ; 过掉当前文件，注意长度需要+1因为NULL也占长度
            invoke lstrlen, esi
            inc eax
            add esi, eax
  
            mov al, [esi]       ; al = 下一个字符
        .ENDW

		mov ecx, newSongCount
		L1:
			mov eax, songMenuSize
			sub eax, ecx
			mov index, eax

			; ecx 有毒
			push ecx

			INVOKE GetSong, index
            INVOKE SendDlgItemMessage, hWin, IDC_SongList, LB_ADDSTRING, 0, ADDR thisSong._name

			pop ecx
			LOOP L1

    .ENDIF

    INVOKE SavePlayListToTXT, hWin

    ret
AddSongByDialog ENDP


;-------------------------------------------------------------------------------------------------------
DeleteSong PROC,
    hWin: DWORD,
; 删除歌曲列表中选中的曲子，将后面的歌曲向前移动，歌单长度减1
; 返回（eax）: 成功-1，失败0
;-------------------------------------------------------------------------------------------------------
    LOCAL index: DWORD
    
    INVOKE SendDlgItemMessage, hWin, IDC_SongList, LB_GETCURSEL, 0, 0	;通过songlist获取下标更合适？
    mov index, eax

    ; 从界面中移除
    INVOKE SendDlgItemMessage, hWin, IDC_SongList, LB_DELETESTRING, eax, 0

	; 输出要删除的曲目
	INVOKE GetSong, index

    ; INVOKE printf, ADDR thisSong._name
    ; INVOKE printf, ADDR ln
    ; INVOKE printf, ADDR thisSong._path
    ; INVOKE printf, ADDR ln

    mov ecx, index
    inc ecx
    .while ecx < songMenuSize
		push ecx

		mov eax, index
		inc eax

        INVOKE GetSong, eax
        INVOKE SetSong, index, ADDR thisSong._name, ADDR thisSong._path

		pop ecx
        inc ecx
        inc index
    .endw

    ; 歌单长度减1              TODO 负值判断
    sub songMenuSize, 1

    ; 最后一首歌曲清空
    INVOKE SetSong, songMenuSize, ADDR initSong._name, ADDR initSong._path

    INVOKE SavePlayListToTXT, hWin

    ret
DeleteSong ENDP

end start
