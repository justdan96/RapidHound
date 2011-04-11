#cs ----------------------------------------------------------------------------

 Program Name: 	 RapidHound
 Author:         Daniel J. Bryant

 RapidHound searches FilesTube using the FilesTube API, and checks any search
 listings to see if the links it has returned are dead or not. It only displays
 links that are available, where the file has not been removed.

#ce ----------------------------------------------------------------------------

; Script Start - Add your code below here

#include <Inet.au3>
#include <Array.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#Include <GuiListView.au3>
#include <ListViewConstants.au3>
#include <WindowsConstants.au3>

#Region ### START Koda GUI section ### Form=d:\obi-w00t\code\rapidhound\frmrapidhound.kxf
$frmRapidHound = GUICreate("RapidHound", 826, 443, 197, 137)
$edtLinks = GUICtrlCreateEdit("", 8, 312, 809, 121)
GUICtrlSetData(-1, "")
$edtSearch = GUICtrlCreateInput("Search...", 8, 8, 601, 21)
$cboExts = GUICtrlCreateCombo("", 624, 8, 97, 24)
GUICtrlSetData(-1, "avi|mkv|rar|zip")
$btnSearch = GUICtrlCreateButton("Search", 736, 8, 81, 25, $WS_GROUP)
$lsvLinks = GUICtrlCreateListView("Direct URL|FilesTube URL", 8, 40, 809, 241)
GUICtrlSendMsg(-1, $LVM_SETCOLUMNWIDTH, 0, 400)
GUICtrlSendMsg(-1, $LVM_SETCOLUMNWIDTH, 1, 400)
$btnDirect = GUICtrlCreateButton("Visit Direct URL", 16, 288, 377, 17, $WS_GROUP)
$btnFT = GUICtrlCreateButton("Visit FilesTube URL", 424, 288, 385, 17, $WS_GROUP)
GUISetState(@SW_SHOW)
#EndRegion ### END Koda GUI section ###

$s_Search = ''
$s_Ext = ''
$s_Key = '3b2fca61ab1c94cb8f791734771ff998'
; hosting is an undocumented feature, but it works. The list of providers and the number they translate to is in Providers.ini
$s_Request = 'http://api.filestube.com/?key=' & $s_Key & '&phrase=' & $s_Search & '&sort=da&extension=' & $s_Ext & '&hosting=1'

$s_NotAvailableTest = 'File no longer available</h2>'
$s_FindURLs = '\<address\>([^<]+)\<\/address\>'
$s_URLTest = '<iframe style="width: 99%;height:80%;margin:0 auto;border:1px solid grey;" src="([^"]+)"'

