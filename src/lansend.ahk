/*! 
(C) mohdumar, 2016
v1
file send structure:
< 8 bytes file size >< 255 bytes file name  and subdir relative path>< 8 bytes file modification time >< 8 bytes creation time ><8bytes crc32> < file content >

uses:
    AHKsock - A simple AHK implementation of Winsock.
     by TheGood
    http://www.autohotkey.com/forum/viewtopic.php?p=355775
    Last updated: August 24th, 2010 
    
*/ 
    #SingleInstance Force
    
    ;Needed if AHKsock isn't in one of your lib folders
    ;#Include %A_ScriptDir%\AHKsock.ahk
	
	FileInstall, about.jpg, %A_Temp%\about.jpg, 1
	
	SettingsFile=lansend.ini
	if !FileExist("lansend.ini")  ;default
	{
	IniWrite, %A_WorkingDir%\ReceivedFiles, %SettingsFile%, Settings, Download_Location 
	FileCreateDir ReceivedFiles
	IniWrite, 0.0.0.0, %SettingsFile%, Settings, Last_IP 
	}
	
	;MsgBox,64, LANSend, Please select a download folder for received files. `nThe default location is the "ReceivedFiles" folder in the application directory.
	
    IniRead, Download_Location, %SettingsFile%, Settings, Download_Location
	if !FileExist(Download_Location)  ;default
	{
		MsgBox,48, LANSend, The path "%Download_Location%" does not exist.`nThe folder will be created when you press OK.
		FileCreateDir % Download_Location
	}
	IniRead, Last_IP, %SettingsFile%, Settings, Last_IP 
	
	
    ;Set up an error handler (this is optional)
    AHKsock_ErrorHandler("AHKsockErrors")
	
			
	bufsize:=1048575
	
	sFile=%Download_Location%\FileTemp.dat
	    
    ;This is only used in order to OutputDebug the average speed of the file transfer at the end
    DllCall("QueryPerformanceFrequency", "int64*", qpFreq)
	;#singleinstance Force
    
    ;Set up an OnExit routine
    OnExit, ParentGuiClose
    
    ;Set default value to invalid handle
    iPeerSocket := -1
	
	listening:=0
	connected:=0  ;initially not conected
	SendingFile = 0
	ReceivingFile=0
	LastFileVerified:=0
	
	TotalSent:=0
	TotalReceived:=0
	SetTimer, StatsUpdate, 50,1000
	    
	Gui, Parent:New, +HwndParentHwnd
    ;Set up the GUI
    Gui, font, bold s9, Consolas
    Gui, +OwnDialogs
    Gui, Add, Edit, r20 w640 vtxtDialog ReadOnly hwndhtxtDialog
	 
	Gui, Font
	Gui, Add, Button, xm gConnectBtn vConnectBtn hwndhbtnConnectBtn Default w120, &Connect to Address
	Gui, Add, Button, x+5 gWaitListen vWaitListen w125 hwndhbtnWaitListen, &Wait for Peer
    Gui, Add, Button, x+5 vbtnSend hwndhbtnSend gbtnSend Disabled w125, &Send File(s)
    Gui, Add, Button, x+5 vbtnSendFolder hwndhbtnSendFolder gbtnSendFolder  Disabled w80, Send &Folder
    Gui, Add, Button, x+5 vEndTransferBtn gEndTransferBtn hwndhEndTransferBtn  Disabled  w80, &End Transfer
	Gui, Add, Button, x+5 gDisconnectBtn vDisconnectBtn hwndhbtnDisconnect Disabled  w80, &Disconnect 
	Gui, Add, Button, xm  gClearBtn vClearbtn hwndhClearBtn w120, Clea&r Log
	Gui, Add, Button, x+5 gDLocationBtn vDLocationBtn hwndhDLocationBtn  w125, Set Download F&older
	Gui, Add, Button, x+5 gOpenDLocationBtn vOpenDLocationBtn hwndhOpenDLocationBtn  w125, Open Dow&nload Folder
	Gui, Add, Button, x+5 gAbout vAboutbtn hwndhbtnAbout w80, A&bout
	Gui, Add, Button, x+5 gParentGuiClose vExitbtn hwndhbtnExit w80, E&xit 
	Gui, Add, StatusBar
	;Gui, Add, Progress, xm w550 hwndhProgBar vProgBar, 0
    Gui, +MinSize
    Gui, Show,, LANSend
	
	SB_SetParts(20,250,200,200) ; Make 3 different parts
	hwndStatusProg := SB_SetProgress(0,3)
	SB_SetText("Idle",2) ; Set a text segment 2
	SB_SetIcon("urlmon.dll", 2)
	
	 
hSysMenu:=DllCall("GetSystemMenu","Int",ParentHwnd,"Int",FALSE) 
nCnt:=DllCall("GetMenuItemCount","Int",hSysMenu) 
DllCall("RemoveMenu","Int",hSysMenu,"UInt",nCnt-6,"Uint","0x400") 
DllCall("DrawMenuBar","Int",ParentHwnd) 

	sName=localhost 
	
	Gosub ClearBtn
	
