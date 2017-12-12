#cs
   Auther: Hansen
   Description: Used to get test status ,and download log
   Version: V1.0
   Update history:
	  Date: 2017/08/10
	  version : v1.04
		 1.Add filter combo
		 2.Add copy clipboard sn function
		 3.Solve completed info just search first menu
		 4.Modify automaticlly refresh time to 180s
	  Date: 2017/08/09
	  version : v1.03
		 1.Adjust BMC FW display more info
		 2.Adjust color if running again
	  Date: 2017/08/07
	  version : v1.02
		 1.Add network status notice
		 2.Add combo controller
		 3.Add adjust Transparency function
		 4.Solve a issue that make server service crash
	  Date: 2017/07/26
	  version : v1.01
		 1.Add check new version function
		 2.Add tip message if test failed or completed found
		 3.Add button ssh function
		 4.Beautify GUI
	  Date: 2017/01/12
	  version : v1.0
		 1.initialization

#ce

#include <FTPEx.au3>
#include <GUIConstantsEx.au3>
#include <ListviewConstants.au3>
#include <File.au3>
#Include <GuiListView.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <Clipboard.au3>
#RequireAdmin
Global		$version="v1.04", _
			$date="2017/08/10"

Opt('MustDeclareVars',1)
Opt("TrayOnEventMode",1)
Opt("TrayMenuMode",11)
Opt("GUIOnEventMode", 1)
Opt("GUICloseOnESC", 1)

Local $process_list
$process_list=ProcessList("1k_moniter.exe")
;Check only one running process
If $process_list[0][0]>1 Then
   WinSetState("1k moniter "&$version,"",@SW_RESTORE)
   Exit(1)
EndIf
;Update new version
Func _UpdateSelf($sFile, $iDelay = 1, $iResume = 0, $sParm = "")
        Local $CmdFile, $CmdCont
        If NOT FileExists($sFile) Then Return(1)
        $iDelay = Int($iDelay)
        If $iDelay < 1 Then $iDelay = 1
        $CmdCont = 'attrib -r -s -h "' & @ScriptFullPath & '"' & @CRLF _
                & ':loop' & @CRLF _
                & 'ping -n ' & $iDelay + 1 & ' 127.0.0.1 > nul' & @CRLF _
                & 'del "' & @ScriptFullPath & '"' & @CRLF _
                & 'if exist "' & @ScriptFullPath & '" goto loop' & @CRLF _
                & 'move /y "' & $sFile & '" "' & @ScriptFullPath & '"' & @CRLF
        If $iResume Then
                If $sParm = "" Then
                        $CmdCont &= '"' & @ScriptFullPath & '"' & @CRLF
                Else
                        $CmdCont &= '"' & @ScriptFullPath & '" ' & $sParm & @CRLF
                EndIf
        EndIf
        $CmdCont &= 'del %0' & @CRLF
        $CmdFile = _TempFile(@TempDir, "~UPD", ".bat", 4)
        FileWrite($CmdFile, $CmdCont)
        Run($CmdFile, @TempDir, @SW_HIDE)
        Return 1
