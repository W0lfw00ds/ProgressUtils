BLOCK-LEVEL ON ERROR UNDO, THROW.

/*
    Purpose:    A class wrapper around Windows 'Command Prompt' (cmd), where each instance is it's own 'CommandPrompt'-window/session.
                
                Usage:
                    DEF VAR oCommandPrompt AS CLASS CommandPrompt NO-UNDO.
                    DEF VAR cOutput        AS CHAR NO-UNDO.
                    
                    /* Write input & read output */
                    oCommandPrompt:Write("$num = 224").
                    cOutput = oCommandPrompt:Read().
                    
                    /* Write input & read output */
                    oCommandPrompt:Write("Write-Output $num").
                    cOutput = oCommandPrompt:Read().
                
                The 'CommandPrompt' instance is closed when you manually free the object with 'DELETE-OBJECT oCommandPrompt'
                Or when the object gets out of scope.
                
                'CommandPrompt' startup settings:
                    - "prompt $NUL": Prompt is set to empty so the outputs only contain the actual output. Can be changed at runtime.
                
                Possible issues and restrictions:
                    - This implementation requires the installation 'Powershell' since it was the only way found to output 'EOF' character
                      in the output with command 'powershell [char]26'. If other solution exists, which doesn't have dependencies to
                      other programs, feel free to update.
*/
CLASS CommandPrompt
    IMPLEMENTS ICommandLineInterpreter:
    
    DEF PRIVATE STREAM stCmd.
    
    &SCOPED-DEFINE COMMANDPROMPT_EOF     "powershell [char]26"
    &SCOPED-DEFINE COMMANDPROMPT_NEWLINE "~r"
    &SCOPED-DEFINE PROGRESS_EOF          26
    
    CONSTRUCTOR PUBLIC CommandPrompt():
        
        /* Start new 'Command Prompt' (cmd) session/stream */
        INPUT-OUTPUT STREAM stCmd THROUGH VALUE("cmd") NO-ECHO.
        
        /* Disable prompt */
        PUT STREAM stCmd UNFORMATTED "prompt $NUL" SKIP.
        
        /* Disable echo */
        PUT STREAM stCmd UNFORMATTED "@echo off" SKIP.
        
        /* Flush startup output */
        THIS-OBJECT:Read().
    END.
    
    DESTRUCTOR CommandPrompt():
        
        /* Close the 'Command Prompt' session/stream */
        INPUT-OUTPUT STREAM stCmd CLOSE.
    END.
    
    /*
        Purpose:    Writes new input into the 'CommandPrompt'.
    */
    /* ICommandLineInterpreter */ METHOD PUBLIC VOID Write(i_cInput AS CHAR):
        IF i_cInput = ? THEN UNDO, THROW NEW Progress.Lang.AppError(SUBST("&1: 'i_cInput' is 'UNKNOWN'!", PROGRAM-NAME(1))).
        
        /* Wrap the command(s) in 'NUL' input redirection so we run the commands 'non-interactively' so the code won't hang for asking user input */
        PUT STREAM stCmd UNFORMATTED SUBST("(&1) < NUL", i_cInput)  SKIP.
        
    END.
    
    /*
        Purpose:    Writes new input into the 'CommandPrompt' and reads output as well.
    */
    /* ICommandLineInterpreter */ METHOD PUBLIC CHAR WriteRead(i_cInput AS CHAR):
        
        /* Write input */
        THIS-OBJECT:Write(i_cInput).
        
        /* Read output */
        RETURN THIS-OBJECT:Read().
    END.
    
    /*
        Purpose:    Reads all available output from 'CommandPrompt'.
    */
    /* ICommandLineInterpreter */ METHOD PUBLIC CHAR Read():
        
        DEF VAR cOutputs         AS CHAR NO-UNDO.
        DEF VAR cFilteredOutputs AS CHAR NO-UNDO.
        DEF VAR iLineCount       AS INT NO-UNDO.
        DEF VAR iLine            AS INT NO-UNDO.
        DEF VAR cLine            AS CHAR NO-UNDO.
        
        /* Output 'EOF' */
        PUT STREAM stCmd UNFORMATTED {&COMMANDPROMPT_EOF} SKIP.
        
        /* Read all output until 'EOF' */
        REPEAT:
            READKEY STREAM stCmd PAUSE 0.
            
            /* If we reached the 'EOF', stop reading */
            IF LASTKEY = {&PROGRESS_EOF} THEN DO:
                LEAVE.
            END.
            
            cOutputs = cOutputs + CHR(LASTKEY).
        END.
        
        /* Loop all outputs line by line (ignore first 4 lines) */
        iLineCount = NUM-ENTRIES(cOutputs, {&COMMANDPROMPT_NEWLINE}).
        DO iLine = 4 TO iLineCount:
            
            /* Ignore last 4 rows (they're part */
            IF iLine = (iLineCount - 3) THEN LEAVE.
            
            cLine = ENTRY(iLine, cOutputs, {&COMMANDPROMPT_NEWLINE}).
            
            /* Delete the first character left-over from the prompt */
            //IF (iLine = 4 OR iLine = 5) AND SUBSTRING(cLine, 1, 1) = CHR(27) THEN DO:
            //    cLine = SUBSTRING(cLine, 2).
            //END.
            
            cFilteredOutputs = cFilteredOutputs + cLine.
        END.
        
        RETURN cFilteredOutputs.
    END.
    
END.
