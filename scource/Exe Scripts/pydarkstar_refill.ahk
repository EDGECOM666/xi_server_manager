;---------------------------------------------------------------------------------------------------------------------------------------------------
;	In order for the python scrypt to work propperly we need to give it its own instance I tried to open it from the manager but it does not behave.
;	So I am giving it its own new shiny console and exe.
;---------------------------------------------------------------------------------------------------------------------------------------------------
	
	Settins_ini_exist := FileExist("Settings.ini")
	
	if (StrLen(Settins_ini_exist) = 0){
		;if settings.ini not found exit 
		ExitApp
	}
	
	if(StrLen(Settins_ini_exist) > 0){
		; Get paths for py scripts from Settings.ini
		pydarkstar_bin := IniRead("Settings.ini", "default_paths", "pydarkstar_bin")
		python_anaconda3 := IniRead("Settings.ini", "default_paths", "python_anaconda3")
	
		DllCall("AllocConsole")
		Run A_comspec " /K " python_anaconda3 "Scripts\activate.bat  " python_anaconda3,,,&pid
		GET_PID := ProcessWait(pid, 5.5)
		SendInput "cd /D " pydarkstar_bin "{Enter}"
		SendInput "conda activate pydarkstar{Enter}"
		SendInput ".\refill.py --force{Enter}"
	}
	
	
	

