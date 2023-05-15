;-----------------------------------------------------------------------------------------------------------------------------------
; Global Script values
	#NoTrayIcon				 ; Do not show AHK tray icon for pause acript etc.
	DetectHiddenText True	 ; True = Used to get the windows title - text of hidden windows.
	DetectHiddenWindows True ; True = used to find the xi_.exe server console and main window. Hidden windows are detected.
	SetTitleMatchMode 3		 ; 3 = A window's title must exactly match WinTitle to be a match. Safest way to search for windows.
	SetTitleMatchMode "Slow" ; Slow: Can be much slower, but works with all controls which respond to the WM_GETTEXT message.
	Debug_On := Array("0")  ; 0 = Off This shows more information in the console and the log file. turn On / Off from help menu.
	Debug_On.Default := "0" ; This is for the Array Index not the actual var value do not change.
	SetTimer Resize_Windows ,1000 ; as the name suggests it autoresize all console windows every 1000 miliseconds
	SetTimer Auto_Start ,2000 ; Will auto start the servers according to the setting in the settings.ini
;-----------------------------------------------------------------------------------------------------------------------------------
	Settings_ini_exist := FileExist("Settings.ini")
	
	if (StrLen(Settings_ini_exist) = 0){
		;if settings.ini not found exit 
		MsgBox "Settings.ini not found."
		ExitApp
	}

	Get_Debug_ini_Setting := IniRead("Settings.ini", "xi_manager", "Debug")
	Debug_On.RemoveAt(1)
	Debug_On.InsertAt(1, Get_Debug_ini_Setting)
	
;-----------------------------------------------------------------------------------------------------------------------------------
; 	Array Referance Ids
;	1 = XI Map
;	2 = XI World
;	3 = XI Search
;	4 = XI Connect
;	5 = pydarkstar
;	6 = XI Server Manager - Main Window - Console
;	Note: ID 7 is only used to dock the console exe and is not located in any array
;-----------------------------------------------------------------------------------------------------------------------------------
; create arrys to store the  PID & HwndID for each .exe or .py
	xi_pids := Array("0","0","0","0","0","0")
	xi_hwnd := Array("0","0","0","0","0","0")
	xi_pids.Default := "0"
	xi_hwnd.Default := "0"
;-----------------------------------------------------------------------------------------------------------------------------------
;	Active console array. Default is 6 = XI Server Manager Console
	Active_Console_Is := Array("6")
;-----------------------------------------------------------------------------------------------------------------------------------
; Tesxt arrays for messages
	xi_main_title := Array("XI Server Manager")
	xi_restart_msg := Array("Status = RUNNING `n `n Yes = Restart Server`n `n No = Cancel Restart","`n`n You are about to Start/Restart all XI servers. `n `n Yes = Start/Restart All Server`n `n No = Cancel Restart")
	xi_exit_msg := Array(" This will close all server instances and exit `n `n Yes = Exit`n `n No = Cancel")
;-----------------------------------------------------------------------------------------------------------------------------------
; Array to show the current active XI or Broker console Text in Main Window Title and set style
	xi_con := Array(" Console - XI Map"," Console - XI World"," Console - XI Search"," Console - XI Connect"," Console - pydarkstar","Console - Main")
;-----------------------------------------------------------------------------------------------------------------------------------
;	Array with xi server , pydarkstar and XI Manager names
	xi_exe := Array("xi_map.exe","xi_world.exe","xi_search.exe","xi_connect.exe","pydarkstar_broker.exe","XI Server Manager.exe","AutoHotKey64.exe")
;-----------------------------------------------------------------------------------------------------------------------------------
;	set the ServerCheckInterval to auto restart server instances this is in miliseconds default is 60000 = 1 Min
	Get_Server_Check_Interval_ini_Setting := IniRead("Settings.ini", "xi_manager", "Server_Check_Interval")
	Server_Check_Interval := Array(Get_Server_Check_Interval_ini_Setting , "0")
;-----------------------------------------------------------------------------------------------------------------------------------
;	Open the main console log file for writing
	Console_Log_File := FileOpen(xi_main_title.Get(1) ".log","W")
;-----------------------------------------------------------------------------------------------------------------------------------
;	Creat a console window for the XI Server Manager.
	DllCall("AllocConsole")
	stdin  := FileOpen("*", "r")
	stdout := FileOpen("*", "w")
	Update_Server_Array_Pids_Hwnd(7)
;-----------------------------------------------------------------------------------------------------------------------------------
;	pydarkstar python apps quick information
;	broker.py = server that buys and sells items on the AH from players
;	buyer.py = server that buys items on the AH from players
;	clear.py = clear the AH of all transactions
;	refill.py = fill the AH with items for sale and exit
;	seller.py = server that sells items on the AH to players
;	scrub.py = download data from the web to create a database of items and prices
;---------------------------------------------------------------------------------------------------------------------------------------------------------
; Make the main gui window for the server manager with option Make the window resizable.
;---------------------------------------------------------------------------------------------------------------------------------------------------------
MyGui := Gui("+Resize", xi_main_title.Get(1))

