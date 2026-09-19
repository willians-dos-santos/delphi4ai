program Delphi4AI.Tests;

uses
  System.SysUtils,
  Vcl.Forms,
  TestFramework,
  GUITestRunner,
  TextTestRunner,
  Utils.JSONArray in '..\utils\Utils.JSONArray.pas',
  LLM.HistoryStrategy in '..\llm\LLM.HistoryStrategy.pas',
  LLM.Tools in '..\llm\LLM.Tools.pas',
  LLM.Tools.Attributes in '..\llm\LLM.Tools.Attributes.pas',
  LLM.Tools.RTTI in '..\llm\LLM.Tools.RTTI.pas',
  LLM.Interfaces in '..\llm\LLM.Interfaces.pas',
  LLM.Base in '..\llm\LLM.Base.pas',
  LLM.MockProvider in 'Mocks\LLM.MockProvider.pas',
  Test.Utils.JSONArray in 'Test.Utils.JSONArray.pas',
  Test.LLM.Base in 'Test.LLM.Base.pas',
  Test.LLM.Tools in 'Test.LLM.Tools.pas',
  LLM.Exceptions in '..\llm\LLM.Exceptions.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := True;

  if FindCmdLineSwitch('console', True) or FindCmdLineSwitch('c', True) then
    TextTestRunner.RunRegisteredTests
  else
    GUITestRunner.RunRegisteredTests;
end.