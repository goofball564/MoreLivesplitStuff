state("LiveSplit") { }

startup
{  
    vars.InstantiatePipeStream = (Action) (() =>
    {
        vars.PipeClient = new System.IO.Pipes.NamedPipeClientStream(".", "Goofbot", System.IO.Pipes.PipeDirection.InOut);
        vars.Task = vars.PipeClient.ConnectAsync();
    });

    vars.WriteMessageToPipe = (Action<string>) ((message) =>
    {
        if (vars.PipeClient.IsConnected)
        {
            byte[] messageBytes = Encoding.UTF8.GetBytes(message);
            vars.PipeClient.Write(messageBytes, 0, messageBytes.Length);
        }

        vars.PipeClient.Dispose();
        vars.InstantiatePipeStream();
    });

    vars.InstantiatePipeStream();
}

onStart
{
    vars.WriteMessageToPipe("Start " + timer.Run.AttemptCount);
}

onSplit
{
    vars.WriteMessageToPipe("Split " + timer.CurrentSplitIndex + " " + timer.Run.Count);
    // if (LiveSplitStateHelper.CheckBestSegment(timer, timer.CurrentSplitIndex - 1, timer.CurrentTimingMethod))
    // {
    //     vars.WriteMessageToPipe("Gold");
    //     print("GOLD SPLIT UWU");
    // }
}

onReset
{
    vars.WriteMessageToPipe("Reset " + timer.Run.AttemptCount);
}

shutdown
{
    vars.PipeClient.Dispose();
}