While 1
	$nMsg = GUIGetMsg()
	Switch $nMsg
		Case $GUI_EVENT_CLOSE
			Exit
		Case $btnDirect
			If _GUICtrlListView_GetSelectedCount($lsvLinks) = 1 Then
				$i_Selected = Int(_GUICtrlListView_GetSelectedIndices($lsvLinks, False))
				;ConsoleWrite('"' & _GUICtrlListView_GetItemText($lsvLinks, $i_Selected) & '"' & @CRLF)
				;Run(@comspec & ' /c start "" "' & _GUICtrlListView_GetItemText($lsvLinks, $i_Selected) & '"','',@sw_hide)
				ShellExecute(_GUICtrlListView_GetItemText($lsvLinks, $i_Selected))
			EndIf
		Case $btnFT
			If _GUICtrlListView_GetSelectedCount($lsvLinks) = 1 Then
				$i_Selected = Int(_GUICtrlListView_GetSelectedIndices($lsvLinks, False))
				;ConsoleWrite('"' & _GUICtrlListView_GetItemText($lsvLinks, $i_Selected,1) & '"' & @CRLF)
				;Run(@comspec & ' /c start "" "' & _GUICtrlListView_GetItemText($lsvLinks, $i_Selected,1) & '"','',@sw_hide)
				ShellExecute(_GUICtrlListView_GetItemText($lsvLinks, $i_Selected,1))
			EndIf
		Case $btnSearch
			$s_Search = _URIEncode(GUICtrlRead($edtSearch))
			$s_Ext = GUICtrlRead($cboExts)
			; Make sure we have a valid search
			If StringLen($s_Ext) = 3 And StringLen($s_Search) > 0 Then
				ConsoleWrite($s_Search & @CRLF)
				; First page, and no links
				$i_Page = 1
				$s_Links = ""
				Do
					; Set up our API request URI, perform the request
					$s_Request = 'http://api.filestube.com/?key=' & $s_Key & '&phrase=' & $s_Search & '&sort=da' & '&extension=' & $s_Ext & '&hosting=1' & '&page=' & $i_Page
					$s_Response = _INetGetSource($s_Request)
					$ai_TotalLinks = StringRegExp($s_Response, '<hitsTotal>([^<]+)</hitsTotal>', 3)
					If Not IsArray($ai_TotalLinks) Then
						MsgBox(0,"", $s_Response)
						ExitLoop
					EndIf
					$ai_TotalLinks[0] = Int($ai_TotalLinks[0])
					$i_Links = 0
					GUICtrlSetData($edtLinks, "")
					GUICtrlSetData($edtLinks, "Performing search (page " & $i_Page & ")..." & @CRLF)

					If Not StringInStr($s_Response,'<hasResults>0</hasResults>') Then
						; Array of URLs
						$as_URLs = StringRegExp($s_Response, $s_FindURLs, 3)

						GUICtrlSetData($edtLinks, GUICtrlRead($edtLinks) & "Gathering links..." & @CRLF)

						; We have an array of URLs
						If IsArray($as_URLs) Then
							$i_Links += UBound($as_URLs)
							; Loop through the URL array
							For $i = 0 to UBound($as_URLs)-1
								ConsoleWrite("URL = " & $as_URLs[$i] & @CRLF)
								; Get the filestube.com/12178247284274/go.html URL
								$s_2ndResponse = _INetGetSource($as_URLs[$i])
								; If the link is listed on the FilesTube page is available, get the real download link
								If Not StringInStr($s_2ndResponse, $s_NotAvailableTest) Then
									GUICtrlSetData($edtLinks, GUICtrlRead($edtLinks) & "Recovering direct links..." & @CRLF)
									ConsoleWrite("AVA  = " & $as_URLs[$i] & " is available." & @CRLF)
									$as_RealURLs = StringRegExp($s_2ndResponse, $s_URLTest, 3)
									; Gather the direct RS link from the go.html page
									If IsArray($as_RealURLs) Then
										GUICtrlSetData($edtLinks, GUICtrlRead($edtLinks) & "Checking direct links..." & @CRLF)
										; Check if the link is dead or not - the first 20 chars on the page will be 'ERROR: File deleted' if the link is dead
										If StringLeft(_INetGetSource($as_RealURLs[0]),20) <> 'ERROR: File deleted ' Then
											; The link is not dead, add it to the list of URLs
											ConsoleWrite("DIR = " & $as_RealURLs[0] & " link is alive" & @CRLF)
											$s_Links &= $as_RealURLs[0] & @CRLF
											_GUICtrlListView_AddItem($lsvLinks, $as_RealURLs[0])
											_GUICtrlListView_AddSubItem($lsvLinks,_GUICtrlListView_GetItemCount($lsvLinks)-1, StringTrimRight($as_URLs[$i], 7) & "details.html",1)
										Else
											; Link is dead
											ConsoleWrite("DED = " & $as_RealURLs[0] & " link is dead" & @CRLF)
										EndIf
									EndIf
								Else
									; Link is not available
									ConsoleWrite("NAV  = " & $as_URLs[$i] & " not available." & @CRLF)
								EndIf
							Next
							$i_Page += 1
						EndIf
					Else
						ConsoleWrite("No results" & @CRLF)
					EndIf
					ConsoleWrite("Finished!" & @CRLF)
					; Keep looping until we have some links to show, or we run out of results
				Until StringLen($s_Links) > 5 Or StringInStr($s_Response,'<hasResults>0</hasResults>') Or $i_Links >= $ai_TotalLinks[0]
				GUICtrlSetData($edtLinks, "")
				GUICtrlSetData($edtLinks, $s_Links)
			EndIf
	EndSwitch
WEnd

; Code from here: 	http://www.autoitscript.com/forum/topic/95850-url-encoding/page__view__findpost__p__689060
; By: 				ProgAndy
Func _URIEncode($sData)
    ; Prog@ndy
    Local $aData = StringSplit(BinaryToString(StringToBinary($sData,4),1),"")
    Local $nChar
    $sData=""
    For $i = 1 To $aData[0]
        ConsoleWrite($aData[$i] & @CRLF)
        $nChar = Asc($aData[$i])
        Switch $nChar
			Case 45
				ConsoleWrite("- to  " & @CRLF)
				$sData &= "%20"
			Case 46
				ConsoleWrite("." & @CRLF)
				$sData &= $aData[$i]
			Case 48 To 57
				ConsoleWrite("num" & @CRLF)
				$sData &= $aData[$i]
			Case 65 To 90, 95, 97 To 122, 126
                $sData &= $aData[$i]
            Case Else
                $sData &= "%" & Hex($nChar,2)
        EndSwitch
    Next
    Return $sData
EndFunc
