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
  System.JSON,
  LLM.Interfaces,
  LLM.HistoryStrategy,
  LLM.Tools,
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
    procedure edtInputKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
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
  LLM.Factory,
  uWeatherTool;

{$R *.dfm}

{ TForm1 }

const
  HISTORY_STRATEGY: array [0 .. 2] of THistoryStrategy = (hsSlidingWindow,
    hsSummarize, hsNone);

procedure TForm1.FormCreate(Sender: TObject);
begin
  InitProvider;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  // FLLM.Free;
end;

procedure TForm1.InitProvider;
begin
  FLLM := CreateLLMProvider(Trim(edtApiKey.Text), Trim(edtBaseURL.Text),
    Trim(edtModel.Text));

  FLLM.HistoryStrategy := HISTORY_STRATEGY[cbbStrategy.ItemIndex];
  FLLM.MaxHistoryMessages := 10;
  FLLM.KeepRecentMessages := 4;

  if not Trim(edtSystemPrompt.Text).IsEmpty then
    FLLM.AddSystem(Trim(edtSystemPrompt.Text));

  // Registra funcoes de exemplo (Tools / Function Calling)
  FLLM.RegisterFunction('obter_hora_atual', 'Retorna a data e hora atual do sistema local',
    '{"type":"object","properties":{}}',
    function(const AArgs: string): string
    begin
      Result := Format('{"data_hora": "%s"}', [DateTimeToStr(Now)]);
    end);

  FLLM.RegisterFunction('consultar_cotacao_moeda', 'Retorna a cotacao estimada de uma moeda em Reais (BRL)',
    '{"type":"object","properties":{"moeda":{"type":"string","description":"Sigla da moeda, ex: USD, EUR, BTC"}},"required":["moeda"]}',
    function(const AArgs: string): string
    var
      LArgs: TJSONObject;
      LMoeda: string;
      LCotacao: Double;
    begin
      LArgs := TJSONObject.ParseJSONValue(AArgs) as TJSONObject;
      try
        LMoeda := 'USD';
        if Assigned(LArgs) then
          LMoeda := UpperCase(LArgs.GetValue<string>('moeda', 'USD'));

        if LMoeda = 'EUR' then
          LCotacao := 6.10
        else if LMoeda = 'BTC' then
          LCotacao := 350000.00
        else
          LCotacao := 5.45;

        Result := Format('{"moeda":"%s","cotacao_brl":%.2f}', [LMoeda, LCotacao]);
      finally
        LArgs.Free;
      end;
    end);

  FLLM.RegisterTool(TWeatherAPI);

  // Notificacoes visuais de execucao de tools
  FLLM.OnBeforeExecuteTool :=
    procedure(const ACall: TLLMToolCall)
    begin
      TThread.Synchronize(nil,
        procedure
        begin
          AppendChat('Ferramenta (Chamada)',
            Format('Funcao "%s" invocada pelo modelo com argumentos: %s', [ACall.Name, ACall.Arguments]));
        end);
    end;

  FLLM.OnAfterExecuteTool :=
    procedure(const ACall: TLLMToolCall; const AResult: string; const ASuccess: Boolean)
    begin
      TThread.Synchronize(nil,
        procedure
        begin
          AppendChat('Ferramenta (Retorno)',
            Format('Retorno de "%s": %s', [ACall.Name, AResult]));
        end);
    end;

  memChat.Clear;
  AppendChat('Sistema', Format('Conversa iniciada com o modelo "%s". Tools registradas: [%s].',
    [FLLM.Model, string.Join(', ', FLLM.Tools.GetNames)]));
  UpdateStatus;
end;

procedure TForm1.AppendChat(const ARole, AText: string);
begin
  memChat.Lines.Add(Format('[%s] %s', [ARole, TimeToStr(Now)]));
  memChat.Lines.Add(AText);
  memChat.Lines.Add(EmptyStr);

  SendMessage(memChat.Handle, EM_SCROLLCARET, 0, 0);
end;

procedure TForm1.UpdateStatus(const ACustomMsg: string);
begin
  if not ACustomMsg.IsEmpty then
    lblStatus.Caption := ACustomMsg
  else if Assigned(FLLM) then
    lblStatus.Caption :=
      Format('Mensagens ativas no historico: %d (Estrategia: %s, Tools: %d)',
      [FLLM.Messages.Count, cbbStrategy.Text, FLLM.Tools.Count])
  else
    lblStatus.Caption := 'Pronto';
end;

procedure TForm1.cbbStrategyChange(Sender: TObject);
begin
  if not Assigned(FLLM) then
    Exit;

  FLLM.HistoryStrategy := HISTORY_STRATEGY[cbbStrategy.ItemIndex];
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
  AppendChat('Sistema', 'Historico de mensagens limpo.');
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

  // Atualiza credenciais do provedor caso o usuario tenha alterado nos campos
  FLLM.ApiKey := Trim(edtApiKey.Text);
  FLLM.BaseURL := Trim(edtBaseURL.Text);
  FLLM.Model := Trim(edtModel.Text);

  if FLLM.ApiKey.IsEmpty and (Pos('localhost', FLLM.BaseURL) = 0) and
    (Pos('127.0.0.1', FLLM.BaseURL) = 0) then
  begin
    ShowMessage('Por favor, informe sua API Key antes de enviar uma mensagem.');
    edtApiKey.SetFocus;
    Exit;
  end;

  // 1. Exibe a mensagem do usuario no chat
  AppendChat('Voce', LUserMsg);
  edtInput.Clear;

  // 2. Adiciona ao historico do provedor
  FLLM.AddUser(LUserMsg);

  // 3. Desabilita controles e mostra feedback de carregamento
  btnEnviar.Enabled := False;
  edtInput.Enabled := False;
  UpdateStatus('Aguardando resposta da IA...');

  // 4. Executa a requisicao assincronamente para nao congelar a interface VCL
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