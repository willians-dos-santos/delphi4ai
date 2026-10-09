program ExemploImagem;

uses
  Vcl.Forms,
  Image.Interfaces in '..\..\image\Image.Interfaces.pas',
  Image.Factory in '..\..\image\Image.Factory.pas',
  Gemini.Image.Provider in '..\..\image\gemini\Gemini.Image.Provider.pas',
  Pollinations.Image.Provider in '..\..\image\pollinations\Pollinations.Image.Provider.pas',
  LLM.Exceptions in '..\..\llm\LLM.Exceptions.pas',
  UnitImagem in 'UnitImagem.pas' {FormImagem};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormImagem, FormImagem);
  Application.Run;
end.