;-------------------------------------------------------
; Create the submenus for the Show Console menu:
MenuServerCon := Menu()
MenuServerCon.Add("&XI Map", StartServerXImap)
MenuServerCon.Add("&XI World", StartServerXIworld)
MenuServerCon.Add("&XI Search", StartServerXIsearch)
MenuServerCon.Add("&XI Connect", StartServerXIconnect)
MenuServerCon.Add() ; Separator line.
MenuServerCon.Add("&Restart All", RestartAll)

;---------------------------------------------------------
; console subMenu
MenuShowServerCon := Menu()
MenuShowServerCon.Add("&XI Map", ShowServerConsoleMap)
MenuShowServerCon.Add("&XI World", ShowServerConsoleWorld)
MenuShowServerCon.Add("&XI Search", ShowServerConsoleSearch)
MenuShowServerCon.Add("&XI Connect", ShowServerConsoleConnect)
MenuShowServerCon.Add() ; Separator line.
MenuShowServerCon.Add("&pydarkstar Broker", ShowServerConsolepydarkstar)
MenuShowServerCon.Add() ; Separator line.
MenuShowServerCon.Add("&XI Server Manager", ShowServerConsoleXIManager)

;---------------------------------------------------------------
; Create SubMenu for pydarkstar
Menupydarkstar := Menu()
Menupydarkstar.Add("&Run Broker.py" , pydarkstarBroker)
Menupydarkstar.Add("&Run Buyer.py" ,  pydarkstarBuyer)
Menupydarkstar.Add("&Run Clear.py" ,  pydarkstarClear)
Menupydarkstar.Add("&Run Refill.py" ,  pydarkstarRefill)
Menupydarkstar.Add("&Run Seller.py" ,  pydarkstarSeller)
Menupydarkstar.Add("&Run Scrub.py" ,  pydarkstarScrub)

HelpMenu := Menu()
HelpMenu.Add("&Enable Debug", MenuHelpDebug)
ExitMenu := Menu()
ExitMenu.add("E&xit", Shutdown_All_Servers)

; Create the menu bar by attaching the submenus to it:
MyMenuBar := MenuBar()
MyMenuBar.Add("&XI Server Control", MenuServerCon)
MyMenuBar.Add("&View Console", MenuShowServerCon)
MyMenuBar.Add("&pydarkstar", Menupydarkstar)
MyMenuBar.Add("&Help", HelpMenu)
MyMenuBar.Add("&Exit", ExitMenu)

; Attach the menu bar to the window:
MyGui.MenuBar := MyMenuBar

;-----------------------------------------------------
; Process events:
MyGui.OnEvent("Close", Shutdown_All_Servers)
MyGui.OnEvent("Size", Resize_Windows)

;	Show / Render the main gui
MyGui.Show("w1020 h540")

; Dock Console into main gui window
WinActivate(xi_hwnd.Get(6))
DllCall("SetParent", "uint", xi_hwnd.Get(6), "uint", MyGui.Hwnd)
WinSetStyle("-0xCF0000", xi_hwnd.Get(6))
ShowServerConsole(6)
PrintConsole( A_LineNumber,  A_ThisFunc, xi_main_title.Get(1)  " v1.0 --- Started")

Auto_Start(*)
{

	settings_ini_autostart := IniRead("Settings.ini", "xi_manager", "Autostart")
	if (settings_ini_autostart = 1 or settings_ini_autostart = 2){
		PrintConsole( A_LineNumber,  A_ThisFunc, "AutoStart: XI Servers")		
		StartServerXImap()
		StartServerXIworld()
		StartServerXIsearch()
		StartServerXIconnect()
	}
	if (settings_ini_autostart = 2 or settings_ini_autostart = 3){
		PrintConsole( A_LineNumber,  A_ThisFunc, "AutoStart: pydarkstar broker")
		pydarkstarBroker()
	}
		
	SetTimer Auto_Start,0
}


ServerTimer(*)
{
;------------------------------------------------------------------------------
;---Prevents interruptions from any timers.
;---Note: Like when a windows is being created 
;------------------------------------------------------------------------------
	Thread "NoTimers" , 1
;------------------------------------------------------------------------------
;	Server Status Start
;------------------------------------------------------------------------------
	SetTimer(ServerCheck, Server_Check_Interval.Get(1))
	PrintConsole( A_LineNumber,  A_ThisFunc, "Server Check Timer Started")
;------------------------------------------------------------------------------
;	End Ststus Checks
;------------------------------------------------------------------------------
}

