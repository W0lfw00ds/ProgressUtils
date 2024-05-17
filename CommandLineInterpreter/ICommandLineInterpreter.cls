BLOCK-LEVEL ON ERROR UNDO, THROW.

/*
    Purpose:    A general interface for 'Command-line interpreter' classes.
                These classes are wrappers around actual 'Command-line interpreters' like:
                    - Windows Command Prompt (cmd)
                    - Windows Powershell (ps)
                    - Unix Bourne Shell (sh)
                    - Unix 'C Shell (csh)
                    - Unix Korn Shell (ksh)
                    - Unix Z Shell (zsh)
                    - Unix TENEX C Shell (tcsh)
*/
INTERFACE ProgressUtils.CommandLineInterpreter.ICommandLineInterpreter:
    
    /*
        Purpose:    Writes new input to the terminal.
    */
    METHOD PUBLIC VOID Write(i_cInput AS CHAR).
    
    /*
        Purpose:    Reads all output from the terminal.
    */
    METHOD PUBLIC CHAR Read().
    
    /*
        Purpose:    Writes new input to the terminal and immediately reads the output as well.
    */
    METHOD PUBLIC CHAR WriteRead(i_cInput AS CHAR):
    
END.
