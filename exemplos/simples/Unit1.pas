unit Unit1;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.TypInfo,
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
  LLM.Exceptions,
  LLM.Schema,
  LLM.Client;

type
  /// <summary>
  /// Enum para demonstrar suporte a tipos enumerados no schema JSON
  /// </summary>
  TClimaCondicao = (ccEnsolarado, ccNublado, ccChuvoso, ccTempestade,
    ccNevando);

  /// <summary>
  /// Record DTO para teste de Saida Estruturada (Stack allocated / Zero memory leak)
  /// </summary>
  [TLLMSchema('PrevisaoTempo', 'Previsao meteorologica estruturada')]
  TPrevisaoTempoRecord = record [TLLMProperty('Nome da cidade')]
    Cidade: string;

    [TLLMProperty('Temperatura estimada em graus Celsius')]
    Temperatura: Double;

    [TLLMProperty('Umidade relativa do ar em porcentagem (0 a 100)')]
    Umidade: Integer;

    [TLLMProperty('Indica se esta chovendo')]
    Chovendo: Boolean;

    [TLLMProperty('Condicao do clima')]
    Condicao: TClimaCondicao;

    [TLLMProperty('Recomendacao ou alerta para o usuario')]
    Recomendacao: string;
  end;

  /// <summary>
  /// Classe DTO para teste de Saida Estruturada baseada em Classes
  /// </summary>
  [TLLMSchema('PerfilProfissional', 'Perfil profissional estruturado')]
  TPerfilUsuarioClass = class
  private
    FNome: string;
    FIdade: Integer;
    FProfissao: string;
    FCompetencias: string;
    FAtivo: Boolean;
  published
    [TLLMProperty('Nome completo da pessoa')]
    property Nome: string read FNome write FNome;

    [TLLMProperty('Idade em anos')]
    property Idade: Integer read FIdade write FIdade;

    [TLLMProperty('Profissao ou especialidade')]
    property Profissao: string read FProfissao write FProfissao;

    [TLLMProperty('Principais habilidades ou competencias tecnicas')]
    property Competencias: string read FCompetencias write FCompetencias;

    [TLLMProperty('Se o cadastro esta ativo')]
    property Ativo: Boolean read FAtivo write FAtivo;
  end;

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
    btnTestRecord: TButton;
    btnTestClass: TButton;
    Label1: TLabel;
    cbProvider: TComboBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnEnviarClick(Sender: TObject);
    procedure edtInputKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure btnLimparClick(Sender: TObject);
    procedure btnAplicarClick(Sender: TObject);
    procedure cbbStrategyChange(Sender: TObject);
    procedure btnTestRecordClick(Sender: TObject);
    procedure btnTestClassClick(Sender: TObject);
    procedure cbProviderChange(Sender: TObject);
  private
    FLLM: TLLMClient;
    procedure InitProvider;
    procedure AppendChat(const ARole, AText: string);
    procedure UpdateStatus(const ACustomMsg: string = '');
    procedure PrepararRequisicao(const AStatusMsg: string);
    procedure FinalizarRequisicao;
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

  cbProvider.Items.Text := EmptyStr.Join(sLineBreak, TLLMProviderType.Names);
  cbProvider.ItemIndex := ptOpenAI.Index;
  cbProviderChange(nil);
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  // FLLM.Free;
end;
 
procedure TForm1.cbProviderChange(Sender: TObject);
begin
  case TLLMProviderType.FromStr(cbProvider.Text) of
    ptOpenAI:
    begin
      edtBaseURL.Text := 'https://api.openai.com/v1/chat/completions';
      edtModel.Text := 'gpt-4o-mini';
      edtApiKey.TextHint := 'Cole sua API Key aqui (sk-...)';
    end;
    ptOllama:
    begin
      edtBaseURL.Text := 'http://localhost:11434/api/chat';
      edtModel.Text := 'llama3.2';
      edtApiKey.TextHint := 'Opcional para Ollama local';
    end;
    ptGroq:
    begin
      edtBaseURL.Text := 'https://api.groq.com/openai/v1/chat/completions';
      edtModel.Text := 'llama-3.3-70b-versatile';
      edtApiKey.TextHint := 'Cole sua Groq API Key aqui (gsk_...)';
    end;
  end;
  InitProvider;
end;