StartServerXImap(*)
{
	if(xi_pids.Get(1) > 0 or xi_hwnd.Get(1) > 0){
	; Broker.py is already running prompt for user input
	PrintConsole( A_LineNumber,  A_ThisFunc, xi_exe.Get(1) " --- Running --- Prompt user for restart")
			Result := MsgBox(xi_restart_msg.Get(1), xi_exe.Get(1) " --!!-- Restart --!!--", "YesNo 0x10")
		if (Result = "Yes"){
			WinClose(xi_hwnd.Get(1))
			Sleep 250
			StartServer(1,"Yes")
		}
		
		if (Result = "No"){
		   ; Restart aborted by user ignore start request
			Return
		}
	}

	if(xi_pids.Get(1) = 0 or xi_hwnd.Get(1) = 0){
		; Start xi_map if not alreay started
		StartServer(1,"Yes")
		ShowServerConsole(1)
	}
	
	if(xi_pids.Get(1) = 0 or xi_hwnd.Get(1) = 0){
		;Failed to get PID or HWND for Server display main console and return to main gui
		ShowServerConsole(6)
	}
}

StartServerXIworld(*)
{
	if(xi_pids.Get(2) > 0 or xi_hwnd.Get(2) > 0){
	; Broker.py is already running prompt for user input
	PrintConsole( A_LineNumber,  A_ThisFunc, xi_exe.Get(2) " --- Running --- Prompt user for restart")
			Result := MsgBox(xi_restart_msg.Get(1), xi_exe.Get(2) " --!!-- Restart --!!--", "YesNo 0x10")
		if (Result = "Yes"){
			WinClose(xi_hwnd.Get(2))
			Sleep 250
			StartServer(2,"Yes")
		}
		
		if (Result = "No"){
		   ; Restart aborted by user ignore start request
			Return
		}
	}

	if(xi_pids.Get(2) = 0 or xi_hwnd.Get(2) = 0){
		; Start xi_world if not alreay started
		StartServer(2,"Yes")
		ShowServerConsole(2)
	}
	
	if(xi_pids.Get(2) = 0 or xi_hwnd.Get(2) = 0){
		;Failed to get PID or HWND for Server display main console and return to main gui
		ShowServerConsole(6)
	}
}

StartServerXIsearch(*)
{
	if(xi_pids.Get(3) > 0 or xi_hwnd.Get(3) > 0){
	; Broker.py is already running prompt for user input
	PrintConsole( A_LineNumber,  A_ThisFunc, xi_exe.Get(3) " --- Running --- Prompt user for restart")
			Result := MsgBox(xi_restart_msg.Get(1), xi_exe.Get(3) " --!!-- Restart --!!--", "YesNo 0x10")
		if (Result = "Yes"){
			WinClose(xi_hwnd.Get(3))
			Sleep 250
			StartServer(3,"Yes")
		}
		
		if (Result = "No"){
		   ; Restart aborted by user ignore start request
			Return
		}
	}

	if(xi_pids.Get(3) = 0 or xi_hwnd.Get(3) = 0){
		; Start xi_search if not alreay started
		StartServer(3,"Yes")
		ShowServerConsole(3)
	}
	
	if(xi_pids.Get(3) = 0 or xi_hwnd.Get(3) = 0){
		;Failed to get PID or HWND for Server display main console and return to main gui
		ShowServerConsole(6)
	}
}

StartServerXIconnect(*)
{
	if(xi_pids.Get(4) > 0 or xi_hwnd.Get(4) > 0){
	; Broker.py is already running prompt for user input
	PrintConsole( A_LineNumber,  A_ThisFunc, xi_exe.Get(4) " --- Running --- Prompt user for restart")
			Result := MsgBox(xi_restart_msg.Get(1), xi_exe.Get(4) " --!!-- Restart --!!--", "YesNo 0x10")
		if (Result = "Yes"){
			WinClose(xi_hwnd.Get(4))
			Sleep 250
			StartServer(4,"Yes")
		}
		
		if (Result = "No"){
		   ; Restart aborted by user ignore start request
			Return
		}
	}

	if(xi_pids.Get(4) = 0 or xi_hwnd.Get(4) = 0){
		; Start xi_connect if not alreay started
		StartServer(4,"Yes")
		ShowServerConsole(4)
	}
	
	if(xi_pids.Get(4) = 0 or xi_hwnd.Get(4) = 0){
		;Failed to get PID or HWND for Server display main console and return to main gui
		ShowServerConsole(6)
	}
}

pydarkstarBroker(*)
{
	if(xi_pids.Get(5) > 0 or xi_hwnd.Get(5) > 0){
	; Broker.py is already running prompt for user input
	PrintConsole( A_LineNumber,  A_ThisFunc, xi_exe.Get(5) " --- Running --- Prompt user for restart")
			Result := MsgBox(xi_restart_msg.Get(1), xi_exe.Get(5) " --!!-- Restart --!!--", "YesNo 0x10")
		if (Result = "Yes"){
			WinClose(xi_hwnd.Get(5))
			Sleep 250
			StartServer(5,"Yes")
		}
		
		if (Result = "No"){
		   ; Restart aborted by user ignore start request
			Return
		}
	}

	if(xi_pids.Get(5) = 0 or xi_hwnd.Get(5) = 0){
		; Start pydarkstarBroker if not alreay started
		StartServer(5,"Yes")
		ShowServerConsole(5)
	}
	
	if(xi_pids.Get(5) = 0 or xi_hwnd.Get(5) = 0){
		;Failed to get PID or HWND for Server display main console and return to main gui
		ShowServerConsole(6)
	}
}

