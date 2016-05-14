#$language = "VBScript"
#$interface = "1.0"

' Script: RunAndCompareCommands.vbs
' Author: Krzysztof Zaleski (cshyshtof@gmail.com)
' Date:   2016.05.14
' Ver:    1.0
' Desc:   In short, the main idea of this script is to collect an output from some show
'         commands, which you run before, and after you apply major changes to your
'         network device. Then, both files are compared using freeware tool ExamDiff.
'         You can then not only compare running configs to verify if all planned commands
'         were applied, but also check status of protocols and relationship to other
'         devices. So, you can make sure, your network works as expected, and you
'         suddenly do not miss half of your routes because your filtering is wrong.
'
'         How the script works:
'
'         I. The script is run before you apply your planned changes:
'          1. Lets you choose device type, which defines commands to execute
'          2. Stops logging (if enabled) for current session (remembers old file)
'          3. Creates new file named <hostname>_<date>_before.txt
'          4. Writes output from show commands, specific to choosen device type
'          5. Recovers old logging file, so you can log your change process
'         II. The script is run after you finish the planned change:
'          1. Lets you choose device type (make sure you select the same type as before)
'          2. Stops logging (if enabled) for current session (remembers old file)
'          3. Creates new file named <hostname>_<date>_after.txt
'          4. Writes output from show commands, specific to choosen device type
'          5. Recovers old logging file
'          6. Runs ExamDiff to compare _before and _after outputs
'
' Prerequisites:
' - ExamDiff tool: http://www.prestosoft.com/edp_examdiff.asp#download

' Issues: 1.0
' - After calling IE window, it is not brought in front (focus on SecureCRT) 

'=========================================================================
' Editable variables
'=========================================================================

' Directory, where _before i _after logs will be stored
Const strLogPath = "h:\Development\SecureCRT\Logs"

' Directory, where text files with defined show commands are stored.
' Files should be named: RunAndCompareCommands-<device type>.txt
' <device-type> is defined inside a web form (see strHtmlBox variable)
Const strCommandsPath = "h:\Development\SecureCRT\RunAndCompareCommands"

' Full path to ExamDiff.exe file
Const strDiffFile = "C:\Program Files (x86)\ExamDiff\ExamDiff.exe"

' Display debugging messages (False | True)
Const blnDebug = False

'=========================================================================
' DO NOE EDIT BELOW, UNLESS YOU KNOW WHAT YOU ARE DOING !!!
'=========================================================================

Const ICON_STOP = 16
Const ICON_QUESTION = 32
Const ICON_WARN = 48
Const ICON_INFO= 64

Const BUTTON_OK = 0
Const BUTTON_CANCEL = 1
Const BUTTON_ABORTRETRYIGNORE = 2
Const BUTTON_YESNOCANCEL = 3
Const BUTTON_YESNO = 4
Const BUTTON_RETRYCANCEL = 5

Const DEFBUTTON1 = 0   ' First button is default
Const DEFBUTTON2 = 256 ' Second button is default
Const DEFBUTTON3 = 512 ' Third button is default

Const IDOK = 1
Const IDCANCEL = 2
Const IDABORT = 3
Const IDRETRY = 4
Const IDIGNORE = 5
Const IDYES = 6
Const IDNO = 7


