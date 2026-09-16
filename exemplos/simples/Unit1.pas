unit Unit1;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  LLM.Interfaces,
  LLM.HistoryStrategy,
  LLM.Exceptions;

type
  TForm1 = class(TForm)
    pnlConfig: TPanel;
    grpConfig: TGroupBox;
    lblBaseURL: TLabel;
    lblModel: TLabel;
    lblApiKey: TLabel;
    lblStrategy: TLabel;
    lblSystemPrompt: TLabel;
    edtBaseURL: TEdit;
    edtModel: TEdit;
    edtApiKey: TEdit;
    cbbStrategy: TComboBox;
    edtSystemPrompt: TEdit;
    btnAplicar: TButton;
    lblInfo: TLabel;
    pnlClient: TPanel;
    memChat: TMemo;
    pnlBottom: TPanel;
    lblStatus: TLabel;
    edtInput: TEdit;
    btnEnviar: TButton;
    btnLimpar: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnEnviarClick(Sender: TObject);
    procedure edtInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnLimparClick(Sender: TObject);
    procedure btnAplicarClick(Sender: TObject);
    procedure cbbStrategyChange(Sender: TObject);
  private
    FLLM: ILLMProvider;
    procedure InitProvider;
    procedure AppendChat(const ARole, AText: string);
    procedure UpdateStatus(const ACustomMsg: string = '');
    procedure EnviarMensagem;
  public
  end;

var
  Form1: TForm1;

implementation

uses
  System.Threading,
  LLM.Factory;

{$R *.dfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  InitProvider;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
//  FLLM.Free;
end;

procedure TForm1.InitProvider;
begin

  FLLM := CreateLLMProvider(
    Trim(edtApiKey.Text),
    Trim(edtBaseURL.Text),
    Trim(edtModel.Text)
  );

  case cbbStrategy.ItemIndex of
    0: FLLM.HistoryStrategy := hsSlidingWindow;
    1: FLLM.HistoryStrategy := hsSummarize;
    2: FLLM.HistoryStrategy := hsNone;
  end;

  FLLM.MaxHistoryMessages := 10;
  FLLM.KeepRecentMessages := 4;

  if not Trim(edtSystemPrompt.Text).IsEmpty then
    FLLM.AddSystem(Trim(edtSystemPrompt.Text));

  memChat.Clear;
  AppendChat('Sistema', 'Conversa iniciada com o modelo "' + FLLM.Model + '". Digite uma mensagem abaixo para interagir.');
  UpdateStatus;
end;

procedure TForm1.AppendChat(const ARole, AText: string);
begin
  memChat.Lines.Add(Format('[%s] %s', [ARole, TimeToStr(Now)]));
  memChat.Lines.Add(AText);
  memChat.Lines.Add(EmptyStr);

  // Rola o memo para a última linha adicionada
  SendMessage(memChat.Handle, EM_SCROLLCARET, 0, 0);
end;

procedure TForm1.UpdateStatus(const ACustomMsg: string);
begin
  if not ACustomMsg.IsEmpty then
    lblStatus.Caption := ACustomMsg
  else if Assigned(FLLM) then
    lblStatus.Caption := Format('Mensagens ativas no histórico: %d (Estratégia: %s)',
      [FLLM.Messages.Count, cbbStrategy.Text])
  else
    lblStatus.Caption := 'Pronto';
end;

procedure TForm1.cbbStrategyChange(Sender: TObject);
begin
  if not Assigned(FLLM) then
    Exit;

  case cbbStrategy.ItemIndex of
    0: FLLM.HistoryStrategy := hsSlidingWindow;
    1: FLLM.HistoryStrategy := hsSummarize;
    2: FLLM.HistoryStrategy := hsNone;
  end;

  UpdateStatus;
end;

procedure TForm1.btnAplicarClick(Sender: TObject);
begin
  InitProvider;
end;

procedure TForm1.btnLimparClick(Sender: TObject);
begin
  if Assigned(FLLM) then
  begin
    FLLM.ClearHistory;
    if not Trim(edtSystemPrompt.Text).IsEmpty then
      FLLM.AddSystem(Trim(edtSystemPrompt.Text));
  end;

  memChat.Clear;
  AppendChat('Sistema', 'Histórico de mensagens limpo.');
  UpdateStatus;
end;

procedure TForm1.edtInputKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    Key := 0; // Evita beep
    EnviarMensagem;
  end;
end;

procedure TForm1.btnEnviarClick(Sender: TObject);
begin
  EnviarMensagem;
end;

procedure TForm1.EnviarMensagem;
var
  LUserMsg: string;
begin
  LUserMsg := Trim(edtInput.Text);
  if LUserMsg.IsEmpty then
    Exit;

  // Atualiza credenciais do provedor caso o usuário tenha alterado nos campos
  FLLM.ApiKey := Trim(edtApiKey.Text);
  FLLM.BaseURL := Trim(edtBaseURL.Text);
  FLLM.Model := Trim(edtModel.Text);

  if FLLM.ApiKey.IsEmpty and (Pos('localhost', FLLM.BaseURL) = 0) and (Pos('127.0.0.1', FLLM.BaseURL) = 0) then
  begin
    ShowMessage('Por favor, informe sua API Key antes de enviar uma mensagem.');
    edtApiKey.SetFocus;
    Exit;
  end;

  // 1. Exibe a mensagem do usuário no chat
  AppendChat('Você', LUserMsg);
  edtInput.Clear;

  // 2. Adiciona ao histórico do provedor
  FLLM.AddUser(LUserMsg);

  // 3. Desabilita controles e mostra feedback de carregamento
  btnEnviar.Enabled := False;
  edtInput.Enabled := False;
  UpdateStatus('Aguardando resposta da IA...');

  // 4. Executa a requisição assincronamente para não congelar a interface VCL
  TTask.Run(
    procedure
    var
      LResposta: string;
      LErro: string;
    begin
      LErro := EmptyStr;
      try
        LResposta := FLLM.Send;
      except
        on E: Exception do
          LErro := E.Message;
      end;

      // Retorna para a thread principal da VCL
      TThread.Synchronize(nil,
        procedure
        begin
          btnEnviar.Enabled := True;
          edtInput.Enabled := True;
          edtInput.SetFocus;

          if not LErro.IsEmpty then
            AppendChat('ERRO', LErro)
          else
            AppendChat('Assistente', LResposta);

          UpdateStatus;
        end);

    end);
end;

end.
