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
  LLM.Schema in '..\llm\LLM.Schema.pas',
  LLM.Client in '..\llm\LLM.Client.pas',
  LLM.Interfaces in '..\llm\LLM.Interfaces.pas',
  LLM.Base in '..\llm\LLM.Base.pas',
  LLM.Exceptions in '..\llm\LLM.Exceptions.pas',
  LLM.Factory in '..\app\LLM.Factory.pas',
  Ollama.Provider in '..\ollama\Ollama.Provider.pas',
  LLM.MockProvider in 'Mocks\LLM.MockProvider.pas',
  Test.Utils.JSONArray in 'Test.Utils.JSONArray.pas',
  Test.LLM.Base in 'Test.LLM.Base.pas',
  Test.LLM.Tools in 'Test.LLM.Tools.pas',
  Test.Ollama.Provider in 'Test.Ollama.Provider.pas',
  Test.LLM.StructuredOutput in 'Test.LLM.StructuredOutput.pas',
  Groq.Provider in '..\groq\Groq.Provider.pas',
  Test.Groq.Provider in 'Test.Groq.Provider.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := True;

  if FindCmdLineSwitch('console', True) or FindCmdLineSwitch('c', True) then
    TextTestRunner.RunRegisteredTests
  else
    GUITestRunner.RunRegisteredTests;
end.