procedure TForm1.InitProvider;
var
  LApiKey, LBaseURL, LModel: string;
begin
  LApiKey := Trim(edtApiKey.Text);
  LBaseURL := Trim(edtBaseURL.Text);
  LModel := Trim(edtModel.Text);

  if Pos('11434', LBaseURL) > 0 then
  begin
    if Pos('/v1', LBaseURL) > 0 then
    begin
      LBaseURL := StringReplace(LBaseURL, '/v1/chat/completions', '/api/chat',
        [rfIgnoreCase]);
      edtBaseURL.Text := LBaseURL;
    end;

  end;


  FLLM := CreateLLMProvider(TLLMProviderType.FromStr(cbProvider.Text), LApiKey,
    LModel, LBaseURL);

  FLLM.HistoryStrategy := HISTORY_STRATEGY[cbbStrategy.ItemIndex];
  FLLM.MaxHistoryMessages := 10;
  FLLM.KeepRecentMessages := 4;

  if not Trim(edtSystemPrompt.Text).IsEmpty then
    FLLM.AddSystem(Trim(edtSystemPrompt.Text));

  // Registra funcoes de exemplo (Tools / Function Calling)
  FLLM.RegisterFunction('obter_hora_atual',
    'Retorna a data e hora atual do sistema local',
    '{"type":"object","properties":{}}',
    function(const AArgs: string): string
    begin
      Result := Format('{"data_hora": "%s"}', [DateTimeToStr(Now)]);
    end);

  FLLM.RegisterFunction('consultar_cotacao_moeda',
    'Retorna a cotacao estimada de uma moeda em Reais (BRL)',
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

        Result := Format('{"moeda":"%s","cotacao_brl":%.2f}',
          [LMoeda, LCotacao]);
      finally
        LArgs.Free;
      end;
    end);

  FLLM.RegisterTool(TWeatherAPI);

  // Notificacoes visuais de execucao de tools
  FLLM.OnBeforeExecuteTool := procedure(const ACall: TLLMToolCall)
    begin
      TThread.Synchronize(nil,
        procedure
        begin
          AppendChat('Ferramenta (Chamada)',
            Format('Funcao "%s" invocada pelo modelo com argumentos: %s',
            [ACall.Name, ACall.Arguments]));
        end);
    end;

  FLLM.OnAfterExecuteTool :=
      procedure(const ACall: TLLMToolCall; const AResult: string;
    const ASuccess: Boolean)
    begin
      TThread.Synchronize(nil,
        procedure
        begin
          AppendChat('Ferramenta (Retorno)', Format('Retorno de "%s": %s',
            [ACall.Name, AResult]));
        end);
    end;

  memChat.Clear;
  AppendChat('Sistema',
    Format('Conversa iniciada com o modelo "%s". Tools registradas: [%s].',
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
  else if FLLM.IsAssigned then
    lblStatus.Caption :=
      Format('Mensagens ativas no historico: %d (Estrategia: %s, Tools: %d)',
      [FLLM.Messages.Count, cbbStrategy.Text, FLLM.Tools.Count])
  else
    lblStatus.Caption := 'Pronto';
end;

procedure TForm1.cbbStrategyChange(Sender: TObject);
begin
  if not FLLM.IsAssigned then
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
  if FLLM.IsAssigned then
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

procedure TForm1.PrepararRequisicao(const AStatusMsg: string);
begin
  btnEnviar.Enabled := False;
  btnLimpar.Enabled := False;
  btnTestRecord.Enabled := False;
  btnTestClass.Enabled := False;
  edtInput.Enabled := False;
  UpdateStatus(AStatusMsg);
end;

procedure TForm1.FinalizarRequisicao;
begin
  btnEnviar.Enabled := True;
  btnLimpar.Enabled := True;
  btnTestRecord.Enabled := True;
  btnTestClass.Enabled := True;
  edtInput.Enabled := True;
  edtInput.SetFocus;
  UpdateStatus;
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
  PrepararRequisicao('Aguardando resposta da IA...');

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
          FinalizarRequisicao;

          if not LErro.IsEmpty then
            AppendChat('ERRO', LErro)
          else
            AppendChat('Assistente', LResposta);
        end);

    end);
end;

procedure TForm1.btnTestRecordClick(Sender: TObject);
var
  LPrompt: string;
