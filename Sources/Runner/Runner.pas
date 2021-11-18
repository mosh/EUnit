﻿namespace RemObjects.Elements.EUnit;

interface

uses
  RemObjects.Elements.EUnit.Reflections;

type
  Runner = public static class
  private
    method RunChildren(Context: RunContext): ITestResult;
    method RunTestcase(Context: RunContext): ITestResult;
    method RunClass(Context: RunContext): ITestResult;
    method RunSuite(Context: RunContext): ITestResult;
    method Run(Context: RunContext): ITestResult;
  public
    method RunTests(Test: ITest): ITestResult;
    method RunTests(Test: ITest) withListener(Listener: IEventListener := nil): ITestResult;
    {$IF NOT ISLAND}
    method RunTestsAsync(Test: ITest) completionHandler(Handler: Action<ITestResult>);
    method RunTestsAsync(Test: ITest) completionHandler(Handler: Action<ITestResult>) withListener(Listener: IEventListener);
    method RunTestsAsync(Test: ITest) completionHandler(Handler: Action<ITestResult>) withListener(Listener: IEventListener) cancelationToken(Token: ICancelationToken);
    {$ENDIF}
  end;

implementation

class method Runner.RunTests(Test: ITest): ITestResult;
begin
  exit RunTests(Test) withListener(nil);
end;

method Runner.RunTests(Test: ITest) withListener(Listener: IEventListener := nil): ITestResult;
begin
  ArgumentNilException.RaiseIfNil(Test, "Test");

  if not assigned(Listener) then
    Listener := DefaultListener;

  var Context := new RunContext(Test, Listener);

  {$IF NOT ISLAND}
  if Listener is IEventListenerGUI then begin
    RunTestsAsync(Test) completionHandler(nil) withListener(Listener);
  end
  else
  begin
    Listener:RunStarted(Test);
    result := Run(Context);
    Listener:RunFinished(result);
  end;
  {$ELSE}
  begin
    Listener:RunStarted(Test);
    result := Run(Context);
    Listener:RunFinished(result);
  end;
  {$ENDIF}
end;

{$IF NOT ISLAND}
method Runner.RunTestsAsync(Test: ITest) completionHandler(Handler: Action<ITestResult>);
begin
  RunTestsAsync(Test) completionHandler(Handler) withListener(nil) cancelationToken(nil);
end;

method Runner.RunTestsAsync(Test: ITest) completionHandler(Handler: Action<ITestResult>) withListener(Listener: IEventListener);
begin
  RunTestsAsync(Test) completionHandler(Handler) withListener(Listener) cancelationToken(nil);
end;

method Runner.RunTestsAsync(Test: ITest) completionHandler(Handler: Action<ITestResult>) withListener(Listener: IEventListener) cancelationToken(Token: ICancelationToken);
begin
  ArgumentNilException.RaiseIfNil(Test, "Test");

  if Listener is IEventListenerGUI then
    (Listener as IEventListenerGUI).PrepareGUI();
  async begin
    var Context := new RunContext(Test, Listener, Token);
    Listener:RunStarted(Test);
    var Results := Run(Context);
    Listener:RunFinished(Results);
    if assigned(Handler) then
      Handler(Results);
    if Listener is IEventListenerGUI then
      (Listener as IEventListenerGUI).FinishGUI();
  end;
  if Listener is IEventListenerGUI then
    (Listener as IEventListenerGUI).RunGUI();
end;
{$ENDIF}

class method Runner.Run(Context: RunContext): ITestResult;
begin
  ArgumentNilException.RaiseIfNil(Context, "Context");
  Context.Listener:TestStarted(Context.Test);

  if Context.Test.Skip then begin
    result := new TestResultNode(Context.Test, TestState.Skipped, "Skipped", String.Format("TEST-SKIPPED,,,{0},Test Skipped", Context.Test.Name))
  end
  else begin
    case Context.Test.Kind of
      TestKind.Suite: result := RunSuite(Context);
      TestKind.Test: result := RunClass(Context);
      TestKind.Testcase: result := RunTestcase(Context);
    end;
  end;

  Context.Listener:TestFinished(result);
end;

class method Runner.RunTestcase(Context: RunContext): ITestResult;
begin
  var InitInstance: Boolean := Context.Type = nil;

  var Actions: BaseAction := new InitializeMethodAction().Then(
                             new InitializeInstanceAction()).Then(
                             new TryFinallyAction(new SetupAction,
                             new MethodAction,
                             new TeardownAction));

  if InitInstance then
    Actions := new InitializeTypeAction().Then(
               new InitializeInstanceAction()).Then(
               new TryFinallyAction(new SetupTestAction,
               Actions,
               new TeardownTestAction));

  if Context.Token:Canceled then
    exit new TestResultNode(Context.Test);

  Actions.Execute(Context);
  exit Context.CurrentResult;
end;

class method Runner.RunClass(Context: RunContext): ITestResult;
begin
  var Actions := new InitializeTypeAction()
                 .Then(new InitializeInstanceAction())
                 .Then(new TryFinallyAction(new SetupTestAction,
                       new ResultAction(ctx -> RunChildren(ctx)),
                       new TeardownTestAction));

  Actions.Execute(Context);
  exit Context.CurrentResult;
end;

class method Runner.RunSuite(Context: RunContext): ITestResult;
begin
  exit RunChildren(Context);
end;

class method Runner.RunChildren(Context: RunContext): ITestResult;
begin
  if Context.Test.Skip then
    exit new TestResultNode(Context.Test, TestState.Skipped, "Skipped", String.Format("TEST-SKIPPED,,,{0},Test Skipped", Context.Test.Name));

  var Node := new TestResultNode(Context.Test);
  var IsFailed: Boolean := false;

  for Item in Context.Test.Children do begin
    var ItemContext := new RunContext withContext(Item, Context);
    var SubNode := Run(ItemContext);

    if (not IsFailed) and (SubNode.State = TestState.Failed) then
      IsFailed := true;

    Node.Add(SubNode);
  end;

  Node.SetResult(if IsFailed then TestState.Failed else TestState.Succeeded, if IsFailed then "One or more test failed" else nil);
  exit Node;
end;

end.