pydarkstarBuyer(*)
{
	PrintConsole( A_LineNumber,  A_ThisFunc, "Starting pydarkstar buyer.py script")
	Run("pydarkstar_buyer.exe", A_WorkingDir,,&pid)
}

pydarkstarClear(*)
{
	PrintConsole( A_LineNumber,  A_ThisFunc, "Starting pydarkstar clear.py script")
	Run("pydarkstar_clear.exe", A_WorkingDir,,&pid)
}

pydarkstarRefill(*)
{
	PrintConsole( A_LineNumber,  A_ThisFunc, "Loading pydarkstar refill.py script")
	Run("pydarkstar_refill.exe", A_WorkingDir,,&pid)
}

pydarkstarSeller(*)
{
	PrintConsole( A_LineNumber,  A_ThisFunc, "Loading pydarkstar seller.py script")
	Run("pydarkstar_seller.exe", A_WorkingDir,,&pid)
}

pydarkstarScrub(*)
{
	PrintConsole( A_LineNumber,  A_ThisFunc, "Loading pydarkstar scrub.py script")
	Run("pydarkstar_scrub.exe", A_WorkingDir,,&pid)
}

RestartAll(*)
{

	Result := MsgBox(xi_restart_msg.Get(2), "--!!-- Restart All XI Servers --!!--", "YesNo 0x10")
	if (Result = "Yes"){
		if(Debug_On.Get(1) = 1){
			PrintConsole( A_LineNumber,  A_ThisFunc, "Rstart All XI Servers triggered by user")
		}
		StartServer(1,"Yes")
		StartServer(2,"Yes")
		StartServer(3,"Yes")
		StartServer(4,"Yes")
		ShowServerConsole(6)
	}
	if (Result = "No"){
		if(Debug_On.Get(1) = 1){
			PrintConsole( A_LineNumber,  A_ThisFunc, "Rstart All XI Servers aborted by user")
		}
		Return
	}
}

ShowServerConsoleMap(*)
{
	ShowServerConsole(1)
}

ShowServerConsoleWorld(*)
{
	ShowServerConsole(2)
}

ShowServerConsoleSearch(*)
{
	ShowServerConsole(3)
}

ShowServerConsoleConnect(*)
{
	ShowServerConsole(4)
}
ShowServerConsolepydarkstar(*)
{
	ShowServerConsole(5)
}

ShowServerConsoleXIManager(*)
{
	ShowServerConsole(6)
}

ShowServerConsole(Server)
{
	WinGetPos( , , &Width, &Height, MyGui.Hwnd)
	if (ProcessExist(xi_pids.Get(1)) > 0){
		WinMove( 4, 0, Width-24, Height-64, xi_hwnd.Get(1))
		WinHide(xi_hwnd.Get(1))
		if(Debug_On.Get(1) = 1){
			PrintConsole( A_LineNumber,  A_ThisFunc, "Hide ConsoleID: 1 ---- Name: " xi_con.Get(1))
		}
	}
	if (ProcessExist(xi_pids.Get(2)) > 0){
		WinMove( 4, 0, Width-24, Height-64, xi_hwnd.Get(2))
		WinHide(xi_hwnd.Get(2))
		if(Debug_On.Get(1) = 1){
			PrintConsole( A_LineNumber,  A_ThisFunc, "Hide ConsoleID: 2 ---- Name: " xi_con.Get(2))
		}
	}
	if (ProcessExist(xi_pids.Get(3)) > 0){
		WinMove( 4, 0, Width-24, Height-64, xi_hwnd.Get(3))
		WinHide(xi_hwnd.Get(3))
		if(Debug_On.Get(1) = 1){
			PrintConsole( A_LineNumber,  A_ThisFunc, "Hide ConsoleID: 3 ---- Name: " xi_con.Get(3))
		}
	}
	if (ProcessExist(xi_pids.Get(4)) > 0){
		WinMove( 4, 0, Width-24, Height-64, xi_hwnd.Get(4))
		WinHide(xi_hwnd.Get(4))
		if(Debug_On.Get(1) = 1){
			PrintConsole( A_LineNumber,  A_ThisFunc, "Hide ConsoleID:  4 ---- Name: " xi_con.Get(4))
		}
	}
	if (ProcessExist(xi_pids.Get(5)) > 0){
		WinMove( 4, 0, Width-24, Height-64, xi_hwnd.Get(5))
		WinHide(xi_hwnd.Get(5))
		if(Debug_On.Get(1) = 1){
			PrintConsole( A_LineNumber,  A_ThisFunc, "Hide ConsoleID: 5 ---- Name: " xi_con.Get(5))
		}
	}
	if (ProcessExist(xi_pids.Get(6)) > 0){
		WinMove( 4, 0, Width-24, Height-64, xi_hwnd.Get(6))
		WinHide(xi_hwnd.Get(6))
		if(Debug_On.Get(1) = 1){
			PrintConsole( A_LineNumber,  A_ThisFunc, "Hide ConsoleID: 6 ---- Name: " xi_con.Get(6))
		}
	}
	
	if (ProcessExist(xi_pids.Get(Server)) > 0) {
		
		; Show the console selected console
		Active_Console_Is.InsertAt(1, Server)
		;WinHide(xi_hwnd.Get(Server))
		WinShow(xi_hwnd.Get(Server))
		WinSetTitle(xi_main_title.Get(1) " --- " xi_con.Get(Server) " --- PID: " xi_pids.Get(Server) " --- HwndID: " xi_hwnd.Get(Server),MyGui.Hwnd)
		WinActivate(MyGui.Hwnd)
		if(Debug_On.Get(1) = 1){
			PrintConsole( A_LineNumber,  A_ThisFunc, "Active console ID: " Active_Console_Is.Get(1))
			PrintConsole( A_LineNumber,  A_ThisFunc, "Name: " xi_con.Get(Server))
			PrintConsole( A_LineNumber,  A_ThisFunc, "HwndID: " xi_hwnd.Get(Server) " ---- PID: " xi_pids.Get(Server))
		}
	}
	; print info on the console windows
	Print_XI_Array_Info()
		
}


 MenuHelpDebug(*)
{
    Result := MsgBox("`n`n Debugging On / Off `n`n  Yes = Enable `n`n No = Disable `n`n", "Enable Debugging", "YesNoCancel 0x20")
	if Result = "Cancel"{
		; cancel selection 
		Return
	}
	if Result = "Yes"{
		;turn on debugging
		Debug_On.RemoveAt(1)
		Debug_On.InsertAt(1, "1")
	}
	if Result = "No"{
		;turn off debugging
		Debug_On.RemoveAt(1)
		Debug_On.InsertAt(1, "0")
	}
}

