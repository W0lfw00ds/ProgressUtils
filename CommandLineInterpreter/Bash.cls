BLOCK-LEVEL ON ERROR UNDO, THROW.

/*
    Purpose:    A class wrapper around Unix 'Bash' (Bourne-Again SHell), where each instance is it's own 'Bash'-window/session.
                
                Usage:
                    DEF VAR oBash   AS CLASS Bash NO-UNDO.
                    DEF VAR cOutput AS CHAR NO-UNDO.
                    
                    /* Write input */
                    oBash:Write("number=42").
                    
                    /* Read output */
                    cOutput = oBash:Read().
                    
                    /* Write input */
                    oBash:Write('echo "$number"').
                    
                    /* Read output */
                    cOutput = oBash:Read().
                
                The 'Bash' instance is closed when you manually free the object with 'DELETE-OBJECT oBash'
                Or when the object gets out of scope.
                
                'Bash' startup settings:
                    - "PS1=''": Prompt is set to empty so the outputs only contain the actual output. Can be changed at runtime.
*/
CLASS ProgressUtils.CommandLineInterpreter.Bash
    IMPLEMENTS ICommandLineInterpreter:
    
    DEF PRIVATE STREAM stBash.
    
    &SCOPED-DEFINE BASH_EOF     'echo -e "\032"'
    &SCOPED-DEFINE BASH_NEWLINE "\n"
    &SCOPED-DEFINE PROGRESS_EOF 26
    
    CONSTRUCTOR PUBLIC Bash():
        
        /* Start new 'Bash' session/stream */
        INPUT-OUTPUT STREAM stBash THROUGH VALUE(
            "bash"
        ) NO-ECHO.
        
        /* Disable prompt */
        PUT STREAM stBash UNFORMATTED "PS1=''" SKIP.
        
        /* Flush startup output */
        THIS-OBJECT:Read().
    END.
    
    DESTRUCTOR Bash():
        
        /* Close the 'Bash' session/stream */
        INPUT-OUTPUT STREAM stBash CLOSE.
    END.
    
    /*
        Purpose:    Writes new input into the 'Bash'.
    */
    /* ICommandLineInterpreter */ METHOD PUBLIC VOID Write(i_cInput AS CHAR):
        IF i_cInput = ? THEN UNDO, THROW NEW Progress.Lang.AppError(SUBST("&1: 'i_cInput' is 'UNKNOWN'!", PROGRAM-NAME(1))).
        
        /* Wrap the command(s) in '/Dev/null' input redirection so we run the commands 'non-interactively' so the code won't hang for asking user input */
        PUT STREAM stBash UNFORMATTED SUBST("( &1 ) < /dev/null", i_cInput) SKIP.
        
    END.
    
    /*
        Purpose:    Writes new input into the 'Bash' and reads output as well.
    */
    /* ICommandLineInterpreter */ METHOD PUBLIC CHAR WriteRead(i_cInput AS CHAR):
        
        /* Write input */
        THIS-OBJECT:Write(i_cInput).
        
        /* Read output */
        RETURN THIS-OBJECT:Read().
    END.
    
    /*
        Purpose:    Reads all available output from 'Bash'.
    */
    /* ICommandLineInterpreter */ METHOD PUBLIC CHAR Read():
        
        DEF VAR cOutputs         AS CHAR NO-UNDO.
        DEF VAR cFilteredOutputs AS CHAR NO-UNDO.
        DEF VAR iLineCount       AS INT NO-UNDO.
        DEF VAR iLine            AS INT NO-UNDO.
        DEF VAR cLine            AS CHAR NO-UNDO.
        
        /* Output 'EOF' */
        PUT STREAM stBash UNFORMATTED {&BASH_EOF} SKIP.
        
        /* Read all output until 'EOF' */
        REPEAT:
            READKEY STREAM stBash PAUSE 0.
            
            /* If we reached the 'EOF', stop reading */
            IF LASTKEY = {&PROGRESS_EOF} THEN DO:
                LEAVE.
            END.
            
            cOutputs = cOutputs + CHR(LASTKEY).
        END.
        
        /* Loop all outputs line by line (ignore first 4 lines) */
        iLineCount = NUM-ENTRIES(cOutputs, {&BASH_NEWLINE}).
        DO iLine = 4 TO iLineCount:
            
            /* Ignore last 4 rows (they're part */
            IF iLine = (iLineCount - 3) THEN LEAVE.
            
            cLine = ENTRY(iLine, cOutputs, {&BASH_NEWLINE}).
            
            cFilteredOutputs = cFilteredOutputs + cLine.
        END.
        
        RETURN cFilteredOutputs.
    END.
    
END.
