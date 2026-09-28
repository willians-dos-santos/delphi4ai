unit Groq.Provider;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.URLClient,
  System.Net.HttpClient,
  LLM.Interfaces,
  LLM.Tools,
  LLM.Base;

const
  GROQ_DEFAULT_URL = 'https://api.groq.com/openai/v1/chat/completions';
  GROQ_DEFAULT_MODEL = 'llama-3.3-70b-versatile';

type
  /// <summary>
  /// Provedor nativo para integracao com o Groq (LPU Inference Engine)
  /// </summary>
  TGroqProvider = class(TLLMProviderBase, IGroqProvider)
  protected
    FRateLimitLimitRequests: Integer;
    FRateLimitRemainingRequests: Integer;
    FRateLimitResetRequests: string;
    FRateLimitLimitTokens: Integer;
    FRateLimitRemainingTokens: Integer;
    FRateLimitResetTokens: string;

    function GetRateLimitLimitRequests: Integer;
    function GetRateLimitRemainingRequests: Integer;
    function GetRateLimitResetRequests: string;
    function GetRateLimitLimitTokens: Integer;
    function GetRateLimitRemainingTokens: Integer;
    function GetRateLimitResetTokens: string;

    procedure PrepareHeaders(AClient: THTTPClient); override;
    procedure DoAfterReceiveResponse(const AResponse: IHTTPResponse); override;
    procedure UpdateRateLimits(const AResponse: IHTTPResponse); virtual;
    function HasToolResultMessage(const AMsgs: TJSONArray): Boolean; virtual;
    function BuildBodyJSON(const AModel: string; ATemp: Double;
      AMaxTok: Integer; AMsgs: TJSONArray): string; override;
  public
    constructor Create(const AApiKey: string;
      const AModel: string = GROQ_DEFAULT_MODEL;
      const ABaseURL: string = GROQ_DEFAULT_URL);

    function GetModelsURL: string;
    function ListModels: TArray<string>;
    procedure UpdateRateLimit(const AHeaderName, AHeaderValue: string); virtual;

    property RateLimitLimitRequests: Integer read GetRateLimitLimitRequests;
    property RateLimitRemainingRequests: Integer read GetRateLimitRemainingRequests;
    property RateLimitResetRequests: string read GetRateLimitResetRequests;
    property RateLimitLimitTokens: Integer read GetRateLimitLimitTokens;
    property RateLimitRemainingTokens: Integer read GetRateLimitRemainingTokens;
    property RateLimitResetTokens: string read GetRateLimitResetTokens;
  end;

implementation

uses
  LLM.Exceptions;

{ TGroqProvider }

constructor TGroqProvider.Create(const AApiKey, AModel, ABaseURL: string);
var
  LURL, LModel: string;
begin
  LURL := ABaseURL;
  if LURL.Trim.IsEmpty then
    LURL := GROQ_DEFAULT_URL;

  LModel := AModel;
  if LModel.Trim.IsEmpty then
    LModel := GROQ_DEFAULT_MODEL;

  inherited Create(AApiKey, LURL, LModel);

  FRateLimitLimitRequests := 0;
  FRateLimitRemainingRequests := 0;
  FRateLimitResetRequests := EmptyStr;
  FRateLimitLimitTokens := 0;
  FRateLimitRemainingTokens := 0;
  FRateLimitResetTokens := EmptyStr;
end;

procedure TGroqProvider.PrepareHeaders(AClient: THTTPClient);
begin
  if FApiKey.Trim.IsEmpty then
    raise Exception.Create('Groq API Key não informada. Forneça uma chave de API válida (ex: gsk_...).');
  inherited PrepareHeaders(AClient);
end;

procedure TGroqProvider.DoAfterReceiveResponse(const AResponse: IHTTPResponse);
begin
  inherited DoAfterReceiveResponse(AResponse);
  UpdateRateLimits(AResponse);
end;

function TGroqProvider.HasToolResultMessage(const AMsgs: TJSONArray): Boolean;
var
  I: Integer;
  LItem: TJSONValue;
  LObj: TJSONObject;
  LRole: string;
begin
  Result := False;
  if AMsgs = nil then
    Exit;

  for I := 0 to AMsgs.Count - 1 do
  begin
    LItem := AMsgs.Items[I];
    if LItem is TJSONObject then
    begin
      LObj := TJSONObject(LItem);
      LRole := LObj.GetValue<string>('role', EmptyStr);
      if SameText(LRole, 'tool') or SameText(LRole, 'function') then
        Exit(True);
    end;
  end;
end;

function TGroqProvider.BuildBodyJSON(const AModel: string; ATemp: Double;
  AMaxTok: Integer; AMsgs: TJSONArray): string;
