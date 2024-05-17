BLOCK-LEVEL ON ERROR UNDO, THROW.

/*
    Purpose:    A class wrapper around Windows 'Powershell', where each instance is it's own 'Powershell'-window/session.
                
                Usage:
                    DEF VAR oPowershell AS CLASS Powershell NO-UNDO.
                    DEF VAR cOutput     AS CHAR NO-UNDO.
                    
                    /* Write input */
                    oPowershell:Write("$num = 224").
                    
                    /* Read output */
                    cOutput = oPowershell:Read().
                    
                    /* Write input */
                    oPowershell:Write("Write-Output $num").
                    
                    /* Read output */
                    cOutput = oPowershell:Read().
                
                The 'Powershell' instance is closed when you manually free the object with 'DELETE-OBJECT oPowershell'
                Or when the object gets out of scope.
                
                'Powershell' startup settings:
                    - '-NonInteractive' startup parameter.       Any prompt for input will result in error since there's no way to input anything with this class.
                    - "$global:Prompt = $null":                  Prompt is set to empty so the outputs only contain the actual output. Can be changed at runtime.
                    - "$ErrorActionPreference = 'Stop'":         Any occured error stops code execution. Can be changed at runtime.
                    - "$ProgressPreference='SilentlyContinue';": 'Powershell' executes the commands, but doesn't display the progress bar. Can be changed at runtime.
*/
CLASS Powershell
    IMPLEMENTS ICommandLineInterpreter:
    
    DEF PRIVATE STREAM stPowershell.
    
    &SCOPED-DEFINE POWERSHELL_EOF     "[char]26"
    &SCOPED-DEFINE POWERSHELL_NEWLINE "~r"
    &SCOPED-DEFINE PROGRESS_EOF       26
    
    CONSTRUCTOR PUBLIC Powershell():
        
        /* Start new 'Powershell' session/stream */
        INPUT-OUTPUT STREAM stPowershell THROUGH VALUE(
            "powershell" +
            " -NonInteractive" /* Start the 'Powershell' in non-interactive mode so the execution won't hang if it's trying to ask user input */
        ) NO-ECHO.
        
        /* Disable prompt */
        PUT STREAM stPowershell UNFORMATTED "$global:Prompt = $null" SKIP.
        
        /* Set 'ErrorActionPreference' to 'Stop' so script execution is stopped on error, instead of continuing */
        PUT STREAM stPowershell UNFORMATTED "$ErrorActionPreference = 'Stop';" SKIP.
        
        /* Set 'ProgressPreference' to 'silentlyContinue' in which 'Powershell' executes the command, but doesn't display the progress bar. */
        PUT STREAM stPowershell UNFORMATTED "$ProgressPreference='SilentlyContinue';" SKIP.
        
        /* Flush startup output */
        THIS-OBJECT:Read().
    END.
    
    DESTRUCTOR Powershell():
        
        /* Close the 'Powershell' session/stream */
        INPUT-OUTPUT STREAM stPowershell CLOSE.
    END.
    
    /*
        Purpose:    Writes new input into the 'Powershell'.
    */
    /* ICommandLineInterpreter */ METHOD PUBLIC VOID Write(i_cInput AS CHAR):
        IF i_cInput = ? THEN UNDO, THROW NEW Progress.Lang.AppError(SUBST("&1: 'i_cInput' is 'UNKNOWN'!", PROGRAM-NAME(1))).
        
        /* Write input */
        PUT STREAM stPowershell UNFORMATTED i_cInput SKIP.
    END.
    
    /*
        Purpose:    Writes new input into the 'Powershell' and reads output as well.
    */
    /* ICommandLineInterpreter */ METHOD PUBLIC CHAR WriteRead(i_cInput AS CHAR):
        
        /* Write input */
        THIS-OBJECT:Write(i_cInput).
        
        /* Read output */
        RETURN THIS-OBJECT:Read().
    END.
    
    /*
        Purpose:    Reads all available output from 'Powershell'.
    */
    /* ICommandLineInterpreter */ METHOD PUBLIC CHAR Read():
        
        DEF VAR cOutputs         AS CHAR NO-UNDO.
        DEF VAR cFilteredOutputs AS CHAR NO-UNDO.
        DEF VAR iLineCount       AS INT NO-UNDO.
        DEF VAR iLine            AS INT NO-UNDO.
        DEF VAR cLine            AS CHAR NO-UNDO.
        
        /* Output 'EOF' */
        PUT STREAM stPowershell UNFORMATTED {&POWERSHELL_EOF} SKIP.
        
        /* Read all output until 'EOF' */
        REPEAT:
            READKEY STREAM stPowershell PAUSE 0.
            
            /* If we reached the 'EOF', stop reading */
            IF LASTKEY = {&PROGRESS_EOF} THEN DO:
                LEAVE.
            END.
            
            cOutputs = cOutputs + CHR(LASTKEY).
        END.
        
        /* Loop all outputs line by line (ignore first 4 lines) */
        iLineCount = NUM-ENTRIES(cOutputs, {&POWERSHELL_NEWLINE}).
        DO iLine = 4 TO iLineCount:
            
            /* Ignore last 4 rows (they're part */
            IF iLine = (iLineCount - 3) THEN LEAVE.
            
            cLine = ENTRY(iLine, cOutputs, {&POWERSHELL_NEWLINE}).
            
            cFilteredOutputs = cFilteredOutputs + cLine.
        END.
        
        RETURN cFilteredOutputs.
    END.
    
END.