begin
  LPrompt := Trim(edtInput.Text);
  if LPrompt.IsEmpty then
    LPrompt :=
      'Qual a previsao do tempo para a cidade de Gramado/RS hoje? Utilize as ferramentas de clima disponiveis e responda estritamente em formato JSON conforme o schema.';

  AppendChat('Voce [Structured Output - Record]', LPrompt);
  edtInput.Clear;

  PrepararRequisicao('Solicitando Saida Estruturada (Record)...');

  TTask.Run(
    procedure
    var
      LPrevisao: TPrevisaoTempoRecord;
      LErro: string;
      LChovendoStr: string;
      LCondicaoStr: string;
    begin
      LErro := EmptyStr;
      try
        FLLM.ApiKey := Trim(edtApiKey.Text);
        FLLM.BaseURL := Trim(edtBaseURL.Text);
        FLLM.Model := Trim(edtModel.Text);

        FLLM.AddUser(LPrompt);
        LPrevisao := FLLM.SendAs<TPrevisaoTempoRecord>;
      except
        on E: Exception do
          LErro := E.Message;
      end;

      TThread.Synchronize(nil,
        procedure
        begin
          FinalizarRequisicao;

          if not LErro.IsEmpty then
            AppendChat('ERRO', LErro)
          else
          begin
            if LPrevisao.Chovendo then
              LChovendoStr := 'Sim'
            else
              LChovendoStr := 'Nao';

            LCondicaoStr := GetEnumName(TypeInfo(TClimaCondicao),
              Ord(LPrevisao.Condicao));

            AppendChat('Assistente [Record Tipado]',
              Format('=== DTO RECEBIDO COM SUCESSO (Record sem memory leak) ==='
              + sLineBreak + '  • Cidade: %s' + sLineBreak +
              '  • Temperatura: %.1f °C' + sLineBreak + '  • Umidade: %d%%' +
              sLineBreak + '  • Chovendo: %s' + sLineBreak + '  • Condicao: %s'
              + sLineBreak + '  • Recomendacao: %s', [LPrevisao.Cidade,
              LPrevisao.Temperatura, LPrevisao.Umidade, LChovendoStr,
              LCondicaoStr, LPrevisao.Recomendacao]));
          end;
        end);
    end);
end;

procedure TForm1.btnTestClassClick(Sender: TObject);
var
  LPrompt: string;
begin
  LPrompt := Trim(edtInput.Text);
  if LPrompt.IsEmpty then
    LPrompt :=
      'Gere o perfil de um Arquiteto de Software Delphi experiente chamado Marcelo. Responda estritamente em formato JSON conforme o schema.';

  AppendChat('Voce [Structured Output - Classe]', LPrompt);
  edtInput.Clear;

  PrepararRequisicao('Solicitando Saida Estruturada (Classe)...');

  TTask.Run(
    procedure
    var
      LPerfil: TPerfilUsuarioClass;
      LErro: string;
      LAtivoStr: string;
    begin
      LErro := EmptyStr;
      LPerfil := nil;
      try
        FLLM.ApiKey := Trim(edtApiKey.Text);
        FLLM.BaseURL := Trim(edtBaseURL.Text);
        FLLM.Model := Trim(edtModel.Text);

        FLLM.AddUser(LPrompt);
        LPerfil := FLLM.SendAs<TPerfilUsuarioClass>;
      except
        on E: Exception do
          LErro := E.Message;
      end;

      TThread.Synchronize(nil,
        procedure
        begin
          try
            FinalizarRequisicao;

            if not LErro.IsEmpty then
              AppendChat('ERRO', LErro)
            else if Assigned(LPerfil) then
            begin
              if LPerfil.Ativo then
                LAtivoStr := 'Sim'
              else
                LAtivoStr := 'Nao';

              AppendChat('Assistente [Classe Tipada]',
                Format('=== DTO RECEBIDO COM SUCESSO (Instancia de Classe) ==='
                + sLineBreak + '  • Nome: %s' + sLineBreak +
                '  • Idade: %d anos' + sLineBreak + '  • Profissao: %s' +
                sLineBreak + '  • Competencias: %s' + sLineBreak +
                '  • Ativo: %s', [LPerfil.Nome, LPerfil.Idade,
                LPerfil.Profissao, LPerfil.Competencias, LAtivoStr]));
            end;
          finally
            LPerfil.Free;
          end;
        end);
    end);
end;

end.