EndFunc
;Transfer log,status file and command result
Func data_trans()
   Local $host='10.67.222.2',$port=19876,$connect_socket=-1,$save_file,$flag=0,$data_recv,$save_folder,$array
   If Not Ping($host,10000) Then
	  MsgBox(4112,'Warning!',"Can't connect to host("&$host&"),Pls try again later...",2)
   EndIf
   $array=StringSplit($data_snd,'|',1)
   TCPStartup()
   $connect_socket=TCPConnect($host,$port)
   If $connect_socket = -1 Then
	  MsgBox(0,'Warning!',"Error! Pls make sure server side service is running!",3)
	  Return
   EndIf
   TCPSend($connect_socket,$data_snd)
   If $array[1] == "log" Then
	  $save_folder=FileSaveDialog('Save to:',@DesktopDir,"Compressed File(*.zip)",8,$array[2]&'.zip')
	  If $save_folder == '' Then
		 Return
	  EndIf
	  $save_file=FileOpen($save_folder,17)
	  MsgBox(0,'Warning!','Start transfer file,Pls wait more than 3s to transfer file!!',2)
	  Do
		 $data_recv=TCPRecv($connect_socket,1024*1024)
		 If $data_recv <> "" Then
			   $flag=1
		 EndIf
		 FileWrite($save_file,$data_recv)
	  Until $data_recv == "" And $flag = 1
	  FileClose($save_file)
   ;process command line
   ElseIf $array[1] == "stop" Then
	  Sleep(50)
	  load_ftp_log()
	  $data_recv=TCPRecv($connect_socket,12)
	  MsgBox(0,'Warning','Stop '&$array[2]&$data_recv,1)
   ElseIf $array[1] == "continue" Then
	  Sleep(50)
	  load_ftp_log()
	  $data_recv=TCPRecv($connect_socket,12)
	  MsgBox(0,'Warning','Continue '&$array[2]&$data_recv,1)
   ElseIf $array[1] == "uuid_on" Then
	  Do
	  $data_recv=TCPRecv($connect_socket,12)
	  Until $data_recv <> ""
	  MsgBox(0,'Warning',$array[1]&' '&$array[3]&':'&$array[2]&$data_recv,1)
   ElseIf $array[1] == "uuid_off" Then
	  Do
		 $data_recv=TCPRecv($connect_socket,12)
	  Until $data_recv <> ""
	  MsgBox(0,'Warning',$array[1]&' '&$array[3]&':'&$array[2]&$data_recv,1)
   ElseIf $array[1] == "delete" Then
	  Do
		 $data_recv=TCPRecv($connect_socket,12)
	  Until $data_recv <> ""
	  MsgBox(0,'Warning',$array[1]&' '&$array[2]&$data_recv,1)
	  refresh()
   ElseIf $array[1] == "update" Then
	  Do
		 $data_recv=TCPRecv($connect_socket,12)
	  Until $data_recv <> ""
	  TCPShutdown()
	  ;check update
	  If $data_recv == "same" Then
		 Return(0)
	  ElseIf $data_recv == "diff" Then
		 Local $newversion=@TempDir&"\1k_moniter.exe",$return_key
			$return_key=MsgBox(4,'Notice',"find a new version program, Pls make sure update !",3)
			if $return_key == 6 Then
			   MsgBox(0,'','Pls wait 10s to Update !!! Then restart this program !',2)
			   Local $command_send="download|1k_moniter.exe"
			   $array=StringSplit($command_send,'|',1)
			   TCPStartup()
			   $connect_socket=TCPConnect($host,$port)
			   If $connect_socket = -1 Then
				  MsgBox(0,'Warning!',"Error! Pls make sure server side service is running!",2)
				  Return(0)
			   EndIf
			Else
			   Return(0)
			EndIf
		 TCPSend($connect_socket,$command_send)
		 $save_file=FileOpen(@TempDir&'\'&$array[2],18)
		 Do
			;Sleep some time to get completed data
			Sleep(100)
			$data_recv=TCPRecv($connect_socket,1024*4)
			If $data_recv <> "" Then
			   $flag=1
			EndIf
			FileWrite($save_file,$data_recv)
		 Until $data_recv == "" And $flag = 1
		 FileClose($save_file)
		 _UpdateSelf($newversion)
		 Return(1)
	  Else
		 Return(0)
	  EndIf
   Else
	  Do
		 $data_recv=TCPRecv($connect_socket,12)
	  Until $data_recv <> ""
	  MsgBox(0,'Warning',$data_recv,1)
   EndIf
   TCPShutdown()
EndFunc
;Load status file
Func load_ftp_log()
   Local $log_path=@MyDocumentsDir&"\status_log\"
   Global $log_blackwords=@MyDocumentsDir&"\status_log\blackwords"
   Local $host='10.67.222.2',$port=19876,$connect_socket=-1,$save_file,$flag=0,$data_recv,$array,$retry=1
   If Not Ping($host,100) Then
	  Return(0)
   EndIf
   Dim $log_file=["download|status.ini","download|status_swap.ini","download|status_completed.ini","download|blackwords"]
   For $data_snd in $log_file
	  $array=StringSplit($data_snd,'|',1)
	  While True
		 TCPStartup()
		 $connect_socket=TCPConnect($host,$port)
		 If $connect_socket <> -1 Then
			ExitLoop(1)
		 EndIf
		 If $connect_socket == -1 And $retry == 3 Then
			MsgBox(0,'Warning!',"Error! Pls make sure server side service is running!",2)
			Exit(1)
		 EndIf
		 $retry+=1
		 Sleep(500)
	  WEnd
	  TCPSend($connect_socket,$data_snd)
	  $save_file=FileOpen($log_path&$array[2],18)
	  Do
		 ;Sleep some time to get completed data
		 Sleep(100)
		 $data_recv=TCPRecv($connect_socket,1024)
		 If $data_recv <> "" Then
			   $flag=1
		 EndIf
		 FileWrite($save_file,$data_recv)
	  Until $data_recv == "" And $flag = 1
	  FileClose($save_file)
   Next
   TCPShutdown()
   $array=StringSplit($log_file[1],'|',1)
   $file_line=_FileCountLines($log_path&$array[2])
   If $file_line <= 5 And $file_line >0 Then
	  Return(0)
   Else
	  Return(1)
   EndIf
EndFunc
;process status log and add label GUI
Func get_content($log_file)
   Local $i,$i_content,$i_content_swap,$i_status,$error1,$countlines,$flag_ongoing,$a=0,$flag_run=0
   Global $server_sn,$server_run,$item[$file_line/5+20],$ii=0,$flag_item_stop,$flag_stop,$completed_count,$ongoing_count,$stop_count,$i_run
   $countlines = _FileCountLines($log_file)
   If $log_file == $log_path Then
	  $completed_count=0
	  $ongoing_count=0
	  $stop_count=0
	  $server_run=IniReadSectionNames($log_file)
   EndIf
   If $countlines == 0 Then
	  GUICtrlSetData($status_label,$ongoing_count&'/'&$stop_count&'/'&$completed_count)
	  If $log_file == $log_path_completed And $flag_first == 0 Then $flag_first=$flag_first+1
	  Return(1)
   EndIf
   $server_sn=IniReadSectionNames($log_file)
   For $i In $server_sn
	  $flag_ongoing=0
	  $flag_stop=0
	  $flag_item_stop=0
	  If $i==$server_sn[0] Then ContinueLoop
	  $i_content=IniReadSection($log_file,$i)
	  If $log_file == $log_path Then
		 $i_content_swap=IniReadSection($log_path_swap,$i)
		 $error1=@error
		 ;here can't write with
		 If $error1=0 Then
			;Ongoing
			If $i_content[1][1] <> $i_content_swap[1][1] Then
			   $flag_ongoing=1
			;Stoped
			ElseIf $i_content[1][1]=$i_content_swap[1][1] Then
			   $flag_stop=1
			EndIf
		 EndIf
	  EndIf
	  If $i_content[1][1] == 1001 Or $log_file == $log_path_completed Then
		 $i_status="Completed"
		 $completed_count+=1
		 $i=StringMid($i_content[7][1],5,12)
	  ElseIf $error1==1 OR $flag_ongoing==1  Then
		 $i_status="Ongoing"
		 $ongoing_count+=1
	  ElseIf $i_content[1][1] <> 1001 AND $flag_stop=1 Then
		 $i_status="Stoped"
		 $stop_count+=1
	  Else
		 $i_status="Error"
	  EndIf
	  If GUICtrlRead($combo_choose) == "All" Or GUICtrlRead($combo_choose) == $i_status Then
		 If $choose_sn_flag == "" Then
			$item[$ii]=GUICtrlCreateListViewItem($i&'|'&$i_content[4][1]&'|'&$i_content[8][1]&'|'&$i_content[2][1]&'|'&$i_content[3][1]&'|'&$i_content[6][1]&'|'&' '&$i_content[5][1]&'|'&$i_content[1][1]&'|'&$i_status&'|'&$i_content[7][1],$list_view)
		 ElseIf $choose_sn_flag == $i Then
			$item[$ii]=GUICtrlCreateListViewItem($i&'|'&$i_content[4][1]&'|'&$i_content[8][1]&'|'&$i_content[2][1]&'|'&$i_content[3][1]&'|'&$i_content[6][1]&'|'&' '&$i_content[5][1]&'|'&$i_content[1][1]&'|'&$i_status&'|'&$i_content[7][1],$list_view)
		 Else
			ContinueLoop
		 EndIf
		 $flag_item_stop=0
		 If $flag_first <> 0 Then
			For $item_stop In $item_stop_total
			   If $item_stop == $i_content[7][1] Then
				  $flag_item_stop=1
				  ExitLoop
			   EndIf
			Next
		 EndIf
		 If $i_status == "Stoped" Then
			GUICtrlSetColor($item[$ii],0x00FF0000)
			If $flag_first <> 0 And $flag_item_stop == 0 Then
			   TrayTip("Notice",$i&" have "&$i_status,10,1)
			   $item_stop_total[$iiii]=$i_content[7][1]
			   $iiii+=1
			EndIf
			If $flag_first == 0 Then
			   $item_stop_total[$iiii]=$i_content[7][1]
			   $iiii+=1
			EndIf
		 ElseIf $i_status == "Completed" Then
			$flag_run=0
			For $i_run In $server_run
			   If $i_run == $i Then
				  GUICtrlSetColor($item[$ii],0x550000FF)
				  $flag_run=1
				  ExitLoop
			   EndIf
			Next
			If $flag_run == 0 Then
			   GUICtrlSetColor($item[$ii],0x0000FF40)
			EndIf
			If $flag_first <> 0 And $flag_item_stop == 0 Then
			   TrayTip("Notice",$i&" have completed!",10,1)
			   $item_stop_total[$iiii]=$i_content[7][1]
			   $iiii+=1
			EndIf
			If $flag_first == 0 Then
			   $item_stop_total[$iiii]=$i_content[7][1]
			   $iiii+=1
			EndIf
		 EndIf
		 $ii+=1
	  EndIf
   Next
   If $log_file == $log_path_completed Then
	  GUICtrlSetData($status_label,$ongoing_count&'/'&$stop_count&'/'&$completed_count)
   EndIf
   If $log_file == $log_path_completed And $flag_first == 0 Then $flag_first=$flag_first+1
EndFunc
;Close button function
Func closeclicked()
   exit
EndFunc
;Refresh manually button function
Func refresh()
   Local $return_key=0,$cco=0
   GUICtrlSetData($progressbar,0)
    _GUICtrlListView_DeleteAllItems($list_view)
   Do
	  $return_key=load_ftp_log()
	  $cco=$cco+1
   Until $return_key == 1 Or $cco == 5
   If $cco == 5 Or $return_key == 0 Then
	  MsgBox(0,'Warning！','Load status files damaged! Pls retry later !',2)
	  Exit(0)
   EndIf
   get_content($log_path)
   get_content($log_path_completed)
   $iii=600
   $choose_sn_flag=""
EndFunc
;Download button function
Func download()
   Local $choose_sn
   Global $data_snd,$choose_folder
   $choose_sn=GUICtrlRead(GUICtrlRead($list_view))
   If $choose_sn == 0 Then
	  MsgBox(0,'Warning!','No item be choosed!',3)
   Else
	  $choose_folder=StringSplit($choose_sn,'|')
	  $data_snd='log|'&$choose_folder[10]
	  data_trans()
   EndIf
EndFunc
;Stop button function
Func stop_test()
   Local $choose_sn
   Global $data_snd,$choose_folder
   $choose_sn=GUICtrlRead(GUICtrlRead($list_view))
   If $choose_sn == 0 Then
	  MsgBox(0,'Warning!','No item be choosed!',3)
   Else
	  $choose_folder=StringSplit($choose_sn,'|')
	  $data_snd='stop|'&$choose_folder[10]
	  data_trans()
   EndIf
EndFunc
;Continue button function
Func continue_test()
   Local $choose_sn
   Global $data_snd,$choose_folder
   $choose_sn=GUICtrlRead(GUICtrlRead($list_view))
   If $choose_sn == 0 Then
	  MsgBox(0,'Warning!','No item be choosed!',3)
   Else
	  $choose_folder=StringSplit($choose_sn,'|')
	  $data_snd='continue|'&$choose_folder[10]
	  data_trans()
   EndIf
EndFunc
;About button function
Func About()
   MsgBox(0,'About 1k_moniter :','Author : Hansen' _
			   &@LF&'Version : '&$version _
			   &@LF&'Date : '&$date _
			   &@LF&'Description : 1k_moniter is a tool to moniter 1k warmreboot and AC power cycles test' _
			   &@LF&'Button list:' _
			   &@LF&'Refresh		--	fresh status list' _
			   &@LF&'Download	--	download test log for your choose server' _
			   &@LF&'Stop		--	will make the server you choosed stop test' _
			   &@LF&'Continue		--	will make the stoped server test continue' _
			   &@LF&'Blacklist		-- 	black list that servers do not allow to run' _
			   &@LF&'UUID On		-- 	Light on UUID LED' _
			   &@LF&'UUID Off		-- 	Light OFF UUID LED' _
			   &@LF&'Delete		-- 	Delete stoped or completed log' _
			   &@LF&'SSH		--	Open Putty and connect to HOST' _
			   &@LF&'Update history :' _
			   &@LF&'	Date: '&$date _
			   &@LF&'	version : '&$version&':' _
			   &@LF&'		1.Add filter combo' _
			   &@LF&'		2.Add copy clipboard sn function' _
			   &@LF&'		3.Solve completed info just search first menu' _
			   &@LF&'		4.Modify automaticlly refresh time to 180s' _
			   &@LF&'	Date: 2017/08/09' _
			   &@LF&'	version : v1.03:' _
			   &@LF&'		1.Adjust BMC FW display more info' _
			   &@LF&'		2.Adjust color if running again' _
			   &@LF&'	Date: 2017/08/07' _
			   &@LF&'	version : v1.02:' _
			   &@LF&'		1.Add network status notice' _
			   &@LF&'		2.Add combo controller' _
			   &@LF&'		3.Add adjust Transparency function' _
			   &@LF&'		4.Solve a issue that make server service crash' _
			   &@LF&'	Date : 2017/07/26' _
			   &@LF&'	version : v1.01:' _
			   &@LF&'		1.Add check new version function' _
			   &@LF&'		2.add tip message if test failed or completed found' _
			   &@LF&'		3.Add button ssh function' _
			   &@LF&'		4.Beautify GUI' _
			   &@LF&'	Date : 2017/01/12' _
			   &@LF&'	version : v1.00' _
			   &@LF&'		1.initialization' _
			   )

EndFunc
;UUID on button function
Func uuid_on()
   Local $choose_sn
   Global $data_snd,$choose_folder
   $choose_sn=GUICtrlRead(GUICtrlRead($list_view))
   If $choose_sn == 0 Then
	  MsgBox(0,'Warning!','No item be choosed!',3)
   Else
	  $choose_folder=StringSplit($choose_sn,'|')
	  $data_snd='uuid_on|'&$choose_folder[4]&'|'&$choose_folder[1]
	  data_trans()
   EndIf
EndFunc
;UUID off button function
Func uuid_off()
   Local $choose_sn
   Global $data_snd,$choose_folder
   $choose_sn=GUICtrlRead(GUICtrlRead($list_view))
   If $choose_sn == 0 Then
	  MsgBox(0,'Warning!','No item be choosed!',3)
   Else
	  $choose_folder=StringSplit($choose_sn,'|')
	  $data_snd='uuid_off|'&$choose_folder[4]&'|'&$choose_folder[1]
	  data_trans()
   EndIf
EndFunc
;Blacklist button function
Func Blacklist()
   Local $file,$file_content
   $file=FileOpen($log_blackwords,0)
	  If $file = -1 Then
		 MsgBox(0,"Warning","No blacklist",1)
	  EndIf
   $file_content=FileRead($file)
   MsgBox(0,"Blacklist",$file_content)
   FileClose($file)
EndFunc
;Delete button function
Func delete_complete_log()
   Local $choose_sn
   Global $data_snd,$choose_folder
   $choose_sn=GUICtrlRead(GUICtrlRead($list_view))
   If $choose_sn == 0 Then
	  MsgBox(0,'Warning!','No item be choosed!',3)
   Else
	  $choose_folder=StringSplit($choose_sn,'|')
	  If $choose_folder[9] == "Completed" Or $choose_folder[9] == "Stoped" Then
		 $data_snd='delete|'&$choose_folder[10]&'|'&$choose_folder[9]
		 data_trans()
	  Else
		 MsgBox(0,'','Pls choose a completed or stoped server !',2)
		 Return(1)
	  EndIf
   EndIf
EndFunc
;SSH button function
Func ssh_run()
   Run("C:\Program Files\PuTTY\putty.exe -ssh cpe-pe@10.67.222.2 -pw 111111" )
EndFunc
;Close GUI
Func exit_gui()
   GUIDelete($main_gui)
   Exit
EndFunc
;Transparency_0
Func Transparency_0()
   WinSetTrans($main_gui, "", 0)
   MsgBox(0,'Fuck!','你麻痹呀，調這麽低能瞅着呀！',2)
EndFunc
;Transparency_25
Func Transparency_25()
   WinSetTrans($main_gui, "", 64)
EndFunc
;Transparency_50
Func Transparency_50()
   WinSetTrans($main_gui, "", 128)
EndFunc
;Transparency_75
Func Transparency_75()
   WinSetTrans($main_gui, "", 192)
EndFunc
;Transparency_100
Func Transparency_100()
   WinSetTrans($main_gui, "", 255)
EndFunc
;Transparency_100
Func Transparency_default()
   WinSetTrans($main_gui, "", 220)
EndFunc
Func Keep_top()
   If TrayItemGetText($tray_top) == 'Botton' Then
	  WinSetOnTop($main_gui, "",1)
	  TrayItemSetText($tray_top,'Top')
   ElseIf TrayItemGetText($tray_top) == 'Top' Then
	  WinSetOnTop($main_gui,"",0)
	  TrayItemSetText($tray_top,'Botton')
   Else
	  MsgBox(0,'Warning!','Error!,Exiting...')
   EndIf
EndFunc
Func filter_mark()
   Local $choose_sn
   Global $choose_folder
   $choose_sn=GUICtrlRead(GUICtrlRead($list_view))
   If $choose_sn == 0 Then
	  MsgBox(0,'Warning!','No item be choosed!',3)
   Else
	  $choose_folder=StringSplit($choose_sn,'|')
	  $choose_sn_flag=$choose_folder[1]
	  refresh()
   EndIf
EndFunc
Func copy_sn()
   Local $choose_sn,$return
   Global $choose_folder
   $choose_sn=GUICtrlRead(GUICtrlRead($list_view))
   If $choose_sn == 0 Then
	  MsgBox(0,'Warning!','No item be choosed!',3)
   Else
	  $choose_folder=StringSplit($choose_sn,'|')
	  _ClipBoard_SetData($choose_folder[1],$CF_TEXT)
	  If Not ($return == 0) Then
		 MsgBox(0,'Notice!','Copy to ClipBoard successfully!',1)
	  EndIf
   EndIf
EndFunc
;Main function
Func main()
   Local $tray_about,$tray_setting,$msg,$item_list,$time_label,$refresh_button,$download_log,$stop_test,$continue_test,$about,$UU_on,$UU_off,$blacklist,$cco=0,$return_key,$network_label,$delete_button,$ssh_button,$tray_wintrans,$tray_trans_0,$tray_trans_25,$tray_trans_50,$tray_trans_75,$tray_trans_100,$tray_trans_default,$combo_choose_start,$combo_choose_change
   Global $log_all_path=@MyDocumentsDir&"\status_log",$log_path=@MyDocumentsDir&"\status_log\status.ini",$log_path_swap=@MyDocumentsDir&"\status_log\status_swap.ini",$log_path_completed=@MyDocumentsDir&"\status_log\status_completed.ini",$list_view,$iii
   Local $host='10.67.222.2'
   Global $main_gui,$file_line,$data_snd,$flag_first=0,$flag_stop_total=0,$iiii=0,$item_stop,$status_label,$contextmenu,$ContextMenu0,$ContextMenu1,$ContextMenu2,$ContextMenu3,$ContextMenu4,$ContextMenu5,$progressbar,$tray_top,$combo_choose,$choose_sn_flag=""
   If Not FileExists(@MyDocumentsDir&'\status_log') Then
	  DirCreate(@MyDocumentsDir&'\status_log')
   EndIf
   If Not FileExists('C:\Program Files\PuTTY') Then
	  DirCreate('C:\Program Files\PuTTY')
	  FileInstall("C:\Program Files\PuTTY\putty.exe",'C:\Program Files\PuTTY\putty.exe',1)
   EndIf
   $main_gui=GUICreate("1k moniter "&$version,735,300,-1,-1)
   Transparency_default()
   GUISetFont(10,400,0,"Calibri",$main_gui,2)
   $progressbar = GUICtrlCreateProgress(0, 297, 735, 3,0x01)
   GUICtrlSetTip(-1,"Cycle refresh automaticlly")
   $list_view=GUICtrlCreateListView("           S/N     | Tester|    Mode|    BMC_IP|    10G_IP|  BIOS|   BMC|Count|  Status|Folder ", 2, 2,735, 268,-1,$LVS_EX_FULLROWSELECT+$LVS_EX_HEADERDRAGDROP)
   $contextmenu=GUICtrlCreateContextMenu($list_view)
   $ContextMenu0 = GUICtrlCreateMenuItem("Filter", $ContextMenu,0,0)
   GUICtrlSetOnEvent(-1, "filter_mark")
   $ContextMenu1 = GUICtrlCreateMenuItem("Copy SN", $ContextMenu,1,0)
   GUICtrlSetOnEvent(-1, "copy_sn")
   $ContextMenu2 = GUICtrlCreateMenuItem("Download", $ContextMenu,2,0)
   GUICtrlSetOnEvent(-1, "download")
   $ContextMenu3 = GUICtrlCreateMenuItem("Delete", $ContextMenu,3,0)
   GUICtrlSetOnEvent(-1, "delete_complete_log")
   $ContextMenu4 = GUICtrlCreateMenuItem("UUID On", $ContextMenu,4,0)
   GUICtrlSetOnEvent(-1, "uuid_on")
   $ContextMenu5 = GUICtrlCreateMenuItem("UUID OFF", $ContextMenu,5,0)
   GUICtrlSetOnEvent(-1, "uuid_off")
   $refresh_button=GUICtrlCreateButton("Refresh",5,275,60,20)
   GUICtrlSetTip($refresh_button,"Refresh manualy")
   GUICtrlSetBkColor($refresh_button,0x00CFFAE9)
   GUICtrlSetOnEvent($refresh_button,"refresh")
   $download_log=GUICtrlCreateButton("Download",67,275,66,20)
   GUICtrlSetTip($download_log,"Download log for choose server")
   GUICtrlSetBkColor($download_log,0x00CFFAE9)
   GUICtrlSetOnEvent($download_log,"download")
   $stop_test=GUICtrlCreateButton("Stop",135,275,60,20)
   GUICtrlSetTip($stop_test,"Add server from blacklist that stoped test")
   GUICtrlSetBkColor($stop_test,0x00CFFAE9)
   GUICtrlSetOnEvent($stop_test,"stop_test")
   $continue_test=GUICtrlCreateButton("Continue",200,275,60,20)
   GUICtrlSetTip($continue_test,"Remove server from blacklist that stoped test")
   GUICtrlSetBkColor($continue_test,0x00CFFAE9)
   GUICtrlSetOnEvent($continue_test,"continue_test")
   $blacklist=GUICtrlCreateButton("Blacklist",265,275,60,20)
   GUICtrlSetTip($blacklist,"Servers in blacklist that stoped test")
   GUICtrlSetBkColor($blacklist,0x00CFFAE9)
   GUICtrlSetOnEvent($blacklist,"BlackList")
   $UU_on=GUICtrlCreateButton("UUID On",330,275,60,20)
   GUICtrlSetTip($UU_on,"Turn on UUID LED")
   GUICtrlSetBkColor($UU_on,0x00CFFAE9)
   GUICtrlSetOnEvent($UU_on,"uuid_on")
   $UU_off=GUICtrlCreateButton("UUID Off",395,275,60,20)
   GUICtrlSetTip($UU_off,"Turn off UUID LED")
   GUICtrlSetBkColor($UU_off,0x00CFFAE9)
   GUICtrlSetOnEvent($UU_off,"uuid_off")
   $delete_button=GUICtrlCreateButton("Delete",460,275,60,20)
   GUICtrlSetTip($delete_button,"Delete choose server logs,but this only can delete completed server")
   GUICtrlSetBkColor($delete_button,0x00CFFAE9)
   GUICtrlSetOnEvent($delete_button,"delete_complete_log")
   $ssh_button=GUICtrlCreateButton("SSH",525,275,60,20)
   GUICtrlSetTip($ssh_button,"SSH login bridge to 10G or SOL client")
   GUICtrlSetBkColor($ssh_button,0x00CFFAE9)
   GUICtrlSetOnEvent($ssh_button,"ssh_run")
   $combo_choose=GUICtrlCreateCombo("All",590,275,60,20,$CBS_DROPDOWNLIST+$CBS_AUTOHSCROLL)
   GUICtrlSetFont($combo_choose,8,400,0,"Calibri",2)
   GUICtrlSetData(-1,'Ongoing|Stoped|Completed','All')
   $status_label=GUICtrlCreateLabel('',660,277,45,20)
   GUICtrlSetTip($status_label,"Ongoing/Stoped/Completed")
   $network_label=GUICtrlCreateLabel("",710,280,20,10)
   GUICtrlSetTip($network_label,"Network connection status")
   GUICtrlSetBkColor($network_label,0x000000FF)
   $tray_wintrans=TrayCreateMenu('Transparency')
   $tray_trans_0=TrayCreateItem('0%',$tray_wintrans)
   TrayItemSetOnEvent($tray_trans_0,"Transparency_0")
   $tray_trans_25=TrayCreateItem('25%',$tray_wintrans)
   TrayItemSetOnEvent($tray_trans_25,"Transparency_25")
   $tray_trans_50=TrayCreateItem('50%',$tray_wintrans)
   TrayItemSetOnEvent($tray_trans_50,"Transparency_50")
   $tray_trans_75=TrayCreateItem('75%',$tray_wintrans)
   TrayItemSetOnEvent($tray_trans_75,"Transparency_75")
   $tray_trans_100=TrayCreateItem('100%',$tray_wintrans)
   TrayItemSetOnEvent($tray_trans_100,"Transparency_100")
   $tray_trans_default=TrayCreateItem('Default',$tray_wintrans)
   TrayItemSetOnEvent($tray_trans_default,"Transparency_default")
   $tray_top=TrayCreateItem('Botton')
   TrayItemSetOnEvent($tray_top,"Keep_top")
   $tray_about=TrayCreateItem('About')
   TrayItemSetOnEvent($tray_about,"About")
   $tray_setting=TrayCreateItem('Exit')
   TrayItemSetOnEvent($tray_setting,"exit_gui")
   If Not Ping($host,100) Then
	  MsgBox(4112,'Warning!',"Can't connect to host("&$host&"),Pls try again later...",2)
	  Exit(0)
   EndIf
   Do
	  $return_key=load_ftp_log()
	  $cco=$cco+1
   Until $return_key == 1 Or $cco == 5
   If $cco == 5 Or $return_key == 0 Then
	  MsgBox(0,'Warning！','Load status files damaged! Pls retry later !',2)
	  Exit(0)
   EndIf
   Global $item_stop_total[$file_line]
   get_content($log_path)
   get_content($log_path_completed)
   GUISetOnEvent($GUI_EVENT_CLOSE, "closeclicked")
   GUISetState()
   ;check new version
   $data_snd="update|"&$version
   data_trans()
   $combo_choose_start=GUICtrlRead($combo_choose)
   Do
	  $ii=0
	  $iii=600
	  While $iii>=0
		 $combo_choose_change=GUICtrlRead($combo_choose)
		 If Not ($combo_choose_change == $combo_choose_start) Then
			$combo_choose_start=$combo_choose_change
			refresh()
			ContinueLoop(2)
		 EndIf
		 If Not Ping($host,100) Then
			GUICtrlSetBkColor($network_label,0x00FF0000)
		 Else
			GUICtrlSetBkColor($network_label,0x000000FF)
		 EndIf
		 GUICtrlSetData($progressbar,$iii/600*100)
		 sleep(1000)
		 $iii-=1
	  WEnd
	  _GUICtrlListView_DeleteAllItems($list_view)
	  load_ftp_log()
	  get_content($log_path)
	  get_content($log_path_completed)
   Until GUIGetMsg()=$GUI_EVENT_CLOSE
EndFunc
;Start
main()