var
  LHasStructuredOutput, LHasTools: Boolean;
  LSaveTools: ILLMToolRegistry;
  LMsgsToSend: TJSONArray;
  LSysInstruction: TJSONObject;
  LSchemaStr: string;
  LVal: TJSONValue;
  LObj: TJSONObject;
begin
  LHasStructuredOutput := Assigned(FResponseFormat) and (FResponseFormat.FormatType <> rfText);
  LHasTools := Assigned(FTools) and (FTools.Count > 0);

  // A API do Groq proibe estritamente a presenca simultanea de 'tools' e 'response_format'
  // (Erro HTTP 400: "json mode cannot be combined with tool/function calling").
  // Quando ambos sao necessarios (ex: obter previsao via get_current_weather e retornar um Record DTO):
  if LHasStructuredOutput and LHasTools then
  begin
    // Fase 1: As ferramentas ainda nao foram executadas (nenhuma resposta de tool no historico).
    // Enviamos 'tools' para que o modelo possa invocar ferramentas (ex: get_current_weather).
    // Omitimos 'response_format' no payload para nao disparar erro 400, mas injetamos o schema como instrucao de sistema.
    if not HasToolResultMessage(AMsgs) then
    begin
      if Assigned(AMsgs) then
        LMsgsToSend := AMsgs.Clone as TJSONArray
      else
        LMsgsToSend := TJSONArray.Create;

      try
        LSysInstruction := TJSONObject.Create;
        LSysInstruction.AddPair('role', 'system');
        if (FResponseFormat.FormatType = rfJSONSchema) and (FResponseFormat.Schema <> nil) then
          LSchemaStr := FResponseFormat.Schema.ToJSON
        else
          LSchemaStr := '{}';

        LSysInstruction.AddPair('content',
          'IMPORTANTE: Voce pode utilizar as ferramentas disponiveis para obter informacoes se necessario. Ao gerar a resposta final (ou caso ferramentas nao sejam necessarias), responda ESTRITAMENTE em formato JSON valido em conformidade com este schema: ' +
          LSchemaStr);
        LMsgsToSend.AddElement(LSysInstruction);

        Result := inherited BuildBodyJSON(AModel, ATemp, AMaxTok, LMsgsToSend);
      finally
        LMsgsToSend.Free;
      end;

      // Suprime response_format nesta fase para permitir que a Groq processe as tools sem o erro 400
      LVal := TJSONObject.ParseJSONValue(Result);
      if LVal is TJSONObject then
      begin
        LObj := TJSONObject(LVal);
        try
          if LObj.FindValue('response_format') <> nil then
          begin
            LObj.RemovePair('response_format').Free;
            Result := LObj.ToJSON;
          end;
        finally
          LObj.Free;
        end;
      end
      else if Assigned(LVal) then
        LVal.Free;
    end
    else
    begin
      // Fase 2: Pelo menos uma ferramenta ja retornou resultado ('role': 'tool').
      // Agora o modelo deve consolidar a resposta final estritamente no schema solicitado.
      // Suprimimos 'tools' para que a Groq aplique 'response_format' sem conflito.
      LSaveTools := FTools;
      FTools := nil;
      try
        Result := inherited BuildBodyJSON(AModel, ATemp, AMaxTok, AMsgs);
      finally
        FTools := LSaveTools;
      end;

      LVal := TJSONObject.ParseJSONValue(Result);
      if LVal is TJSONObject then
      begin
        LObj := TJSONObject(LVal);
        try
          if LObj.FindValue('tools') <> nil then
            LObj.RemovePair('tools').Free;
          if LObj.FindValue('tool_choice') <> nil then
            LObj.RemovePair('tool_choice').Free;
          Result := LObj.ToJSON;
        finally
          LObj.Free;
        end;
      end
      else if Assigned(LVal) then
        LVal.Free;
    end;
  end
  else
    Result := inherited BuildBodyJSON(AModel, ATemp, AMaxTok, AMsgs);

  // Verificacao defensiva adicional final: assegura que em nenhuma hipotese 'tools' e 'response_format'
  // coexistam no payload final enviado aos endpoints da API do Groq.
  LVal := TJSONObject.ParseJSONValue(Result);
  if LVal is TJSONObject then
  begin
    LObj := TJSONObject(LVal);
    try
      if (LObj.FindValue('response_format') <> nil) and (LObj.FindValue('tools') <> nil) then
      begin
        LObj.RemovePair('tools').Free;
        if LObj.FindValue('tool_choice') <> nil then
          LObj.RemovePair('tool_choice').Free;
        Result := LObj.ToJSON;
      end;
    finally
      LObj.Free;
    end;
  end
  else if Assigned(LVal) then
    LVal.Free;
