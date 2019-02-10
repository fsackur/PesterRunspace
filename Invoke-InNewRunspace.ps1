<#
    .SYNOPSIS
    When called at the top of a script, re-invokes that script in a separate runspace.

    .DESCRIPTION
    When testing, it's often important to run in a fresh environment and, if testing
    classes, to run in a separate AppDomain. This script achieves that.

    At the top of your pester script, add the following code:

        if (Invoke-InNewRunspace.ps1) {return}

    Adjust the path to Invoke-InNewRunspace.ps1 to suit your layout.

    .LINK
    https:#github.com/Microsoft/Windows-classic-samples/blob/master/Samples/PowerShell/Debugger/cs/DebuggerSample.cs
#>
using namespace System.Collections.Generic
using namespace System.Management.Automation


        public void Run()
        {
            Console.WriteLine("Starting PowerShell Debugger Sample");
            Console.WriteLine();

            # Create sample script file to debug.
            string fileName = "PowerShellSDKDebuggerSample.ps1";
            string filePath = System.IO.Path.Combine(Environment.CurrentDirectory, fileName);
            System.IO.File.WriteAllText(filePath, _script);

            using (Runspace runspace = RunspaceFactory.CreateRunspace())
            {
                # Open runspace and set debug mode to debug PowerShell scripts and
                # Workflow scripts.  PowerShell script debugging is enabled by default,
                # Workflow debugging is opt-in.
                runspace.Open();
                runspace.Debugger.SetDebugMode(DebugModes.LocalScript);

                using (PowerShell powerShell = PowerShell.Create())
                {
                    powerShell.Runspace = runspace;

                    # Set breakpoint update event handler.  The breakpoint update event is
                    # raised whenever a break point is added, removed, enabled, or disabled.
                    # This event is generally used to display current breakpoint information.
                    runspace.Debugger.BreakpointUpdated += HandlerBreakpointUpdatedEvent;

                    # Set debugger stop event handler.  The debugger stop event is raised
                    # whenever a breakpoint is hit, or for each script execution sequence point
                    # when the debugger is in step mode.  The debugger remains stopped at the
                    # current execution location until the event handler returns.  When the
                    # event handler returns it should set the DebuggerStopEventArgs.ResumeAction
                    # to indicate how the debugger should proceed:
                    #  - Continue      Continue execution until next breakpoint is hit.
                    #  - StepInto      Step into function.
                    #  - StepOut       Step out of function.
                    #  - StepOver      Step over function.
                    #  - Stop          Stop debugging.
                    runspace.Debugger.DebuggerStop += HandleDebuggerStopEvent;

                    # Set initial breakpoint on line 10 of script.  This breakpoint
                    # will be in the script workflow function.
                    powerShell.AddCommand("Set-PSBreakpoint").AddParameter("Script", filePath).AddParameter("Line", 10);
                    powerShell.Invoke();

                    Console.WriteLine("Starting script file: " + filePath);
                    Console.WriteLine();

                    # Run script file.
                    powerShell.Commands.Clear();
                    powerShell.AddScript(filePath).AddCommand("Out-String").AddParameter("Stream", true);
                    var scriptOutput = new PSDataCollection<PSObject>();
                    scriptOutput.DataAdded += (sender, args) =>
                        {
                            # Stream script output to console.
                            foreach (var item in scriptOutput.ReadAll())
                            {
                                Console.WriteLine(item);
                            }
                        };
                    powerShell.Invoke<PSObject>(null, scriptOutput);
                }
            }

            # Delete the sample script file.
            if (System.IO.File.Exists(filePath))
            {
                System.IO.File.Delete(filePath);
            }

            Console.WriteLine("PowerShell Debugger Sample Complete");
            Console.WriteLine();
            Console.WriteLine("Press any key to exit.");
            Console.ReadKey(true);
        }

        #endregion

        #region Private Methods

        # Method to handle the Debugger DebuggerStop event.
        # The debugger will remain in debugger stop mode until this event
        # handler returns, at which time DebuggerStopEventArgs.ResumeAction should
        # be set to indicate how the debugger should proceed (Continue, StepInto,
        # StepOut, StepOver, Stop).
        # This handler should run a REPL (Read Evaluate Print Loop) to allow user
        # to investigate the state of script execution, by processing user commands
        # with the Debugger.ProcessCommand method.  If a user command releases the
        # debugger then the DebuggerStopEventArgs.ResumeAction is set and this
        # handler returns.
        private void HandleDebuggerStopEvent(object sender, DebuggerStopEventArgs args)
        {
            Debugger debugger = sender as Debugger;
            DebuggerResumeAction? resumeAction = null;

            # Display messages pertaining to this debugger stop.
            WriteDebuggerStopMessages(args);

            # Simple REPL (Read Evaluate Print Loop) to process
            # Debugger commands.
            while (resumeAction == null)
            {
                # Write debug prompt.
                Console.Write("[DBG] PS >> ");
                string command = Console.ReadLine();
                Console.WriteLine();

                # Stream output from command processing to console.
                var output = new PSDataCollection<PSObject>();
                output.DataAdded += (dSender, dArgs) =>
                {
                    foreach (var item in output.ReadAll())
                    {
                        Console.WriteLine(item);
                    }
                };

                # Process command.
                # The Debugger.ProcesCommand method will parse and handle debugger specific
                # commands such as 'h' (help), 'list', 'stepover', etc.  If the command is
                # not specific to the debugger then it will be evaluated as a PowerShell
                # command or script.  The returned DebuggerCommandResults object will indicate
                # whether the command was evaluated by the debugger and if the debugger should
                # be released with a specific resume action.
                PSCommand psCommand = new PSCommand();
                psCommand.AddScript(command).AddCommand("Out-String").AddParameter("Stream", true);
                DebuggerCommandResults results = debugger.ProcessCommand(psCommand, output);
                if (results.ResumeAction != null)
                {
                    resumeAction = results.ResumeAction;
                }
            }

            # Return from event handler with user resume action.
            args.ResumeAction = resumeAction.Value;
        }

        # Method to handle the Debugger BreakpointUpdated event.
        # This method will display the current breakpoint change and maintain a
        # collection of all current breakpoints.
        private void HandlerBreakpointUpdatedEvent(object sender, BreakpointUpdatedEventArgs args)
        {
            # Write message to console.
            ConsoleColor saveFGColor = Console.ForegroundColor;
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine();

            switch (args.UpdateType)
            {
                case BreakpointUpdateType.Set:
                    if (!_breakPoints.ContainsKey(args.Breakpoint.Id))
                    {
                        _breakPoints.Add(args.Breakpoint.Id, args.Breakpoint);
                    }
                    Console.WriteLine("Breakpoint created:");
                    break;

                case BreakpointUpdateType.Removed:
                    _breakPoints.Remove(args.Breakpoint.Id);
                    Console.WriteLine("Breakpoint removed:");
                    break;

                case BreakpointUpdateType.Enabled:
                    Console.WriteLine("Breakpoint enabled:");
                    break;

                case BreakpointUpdateType.Disabled:
                    Console.WriteLine("Breakpoint disabled:");
                    break;
            }

            Console.WriteLine(args.Breakpoint.ToString());
            Console.WriteLine();
            Console.ForegroundColor = saveFGColor;
        }

        # <summary>
        # Helper method to write debugger stop messages.
        # </summary>
        # <param name="args">DebuggerStopEventArgs for current debugger stop</param>
        private void WriteDebuggerStopMessages(DebuggerStopEventArgs args)
        {
            # Write debugger stop information in yellow.
            ConsoleColor saveFGColor = Console.ForegroundColor;
            Console.ForegroundColor = ConsoleColor.Yellow;

            # Show help message only once.
            if (!_showHelpMessage)
            {
                Console.WriteLine("Entering debug mode. Type 'h' to get help.");
                Console.WriteLine();
                _showHelpMessage = true;
            }

            # Break point summary message.
            string breakPointMsg = String.Format(System.Globalization.CultureInfo.InvariantCulture,
                "Breakpoints: Enabled {0}, Disabled {1}",
                (_breakPoints.Values.Where<Breakpoint>((bp) => { return bp.Enabled; })).Count(),
                (_breakPoints.Values.Where<Breakpoint>((bp) => { return !bp.Enabled; })).Count());
            Console.WriteLine(breakPointMsg);
            Console.WriteLine();

            # Breakpoint stop information.  Writes all breakpoints that
            # pertain to this debugger execution stop point.
            if (args.Breakpoints.Count > 0)
            {
                Console.WriteLine("Debugger hit breakpoint on:");
                foreach (var breakPoint in args.Breakpoints)
                {
                    Console.WriteLine(breakPoint.ToString());
                }
                Console.WriteLine();
            }

            # Script position stop information.
            # This writes the InvocationInfo position message if
            # there is one.
            if (args.InvocationInfo != null)
            {
                Console.WriteLine(args.InvocationInfo.PositionMessage);
                Console.WriteLine();
            }

            Console.ForegroundColor = saveFGColor;
        }

        #endregion