Resize_Windows(*)
{

	WinGetPos( , , &Width, &Height, MyGui.Hwnd)	
	if (ProcessExist(xi_pids.Get(1)) > 0) {
		WinMove( 4, 0, Width-24, Height-64, xi_hwnd.Get(1))
	}
		
	if (ProcessExist(xi_pids.Get(2)) > 0) {
		WinMove( 4, 0, Width-24, Height-64, xi_hwnd.Get(2))
	}
		
	if (ProcessExist(xi_pids.Get(3)) > 0) {
		WinMove( 4, 0, Width-24, Height-64, xi_hwnd.Get(3))
	}
	
	if (ProcessExist(xi_pids.Get(4)) > 0) {
		WinMove( 4, 0, Width-24, Height-64, xi_hwnd.Get(4))
	}
		
	if (ProcessExist(xi_pids.Get(5)) > 0) {
		WinMove( 4, 0, Width-24, Height-64, xi_hwnd.Get(5))
	}
		
	if (ProcessExist(xi_pids.Get(6)) > 0) {
		WinMove( 4, 0, Width-24, Height-64, xi_hwnd.Get(6))
	}
	
}

Shutdown_All_Servers(*)
{
	; User selected "Exit" from the File menu or click close button.
	Result := MsgBox(xi_exit_msg.Get(1), xi_main_title.Get(1), "YesNo 0x10")
	if Result = "No"{
		;Server Shutdown Aborted by user
		return
	}
	if Result = "Yes"{
		PrintConsole( A_LineNumber,  A_ThisFunc, "Shutting down all servers and exiting " xi_main_title.Get(1))
		Console_Log_File.Close()
		SetTimer Resize_Windows ,0 
		SetTimer ServerCheck,Server_Check_Interval.Get(2) 
		;SetTimer Auto_Resize_Windows,0
		Sleep 250
		; Shuntdown all server windows and exit
		ProcessClose(xi_pids.Get(1))
		Sleep 250
		ProcessClose(xi_pids.Get(2))
		Sleep 250
		ProcessClose(xi_pids.Get(3))
		Sleep 250
		ProcessClose(xi_pids.Get(4))
		Sleep 250
		if (xi_pids.Get(5) > 0){
			WinClose(xi_hwnd.Get(5))
		}
		Sleep 250
		ProcessClose(xi_pids.Get(6))
		Sleep 250
		ExitApp
	}
}

