program ExemploSimples;

uses
  Vcl.Forms,
  LLM.Exceptions in '..\..\llm\LLM.Exceptions.pas',
  LLM.HistoryStrategy in '..\..\llm\LLM.HistoryStrategy.pas',
  LLM.Interfaces in '..\..\llm\LLM.Interfaces.pas',
  LLM.Base in '..\..\llm\LLM.Base.pas',
  Utils.JSONArray in '..\..\utils\Utils.JSONArray.pas',
  Unit1 in 'Unit1.pas' {Form1},
  LLM.Factory in '..\..\app\LLM.Factory.pas',
  uWeatherTool in 'uWeatherTool.pas',
  LLM.Tools.Attributes in '..\..\llm\LLM.Tools.Attributes.pas',
  LLM.Tools.RTTI in '..\..\llm\LLM.Tools.RTTI.pas',
  LLM.Schema in '..\..\llm\LLM.Schema.pas',
  LLM.Client in '..\..\llm\LLM.Client.pas',
  Ollama.Provider in '..\..\ollama\Ollama.Provider.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
