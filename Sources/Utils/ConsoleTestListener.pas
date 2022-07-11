﻿namespace RemObjects.Elements.EUnit;

interface

type
  ConsoleTestListener = public class (IEventListener)
  private
    Offset: Integer;
    method StringOffset: String;
    method StateToString(State: TestState): String;
  protected
    method Output(Message: String); virtual;
  public
    method RunStarted(Test: ITest); virtual;
    method TestStarted(Test: ITest); virtual;
    method TestFinished(TestResult: ITestResult); virtual;
    method RunFinished(TestResult: ITestResult); virtual;

    property UseAnsiColorOutput: Boolean;
    class property EmitParseableMessages: Boolean read assembly write := false;
    class property EmitParseableSuccessMessages: Boolean read assembly write := false;
    class property EmitSuccessMessages: Boolean read assembly write := false;

    class constructor;
    begin
      var lHasParsableMessageEnvironmentVar := length(Environment.EnvironmentVariable[Runner.EUNIT_PARSABLE_MESSAGES]) > 0;
      var lHasParsableMessageCommandlineSwitch := false;
      {$IF DARWIN}
      lHasParsableMessageCommandlineSwitch := Foundation.NSProcessInfo.processInfo.arguments.Any(s -> s = "--"+Runner.EUNIT_PARSABLE_MESSAGES);
      EmitSuccessMessages := Foundation.NSProcessInfo.processInfo.arguments.Where(s -> s = "--"+Runner.EUNIT_SUCCESS_MESSAGES).Any;
      {$ELSEIF ECHOES}
      lHasParsableMessageCommandlineSwitch := System.Environment.CommandLine.Contains("--"+Runner.EUNIT_PARSABLE_MESSAGES);
      EmitSuccessMessages := System.Environment.CommandLine.Contains("--"+Runner.EUNIT_SUCCESS_MESSAGES);
      {$ENDIF}
      EmitSuccessMessages := EmitSuccessMessages or (length(Environment.EnvironmentVariable[Runner.EUNIT_SUCCESS_MESSAGES]) > 0);
      EmitParseableMessages := lHasParsableMessageEnvironmentVar or lHasParsableMessageCommandlineSwitch;
      EmitParseableSuccessMessages := EmitSuccessMessages and EmitParseableMessages; // for now
    end;

  end;

implementation

method ConsoleTestListener.StateToString(State: TestState): String;
begin
  case State of
    TestState.Untested: exit "Untested";
    TestState.Skipped: exit "Skipped";
    TestState.Failed: exit "Failed";
    TestState.Succeeded: exit "Succeeded";
  end;
end;

method ConsoleTestListener.TestFinished(TestResult: ITestResult);
begin
  if TestResult.State = TestState.Skipped then
    exit;

  if TestResult.Test.Kind <> TestKind.Testcase then
      dec(Offset, 2);

  if EmitParseableMessages then begin
    if (TestResult.State ≠ TestState.Succeeded) or ConsoleTestListener.EmitParseableSuccessMessages then
      Output(TestResult.ParsableMessage);
  end
  else begin
    var Failed := "Failed";
    var Succeeded := "Succeeded";

    if UseAnsiColorOutput then begin
      Failed := #27"[1m"#27"[31mFailed"#27"[0m";
      Succeeded := #27"[32mSucceded"#27"[0m";
    end;

    var Message: String;
    if TestResult.State = TestState.Failed then
      Message := String.Format("{0}{1} finished. State: {2}. Message: {3}", StringOffset, TestResult.Name, Failed, TestResult.Message)
    else
      Message := String.Format("{0}{1} finished. State: {2}.", StringOffset, TestResult.Name, Succeeded);
    Output(Message);
  end;

end;

method ConsoleTestListener.RunStarted(Test: ITest);
begin
  Offset := 0;
end;

method ConsoleTestListener.RunFinished(TestResult: ITestResult);
begin
  if EmitParseableMessages then begin
  end
  else begin
    Output("======================================");
    var S := new Summary(TestResult, item -> (item.Test.Kind = TestKind.Testcase));
    Output(String.Format("{0} succeeded, {1} failed, {2} skipped, {3} untested", S.Succeeded, S.Failed, S.Skipped, S.Untested));
  end;
end;

method ConsoleTestListener.Output(Message: String);
begin
  if length(Message) > 0 then begin
    {$IFNDEF NETFX_CORE}
    writeLn(Message);
    {$ELSE}
    System.Diagnostics.Debug.WriteLine(Message);
    {$ENDIF}
  end;
end;

method ConsoleTestListener.TestStarted(Test: ITest);
begin
  if (Test.Kind = TestKind.Testcase) or (Test.Skip) then
    exit;

  if not EmitParseableMessages then
    Output(String.Format("{0}{1} started", StringOffset, Test.Name));
  inc(Offset, 2);
end;

method ConsoleTestListener.StringOffset: String;
begin
  if Offset <= 0 then
    exit "";

  exit new StringBuilder().Append(' ', Offset).ToString;
end;

end.