ServerCheck(*)
{
;---------------------------------------------------------------------------------------------
; /*
;  * SendMessageTimeout values
; 
; #define SMTO_NORMAL         0x0000 ; The calling thread is not prevented from processing other requests while waiting for the function to return.
; #define SMTO_BLOCK          0x0001 ; Prevents the calling thread from processing any other requests until the function returns.
; #define SMTO_ABORTIFHUNG    0x0002 ; The function returns without waiting for the time-out period to elapse if the receiving thread appears to not respond or "hangs."
; #if(WINVER >= 0x0500)
; #define SMTO_NOTIMEOUTIFNOTHUNG 0x0008
; #endif /* WINVER >= 0x0500 */
; #endif /* !NONCMESSAGES */
; 
; 
; SendMessageTimeout(
;     __in HWND hWnd,
;     __in UINT Msg,
;     __in WPARAM wParam,
;     __in LPARAM lParam,
;     __in UINT fuFlags,
;     __in UINT uTimeout,
;     __out_opt PDWORD_PTR lpdwResult);
;
; Scource Link Below
;---------------------------------------------------------------------------------------------
; https://learn.microsoft.com/en-us/previous-versions/windows/embedded/ms939981(v=msdn.10)
; or
; https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendmessagetimeoutw
;---------------------------------------------------------------------------------------------

	xi_map_status     := DllCall("SendMessageTimeout", "UInt", xi_hwnd.Get(1), "UInt", 0x0000, "Int", 0, "Int", 0, "UInt", 0x0002, "UInt", 1000, "UInt *", 0)
	xi_world_status   := DllCall("SendMessageTimeout", "UInt", xi_hwnd.Get(2), "UInt", 0x0000, "Int", 0, "Int", 0, "UInt", 0x0002, "UInt", 1000, "UInt *", 0)
	xi_search_status  := DllCall("SendMessageTimeout", "UInt", xi_hwnd.Get(3), "UInt", 0x0000, "Int", 0, "Int", 0, "UInt", 0x0002, "UInt", 1000, "UInt *", 0)	
	xi_connect_status := DllCall("SendMessageTimeout", "UInt", xi_hwnd.Get(4), "UInt", 0x0000, "Int", 0, "Int", 0, "UInt", 0x0002, "UInt", 1000, "UInt *", 0)	
	pydarkstar_status := DllCall("SendMessageTimeout", "UInt", xi_hwnd.Get(5), "UInt", 0x0000, "Int", 0, "Int", 0, "UInt", 0x0002, "UInt", 1000, "UInt *", 0)	

	if(Debug_On.Get(1) = 1 or Debug_On.Get(1) = 2){
		PrintConsole( A_LineNumber,  A_ThisFunc, "Starting Server Checks: ")
		PrintConsole( A_LineNumber,  A_ThisFunc, "xi_map status: " xi_map_status)
		PrintConsole( A_LineNumber,  A_ThisFunc, "xi_world status: " xi_world_status)
		PrintConsole( A_LineNumber,  A_ThisFunc, "xi_search status: " xi_search_status)
		PrintConsole( A_LineNumber,  A_ThisFunc, "xi_connect status: " xi_connect_status)
		PrintConsole( A_LineNumber,  A_ThisFunc, "pydarkstar broker status: " pydarkstar_status)
	}

;--------------------------------------------------------------------------------------------------------------------------------------------------------
;	if any of the status check = 0 then that server could not be reached.
; 	Note: this will only restart a server that was started with the xi server manager.
;	0 means exe did not respond to send message request. this could indacate that the server could be hung, not responding or not running ( crashed ).
;--------------------------------------------------------------------------------------------------------------------------------------------------------
	if (xi_hwnd.Get(1)> 0 and xi_map_status = 0){
		PrintConsole( A_LineNumber,  A_ThisFunc, xi_exe.Get(1) " is not responding.")
		PrintConsole( " ",  " ", " ")
		StartServer(1, "Yes")
	}
	if (xi_hwnd.Get(2)> 0 and xi_world_status = 0){
		PrintConsole( A_LineNumber,  A_ThisFunc, xi_exe.Get(2) " is not responding.")
		PrintConsole( " ",  " ", " ")
		StartServer(2, "Yes")
	}
	if (xi_hwnd.Get(3)> 0 and xi_search_status = 0){
		PrintConsole( A_LineNumber,  A_ThisFunc, xi_exe.Get(3) " is not responding.")
		PrintConsole( " ",  " ", " ")
		StartServer(3, "Yes")
	}
	if (xi_hwnd.Get(4)> 0 and xi_connect_status = 0){
		PrintConsole( A_LineNumber,  A_ThisFunc, xi_exe.Get(4) " is not responding.")
		PrintConsole( " ",  " ", " ")
		StartServer(4, "Yes")
	}
	if (xi_hwnd.Get(5)> 0 and pydarkstar_status = 0){
		PrintConsole( A_LineNumber,  A_ThisFunc, xi_exe.Get(5) " is not responding.")
		PrintConsole( " ",  " ", " ")
		StartServer(5, "Yes")
	}
	
}