Gui, Child:New 
Gui, Child:+OwnerParent -MinSize -MaxSize +ToolWindow -SysMenu
Gui, Child:Add, Text,, Enter Remote IP: 
Gui, Child:Add, Custom, ClassSysIPAddress32 r1 w140 hwndhIPControl
Global sIPList
	Loop, parse, sIPList, `n
	{ 
	StringSplit, iparr, A_LoopField,.
	ipmask=%iparr1%.%iparr2%.0.0
	Gui, Child:Add, Button,w140 gSetMask, Set Mask to %ipmask%
	}
Gui, Child:Add,Button,xm y+30 gConnectBtnPress w140 Default hwndhConnectIP, &Connect
Gui, Child:Add,Button, gCancelBtnPress w140, &Wait for Peers... 
IPCtrlSetAddress(hIPControl,Last_IP)

;about
Gui, About:New
Gui, About:Margin, 0, 0
Gui, About:+OwnerParent -MinSize -MaxSize -SysMenu
Gui, About:Add, Picture, x0 y0 w270 h-1, %A_Temp%\about.jpg
;Gui, About:Margin, 10, 10
Gui, About:Add, Text,x10 y+10, LANSend 1.0`nA simple LAN file sharing utility`n`nCopyright (C) 2016 mohdumar`nUses AHKsock by TheGood @ ahkforum, (C) 2011
Gui, About:Margin, 0,10
Gui, About:Add,Button,x10 y+30 gHideAbout w100 Default, &OK
	
	Gosub ConnectBtn
	return

	About:
	Gui, Parent:+Disabled
	Gui, About:Show,, About
	return
	
	HideAbout:	
Gui, Parent:-Disabled
Gui, Parent:Show
Gui, About:Hide 
	return
	
DLocationBtn:	
newloc:=SelectFolderEx(Download_Location, "Select Location for Received Files", OwnerHwnd := ParentHwnd, "Select Folder")
if !newloc 
	return
Download_Location:=newloc
IniWrite, %Download_Location%, %SettingsFile%, Settings, Download_Location 
AddLine("Received Files will be saved in " Download_Location)
return
	 
OpenDLocationBtn:
If FileExist(Download_Location) ;Make sure it exists
                Run % "explorer.exe /root," Download_Location
Return

XPaxrentGuiSize:
    Anchor(htxtDialog, "wh") 
    Anchor(hbtnSend, "y") 
    Anchor(hbtnConnectBtn, "y") 
    Anchor(hbtnWaitListen, "y") 
    Anchor(hbtnDisconnect, "y") 
    Anchor(hEndTransferBtn, "y") 
    Anchor(hClearBtn, "y") 
    Anchor(hbtnSendFolder, "y") 
    Anchor(hbtnExit, "y") 
    Anchor(hwndStatusProg, "wy","r")
Return

ConnectBtn:    
Gui, Parent:+Disabled
Gui, Child:Show,, Connect to IP
return

SetMask: 
ipmask := RegExReplace(A_GuiControl, "Set Mask to ") 
IPCtrlSetAddress(hIPControl,ipmask)
return

IPCtrlSetAddress(hControl, ipaddress)
{
    static WM_USER := 0x400
    static IPM_SETADDRESS := WM_USER + 101

    ; Pack the IP address into a 32-bit word for use with SendMessage.
    ipaddrword := 0
    Loop, Parse, ipaddress, .
        ipaddrword := (ipaddrword * 256) + A_LoopField
    SendMessage IPM_SETADDRESS, 0, ipaddrword,, ahk_id %hControl%
}

IPCtrlGetAddress(hControl)
{
    static WM_USER := 0x400
    static IPM_GETADDRESS := WM_USER + 102

    VarSetCapacity(addrword, 4)
    SendMessage IPM_GETADDRESS, 0, &addrword,, ahk_id %hControl%
    return NumGet(addrword, 3, "UChar") "." NumGet(addrword, 2, "UChar") "." NumGet(addrword, 1, "UChar") "." NumGet(addrword, 0, "UChar")
}

ConnectBtnPress:
Gosub ChildGuiClose ;disable and stop waiting
WaitListen(0)
Global sName=IPCtrlGetAddress(hIPControl)
GuiControl,Parent:Disable,ConnectBtn
	AddLine("Trying to connect to " sName)
	GuiControl,Parent:Disable,WaitListen
    If (i := AHKsock_Connect(sName, 27015, "Peer"))
        AddLine("AHKsock_Connect() failed with return value = " i " and ErrorLevel = " ErrorLevel)
return

ClearBtn:
GuiControl,Parent:, txtDialog
	AddLine("Welcome to LANSend")
	AddLine("Local Computer Name: " A_ComputerName) 
	;Get the IPs
	Global sIPList
    If (i := AHKsock_GetAddrInfo(A_ComputerName, sIPList)) {
        MsgBox 0x10, Error, % "AHKsock_GetAddrInfo failed.`nReturn value = " i ".`nErrorLevel = " ErrorLevel
        Return
    } 
	Loop, parse, sIPList, `n
	{
	AddLine("Local IP Address: " A_LoopField)
	}
	AddLine("Received Files will be saved in " Download_Location)
	AddLine("===============================")
return

CancelBtnPress:
Gosub ChildGuiClose
WaitListen()
return

ChildGuiClose:
Gui, Parent:-Disabled
Gui, Parent:Show
Gui, Child:Hide 
return

ParentGuiEscape:
ParentGuiClose:  
    ;So that we don't go back to listening on disconnect
	if (!bExiting)	
    AddLine("Exiting...")
	
    bExiting := True
    /*! If the GUI is closed, this function will be called twice:
        - Once non-critically when the GUI event fires (GuiEscape or GuiClose) (graceful shutdown will occur), and
        - Once more critically during the OnExit sub (after the previous GUI event calls ExitApp)
        
        But if the application is exited using the Exit item in the tray's menu, graceful shutdown will be impossible
        because AHKsock_Close() will only be called once critically during the OnExit sub.
    */
    AHKsock_Close()
ExitApp

WaitListen(EnableListen=1,StopMessage=0)
{
Global listening
if (EnableListen) 
{
If (!listening)  ;if already enabled dont do anything
{
	if (!connected)
	{
		If (i := AHKsock_Listen(27015, "Peer")) {
			AddLine("AHKsock_Listen() failed with return value = " i " and ErrorLevel = " ErrorLevel)
			bCantListen := True ;So that if the connect() attempt fails, we exit.
			return
		}
	}
}
   ;already listening so
		AddLine("Waiting for peer to connect...")			
		Gui Parent:Default		
		SB_SetText("Waiting for peer...",2)
		listening:=1
		GuiControl,Parent:,WaitListen,S&top Waiting
}
else   ;disable listening
{
If (listening)
{
AHKsock_Listen(27015)  ;stop listening
	GuiControl,Parent:,WaitListen,&Wait for Peer
	if StopMessage
	AddLine("Stopped listening for peers.")			
	Gui Parent:Default		
	SB_SetText("Idle",2)
	listening:=0
}
}
}

WaitListen: ;btn wait/stop
Global listening
If (listening)
WaitListen(0,1)
else
WaitListen()
return

ToggleConnectBtn:
global connected,receivingfile,sendingfile
;AddLine("DEBUG: connected" connected "  send" sendingfile "  listening" listening " recv"receivingfile)
if connected=1
{ 
Gui, Parent:Default
SB_SetIcon("urlmon.dll", 1)
GuiControl,Parent:Disable,ConnectBtn
GuiControl,Parent:Disable,WaitListen
GuiControl,Parent:Enable,DisconnectBtn
GuiControl, Parent:Enable, btnSend 
GuiControl, Parent:Enable, btnSendFolder 
GuiControl, Parent:Disable, EndTransferBtn
if !multifiles
SB_SetProgress(0,3)
if (sendingfile OR receivingfile)
{
	GuiControl, Parent:Disable, btnSend 
	GuiControl, Parent:Disable, btnSendFolder
	GuiControl, Parent:Enable, EndTransferBtn
}
}
else  ;not connected
{
Gui, Parent:Default
SB_SetIcon("urlmon.dll", 2)
GuiControl,Parent:Enable,ConnectBtn
GuiControl,Parent:Enable,WaitListen
GuiControl,Parent:Disable,DisconnectBtn
GuiControl, Parent:Disable, btnSend 
GuiControl, Parent:Disable, btnSendFolder
GuiControl, Parent:Disable, EndTransferBtn 
if !multifiles
SB_SetProgress(0,3)
}
return

EndTransferBtn: 
GuiControl, Parent:Disable, EndTransferBtn
global sendingfile:=0
;global receivingfile:=0 
Global WillReconnect:=1
;Global JustEndedRecv:=1
Gosub DisconnectBtn
return
 

StatsUpdate:
Gui, Parent:Default
SB_SetText("Sent: " Round(TotalSent/1048576,1) "MB, Recv: "Round(TotalReceived/1048576,1)"MB",4)
return


DisconnectBtn:
if (WillReconnect){
	AddLine("===================")
	AddLine("END TRANSFER WILL RESET CONNECTION")
	}
else
AddLine("Attempting to Disconnect")
If (i := AHKsock_Close(iPeerSocket)) {
        AddLine("AHKsock_Close() failed with return value = " i " and ErrorLevel = " ErrorLevel)
		return
}
connected:=0
return

btnSend:
FileSend(0)
return

btnSendFolder:
FileSend(1)
return
	
AddLine(Byref tempstr)
{ 
	AddDialog(&tempstr)
	OutputDebug, % tempstr
} 