if ([runspace]::DefaultRunspace.Name -notmatch 'Pester')
{
    $ISS = [initialsessionstate]::CreateDefault()
    $ISS.ImportPSModule('Pester')
    $ISS.UseFullLanguageModeInDebugger = $true

    $RS = [runspacefactory]::CreateRunspace($Host, $ISS)
    $RS.Name = "Pester" + [datetime]::Now.ToString('s')

    $RS.Open()
    $RS.Debugger.SetDebugMode('LocalScript')

    $Frame = (Get-PSCallStack)[1]
    $TestBreakpoints = Get-PSBreakpoint -Script $Frame.InvocationInfo.MyCommand.Source
    $RS.Debugger.SetBreakpoints([List[Breakpoint]]$TestBreakpoints)
    $RS.Debugger.BreakpointUpdated += HandlerBreakpointUpdatedEvent;

    # Set debugger stop event handler.  The debugger stop event is raised
    # whenever a breakpoint is hit, or for each script execution sequence point
    # when the debugger is in step mode.  The debugger remains stopped at the
    # current execution location until the event handler returns.  When the
    # event handler returns it should set the DebuggerStopEventArgs.ResumeAction
    # to indicate how the debugger should proceed:
    #  - Continue      Continue execution until next breakpoint is hit.
    #  - StepInto      Step into function.
    #  - StepOut       Step out of function.
    #  - StepOver      Step over function.
    #  - Stop          Stop debugging.
    $RS.Debugger.DebuggerStop += HandleDebuggerStopEvent;

    $PS = [Powershell]::Create()
    $PS.Runspace = $RS

    $null = $PS.
        AddScript('Write-Verbose "Running in runspace $([runspace]::DefaultRunspace.Name)" -Verbose').
        AddStatement().
        AddCommand("Set-Location").
        AddParameter('Path', $PWD.Path)

    $PS.Invoke()
    $PS.Commands.Clear()




    Get-Variable *Preference |
        Where-Object {$_.Name -notmatch '^WhatIf|^Confirm'} |
        ForEach-Object {
        $null = $PS.
            AddScript("`$$($_.Name) = '$($_.Value)'")
    }

    try
    {
        $PS.Invoke()
        $PS.Commands.Clear()
    }
    catch
    {
        if ($_ -notmatch 'No commands are specified')
        {
            throw
        }
    }



    $Invocation = $Frame.InvocationInfo.MyCommand.Source

    $null = $PS.AddScript($Invocation)


    $PS.Invoke()

    $PS.Streams.Error       | ForEach-Object {Write-Error $_}
    $PS.Streams.Warning     | ForEach-Object {Write-Warning $_}
    $PS.Streams.Verbose     | ForEach-Object {Write-Verbose $_}
    $PS.Streams.Debug       | ForEach-Object {Write-Debug $_}
    $PS.Streams.Information | ForEach-Object {Write-Information $_}

    $RS.Dispose()
    $PS.Dispose()


    return $true
}
else
{
    return $false
}