StartServer(Server, ResetServerCheckTimer)
{
;----------------------------------------------------------------------------------------------
;	if the server was running reset the check timer and make a new instance of the server
;----------------------------------------------------------------------------------------------

	if (ResetServerCheckTimer = "Yes"){
		SetTimer(ServerCheck, Server_Check_Interval.Get(2))
	}
	
;-----------------------------------------------------------------------------------------------------------
;	if the vale of Server is 1 - 4 launch the XI Server whtn that ID
;-----------------------------------------------------------------------------------------------------------
	if (Server > 0 and Server  < 6 ) {
	
		;check for xi server and if running close it to start a new one
		if (ProcessExist(xi_exe.Get(Server)) > 0){
			PrintConsole( A_LineNumber,  A_ThisFunc, "Error Starting Server: " xi_exe.Get(Server) " --- Error: failed to get proper process ID.")
			PrintConsole( A_LineNumber,  A_ThisFunc, "Error Starting Server: This could be due to the " xi_exe.Get(Server) " is already running.")
			PrintConsole( A_LineNumber,  A_ThisFunc, "PID found for " xi_exe.Get(Server) " --- Atemptting to shutdown server process")
			if (Server = 5){
				WinClose(xi_hwnd.Get(5))
			}
				if (Server < 5){
					ProcessClose xi_exe.Get(Server)
				}
			PrintConsole( A_LineNumber,  A_ThisFunc,  xi_exe.Get(Server) " --- Shutdown server complete")
		}

		Get_xi_Server_ini_Setting := IniRead("Settings.ini", "default_paths", "xi_Server")
		if (Server = 5){
			Get_xi_Server_ini_Setting := A_WorkingDir "\"
		}
		
		PrintConsole( A_LineNumber,  A_ThisFunc, "Atempting to start: " xi_exe.Get(Server))		
		if (Debug_On.Get(1) = 1){
			PrintConsole( A_LineNumber,  A_ThisFunc, "XI exe Path: " Get_xi_Server_ini_Setting)
		}
		
		
		Run xi_exe.Get(Server), Get_xi_Server_ini_Setting, , &pid
		Sleep 250

		Update_Server_Array_Pids_Hwnd(Server)
		
		if(xi_pids.Get(Server) = 0 or xi_hwnd.Get(Server) = 0){
			;Failed to get PID or HWND for Server returning to main gui
			PrintConsole( A_LineNumber,  A_ThisFunc, "Error no valid PID or HwndID found for " xi_exe.Get(Server))
			if(Debug_On.Get(1) = 0){
				PrintConsole( A_LineNumber,  A_ThisFunc, "Please enable degugging located in the help menu.")
				PrintConsole( A_LineNumber,  A_ThisFunc, "try to start server again for more detailed information.")
			}
			Return
		}

		PrintConsole( A_LineNumber,  A_ThisFunc, "Started Server: " xi_exe.Get(Server))
		PrintConsole( A_LineNumber,  A_ThisFunc, "Process Name: " ProcessGetName(xi_pids.Get(Server)) " --- Process PID: " xi_pids.Get(Server) " --- HwndID: "  xi_hwnd.Get(Server))
		PrintConsole( A_LineNumber,  A_ThisFunc, "Process Path: " ProcessGetPath(xi_pids.Get(Server)))
		Dll_Return := DllCall("SetParent", "uint", xi_hwnd.Get(Server), "uint", MyGui.Hwnd)
		WinSetStyle("-0xCF0000", xi_hwnd.Get(Server))
		PrintConsole( A_LineNumber,  A_ThisFunc, "Docking Server: " xi_exe.Get(Server) " to main Window")
		
		if(Debug_On.Get(1) = 1){
			PrintConsole( A_LineNumber,  A_ThisFunc, "Dll Return: " Dll_Return)
			PrintConsole( A_LineNumber,  A_ThisFunc, "Return Last Error: " A_LastError)
		}
		
		; Call function to check server status 
		ServerTimer()
		PrintConsole( " ",  " ", " ")
	}
}