ReplaceLine(Byref tempstr)
{
tempstr:="> " tempstr "`r`n" 
ptrText:=&tempstr
global htxtDialog 
GuiControlGet, txtDialogtxt ,Parent:,txtDialog

 SendMessage, 0x000E, 0, 0,, ahk_id %htxtDialog% ;WM_GETTEXTLENGTH
        iPos := ErrorLevel
StringGetPos, isign, txtDialogtxt, >,R
len:= strlen(txtDialogtxt)
diff:=ipos-len
;msgbox iPos:%ipos%   `n Position of >: %isign%`n Strlen: %len%`n 
    SendMessage, 0x00B1, isign+diff-1, ipos,, ahk_id %htxtDialog% ;EM_SETSEL
    SendMessage, 0x00C2, False, ptrText,, ahk_id %htxtDialog% ;EM_REPLACESEL
	
    SendMessage, 0x0115, 7, 0,, ahk_id %htxtDialog% ;WM_VSCROLL
}

AddDialog(ptrText, bYou = True) {
    Global htxtDialog
    
    ;Append the interlocutor
    sAppend := bYou ? "> " : "> "
    InsertText(htxtDialog, &sAppend)
    
    ;Append the new text
    InsertText(htxtDialog, ptrText)
    
    ;Append a new line
    sAppend := "`r`n"
    InsertText(htxtDialog, &sAppend)
    
    ;Scroll to bottom
    SendMessage, 0x0115, 7, 0,, ahk_id %htxtDialog% ;WM_VSCROLL
}

Peer(sEvent, iSocket = 0, sName = 0, sAddr = 0, sPort = 0, ByRef bData = 0, bDataLength = 0) {
    Global iPeerSocket, bExiting, bSameMachine, bCantListen, WillReconnect
    Static iIgnoreDisconnect
    
    If (sEvent = "ACCEPTED") {	
	
		global sendingfile:=0
		global receivingfile:=0
        
		;AddLine("ACCEPTED: connected" connected "  send" sendingfile "  listening" listening " recv"receivingfile)
        global connected:=1
		gosub ToggleConnectBtn
		
        ;Stop listening (see comment block in CONNECTED event)
        ;AHKsock_Listen(27015)
		WaitListen(0)
		
        AddLine("Peer with IP " sAddr " connected!")	
		
    If (i := AHKsock_GetNameInfo(sAddr,hostname)) {
        MsgBox 0x10, Error, % "AHKsock_GetNameInfo failed.`nReturn value = " i ".`nErrorLevel = " ErrorLevel
        Return
    } 
        AddLine("Peer Hostname is " hostname)		
		
		Gui Parent:Default		
		SB_SetText("Connected to " sAddr " (" hostname ")",2)
		Global hIPControl
		IPCtrlSetAddress(hIPControl,sAddr)
		Global SettingsFile
		IniWrite, %sAddr%, %SettingsFile%, Settings, Last_IP  
		 
        If (iPeerSocket <> -1) {
            AddLine("We already have a peer! Disconnecting...")
            AHKsock_Close(iSocket) ;Close the socket
            iIgnoreDisconnect += 1 ;So that we don't react when this peer disconnects
            Return
        }
        
        ;Remember the socket
        iPeerSocket := iSocket
		AHKsock_SockOpt(iSocket, "SO_SNDBUF",bufsize+1)
		AHKsock_SockOpt(iSocket, "SO_RCVBUF",bufsize+1)
		
        ;Allow input and set focus
                
		
    } If (sEvent = "CONNECTED") {
		
		global sendingfile:=0
		global receivingfile:=0
        
		;AddLine("CONNECTED: connected" connected "  send" sendingfile "  listening" listening " recv"receivingfile)
        ;Check if the connection attempt was successful
        If (iSocket = -1) {
            AddLine("AHKsock_Connect() failed.")
            
            ;Check if we are not currently listening, and if we already tried to listen and failed.
            If bCantListen
                ExitApp 
            
            ;If the connection attempt was on this computer, we can start listening now since the connect attempt is
            ;over and we thus run no risk of ending up connected to ourselves. 
            If 1 { ;bSameMachine {
                WaitListen()
            }
             gosub ToggleConnectBtn
            ;The connect attempt failed, but we are now listening for clients. We can leave now.
            Return
            
        } Else OutputDebug, % "AHKsock_Connect() successfully connected on IP " sAddr "."
        
        ;We now have an established connection with a peer
        
        ;This is the same fail-safe as in the ACCEPTED event (see comment block there)
        If (iPeerSocket <> -1) {
            AddLine("We already have a peer! Disconnecting...")
            AHKsock_Close(iSocket) ;Close the socket
            iIgnoreDisconnect += 1 ;So that we don't react when this peer disconnects
            Return
        }
        
        ;Remember the socket
        iPeerSocket := iSocket        
		AHKsock_SockOpt(iSocket, "SO_SNDBUF",bufsize+1)
		AHKsock_SockOpt(iSocket, "SO_RCVBUF",bufsize+1)
		 
		
        global connected:=1
		gosub ToggleConnectBtn
		
		WaitListen(0)
        
		global WillReconnect:=0
        ;Update status
		AddLine("Connected to " sName)  
		
				
		
		If (i := AHKsock_GetNameInfo(sName,hostname)) {
        MsgBox 0x10, Error, % "AHKsock_GetNameInfo failed.`nReturn value = " i ".`nErrorLevel = " ErrorLevel
        Return
		}
		
		AddLine("Peer Hostname is " hostname)   
		Gui Parent:Default		
		SB_SetText("Connected to " sName " (" hostname ")",2)  
		Global hIPControl
		IPCtrlSetAddress(hIPControl,sName)		
		Global SettingsFile
		IniWrite, %sName%, %SettingsFile%, Settings, Last_IP 
		
        ;Allow input and set focus
        gosub ToggleConnectBtn
    } Else If (sEvent = "DISCONNECTED") {
        
        ;Check if we're supposed to ignore this event
        If iIgnoreDisconnect {
            iIgnoreDisconnect -= 1
            Return
        }
       global connected:=0
        ;Reset variable
        iPeerSocket := -1
        
        ;Delete any past data the stream processor had stored 
		Streamer(0,0,1,SendingFile)
        ;We should go back to listening (unless we're in the process of leaving)
        If Not bExiting {		
			if (WillReconnect)
			{ 	 			
			AddLine("The peer was disconnected!")	
			Gosub ConnectBtnPress  ;connect again
			}
			else
			{
			AddLine("The peer disconnected!")	
            WaitListen()           
			Gosub ToggleConnectBtn
            ;Disable input and clear textbox
            GuiControl, Parent:Focus, Connectbtn 
			}           
        }
        
    } Else If (sEvent = "RECEIVED") {
         
		
        ;Send to the stream processor
		if !sendingfile  ;process the received data,      
		{
		Streamer(bData, bDataLength)
		}
		else
		{ 
		}
    }
}


Streamer(ByRef bNewData=0,bNewDataLength=0,Interrupted=0,Sender=0)
{	 
critical
	Gui, Parent:Default
	Static bPastData, bPastDataLength
    Static hFile := -1, iFileSize, qpTstart, iModTime, iCrTime
    Global qpFreq, bSilent, sFile
    Static prevTime:=0, prevSize:=0
	Static fileNameRec=, crc32server=
	Global ReceivingFile
	Static FirstReceive:=1
	Global WillReconnect
	Global iPeerSocket
	static firstRateOutput:=1
	
if (Interrupted)
{
	if (ReceivingFile)
		{
		;We can close the file handle and reset the value
            File_Close(hFile)
            hFile := -1 ;Reset value to indicate that we closed the file
			iFileSize:=0
			bPastData=
			bPastDataLength=
			firstRateOutput:=1
			ReceivingFile=0
			FirstReceive:=1
			prevTime:=0, prevSize:=0
			SB_SetProgress(0,3)
	GuiControl, Parent:Enable, btnSend
	GuiControl, Parent:Enable, btnSendFolder
		    FileDelete, %sFile%  
			AddLine("File Receiving Interrupted!") 		
		}
		if (Sender)
		{		 		
				SB_SetProgress(0,3)
				AddLine("File Sending Interrupted!")
		}
		return
}

if (WillReconnect)
	{ 
		return
	}

ReceivingFile:=1
		
	if (FirstReceive && !Sender)
	{
	AddLine("===================")
	AddLine("Receiving file...")
	gosub ToggleConnectBtn
	FirstReceive:=0	
	GuiControl, Parent:Disable, btnSend
	GuiControl, Parent:Disable, btnSendFolder 
	}
		

 ;Check if the target file is ready for writing
        If (hFile = -1) {
            
            ;We need to get the file ready for writing 
            ;Delete the target file if it exists
            FileDelete, %sFile%
            
            ;Open the file for writing
            hFile := File_Open("Write", sFile)
            If (hFile = -1) { ;Check for error
                AddLine("Client - Could not open the file in RECV! ErrorLevel = " ErrorLevel)
                return
            } 
        }
		If bPastDataLength {
            addline("processing pastdata ------------- iPoin"iPointer " bPstLen"bPastDataLength)
            bDataLength := bNewDataLength + bPastDataLength
            
            ;Prep the variable which will hold past and new data
            VarSetCapacity(bData, bDataLength, 0)
            
            ;Copy old data and then new data
            CopyBinData(&bPastData, &bData, bPastDataLength)
            CopyBinData(&bNewData, &bData + bPastDataLength, bNewDataLength)
            
            ;We can now delete the old data
            VarSetCapacity(bPastData, 0) ;Clear the variable to free some memory since it won't be used
            bPastDataLength := 0 ;Reset the value
            
            ;Set the data pointer to the new data we just created
            bDataPointer := &bData
            
            /*! The advantage of using a data pointer is so that the code that follows after can work regardless of whether
            the data to process is in bNewData (if we had nothing to prepend), or in bData (if we had to create it to
            prepend some past data). The variable bDataLength holds the length of the data to which bDataPointer points.
            */
            
        ;Set the data pointer to the newly arrived data
        } Else bDataPointer := &bNewData, bDataLength := bNewDataLength
        
        ;Check if we fully received the 8-byte file size integer yet.
        If Not iFileSize {
            
			Static HeaderLength:=8 + 255 + 8 + 8 + 8
            ;Check if only part of the 8 bytes + xxxx are here
            If (bDataLength < HeaderLength) {
                
                ;Save what we have and leave
                VarSetCapacity(bPastData, HeaderLength, 0)
                CopyBinData(bDataPointer, &bPastData, bDataLength)
				bPastDataLength:=bDataLength
                Return
            }
             
            ;Extract the 8 bytes
            iFileSize := NumGet(bDataPointer + 0, 0, "int64")
			fileNameRec:= StrGet(bDataPointer + 8, 255, "")
			iModTime := NumGet(bDataPointer + 8 + 255, 0, "int64")
			iCrTime := NumGet(bDataPointer + 8 + 255 + 8, 0, "int64")
			crc32server :=  StrGet(bDataPointer + 8 + 255 + 8 + 8, 8, "")
            
			iFileMB:=Round(iFileSize/1048576,3) 			
			AddLine("File path/name: " fileNameRec)	
			AddLine("File size: " iFileMB " MB")		
            
            ;Check if there is data after the 64-bit integer that we have to write to the file
            If (bDataLength = HeaderLength) {
                
                ;Reset the performance counter value so that it will be
                ;queried just before writing the first bytes to the file
                qpTstart := -1
                
                Return ;Nothing to write
            }
            
            ;We're about to write the first bytes. Query the performance counter before!
            DllCall("QueryPerformanceCounter", "int64*", qpTstart)
            
            ;Write the data after the header to the file (that's why we do + )
            ;iWritten := File_Write(hFile, bDataPointer + HeaderLength, bDataLength - HeaderLength)
			;increment pointer
			bDataPointer:=bDataPointer + HeaderLength
			bDataLength:=bDataLength - HeaderLength
            
        } ;Else {
            
            If (qpTstart = -1) ;Check if it hasn't already been queried
                DllCall("QueryPerformanceCounter", "int64*", qpTstart)
            
            ;Append the data we received to the file
			iPointer := File_Pointer(hFile)
			remainingbytes:=iFileSize-iPointer
			;Addline("iFileSz"iFileSize " iPointer"iPointer " bDataLength" bDataLength " remaining"remainingbytes " bpastdatalength"bPastDataLength)
			if(bDataLength<=remainingbytes)			
				iWritten := File_Write(hFile, bDataPointer, bDataLength)
			else
			{			 
				iWritten := File_Write(hFile, bDataPointer, remainingbytes)
				VarSetCapacity(bPastData, bDataLength-remainingbytes, 0)
                CopyBinData(bDataPointer+remainingbytes, &bPastData, bDataLength-remainingbytes)
				bPastDataLength:=bDataLength-remainingbytes
				iPointer := File_Pointer(hFile)
			;Addline("extra data ---iFileSz"iFileSize " iPointer"iPointer " bDataLength" bDataLength " remaining"remainingbytes " bpastdatalength"bPastDataLength)
			}
        ;}
        
        ;Don't uncomment this line if receiving large files, or otherwise the log will quickly fill up.
        ;OutputDebug, % "Client - Data written to file: " iWritten ;FOR DEBUGGING PURPOSES ONLY
        
        ;Get the current file pointer (i.e. the number of bytes written to file so far)
        iPointer := File_Pointer(hFile)
        
		Global TotalReceived += bDataLength
        Gosub StatsUpdate
		 
		;rate			
			CurrentSeconds:=UnixEpoch()
			if (CurrentSeconds>prevTime)
			{
				rate:=Round((iPointer - prevSize)/1048576,2)
				;OutputDebug, % "======= calculated rate: " rate
				;OutputDebug, % "======= calculated pointer: " iPointer
				;GuiControl,Text,RateText, Rate: %rate% 
				if prevTime ;we dont want zero
				{
				if firstRateOutput
				{
					AddLine("Transfer Rate: " rate " MB/s")	 
					firstRateOutput:=0
					}
				else
					replaceLine("Transfer Rate: " rate " MB/s")	
				}  
				 
				prevTime:=CurrentSeconds					
				prevSize := iPointer	
			}
			
				;AddLine("Transfer Rate: " bDataLength " bytes/event")
			
			If (iPointer > iFileSize)
			{
			addline("FATAL OVERWRITE ERROR ---")
			}
			
			;Check if we have received the whole file
        If (iPointer = iFileSize) {
            
            ;We can close the file handle and reset the value
            File_Close(hFile)
            hFile := -1 ;Reset value to indicate that we closed the file
			iFileSize:=0
			FirstReceive:=1
			ReceivingFile=0
			firstRateOutput:=1
			prevTime:=0, prevSize:=0
	
	;create folders
	Global Download_Location
	SplitPath, fileNameRec, OutFileName, OutDir 
	FileCreateDir, %Download_Location%\%outdir%
		    Filemove, %sFile%, %Download_Location%\%fileNameRec%,1
			FileSetTime, Integer2Time(iModTime), %Download_Location%\%fileNameRec%, M
			FileSetTime, Integer2Time(iCrTime), %Download_Location%\%fileNameRec%, C
			
			 
            str:="File Received!" 
			AddLine("File Received! Performing File Verification...") 
			crc32str:=LC_FileCRC32(Download_Location "\" fileNameRec)
			/*
			VarSetCapacity(bCRC32, 8, 0)
			StrPut(crc32str,&bCRC32+0,8,"")		
			If (i := AHKsock_ForceSend(iPeerSocket, &bCRC32, 1)) {
					AddLine("AHKsock_ForceSend CRC failed with return value = " i " and error code = " ErrorLevel " at line " A_LineNumber) 
					gosub ToggleConnectBtn				
					return
				}
				*/
			if (crc32str=crc32server)
			AddLine("CRC32 matched! File Verified! ")
			else			
			{
			AddLine("CRC32 did not match! Error in File Transmission! " crc32str " != " crc32server)
			gosub EndTransferBtn
			} 
			fileNameRec=
			AddLine("===================")
	GuiControl, Parent:Enable, btnSend
	GuiControl, Parent:Enable, btnSendFolder
			SB_SetProgress(0,3)
			gosub ToggleConnectBtn
            ;Output the average speed for the transfer
            DllCall("QueryPerformanceCounter", "int64*", qpTend)
            ;OutputDebug, % "End Average speed = " Round((iFileSize / 1024) / ((qpTend - qpTstart) / qpFreq)) " kB/s"
        }
		
        ;Update progress bar 
		SB_SetProgress(iPointer * 100 / iFileSize,3)
        GuiControl,, hwndStatusProg, % iPointer * 100 / iFileSize 
}

UnixEpoch()
{
T = %A_Now%
T -= 1970,s
return T
}

AHKsockErrors(iError, iSocket) {
    AddLine("Error " iError " with error code = " ErrorLevel ((iSocket <> -1) ? " on socket " iSocket "." : "."))
}

CopyBinData(ptrSource, ptrDestination, iLength) {
    If iLength ;Only do it if there's anything to copy
        DllCall("RtlMoveMemory", "Ptr", ptrDestination, "Ptr", ptrSource, "UInt", iLength)
}

/*! TheGood
    Append text to an Edit control
    http://www.autohotkey.com/forum/viewtopic.php?t=56717
*/
InsertText(hEdit, ptrText, iPos = -1) {
    
    If (iPos = -1) {
        SendMessage, 0x000E, 0, 0,, ahk_id %hEdit% ;WM_GETTEXTLENGTH
        iPos := ErrorLevel
    }
    
    SendMessage, 0x00B1, iPos, iPos,, ahk_id %hEdit% ;EM_SETSEL
    SendMessage, 0x00C2, False, ptrText,, ahk_id %hEdit% ;EM_REPLACESEL
}

;Anchor by Titan, adapted by TheGood
;http://www.autohotkey.com/forum/viewtopic.php?p=377395#377395
Anchor(i, a = "", r = false) {
	static c, cs = 12, cx = 255, cl = 0, g, gs = 8, gl = 0, gpi, gw, gh, z = 0, k = 0xffff, ptr
	If z = 0
		VarSetCapacity(g, gs * 99, 0), VarSetCapacity(c, cs * cx, 0), ptr := A_PtrSize ? "Ptr" : "UInt", z := true
	If (!WinExist("ahk_id" . i)) {
		GuiControlGet, t, Hwnd, %i%
		If ErrorLevel = 0
			i := t
		Else ControlGet, i, Hwnd, , %i%
	}
	VarSetCapacity(gi, 68, 0), DllCall("GetWindowInfo", "UInt", gp := DllCall("GetParent", "UInt", i), ptr, &gi)
		, giw := NumGet(gi, 28, "Int") - NumGet(gi, 20, "Int"), gih := NumGet(gi, 32, "Int") - NumGet(gi, 24, "Int")
	If (gp != gpi) {
		gpi := gp
		Loop, %gl%
			If (NumGet(g, cb := gs * (A_Index - 1)) == gp, "UInt") {
				gw := NumGet(g, cb + 4, "Short"), gh := NumGet(g, cb + 6, "Short"), gf := 1
				Break
			}
		If (!gf)
			NumPut(gp, g, gl, "UInt"), NumPut(gw := giw, g, gl + 4, "Short"), NumPut(gh := gih, g, gl + 6, "Short"), gl += gs
	}
	ControlGetPos, dx, dy, dw, dh, , ahk_id %i%
	Loop, %cl%
		If (NumGet(c, cb := cs * (A_Index - 1), "UInt") == i) {
			If a =
			{
				cf = 1
				Break
			}
			giw -= gw, gih -= gh, as := 1, dx := NumGet(c, cb + 4, "Short"), dy := NumGet(c, cb + 6, "Short")
				, cw := dw, dw := NumGet(c, cb + 8, "Short"), ch := dh, dh := NumGet(c, cb + 10, "Short")
			Loop, Parse, a, xywh
				If A_Index > 1
					av := SubStr(a, as, 1), as += 1 + StrLen(A_LoopField)
						, d%av% += (InStr("yh", av) ? gih : giw) * (A_LoopField + 0 ? A_LoopField : 1)
			DllCall("SetWindowPos", "UInt", i, "UInt", 0, "Int", dx, "Int", dy
				, "Int", InStr(a, "w") ? dw : cw, "Int", InStr(a, "h") ? dh : ch, "Int", 4)
			If r != 0
				DllCall("RedrawWindow", "UInt", i, "UInt", 0, "UInt", 0, "UInt", 0x0101) ; RDW_UPDATENOW | RDW_INVALIDATE
			Return
		}
	If cf != 1
		cb := cl, cl += cs
	bx := NumGet(gi, 48, "UInt"), by := NumGet(gi, 16, "Int") - NumGet(gi, 8, "Int") - gih - NumGet(gi, 52, "UInt")
	If cf = 1
		dw -= giw - gw, dh -= gih - gh
	NumPut(i, c, cb, "UInt"), NumPut(dx - bx, c, cb + 4, "Short"), NumPut(dy - by, c, cb + 6, "Short")
		, NumPut(dw, c, cb + 8, "Short"), NumPut(dh, c, cb + 10, "Short")
	Return, true
}


 


Integer2Time(X)
{	
	returnDate = 16010101000000
	returnDate += X, s
	return returnDate
}

Time2Integer(T)
{
T -= 1601,s
return T
}


;send

FileSend(SendFolder=0)
{			
			Global ParentHwnd
			Gui Parent:+OwnDialogs
			
			sFiles=
			
			if (SendFolder)
			{
				sFolder:=SelectFolderEx("", "Select Folder to Send", ParentHwnd,  "Select Folder")
				if !sFolder
				return
				SplitPath, sFolder, OutFileName, OutDir, OutExtension, OutNameNoExt, OutDrive
				sFiles=%OutDir%`n 
				Loop, Files, %sFolder%\*.*, R
				{
				fpath := StrReplace(A_LoopFileLongPath, sFolder)
				sFiles=%sFiles%%OutFileName%%fpath%`n 
				}
			}
			else ;files only
			{
			FileSelectFile, sFiles, M3
			if ErrorLevel 
			return 
			}
			
			
			dirname=
			totalsize=0
			sentsize=0
			
			
			;msgbox % sfiles  
			;calc size
			Loop, parse, sFiles, `n
			{			
				if A_Index=1
				{
					dirname:=A_LoopField
					continue
				}
				sFile=%dirname%\%A_LoopField% 
				FileGetSize, fsize, %sFile%
				totalsize += fsize
			}
			AddLine("Total Size of Files to be Sent: " Round(totalsize/1048576,2) " MB")
			
			Global multifiles:=1  ;so set progress doesnt zero 
			
			;send files===================================================
			Loop, parse, sFiles, `n
			{			
			if (A_Index=1 or !A_LoopField)
			{ 
				continue
			} 			 
			sFile=%dirname%\%A_LoopField% 

			Global SendingFile = 1
			Global LastFileVerified=0
			Global connected, bufsize 
					
					gosub ToggleConnectBtn	
			
			FileGetTime, otime, %sFile%, M
			modtime:=Time2Integer(otime)
			FileGetTime, otime, %sFile%, C
			crtime:=Time2Integer(otime) 			
			
			AddLine("===================")
			AddLine("Sending file " sFile)
			
			Global iPeerSocket
			
			hFile := File_Open("ReadSeq", sFile) ;Add the Sequential option since reading will be sequential
            If (hFile = -1) { ;Check for error
                AddLine("Server - Could not open the file in SEND! ErrorLevel = " ErrorLevel)
                 
                Return
            }
			
			;Get Name 
			;SplitPath, sFile,iFN 
			iFN:=A_LoopField ;with folder prefix
            
            ;Get the size
            iFileSize := File_Size(hFile)
            If (iFileSize = -1) { ;Check for error
                AddLine("Server - Could not get the file size! ErrorLevel = " ErrorLevel)                
                ;Close the file
                File_Close(hFile) 
                Return
            }
					
			AddLine("File Size: " Round(iFileSize/1048576,3) " MB")
        
			AddLine("Calculating CRC32...")
			crc32str:=LC_FileCRC32(sFile)	 
            ;Prepare the integer containing the file size which we will send to the client
            ;We need to create an actual 64-bit integer manually, because AHK keeps variables as strings
            VarSetCapacity(bFileSize, 8, 0)
            NumPut(iFileSize, bFileSize, 0, "int64") 
            
            ;Set to 0 to indicate that we can start reading from the file
            bFileLength := 0
			
			;Read only (up to) 8191 - 8 = 8183 bytes from the file
            bFileLengthTemp := File_Read(hFile, bFileTemp, bufsize-8)
            If (bFileLengthTemp = -1) { ;Check for error
                AddLine("File couldn't be read! ErrorLevel = " ErrorLevel)
                
                ;Close the file and reset the file handle value
                File_Close(hFile)
                hFile := -1
                Return
            }
            
            ;Prepare the bFile to hold the bytes read + the 64-bit int + file details
            VarSetCapacity(bFile, bFileLengthTemp + 8 + 255 + 8 + 8 + 8)
            
            ;Copy the 64-bit int at the first 8 bytes of bFile
            CopyBinData(&bFileSize, &bFile, 8)
            
			;name			
			StrPut(iFN,&bFile+8, 255,"")		
			
			;time mod and create
			VarSetCapacity(btempTime, 8, 0)
            NumPut(modtime, btempTime, 0, "int64")
			CopyBinData(&btempTime, &bFile + 8 + 255, 8)
            NumPut(crtime, btempTime, 0, "int64")
			CopyBinData(&btempTime, &bFile + 8 + 255 + 8, 8)
			
			StrPut(crc32str,&bFile + 8 + 255 + 8 + 8, 8,"")
			
            ;Copy the bytes read from the file after the first x bytes
            CopyBinData(&bFileTemp, &bFile + 8 + 255 + 8 + 8 + 8, bFileLengthTemp) 
			
            ;Set the length of the chunk bFile
            bFileLength := bFileLengthTemp + 8 + 255 + 8 + 8 + 8
			
				
					AddLine("Begin Sending...")
			Loop
			{
			if !connected   ;disconnected
			{
					Global SendingFile = 0
					Global multifiles:=0
					File_Close(hFile)	
					gosub ToggleConnectBtn	 		
					VarSetCapacity(bFile, 0)		
					;addline("File Sending Interrupted - closed.")			
					hFile := -1
					return
			}
			if !SendingFile   ;canceled sending
			{	
					Global multifiles:=0
					VarSetCapacity(bFile, 0)
					hFile := -1
					File_Close(hFile)		
					;addline("File Sending Interrupted - not sendingfile.")
					gosub ToggleConnectBtn	
					return
			}
			;otherwise send the packets
			If (i := AHKsock_ForceSend(iPeerSocket, &bFile, bFileLength)) {
					AddLine("AHKsock_ForceSend failed with return value = " i " and error code = " ErrorLevel " at line " A_LineNumber)
					Global SendingFile = 0
					File_Close(hFile)
					gosub DisconnectBtn ;;===============
					gosub ToggleConnectBtn				
					return
				}
			Global TotalSent += bFileLength
			iPointer := File_Pointer(hFile)
			tempsentsize:=sentsize+iPointer
			If (iPointer >= iFileSize)
                Break
			bFileLength := File_Read(hFile, bFile, bufsize) 
			;addline("sending ...."iFN)
			;SB_SetProgress(iPointer * 100 / iFileSize,3)
			SB_SetProgress(tempsentsize * 100 / totalsize,3,"-smooth")
			Gosub StatsUpdate
			;AddLine("Percentage done " tempsentsize * 100 / totalsize)
			;GuiControl,, hwndStatusProg, % iPointer * 100 / iFileSize 
			}
			sentsize+=iFileSize
			;AddLine("Sentsize " Round(sentsize/1048576,2))       
        ;Close the file
        File_Close(hFile)
        
        ;Free any memory related to the last chunk of file data we read
        VarSetCapacity(bFile, 0)
        
        ;We can reset the file handle variable now so that we can accept new clients. 
        ;We don't need to actually wait for the client we just served to disconnect because as long as we are done sending
        ;data to it, we can use our static variables to track the data sending progress with another client!
        hFile := -1
		 
		 /*
		 AddLine("Waiting for receipt acknowledgment...") 
		 While(!LastFileVerified)
		 { 
		 }
		 */
		 
			AddLine("File sent.") 
			;SB_SetProgress(0,3)
			AddLine("===================")
			Global SendingFile = 0  ; end of file successful transfer
			SB_SetProgress(sentsize * 100 / totalsize,3,"-smooth")
		
		} ;end loop files
		Global multifiles:=0
			Gosub ToggleConnectBtn	 
			if SendFolder
			ADDline("The folder was successfully sent.")
}

/*! TheGood
    Simple file functions
    http://www.autohotkey.com/forum/viewtopic.php?t=56510
*/

File_Open(sType, sFile) {
    
    bRead := InStr(sType, "READ")
    bSeq  := sType = "READSEQ"
    
    ;Open the file for writing with GENERIC_WRITE/GENERIC_READ, NO SHARING/FILE_SHARE_READ & FILE_SHARE_WRITE, and
    ;OPEN_ALWAYS/OPEN_EXISTING, and FILE_FLAG_SEQUENTIAL_SCAN
    hFile := DllCall("CreateFile", "Str", sFile, "UInt", bRead ? 0x80000000 : 0x40000000, "UInt", bRead ? 3 : 0, "Ptr", 0
                                 , "UInt", bRead ? 3 : 4, "UInt", bSeq ? 0x08000000 : 0, "Ptr", 0, "Ptr")
    If (hFile = -1 Or ErrorLevel) { ;Check for any error other than ERROR_FILE_EXISTS
        ErrorLevel := ErrorLevel ? ErrorLevel : A_LastError
        Return -1 ;Return INVALID_HANDLE_VALUE
    } Else Return hFile
}

File_Read(hFile, ByRef bData, iLength = 0) {
    
    ;Check if we're reading up to the rest of the file
    If Not iLength ;Set the length equal to the remaining part of the file
        iLength := File_Size(hFile) - File_Pointer(hFile)
    
    ;Prep the variable
    VarSetCapacity(bData, iLength, 0)
    
    ;Read the file
    r := DllCall("ReadFile", "Ptr", hFile, "Ptr", &bData, "UInt", iLength, "UInt*", iLengthRead, "Ptr", 0)
    If (Not r Or ErrorLevel) {
        ErrorLevel := ErrorLevel ? ErrorLevel : A_LastError
        Return -1
    } Else Return iLengthRead
}

File_Write(hFile, ptrData, iLength) {
    
    ;Write to the file
    r := DllCall("WriteFile", "Ptr", hFile, "Ptr", ptrData, "UInt", iLength, "UInt*", iLengthWritten, "Ptr", 0)
    If (Not r Or ErrorLevel) {
        ErrorLevel := ErrorLevel ? ErrorLevel : A_LastError
        Return -1
    } Else Return iLengthWritten
}

File_Pointer(hFile, iOffset = 0, iMethod = -1) {
    
    ;Check if we're on auto
    If (iMethod = -1) {
        
        ;Check if we should use FILE_BEGIN, FILE_CURRENT, or FILE_END
        If (iOffset = 0)
            iMethod := 1 ;We're just retrieving the current pointer. FILE_CURRENT
        Else If (iOffset > 0)
            iMethod := 0 ;We're moving from the beginning. FILE_BEGIN
        Else If (iOffset < 0)
            iMethod := 2 ;We're moving from the end. FILE_END
    } Else If iMethod Is Not Integer
        iMethod := (iMethod = "BEGINNING" ? 0 : (iMethod = "CURRENT" ? 1 : (iMethod = "END" ? 2 : 0)))
    
    r := DllCall("SetFilePointerEx", "Ptr", hFile, "Int64", iOffset, "Int64*", iNewPointer, "UInt", iMethod)
    If (Not r Or ErrorLevel) {
        ErrorLevel := ErrorLevel ? ErrorLevel : A_LastError
        Return -1
    } Else Return iNewPointer
}

File_Size(hFile) {
    r := DllCall("GetFileSizeEx", "Ptr", hFile, "Int64*", iFileSize)
    If (Not r Or ErrorLevel) {
        ErrorLevel := ErrorLevel ? ErrorLevel : A_LastError
        Return -1
    } Else Return iFileSize
}

File_Close(hFile) {
    If Not (r := DllCall("CloseHandle", "Ptr", hFile)) {
        ErrorLevel := ErrorLevel ? ErrorLevel : A_LastError
        Return False
    } Return True
}

 

 
 
 
 
 
 
;@ahkforum
SB_SetProgress(Value=0,Seg=1,Ops="")
{
   ; Definition of Constants   
   Static SB_GETRECT      := 0x40a      ; (WM_USER:=0x400) + 10
        , SB_GETPARTS     := 0x406
        , SB_PROGRESS                   ; Container for all used hwndBar:Seg:hProgress
        , PBM_SETPOS      := 0x402      ; (WM_USER:=0x400) + 2
        , PBM_SETRANGE32  := 0x406
        , PBM_SETBARCOLOR := 0x409
        , PBM_SETBKCOLOR  := 0x2001 
        , dwStyle         := 0x50000001 ; forced dwStyle WS_CHILD|WS_VISIBLE|PBS_SMOOTH

   ; Find the hWnd of the currentGui's StatusbarControl
   Gui,Parent:+LastFound
   ControlGet,hwndBar,hWnd,,msctls_statusbar321

   if (!StrLen(hwndBar)) { 
      rErrorLevel := "FAIL: No StatusBar Control"     ; Drop ErrorLevel on Error
   } else If (Seg<=0) {
      rErrorLevel := "FAIL: Wrong Segment Parameter"  ; Drop ErrorLevel on Error
   } else if (Seg>0) {
      ; Segment count
      SendMessage, SB_GETPARTS, 0, 0,, ahk_id %hwndBar%
      SB_Parts :=  ErrorLevel - 1
      If ((SB_Parts!=0) && (SB_Parts<Seg)) {
         rErrorLevel := "FAIL: Wrong Segment Count"  ; Drop ErrorLevel on Error
      } else {
         ; Get Segment Dimensions in any case, so that the progress control
         ; can be readjusted in position if neccessary
         if (SB_Parts) {
            VarSetCapacity(RECT,16,0)     ; RECT = 4*4 Bytes / 4 Byte <=> Int
            ; Segment Size :: 0-base Index => 1. Element -> #0
            SendMessage,SB_GETRECT,Seg-1,&RECT,,ahk_id %hwndBar%
            If ErrorLevel
               Loop,4
                  n%A_index% := NumGet(RECT,(a_index-1)*4,"Int")
            else
               rErrorLevel := "FAIL: Segmentdimensions" ; Drop ErrorLevel on Error
         } else { ; We dont have any parts, so use the entire statusbar for our progress
            n1 := n2 := 0
            ControlGetPos,,,n3,n4,,ahk_id %hwndBar%
         } ; if SB_Parts

         If (InStr(SB_Progress,":" Seg ":")) {

            hWndProg := (RegExMatch(SB_Progress, hwndBar "\:" seg "\:(?P<hWnd>([^,]+|.+))",p)) ? phWnd :

         } else {

            If (RegExMatch(Ops,"i)-smooth"))
               dwStyle ^= 0x1

            hWndProg := DllCall("CreateWindowEx","uint",0,"str","msctls_progress32"
               ,"uint",0,"uint", dwStyle
               ,"int",0,"int",0,"int",0,"int",0 ; segment-progress :: X/Y/W/H
               ,"uint",DllCall("GetAncestor","uInt",hwndBar,"uInt",1) ; gui hwnd
               ,"uint",0,"uint",0,"uint",0)

            SB_Progress .= (StrLen(SB_Progress) ? "," : "") hwndBar ":" Seg ":" hWndProg

         } ; If InStr Prog <-> Seg

         ; HTML Colors
         Black:=0x000000,Green:=0x008000,Silver:=0xC0C0C0,Lime:=0x00FF00,Gray:=0x808080
         Olive:=0x808000,White:=0xFFFFFF,Yellow:=0xFFFF00,Maroon:=0x800000,Navy:=0x000080
         Red:=0xFF0000,Blue:=0x0000FF,Fuchsia:=0xFF00FF,Aqua:=0x00FFFF

         If (RegExMatch(ops,"i)\bBackground(?P<C>[a-z0-9]+)\b",bg)) {
              if ((strlen(bgC)=6)&&(RegExMatch(bgC,"i)([0-9a-f]{6})")))
                  bgC := "0x" bgC
              else if !(RegExMatch(bgC,"i)^0x([0-9a-f]{1,6})"))
                  bgC := %bgC%
              if (bgC+0!="")
                  SendMessage, PBM_SETBKCOLOR, 0
                      , ((bgC&255)<<16)+(((bgC>>8)&255)<<8)+(bgC>>16) ; BGR
                      ,, ahk_id %hwndProg%
         } ; If RegEx BGC
         If (RegExMatch(ops,"i)\bc(?P<C>[a-z0-9]+)\b",fg)) {
              if ((strlen(fgC)=6)&&(RegExMatch(fgC,"i)([0-9a-f]{6})")))
                  fgC := "0x" fgC
              else if !(RegExMatch(fgC,"i)^0x([0-9a-f]{1,6})"))
                  fgC := %fgC%
              if (fgC+0!="")
                  SendMessage, PBM_SETBARCOLOR, 0
                      , ((fgC&255)<<16)+(((fgC>>8)&255)<<8)+(fgC>>16) ; BGR
                      ,, ahk_id %hwndProg%
         } ; If RegEx FGC

         If ((RegExMatch(ops,"i)(?P<In>[^ ])?range((?P<Lo>\-?\d+)\-(?P<Hi>\-?\d+))?",r)) 
              && (rIn!="-") && (rHi>rLo)) {    ; Set new LowRange and HighRange
              SendMessage,0x406,rLo,rHi,,ahk_id %hWndProg%
         } else if ((rIn="-") || (rLo>rHi)) {  ; restore defaults on remove or invalid values
              SendMessage,0x406,0,100,,ahk_id %hWndProg%
         } ; If RegEx Range
      
         If (RegExMatch(ops,"i)\bEnable\b"))
            Control, Enable,,, ahk_id %hWndProg%
         If (RegExMatch(ops,"i)\bDisable\b"))
            Control, Disable,,, ahk_id %hWndProg%
         If (RegExMatch(ops,"i)\bHide\b"))
            Control, Hide,,, ahk_id %hWndProg%
         If (RegExMatch(ops,"i)\bShow\b"))
            Control, Show,,, ahk_id %hWndProg%

         ControlGetPos,xb,yb,,,,ahk_id %hwndBar%
         ControlMove,,xb+n1,yb+n2,n3-n1,n4-n2,ahk_id %hwndProg%
         SendMessage,PBM_SETPOS,value,0,,ahk_id %hWndProg%

      } ; if Seg greater than count
   } ; if Seg greater zero 
   If (regExMatch(rErrorLevel,"^FAIL")) {
      ErrorLevel := rErrorLevel
      Return -1
   } else 
      Return hWndProg

}


;ahkforum ==================================================================================================================================
; Shows a dialog to select a folder.
; Depending on the OS version the function will use either the built-in FileSelectFolder command (XP and previous)
; or the Common Item Dialog (Vista and later).
; Parameter:
;     StartingFolder -  the full path of a folder which will be preselected.
;     Prompt         -  a text used as window title (Common Item Dialog) or as text displayed withing the dialog.
;     ----------------  Common Item Dialog only:
;     OwnerHwnd      -  HWND of the Gui which owns the dialog. If you pass a valid HWND the dialog will become modal.
;     BtnLabel       -  a text to be used as caption for the apply button.
;  Return values:
;     On success the function returns the full path of selected folder; otherwise it returns an empty string.
; MSDN:
;     Common Item Dialog -> msdn.microsoft.com/en-us/library/bb776913%28v=vs.85%29.aspx
;     IFileDialog        -> msdn.microsoft.com/en-us/library/bb775966%28v=vs.85%29.aspx
;     IShellItem         -> msdn.microsoft.com/en-us/library/bb761140%28v=vs.85%29.aspx
; ==================================================================================================================================
SelectFolderEx(StartingFolder := "", Prompt := "", OwnerHwnd := 0, OkBtnLabel := "") {
   Static OsVersion := DllCall("GetVersion", "UChar")
        , IID_IShellItem := 0
        , InitIID := VarSetCapacity(IID_IShellItem, 16, 0)
                  & DllCall("Ole32.dll\IIDFromString", "WStr", "{43826d1e-e718-42ee-bc55-a1e261c37bfe}", "Ptr", &IID_IShellItem)
        , Show := A_PtrSize * 3
        , SetOptions := A_PtrSize * 9
        , SetFolder := A_PtrSize * 12
        , SetTitle := A_PtrSize * 17
        , SetOkButtonLabel := A_PtrSize * 18
        , GetResult := A_PtrSize * 20
   SelectedFolder := ""
   If (OsVersion < 6) { ; IFileDialog requires Win Vista+, so revert to FileSelectFolder
      FileSelectFolder, SelectedFolder, *%StartingFolder%, 3, %Prompt%
      Return SelectedFolder
   }
   OwnerHwnd := DllCall("IsWindow", "Ptr", OwnerHwnd, "UInt") ? OwnerHwnd : 0
   If !(FileDialog := ComObjCreate("{DC1C5A9C-E88A-4dde-A5A1-60F82A20AEF7}", "{42f85136-db7e-439c-85f1-e4075d135fc8}"))
      Return ""
   VTBL := NumGet(FileDialog + 0, "UPtr")
   ; FOS_CREATEPROMPT | FOS_NOCHANGEDIR | FOS_PICKFOLDERS
   DllCall(NumGet(VTBL + SetOptions, "UPtr"), "Ptr", FileDialog, "UInt", 0x00002028, "UInt")
   If (StartingFolder <> "")
      If !DllCall("Shell32.dll\SHCreateItemFromParsingName", "WStr", StartingFolder, "Ptr", 0, "Ptr", &IID_IShellItem, "PtrP", FolderItem)
         DllCall(NumGet(VTBL + SetFolder, "UPtr"), "Ptr", FileDialog, "Ptr", FolderItem, "UInt")
   If (Prompt <> "")
      DllCall(NumGet(VTBL + SetTitle, "UPtr"), "Ptr", FileDialog, "WStr", Prompt, "UInt")
   If (OkBtnLabel <> "")
      DllCall(NumGet(VTBL + SetOkButtonLabel, "UPtr"), "Ptr", FileDialog, "WStr", OkBtnLabel, "UInt")
   If !DllCall(NumGet(VTBL + Show, "UPtr"), "Ptr", FileDialog, "Ptr", OwnerHwnd, "UInt") {
      If !DllCall(NumGet(VTBL + GetResult, "UPtr"), "Ptr", FileDialog, "PtrP", ShellItem, "UInt") {
         GetDisplayName := NumGet(NumGet(ShellItem + 0, "UPtr"), A_PtrSize * 5, "UPtr")
         If !DllCall(GetDisplayName, "Ptr", ShellItem, "UInt", 0x80028000, "PtrP", StrPtr) ; SIGDN_DESKTOPABSOLUTEPARSING
            SelectedFolder := StrGet(StrPtr, "UTF-16"), DllCall("Ole32.dll\CoTaskMemFree", "Ptr", StrPtr)
         ObjRelease(ShellItem)
   }  }
   If (FolderItem)
      ObjRelease(FolderItem)
   ObjRelease(FileDialog)
   Return SelectedFolder
}


;joedf @ git  libcrypt ahk
LC_FileCRC32(sFile := "", cSz := 4) {
	Bytes := ""
	cSz := (cSz < 0 || cSz > 8) ? 2**22 : 2**(18 + cSz)
	VarSetCapacity(Buffer, cSz, 0)
	hFil := DllCall("Kernel32.dll\CreateFile", "Str", sFile, "UInt", 0x80000000, "UInt", 3, "Int", 0, "UInt", 3, "UInt", 0, "Int", 0, "UInt")
	if (hFil < 1)
	{
		return hFil
	}
	hMod := DllCall("Kernel32.dll\LoadLibrary", "Str", "Ntdll.dll")
	CRC32 := 0
	DllCall("Kernel32.dll\GetFileSizeEx", "UInt", hFil, "Int64", &Buffer), fSz := NumGet(Buffer, 0, "Int64")
	loop % (fSz // cSz + !!Mod(fSz, cSz))
	{
		DllCall("Kernel32.dll\ReadFile", "UInt", hFil, "Ptr", &Buffer, "UInt", cSz, "UInt*", Bytes, "UInt", 0)
		CRC32 := DllCall("Ntdll.dll\RtlComputeCrc32", "UInt", CRC32, "UInt", &Buffer, "UInt", Bytes, "UInt")
	}
	DllCall("Kernel32.dll\CloseHandle", "Ptr", hFil)
	SetFormat, Integer, % SubStr((A_FI := A_FormatInteger) "H", 0)
	CRC32 := SubStr(CRC32 + 0x1000000000, -7)
	DllCall("User32.dll\CharLower", "Str", CRC32)
	SetFormat, Integer, %A_FI%
	return CRC32, DllCall("Kernel32.dll\FreeLibrary", "Ptr", hMod)
}