end;

procedure TGroqProvider.UpdateRateLimit(const AHeaderName, AHeaderValue: string);
var
  LName: string;
begin
  LName := AHeaderName.Trim.ToLower;
  if LName = 'x-ratelimit-limit-requests' then
    FRateLimitLimitRequests := StrToIntDef(AHeaderValue, 0)
  else if LName = 'x-ratelimit-remaining-requests' then
    FRateLimitRemainingRequests := StrToIntDef(AHeaderValue, 0)
  else if LName = 'x-ratelimit-reset-requests' then
    FRateLimitResetRequests := AHeaderValue
  else if LName = 'x-ratelimit-limit-tokens' then
    FRateLimitLimitTokens := StrToIntDef(AHeaderValue, 0)
  else if LName = 'x-ratelimit-remaining-tokens' then
    FRateLimitRemainingTokens := StrToIntDef(AHeaderValue, 0)
  else if LName = 'x-ratelimit-reset-tokens' then
    FRateLimitResetTokens := AHeaderValue;
end;

procedure TGroqProvider.UpdateRateLimits(const AResponse: IHTTPResponse);
const
  GROQ_HEADERS: array[0..5] of string = (
    'x-ratelimit-limit-requests',
    'x-ratelimit-remaining-requests',
    'x-ratelimit-reset-requests',
    'x-ratelimit-limit-tokens',
    'x-ratelimit-remaining-tokens',
    'x-ratelimit-reset-tokens'
  );
var
  LHeader: string;
begin
  if AResponse = nil then
    Exit;

  for LHeader in GROQ_HEADERS do
  begin
    if AResponse.ContainsHeader(LHeader) then
      UpdateRateLimit(LHeader, AResponse.HeaderValue[LHeader]);
  end;
end;

function TGroqProvider.GetModelsURL: string;
begin
  if FBaseURL.Contains('/chat/completions') then
    Result := StringReplace(FBaseURL, '/chat/completions', '/models', [rfIgnoreCase])
  else if FBaseURL.EndsWith('/') then
    Result := FBaseURL + 'models'
  else
    Result := FBaseURL + '/models';
end;

function TGroqProvider.ListModels: TArray<string>;
var
  LClient: THTTPClient;
  LResp: IHTTPResponse;
  LJSONVal, LDataVal, LItemVal, LIdVal: TJSONValue;
  LRoot: TJSONObject;
  LDataArr: TJSONArray;
  I: Integer;
begin
  SetLength(Result, 0);
  if FApiKey.Trim.IsEmpty then
    raise Exception.Create('Groq API Key não informada para listar modelos.');

  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := 5000;
    LClient.ResponseTimeout := 10000;
    PrepareHeaders(LClient);
    try
      LResp := LClient.Get(GetModelsURL);
      if LResp.StatusCode <> 200 then
        Exit;

      LJSONVal := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8));
      if LJSONVal is TJSONObject then
      begin
        LRoot := TJSONObject(LJSONVal);
        try
          LDataVal := LRoot.FindValue('data');
          if LDataVal is TJSONArray then
          begin
            LDataArr := TJSONArray(LDataVal);
            SetLength(Result, LDataArr.Count);
            for I := 0 to LDataArr.Count - 1 do
            begin
              LItemVal := LDataArr.Items[I];
              if LItemVal is TJSONObject then
              begin
                LIdVal := TJSONObject(LItemVal).FindValue('id');
                if LIdVal is TJSONString then
                  Result[I] := LIdVal.Value
                else
                  Result[I] := EmptyStr;
              end;
            end;
          end;
        finally
          LRoot.Free;
        end;
      end
      else if Assigned(LJSONVal) then
        LJSONVal.Free;
    except
      SetLength(Result, 0);
    end;
  finally
    LClient.Free;
  end;
end;

function TGroqProvider.GetRateLimitLimitRequests: Integer;
begin
  Result := FRateLimitLimitRequests;
end;

function TGroqProvider.GetRateLimitRemainingRequests: Integer;
begin
  Result := FRateLimitRemainingRequests;
end;

function TGroqProvider.GetRateLimitResetRequests: string;
begin
  Result := FRateLimitResetRequests;
end;

function TGroqProvider.GetRateLimitLimitTokens: Integer;
begin
  Result := FRateLimitLimitTokens;
end;

function TGroqProvider.GetRateLimitRemainingTokens: Integer;
begin
  Result := FRateLimitRemainingTokens;
end;

function TGroqProvider.GetRateLimitResetTokens: string;
begin
  Result := FRateLimitResetTokens;
end;

end.