Update_Server_Array_Pids_Hwnd(Server)
{
	if(Debug_On.Get(1) = 1){
		PrintConsole( A_LineNumber,  A_ThisFunc, "EXE / AHK Script Name is: " A_ScriptName " --- MyGui.Hwnd: " A_ScriptHwnd)
		PrintConsole( A_LineNumber,  A_ThisFunc, "Process Name: " ProcessGetName(WinGetPID(A_ScriptHwnd)))
		PrintConsole( A_LineNumber,  A_ThisFunc, "Finding PIDs and HwndID for " xi_exe.Get(Server))
	}
	
	pids := WinGetList()
	for this_pid in pids
	{
		;WinActivate this_id
		pid_class := WinGetClass(this_pid)
		pid_title := WinGetTitle(this_pid)
		if(Debug_On.Get(1) = 1){
			PrintConsole( A_LineNumber,  A_ThisFunc," ")
			PrintConsole( A_LineNumber,  A_ThisFunc,"PID: " this_pid)
			PrintConsole( A_LineNumber,  A_ThisFunc,"ClassID: " pid_class)
			PrintConsole( A_LineNumber,  A_ThisFunc,"Win Title Name: " pid_title)
			PrintConsole( A_LineNumber,  A_ThisFunc," ")
		}
		if (InStr(pid_class, "ConsoleWindowClass") > 0 or InStr(pid_class, "AutoHotkey") > 0){
		; do not remove this if statment if you plan on run script this is the name for the console when testing
			if (Server = 7 and InStr(pid_title, "AutoHotKey64.exe") > 0){
				xi_pids.RemoveAt(6)
				xi_hwnd.RemoveAt(6)
				xi_pids.InsertAt(6, WinGetPID(this_pid))
				xi_hwnd.InsertAt(6, WinGetID(this_pid))
				break
			}
			
			if (Server = 7 and InStr(pid_title, xi_exe.Get(6)) > 0){
				xi_pids.RemoveAt(6)
				xi_hwnd.RemoveAt(6)
				xi_pids.InsertAt(6, WinGetPID(this_pid))
				xi_hwnd.InsertAt(6, WinGetID(this_pid))
				break
			}
			
			if (Server = 2 and InStr(pid_title, "world-server") > 0){
				xi_pids.RemoveAt(2)
				xi_hwnd.RemoveAt(2)
				xi_pids.InsertAt(2, WinGetPID(this_pid))
				xi_hwnd.InsertAt(2, WinGetID(this_pid))
				break
			}
			
		}
		
		
		if (InStr(pid_title, xi_exe.Get(Server)) > 0){
		
			if (Server = 5){
				xi_pids.RemoveAt(Server)
				xi_hwnd.RemoveAt(Server)
				xi_pids.InsertAt(Server, WinGetPID(this_pid))
				xi_hwnd.InsertAt(Server, WinGetID(this_pid))
				break
			}
			if (Server < 5){
				xi_pids.RemoveAt(Server)
				xi_hwnd.RemoveAt(Server)
				xi_pids.InsertAt(Server, WinGetPID(this_pid))
				xi_hwnd.InsertAt(Server, WinGetID(this_pid))
				break
			}
		}
		
	
	}
	if (Server = 7){
		if(xi_pids.Get(6) = 0 or xi_hwnd.Get(6) = 0){
		;	Failed to get PID or HWND
			return
		}
		if(Debug_On.Get(1) = 1){
			PrintConsole( A_LineNumber,  A_ThisFunc, "Updated PIDs and HwndID for " xi_exe.Get(7))
		}
	}
	
	if (Server < 7){
		if(xi_pids.Get(Server) = 0 or xi_hwnd.Get(Server) = 0){
		;	Failed to get PID or HWND
			return
		}
		
		if(Debug_On.Get(1) = 1){
			PrintConsole( A_LineNumber,  A_ThisFunc, "Updated PIDs and HwndID for " xi_exe.Get(Server))
		}
	}
	
}




Print_XI_Array_Info(*)
{
	if(Debug_On.Get(1) = 1){
		PrintConsole( A_LineNumber,  A_ThisFunc, "ConsoleID: " 1 " ---- Pid: " xi_pids.Get(1) " --- Hwnd: " xi_hwnd.Get(1) " --- Name: " xi_exe.Get(1))
		PrintConsole( A_LineNumber,  A_ThisFunc, "ConsoleID: " 2 " ---- Pid: " xi_pids.get(2) " --- Hwnd: " xi_hwnd.Get(2) " --- Name: " xi_exe.Get(2))	
		PrintConsole( A_LineNumber,  A_ThisFunc, "ConsoleID: " 3 " ---- Pid: " xi_pids.Get(3) " --- Hwnd: " xi_hwnd.Get(3) " --- Name: " xi_exe.Get(3))
		PrintConsole( A_LineNumber,  A_ThisFunc, "ConsoleID: " 4 " ---- Pid: " xi_pids.Get(4) " --- Hwnd: " xi_hwnd.Get(4) " --- Name: " xi_exe.Get(4))
		PrintConsole( A_LineNumber,  A_ThisFunc, "ConsoleID: " 5 " ---- Pid: " xi_pids.Get(5) " --- Hwnd: " xi_hwnd.Get(5) " --- Name: " xi_exe.Get(5))
		PrintConsole( A_LineNumber,  A_ThisFunc, "ConsoleID: " 6 " ---- Pid: " xi_pids.Get(6) " --- Hwnd: " xi_hwnd.Get(6) " --- Name: " xi_exe.Get(6))
	}
}

PrintConsole(line_num, function_info, str_print_console)
{
	; Console output format example of current
	; Date - Time - Function Name -  Line Number - Message to print
	TimeStamp := FormatTime( , "MM/dd/yy  HH:mm:ss")
    line_number_function_name := function_info "  " line_num
	MessageOut := "[" TimeStamp "] [" line_number_function_name "]  " str_print_console
	prnt := RTrim(MessageOut, "`n")
	stdout.WriteLine(prnt)
	stdout.Read(0) ; Flush the write buffer.
	Console_Log_File.Write(MessageOut "`r`n")
}