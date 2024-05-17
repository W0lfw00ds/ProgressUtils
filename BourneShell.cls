BLOCK-LEVEL ON ERROR UNDO, THROW.

/*
    Purpose:    A class wrapper around Unix 'Bourne Shell' (sh), where each instance is it's own 'Bourne Shell'-window/session.
                
                Usage:
                    DEF VAR oBourneShell AS CLASS BourneShell NO-UNDO.
                    DEF VAR cOutput      AS CHAR NO-UNDO.
                    
                    /* Write input */
                    oBourneShell:Write("number=42").
                    
                    /* Read output */
                    cOutput = oBourneShell:Read().
                    
                    /* Write input */
                    oBourneShell:Write('echo "$number"').
                    
                    /* Read output */
                    cOutput = oBourneShell:Read().
                
                The 'BourneShell' instance is closed when you manually free the object with 'DELETE-OBJECT oBourneShell'
                Or when the object gets out of scope.
                
                'BourneShell' startup settings:
                    - "PS1=''": Prompt is set to empty so the outputs only contain the actual output. Can be changed at runtime.
*/
CLASS BourneShell
    IMPLEMENTS ICommandLineInterpreter:
    
    DEF PRIVATE STREAM stSH.
    
    &SCOPED-DEFINE BOURNESHELL_EOF     'echo -e "\032"'
    &SCOPED-DEFINE BOURNESHELL_NEWLINE "\n"
    &SCOPED-DEFINE PROGRESS_EOF        26
    
    CONSTRUCTOR PUBLIC BourneShell():
        
        /* Start new 'Bourne Shell' session/stream */
        INPUT-OUTPUT STREAM stSH THROUGH VALUE(
            "sh"
        ) NO-ECHO.
        
        /* Disable prompt */
        PUT STREAM stSH UNFORMATTED "PS1=''" SKIP.
        
        /* Flush startup output */
        THIS-OBJECT:Read().
    END.
    
    DESTRUCTOR BourneShell():
        
        /* Close the 'Bourne Shell' session/stream */
        INPUT-OUTPUT STREAM stSH CLOSE.
    END.
    
    /*
        Purpose:    Writes new input into the 'Bourne Shell'.
    */
    /* ICommandLineInterpreter */ METHOD PUBLIC VOID Write(i_cInput AS CHAR):
        IF i_cInput = ? THEN UNDO, THROW NEW Progress.Lang.AppError(SUBST("&1: 'i_cInput' is 'UNKNOWN'!", PROGRAM-NAME(1))).
        
        /* Wrap the command(s) in '/Dev/null' input redirection so we run the commands 'non-interactively' so the code won't hang for asking user input */
        PUT STREAM stSH UNFORMATTED SUBST("( &1 ) < /dev/null", i_cInput) SKIP.
        
    END.
    
    /*
        Purpose:    Writes new input into the 'Bourne Shell' and reads output as well.
    */
    /* ICommandLineInterpreter */ METHOD PUBLIC CHAR WriteRead(i_cInput AS CHAR):
        
        /* Write input */
        THIS-OBJECT:Write(i_cInput).
        
        /* Read output */
        RETURN THIS-OBJECT:Read().
    END.
    
    /*
        Purpose:    Reads all available output from 'Bourne Shell'.
    */
    /* ICommandLineInterpreter */ METHOD PUBLIC CHAR Read():
        
        DEF VAR cOutputs         AS CHAR NO-UNDO.
        DEF VAR cFilteredOutputs AS CHAR NO-UNDO.
        DEF VAR iLineCount       AS INT NO-UNDO.
        DEF VAR iLine            AS INT NO-UNDO.
        DEF VAR cLine            AS CHAR NO-UNDO.
        
        /* Output 'EOF' */
        PUT STREAM stSH UNFORMATTED {&BOURNESHELL_EOF} SKIP.
        
        /* Read all output until 'EOF' */
        REPEAT:
            READKEY STREAM stSH PAUSE 0.
            
            /* If we reached the 'EOF', stop reading */
            IF LASTKEY = {&PROGRESS_EOF} THEN DO:
                LEAVE.
            END.
            
            cOutputs = cOutputs + CHR(LASTKEY).
        END.
        
        /* Loop all outputs line by line (ignore first 4 lines) */
        iLineCount = NUM-ENTRIES(cOutputs, {&BOURNESHELL_NEWLINE}).
        DO iLine = 4 TO iLineCount:
            
            /* Ignore last 4 rows (they're part */
            IF iLine = (iLineCount - 3) THEN LEAVE.
            
            cLine = ENTRY(iLine, cOutputs, {&BOURNESHELL_NEWLINE}).
            
            cFilteredOutputs = cFilteredOutputs + cLine.
        END.
        
        RETURN cFilteredOutputs.
    END.
    
END.
