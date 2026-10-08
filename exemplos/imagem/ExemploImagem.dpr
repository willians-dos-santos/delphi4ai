program ExemploImagem;

uses
  Vcl.Forms,
  LLM.Image.Interfaces in '..\..\llm\LLM.Image.Interfaces.pas',
  Gemini.Image.Provider in '..\..\gemini\Gemini.Image.Provider.pas',
  Pollinations.Image.Provider in '..\..\pollinations\Pollinations.Image.Provider.pas',
  LLM.Factory in '..\..\app\LLM.Factory.pas',
  LLM.Exceptions in '..\..\llm\LLM.Exceptions.pas',
  UnitImagem in 'UnitImagem.pas' {FormImagem},
  Ollama.Provider in '..\..\ollama\Ollama.Provider.pas',
  Groq.Provider in '..\..\groq\Groq.Provider.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormImagem, FormImagem);
  Application.Run;
end.
