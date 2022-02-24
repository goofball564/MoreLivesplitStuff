/*

For Dark Souls speedrunners who want to time their segment practice from 0.

WARNING: THIS SCRIPT OVERWRITES YOUR IN-GAME TIME. IT IS NOT APPROVED FOR 
SPEEDRUNS, AND USING IT IS **CHEATING**.

How this script works:
Load a savefile for segment practice. Start your Livesplit timer in the main 
menu. When it detects that you've loaded into the game, it will overwrite
your in-game time in memory to 0. It only does this once after starting the timer, so it
won't continue to overwrite the time everytime you quitout and load in.

This behavior is meant to work in conjunction with the IGT plugin.

This script should not be used when starting a new game for a speedrun:
the script would detect the timer starting to tick from 0,
and overwrite it back to 0, resulting in the timer being a frame or
more faster than it should be. This is cheating; don't be a cheater.

Although there is a setting to disable this script and a safeguard against it 
working when you start a new game, the best thing to do is not include
this in a layout you use for actual speedruns.

*/

state("DARKSOULS") {}

state("DarkSoulsRemastered") {}

startup
{
    // Will not overwrite IGT if it is less than this (in IGT milliseconds).
    vars.MinimumInitialTime = 10000;

    vars.CooldownStopwatch = new Stopwatch();

    settings.Add("enable", false, "Enable");

    vars.IgtChanged = false;
    vars.NewGameDetected = false;
}

onReset
{
    vars.IgtChanged = false;
    vars.NewGameDetected = false;
}

init
{
    // ---------- POINTER FUNCTIONS ----------

    vars.GetAOBRelativePtr = (Func<SignatureScanner, SigScanTarget, int, IntPtr>) ((scanner, sst, instructionLength) => 
    {
        int aobOffset = sst.Signatures[0].Offset;

        IntPtr ptr = scanner.Scan(sst);
        if (ptr == default(IntPtr))
        {
            throw new Exception("AOB Scan Unsuccessful");
        }

        int offset = memory.ReadValue<int>(ptr);

        return ptr - aobOffset + offset + instructionLength;
    });

    // Needs to have same signature as other AOB Ptr Func; ignoredValue is ignored.
    vars.GetAOBAbsolutePtr = (Func<SignatureScanner, SigScanTarget, int, IntPtr>) ((scanner, sst, ignoredValue) => 
    {
        IntPtr ptr = scanner.Scan(sst);
        if (ptr == default(IntPtr))
        {
            throw new Exception("AOB Scan Unsuccessful");
        }

        IntPtr tempPtr;
        if (!game.ReadPointer(ptr, out tempPtr))
        {
            throw new Exception("AOB scan did not yield valid pointer");
        }

        return tempPtr;
    });

    // ---------- GAME SPECIFIC AOBs, OFFSETS, AND VALUES ----------

    SignatureScanner sigScanner = new SignatureScanner(game, modules.First().BaseAddress, modules.First().ModuleMemorySize);
    
    if (game.ProcessName.ToString() == "DARKSOULS")
    {    
        vars.GameDataManAOB = new SigScanTarget(1, "A1 ?? ?? ?? ?? 8B 40 34 53 32");
        vars.IgtOffsets = new int[] {0x68};
        vars.GetAOBPtr = vars.GetAOBAbsolutePtr;
    }
    else if (game.ProcessName.ToString() == "DarkSoulsRemastered")
    {
        vars.GameDataManAOB = new SigScanTarget(3, "48 8B 05 ?? ?? ?? ?? 45 33 ED 48 8B F1 48 85 C0");
        vars.IgtOffsets = new int[] {0xA4};
        vars.GetAOBPtr = vars.GetAOBRelativePtr;
    }

    // ---------- GET BASE POINTERS ----------

    // How long to wait before retrying AOB scanning if AOB scanning fails.
    const int MILLISECONDS_TO_WAIT_BEFORE_RESCAN = 100;

    // Stopwatch is defined in startup block and is used to mimic
    // Thread.Sleep without locking the Livesplit UI; 
    // If an AOB scan fails, retry after a specified number of milliseconds.
    if (!vars.CooldownStopwatch.IsRunning || vars.CooldownStopwatch.ElapsedMilliseconds > MILLISECONDS_TO_WAIT_BEFORE_RESCAN)
    {
        vars.CooldownStopwatch.Start();
        try 
        {
            vars.GameDataManPtr = vars.GetAOBPtr(sigScanner, vars.GameDataManAOB, 7);
        }
        catch (Exception e)
        {
            vars.CooldownStopwatch.Restart();
            throw new Exception(e.ToString() + "\ninit {} needs to be recalled; base pointer creation unsuccessful");
        }
    }
    else
    {
        throw new Exception("init {} needs to be recalled; waiting to rescan for base pointers");
    }

    vars.CooldownStopwatch.Reset();

    vars.IgtDeepPtr = new DeepPointer(vars.GameDataManPtr, vars.IgtOffsets);

    vars.Igt = new MemoryWatcher<uint>(vars.IgtDeepPtr);
}

update
{
    vars.Igt.Update(game);

    if (settings["enable"] && timer.CurrentPhase == TimerPhase.Running && !vars.IgtChanged && !vars.NewGameDetected)
    {
        var igtPtr = IntPtr.Zero;

        // Script stops having any effect after either of these conditions is met.
        if (vars.Igt.Current >= vars.MinimumInitialTime && vars.IgtDeepPtr.DerefOffsets(game, out igtPtr))
        {
            game.WriteBytes(igtPtr, BitConverter.GetBytes((uint)0));
            vars.IgtChanged = true;
        }
        else if (vars.Igt.Current > 0 && vars.Igt.Current < vars.MinimumInitialTime)
        {
            vars.NewGameDetected = true;
        }
    }
}