Sub Main
    Dim strHostname
    Dim strGuessHostname
    Dim intConfirm
    Dim objFile
    Dim strCommandsLine
    Dim blnWaitFor
    Dim blnAfter
    Dim strMatch
    Dim objIE
    Dim strDiffFileCmd
    Dim strDevType
    Dim strLogFileAfter
    Dim strLogFileBefore
    Dim strLogFile
    Dim strLogFileOrig
    Dim strCommandsFile
    Dim strHtmlBox
    Dim strDevTypeHtml

    crt.Screen.Synchronous = True
    Set objFile = CreateObject("Scripting.FileSystemObject")
    
    If (Not objFile.FolderExists(strCommandsPath)) Then
        intConfirm = crt.Dialog.MessageBox( _
            "Directory with files containing show commands does not exist:" & vbcrlf & _
            "[" & strCommandsPath & "]", "Error", ICON_STOP Or BUTTON_OK)
        Exit Sub
    End If
    
    If (Not objFile.FolderExists(strLogPath)) Then
        intConfirm = crt.Dialog.MessageBox( _
            "Log dir does not exist:" & vbcrlf & _
            "[" & strLogPath & "]", "Error", ICON_STOP Or BUTTON_OK)
        Exit Sub
    End If

    If (Not crt.Session.Connected) Then
        intConfirm = crt.Dialog.MessageBox("You must login to device first", "Error", ICON_STOP Or BUTTON_OK)
        Exit Sub
    End If

    Crt.Screen.IgnoreEscape = True

    Crt.Screen.Send vbcr    
    strGuessHostname = crt.Screen.ReadString("#")

    Set objRegexp = new RegExp
    objRegexp.Pattern = "\s+(.+)$"
    
    If objRegexp.Test(strGuessHostname) = True Then
        Set strMatches = objRegexp.Execute(strGuessHostname)
        For Each strMatch In strMatches
            strGuessHostname = strMatch.SubMatches(0)
        Next
    Else
        intConfirm = crt.Dialog.MessageBox("Problem guessing hostname", "Error", ICON_STOP Or BUTTON_OK)
        Exit Sub
    End If

    ' You are asked to confirm the hostname, as some hostnames are not dir-friendly (ex. ASA cluster)
    strHostname = crt.Dialog.Prompt("Confirm hostname: ", "Hostname", strGuessHostname)
        
    If strHostname = "" Then
        intConfirm = crt.Dialog.MessageBox ("You must specify a hostname", "Error", ICON_STOP Or BUTTON_OK)
        Exit Sub
    End If

    Set objIE = CreateObject("InternetExplorer.Application")
    objIE.Offline = True
    objIE.navigate "about:blank"

    Do
        crt.Sleep 100
    Loop While objIE.Busy

    strHtmlBox = _
        "<br/>" & _
        "<p style='font-family: Verdana; color: navy; font-weight:bold; font-size:0.8em; text-align:center'>Choose device type:</p>" & _
        "<div style='font-family: Verdana; font-size: 0.7em; color: navy; text-align:center'>" & _
        "<hr style='height:1'/>" & _
        "<button name='Router' style='border: 1px solid grey; margin: 2px; padding: 2px; background-color: #EEEEEE;' " & _
        " Onclick='document.all(""ButtonHandler"").value=""Router""'>Router</button><br/><br/>" & _
        "<button name='Switch' style='border: 1px solid grey; margin: 2px; padding: 2px; background-color: #EEEEEE;' " & _
        " Onclick='document.all(""ButtonHandler"").value=""Switch""'>Switch</button><br/><br/>" & _
        "<button name='Firewall' style='border: 1px solid grey; margin: 2px; padding: 2px; background-color: #EEEEEE;' " & _
        " Onclick='document.all(""ButtonHandler"").value=""Firewall""'>Firewall</button><br/><br/>" & _
        "<button name='Nexus' style='border: 1px solid grey; margin: 2px; padding: 2px; background-color: #EEEEEE;' " & _
        " Onclick='document.all(""ButtonHandler"").value=""Nexus""'>Nexus</button><br/><br/>" & _
        "<hr style='height:1'/>" & _
        "</div>" & _
        "<input name='ButtonHandler' value='' type='hidden'/>"
     
    objIE.Document.Body.innerHTML = strHTMLBox
    objIE.document.Title = "Device type"
    objIE.MenuBar = False
    objIE.Resizable = False
    objIE.StatusBar = False
    objIE.AddressBar = False
    objIE.Toolbar = False
    objIE.Height = 320
    objIE.Width = 300
    objIE.Visible = True

    Do
        crt.Sleep 100
    Loop While objIE.Busy

    Dim strTitle
    strTitle = objIE.document.Title & " - Internet Explorer"

    Set objShell = CreateObject("WScript.Shell")
    objShell.AppActivate strTitle

    Do
        ' Check if Alt+F4 or 'X' was pressed
        On Error Resume Next
            Err.Clear
            strNothing = objIE.Document.All("ButtonHandler").Value
            If Err.Number <> 0 Then
                intConfirm = crt.Dialog.MessageBox ("Script cancelled", "Cancel", ICON_STOP Or BUTTON_OK)
                Exit Sub
            End If
        On Error Goto 0
        
        Select Case objIE.Document.All("ButtonHandler").Value
            Case "Cancel"
                g_objIE.quit
                Exit Sub
                
            Case "Router"
                objIE.quit
                strDevType = "Router"
                Exit Do

            Case "Switch"
                objIE.quit
                strDevType = "Switch"
                Exit Do

            Case "Firewall"
                objIE.quit
                strDevType = "Firewall"
                Exit Do              

            Case "Nexus"
                objIE.quit
                strDevType = "Nexus"
                Exit Do 
        End Select
        crt.Sleep 100
    Loop

    strCommandsFile = strCommandsPath + "\RunAndCompareCommands-" + strDevType + ".txt"

    If (blnDebug) Then
        intConfirm = crt.Dialog.MessageBox("Commands file:" & vbcrlf & "[" & strCommandsFile & "]", "DEBUG", ICON_INFO Or BUTTON_OK)
    End If
    
    If (Not objFile.FileExists(strCommandsFile)) Then
        intConfirm = crt.Dialog.MessageBox( _
            "File containing show commands does not exist:" & vbcrlf & _
            "[" & strCommandsFile & "]", "Error", ICON_STOP Or BUTTON_OK)
        Exit Sub
    End If

    strLogFileBefore = strLogPath + "\" + strHostname + "_" + CStr(Date) + "_before.txt"
    strLogFileAfter = strLogPath + "\" + strHostname + "_" + CStr(Date) + "_after.txt"

    If (blnDebug) Then
        intConfirm = crt.Dialog.MessageBox( _
            "Before file:" & vbcrlf & "[" & strLogFileBefore & "]" & vbcrlf & vbcrlf & _
            "After file:" & vbcrlf & "[" & strLogFileAfter & "]", "DEBUG", ICON_INFO Or BUTTON_OK)
    End If
 
    If (Not objFile.FileExists(strLogFileBefore)) Then
        If (blnDebug) Then
            intConfirm = crt.Dialog.MessageBox("Running commands before making changes", "DEBUG", ICON_INFO Or BUTTON_OK)
        End If
        strLogFile = strLogFileBefore
        blnAfter = false
    Else
        If (Not objFile.FileExists(strLogFileAfter)) Then
            If (blnDebug) Then
                intConfirm = crt.Dialog.MessageBox("Running commands after changes are done", "DEBUG", ICON_INFO Or BUTTON_OK)
            End If
        Else
            intConfirm = crt.Dialog.MessageBox("Log file (after) exists, overwrite?" & vbcrlf & vbcrlf & _
                "[" & strLogFileAfter & "]", "File exists", ICON_QUESTION Or BUTTON_YESNO)
            If (intConfirm = IDNO) Then
                Exit Sub
            End If
        End If
        strLogFile = strLogFileAfter
        blnAfter = true
    End If
    
    If (blnDebug) Then
        intConfirm = crt.Dialog.MessageBox("The output from commands will be written into file:" & vbcrlf & _
            "[" & strLogFile & "]", "DEBUG", ICON_INFO Or BUTTON_OK)
    End If
    
    If (Crt.Session.Logging = True) Then
        strLogFileOrig = crt.Session.LogFileName

        If (blnDebug) Then
            intConfirm = crt.Dialog.MessageBox("Old log file:" & vbcrlf & _
                "[" & strLogFileOrig & "]", "DEBUG", ICON_INFO Or BUTTON_OK)
        End If
        crt.Session.Log False
    End If

    crt.Session.LogFileName = strLogFile
    crt.Session.Log True, False

    Set objCommandsFile = CreateObject("Scripting.FileSystemObject")
    Set hndCommandsFile = objCommandsFile.OpenTextFile(strCommandsFile)
    
    While Not hndCommandsFile.AtEndOfStream
        strCommandsLine = hndCommandsFile.ReadLine
        
        If (blnDebug) Then
            intConfirm = crt.Dialog.MessageBox("Command:" & "[" & strCommandsLine & "]", "DEBUG", ICON_INFO Or BUTTON_OK)
        End If
        
        crt.Screen.Send strCommandsLine & vbcr
        blnWaitFor = crt.Screen.WaitForString(strHostname & "#", intTimeout)
    Wend

    hndCommandsFile.Close 
    crt.Session.Log False

    If (strLogFileOrig <> "") Then
        If (blnDebug) Then
            intConfirm = crt.Dialog.MessageBox("Recovered old log file:" & vbcrlf & _
                "[" & strLogFileOrig & "]", "DEBUG", ICON_INFO Or BUTTON_OK)
        End If
        crt.Session.LogFileName = strLogFileOrig
        crt.Session.Log True, True
    End If

    If (blnAfter = true) Then
        strDiffFileCmd = """" + strDiffFile + """ """ + strLogFileBefore + """ """ + strLogFileAfter + """"
        Set shell = CreateObject("WScript.Shell")
        shell.Run strDiffFileCmd
    End If

End Sub
