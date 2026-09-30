unit Gemini.Provider;

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
  GEMINI_DEFAULT_URL = 'https://generativelanguage.googleapis.com/v1beta';
  GEMINI_DEFAULT_MODEL = 'gemini-2.5-flash';

type
  /// <summary>
  /// Provedor nativo para integracao com a API REST do Google Gemini (generateContent)
  /// </summary>
  TGeminiProvider = class(TLLMProviderBase, IGeminiProvider)
  private
    function FindToolNameById(const AToolCallId: string): string;
    function ConvertSchemaTypesToUppercase(const ASchema: TJSONObject): TJSONObject;
  protected
    FPromptTokenCount: Integer;
    FCandidatesTokenCount: Integer;
    FTotalTokenCount: Integer;

    function GetPromptTokenCount: Integer;
    function GetCandidatesTokenCount: Integer;
    function GetTotalTokenCount: Integer;

    procedure PrepareHeaders(AClient: THTTPClient); override;
    function BuildBodyJSON(const AModel: string; ATemp: Double;
      AMaxTok: Integer; AMsgs: TJSONArray): string; override;
    function ExtractErrorMessage(const AErrorJSON: string): string; override;
    function ExecuteRequest(const ABodyJSON: string;
      out ARawJSON: string): string; override;
    procedure AppendAssistantToolCallsToHistory(const ARawJSON: string); override;
  public
    constructor Create(const AApiKey: string;
      const AModel: string = GEMINI_DEFAULT_MODEL;
      const ABaseURL: string = GEMINI_DEFAULT_URL);

    procedure AddToolResult(const AToolCallId, AContent: string); override;
    function HasToolResultMessage(const AMsgs: TJSONArray): Boolean; virtual;

    function GetGenerateContentURL: string;
    function GetModelsURL: string;
    function ListModels: TArray<string>;

    property PromptTokenCount: Integer read GetPromptTokenCount;
    property CandidatesTokenCount: Integer read GetCandidatesTokenCount;
    property TotalTokenCount: Integer read GetTotalTokenCount;
  end;

implementation

uses
  LLM.Exceptions;

{ TGeminiProvider }

constructor TGeminiProvider.Create(const AApiKey, AModel, ABaseURL: string);
var
  LURL, LModel: string;
begin
  LURL := ABaseURL;
  if LURL.Trim.IsEmpty then
    LURL := GEMINI_DEFAULT_URL;

  LModel := AModel;
  if LModel.Trim.IsEmpty then
    LModel := GEMINI_DEFAULT_MODEL;

  inherited Create(AApiKey, LURL, LModel);

  FPromptTokenCount := 0;
  FCandidatesTokenCount := 0;
  FTotalTokenCount := 0;
end;

function TGeminiProvider.GetPromptTokenCount: Integer;
begin
  Result := FPromptTokenCount;
end;

function TGeminiProvider.GetCandidatesTokenCount: Integer;
begin
  Result := FCandidatesTokenCount;
end;

function TGeminiProvider.GetTotalTokenCount: Integer;
begin
  Result := FTotalTokenCount;
end;

procedure TGeminiProvider.PrepareHeaders(AClient: THTTPClient);
begin
  if FApiKey.Trim.IsEmpty then
    raise Exception.Create('Gemini API Key não informada. Forneça uma chave de API válida.');
  AClient.CustomHeaders['x-goog-api-key'] := FApiKey.Trim;
  AClient.CustomHeaders['Content-Type'] := 'application/json';
end;

function TGeminiProvider.GetGenerateContentURL: string;
var
  LBase, LModel: string;
begin
  LModel := FModel.Trim;
  if LModel.IsEmpty then
    LModel := GEMINI_DEFAULT_MODEL;

  if FBaseURL.Contains(':generateContent') then
    Result := FBaseURL
  else
  begin
    LBase := FBaseURL.TrimRight(['/']);

    // Remove rotas residuais de OpenAI/Groq se tiverem sido herdadas ou coladas
    if LBase.EndsWith('/chat/completions', True) then
      LBase := LBase.Substring(0, LBase.Length - Length('/chat/completions')).TrimRight(['/']);
    if LBase.EndsWith('/openai', True) then
      LBase := LBase.Substring(0, LBase.Length - Length('/openai')).TrimRight(['/']);
    if LBase.EndsWith('/v1', True) then
      LBase := LBase.Substring(0, LBase.Length - Length('/v1')).TrimRight(['/']);

    // Se a URL residual pertencia a outro provedor (OpenAI, Groq, Ollama)
    if LBase.Contains('api.openai.com') or LBase.Contains('api.groq.com') or
       LBase.Contains('localhost:11434') or LBase.Contains('127.0.0.1:11434') or
       LBase.IsEmpty then
    begin
      LBase := GEMINI_DEFAULT_URL;
    end
    else if not LBase.Contains('/v1') and not LBase.Contains('/v1beta') then
    begin
      LBase := LBase + '/v1beta';
    end;

    Result := Format('%s/models/%s:generateContent', [LBase, LModel]);
  end;

  if not FApiKey.Trim.IsEmpty and not Result.Contains('key=') then
  begin
    if Result.Contains('?') then
      Result := Result + '&key=' + FApiKey.Trim
    else
      Result := Result + '?key=' + FApiKey.Trim;
  end;
end;

function TGeminiProvider.FindToolNameById(const AToolCallId: string): string;
var
  I, J: Integer;
  LMsgObj: TJSONObject;
  LToolCalls: TJSONArray;
  LCallObj, LFuncObj: TJSONObject;
begin
  Result := EmptyStr;

  // 1. Procura nas ultimas tool calls em memoria
  for I := 0 to Length(FLastToolCalls) - 1 do
  begin
    if SameText(FLastToolCalls[I].Id, AToolCallId) then
      Exit(FLastToolCalls[I].Name);
  end;

  // 2. Busca no historico em ordem reversa
  if Assigned(FMessages) then
  begin
    for I := FMessages.Count - 1 downto 0 do
    begin
      if FMessages.Items[I] is TJSONObject then
      begin
        LMsgObj := TJSONObject(FMessages.Items[I]);
        if LMsgObj.FindValue('tool_calls') is TJSONArray then
        begin
          LToolCalls := TJSONArray(LMsgObj.FindValue('tool_calls'));
          for J := 0 to LToolCalls.Count - 1 do
          begin
            if LToolCalls.Items[J] is TJSONObject then
            begin
              LCallObj := TJSONObject(LToolCalls.Items[J]);
              if SameText(LCallObj.GetValue<string>('id', EmptyStr), AToolCallId) then
              begin
                if LCallObj.FindValue('function') is TJSONObject then
                begin
                  LFuncObj := TJSONObject(LCallObj.FindValue('function'));
                  Exit(LFuncObj.GetValue<string>('name', EmptyStr));
                end;
              end;
            end;
          end;
        end;
      end;
    end;
  end;

  // Se houver exatamente 1 tool call recente, assume o nome dela como fallback
  if Length(FLastToolCalls) = 1 then
    Exit(FLastToolCalls[0].Name);
end;

procedure TGeminiProvider.AddToolResult(const AToolCallId, AContent: string);
var
  LMsg: TJSONObject;
  LName: string;
begin
  LName := FindToolNameById(AToolCallId);
  LMsg := TJSONObject.Create;
  LMsg.AddPair('role', 'tool');
  LMsg.AddPair('tool_call_id', AToolCallId);
  if not LName.IsEmpty then
    LMsg.AddPair('name', LName);
  LMsg.AddPair('content', AContent);
  FMessages.AddElement(LMsg);
end;

function TGeminiProvider.HasToolResultMessage(const AMsgs: TJSONArray): Boolean;
var
  I: Integer;
  LItem: TJSONValue;
  LObj: TJSONObject;
  LRole: string;
begin
  Result := False;
  if AMsgs = nil then
    Exit;

  // Percorre de tras para frente para analisar o turno atual
  for I := AMsgs.Count - 1 downto 0 do
  begin
    LItem := AMsgs.Items[I];
    if LItem is TJSONObject then
    begin
      LObj := TJSONObject(LItem);
      LRole := LObj.GetValue<string>('role', EmptyStr);

      // Se encontrou retorno de tool antes do ultimo user, ja houve execucao de tool neste turno
      if SameText(LRole, 'tool') or SameText(LRole, 'function') then
        Exit(True);

      // Se encontrou a ultima mensagem do usuario sem passar por nenhuma tool, as tools ainda nao rodaram neste turno
      if SameText(LRole, 'user') then
        Exit(False);
    end;
  end;
end;

function TGeminiProvider.ConvertSchemaTypesToUppercase(const ASchema: TJSONObject): TJSONObject;
var
  LCloned: TJSONObject;

  procedure ProcessObject(AObj: TJSONObject);
  var
    I, J: Integer;
    LPair: TJSONPair;
    LVal: TJSONValue;
    LArr: TJSONArray;
  begin
    if AObj = nil then Exit;

    for I := AObj.Count - 1 downto 0 do
    begin
      LPair := AObj.Pairs[I];
      var LKey := LPair.JsonString.Value;
      LVal := LPair.JsonValue;

      // Gemini proibe campos como 'additionalProperties', 'title', '$schema', etc. no seu Schema
      if SameText(LKey, 'additionalProperties') or
         SameText(LKey, 'title') or
         SameText(LKey, '$schema') or
         SameText(LKey, '$defs') or
         SameText(LKey, 'definitions') then
      begin
        AObj.RemovePair(LKey).Free;
        Continue;
      end;

      if SameText(LKey, 'type') and (LVal is TJSONString) then
      begin
        LPair.JsonValue := TJSONString.Create(TJSONString(LVal).Value.ToUpper);
      end
      else if LVal is TJSONObject then
        ProcessObject(TJSONObject(LVal))
      else if LVal is TJSONArray then
      begin
        LArr := TJSONArray(LVal);
        for J := 0 to LArr.Count - 1 do
        begin
          if LArr.Items[J] is TJSONObject then
            ProcessObject(TJSONObject(LArr.Items[J]));
        end;
      end;
    end;
  end;

begin
  if ASchema = nil then
    Exit(nil);

  LCloned := ASchema.Clone as TJSONObject;
  try
    ProcessObject(LCloned);
    Result := LCloned;
  except
    LCloned.Free;
    raise;
  end;
end;

function TGeminiProvider.BuildBodyJSON(const AModel: string; ATemp: Double;
  AMaxTok: Integer; AMsgs: TJSONArray): string;
var
  LBody, LGenConfig: TJSONObject;
  LContentsArr, LToolsArr: TJSONArray;
  LSysInstruction, LSysPart: TJSONObject;
  LSysParts: TJSONArray;
  LHasSystem: Boolean;
  I, J: Integer;
  LItem: TJSONValue;
  LMsgObj: TJSONObject;
  LRole, LContent, LToolId, LToolName, LArgsStr: string;
  LGeminiRole: string;
  LTurnObj, LPartObj, LCallPart, LRespPart, LFuncCallObj, LFuncRespObj, LArgsObj, LRespDataObj: TJSONObject;
  LTurnParts: TJSONArray;
  LToolCallsVal, LParsedVal: TJSONValue;
  LToolCallsArr: TJSONArray;
  LCallObj, LFuncObj: TJSONObject;
  LToolDeclsArr: TJSONArray;
  LToolsRawArr: TJSONArray;
  LToolItemVal, LToolFuncVal: TJSONValue;
  LToolItemObj, LToolFuncObj, LToolDeclObj, LToolWrapObj: TJSONObject;
  LToolParamObj: TJSONObject;
  LConvertedSchema: TJSONObject;
  LLastTurn: TJSONObject;
  LHasStructuredOutput, LHasTools, LHasToolResults: Boolean;
  LSchemaStr: string;
  LGCDef: TJSONObject;
begin
  LBody := TJSONObject.Create;
  try
    // 1. Processa System Instructions e monta as mensagens
    LSysParts := nil;
    LHasSystem := False;

    LContentsArr := TJSONArray.Create;

    if Assigned(AMsgs) then
    begin
      for I := 0 to AMsgs.Count - 1 do
      begin
        LItem := AMsgs.Items[I];
        if not (LItem is TJSONObject) then
          Continue;

        LMsgObj := TJSONObject(LItem);
        LRole := LMsgObj.GetValue<string>('role', EmptyStr).ToLower;
        LContent := LMsgObj.GetValue<string>('content', EmptyStr);

        // System Instruction do Gemini
        if (LRole = 'system') then
        begin
          if not LContent.IsEmpty then
          begin
            if LSysParts = nil then
              LSysParts := TJSONArray.Create;
            LSysPart := TJSONObject.Create;
            LSysPart.AddPair('text', LContent);
            LSysParts.AddElement(LSysPart);
            LHasSystem := True;
          end;
          Continue;
        end;

        // Determina a role equivalente no Gemini
        if (LRole = 'assistant') or (LRole = 'model') then
          LGeminiRole := 'model'
        else // 'user', 'tool', 'function'
          LGeminiRole := 'user';

        // Verifica se a role e identica ao ultimo turn ja adicionado (para alternar estritamente)
        LTurnObj := nil;
        LTurnParts := nil;
        if LContentsArr.Count > 0 then
        begin
          LLastTurn := TJSONObject(LContentsArr.Items[LContentsArr.Count - 1]);
          if SameText(LLastTurn.GetValue<string>('role', EmptyStr), LGeminiRole) then
          begin
            LTurnObj := LLastTurn;
            LTurnParts := TJSONArray(LTurnObj.FindValue('parts'));
          end;
        end;

        if LTurnObj = nil then
        begin
          LTurnObj := TJSONObject.Create;
          LTurnObj.AddPair('role', LGeminiRole);
          LTurnParts := TJSONArray.Create;
          LTurnObj.AddPair('parts', LTurnParts);
          LContentsArr.AddElement(LTurnObj);
        end;

        // Trata os tipos de conteudo
        if LRole = 'tool' then
        begin
          LToolId := LMsgObj.GetValue<string>('tool_call_id', EmptyStr);
          LToolName := LMsgObj.GetValue<string>('name', EmptyStr);
          if LToolName.IsEmpty then
            LToolName := FindToolNameById(LToolId);
          if LToolName.IsEmpty then
            LToolName := 'tool_function';

          LRespPart := TJSONObject.Create;
          LFuncRespObj := TJSONObject.Create;
          LFuncRespObj.AddPair('name', LToolName);
          if not LToolId.IsEmpty then
            LFuncRespObj.AddPair('id', LToolId);

          // Verifica se o conteudo retornado pela tool e um objeto JSON
          LParsedVal := TJSONObject.ParseJSONValue(LContent);
          if LParsedVal is TJSONObject then
            LRespDataObj := TJSONObject(LParsedVal)
          else
          begin
            if Assigned(LParsedVal) then
              LParsedVal.Free;
            LRespDataObj := TJSONObject.Create;
            LRespDataObj.AddPair('output', LContent);
          end;

          LFuncRespObj.AddPair('response', LRespDataObj);
          LRespPart.AddPair('functionResponse', LFuncRespObj);
          LTurnParts.AddElement(LRespPart);
        end
        else if (LRole = 'assistant') or (LRole = 'model') then
        begin
          LToolCallsVal := LMsgObj.FindValue('tool_calls');
          if (LToolCallsVal is TJSONArray) and (TJSONArray(LToolCallsVal).Count > 0) then
          begin
            LToolCallsArr := TJSONArray(LToolCallsVal);
            for J := 0 to LToolCallsArr.Count - 1 do
            begin
              if LToolCallsArr.Items[J] is TJSONObject then
              begin
                LCallObj := TJSONObject(LToolCallsArr.Items[J]);
                LToolId := LCallObj.GetValue<string>('id', EmptyStr);
                LToolName := EmptyStr;
                LArgsStr := '{}';

                if LCallObj.FindValue('function') is TJSONObject then
                begin
                  LFuncObj := TJSONObject(LCallObj.FindValue('function'));
                  LToolName := LFuncObj.GetValue<string>('name', EmptyStr);
                  LArgsStr := LFuncObj.GetValue<string>('arguments', '{}');
                end;

                LCallPart := TJSONObject.Create;
                LFuncCallObj := TJSONObject.Create;
                LFuncCallObj.AddPair('name', LToolName);
                if not LToolId.IsEmpty then
                  LFuncCallObj.AddPair('id', LToolId);

                LParsedVal := TJSONObject.ParseJSONValue(LArgsStr);
                if LParsedVal is TJSONObject then
                  LArgsObj := TJSONObject(LParsedVal)
                else
                begin
                  if Assigned(LParsedVal) then
                    LParsedVal.Free;
                  LArgsObj := TJSONObject.Create;
                end;

                LFuncCallObj.AddPair('args', LArgsObj);
                LCallPart.AddPair('functionCall', LFuncCallObj);
                LTurnParts.AddElement(LCallPart);
              end;
            end;
          end;

          if not LContent.IsEmpty then
          begin
            LPartObj := TJSONObject.Create;
            LPartObj.AddPair('text', LContent);
            LTurnParts.AddElement(LPartObj);
          end;
        end
        else
        begin
          // Mensagem de usuario normal
          LPartObj := TJSONObject.Create;
          LPartObj.AddPair('text', LContent);
          LTurnParts.AddElement(LPartObj);
        end;
      end;
    end;

    // Garante que o historico comece com role 'user' se estiver vazio
    if LContentsArr.Count = 0 then
    begin
      LTurnObj := TJSONObject.Create;
      LTurnObj.AddPair('role', 'user');
      LTurnParts := TJSONArray.Create;
      LPartObj := TJSONObject.Create;
      LPartObj.AddPair('text', EmptyStr);
      LTurnParts.AddElement(LPartObj);
      LTurnObj.AddPair('parts', LTurnParts);
      LContentsArr.AddElement(LTurnObj);
    end;

    LBody.AddPair('contents', LContentsArr);

    LHasStructuredOutput := Assigned(FResponseFormat) and (FResponseFormat.FormatType <> rfText);
    LHasTools := Assigned(FTools) and (FTools.Count > 0);
    LHasToolResults := HasToolResultMessage(AMsgs);

    // Se houver conflito entre Tools e Structured Output na Fase 1 (ferramentas ainda nao foram executadas):
    // A API Gemini rejeita estritamente a presenca simultanea de 'tools' e 'responseMimeType'/'responseSchema' (erro 400).
    // Enviamos 'tools' para que o modelo possa acionar as funcoes e injetamos o schema como instrucao de sistema.
    if LHasStructuredOutput and LHasTools and (not LHasToolResults) then
    begin
      if (FResponseFormat.FormatType = rfJSONSchema) and (FResponseFormat.Schema <> nil) then
        LSchemaStr := FResponseFormat.Schema.ToJSON
      else
        LSchemaStr := '{}';

      if LSysParts = nil then
        LSysParts := TJSONArray.Create;

      LSysPart := TJSONObject.Create;
      LSysPart.AddPair('text',
        'IMPORTANTE: Voce pode utilizar as ferramentas disponiveis para obter informacoes se necessario. ' +
        'Ao gerar a resposta final (ou caso ferramentas nao sejam necessarias), responda ESTRITAMENTE em formato JSON valido em conformidade com este schema: ' +
        LSchemaStr);
      LSysParts.AddElement(LSysPart);
      LHasSystem := True;
    end;

    // Adiciona systemInstruction se existir
    if LHasSystem and (LSysParts <> nil) then
    begin
      LSysInstruction := TJSONObject.Create;
      LSysInstruction.AddPair('parts', LSysParts);
      LBody.AddPair('systemInstruction', LSysInstruction);
    end;

    // 2. Generation Config
    LGenConfig := TJSONObject.Create;

    if ATemp >= 0 then
      LGenConfig.AddPair('temperature', TJSONNumber.Create(ATemp));

    if AMaxTok > 0 then
      LGenConfig.AddPair('maxOutputTokens', TJSONNumber.Create(AMaxTok));

    // Structured Output
    // Se houver conflito com tools e as tools ainda nao foram executadas (Fase 1),
    // suprimimos responseMimeType e responseSchema nesta chamada para evitar o erro 400.
    if LHasStructuredOutput and (not (LHasTools and (not LHasToolResults))) then
    begin
      case FResponseFormat.FormatType of
        rfJSONObject:
        begin
          LGenConfig.AddPair('responseMimeType', 'application/json');
        end;
        rfJSONSchema:
        begin
          LGenConfig.AddPair('responseMimeType', 'application/json');
          if FResponseFormat.Schema <> nil then
          begin
            LConvertedSchema := ConvertSchemaTypesToUppercase(FResponseFormat.Schema);
            LGenConfig.AddPair('responseSchema', LConvertedSchema);
          end;
        end;
      end;
    end;

    if LGenConfig.Count > 0 then
      LBody.AddPair('generationConfig', LGenConfig)
    else
      LGenConfig.Free;

    // 3. Tools / Function Calling
    // Se houver conflito com Structured Output e as tools ja tiverem sido executadas (Fase 2),
    // suprimimos 'tools' para permitir que o Gemini gere a resposta final estruturada com responseSchema sem erro 400.
    if LHasTools and (not (LHasStructuredOutput and LHasToolResults)) then
    begin
      LToolsRawArr := FTools.ToJSONArray;
      try
        LToolDeclsArr := TJSONArray.Create;
        for I := 0 to LToolsRawArr.Count - 1 do
        begin
          LToolItemVal := LToolsRawArr.Items[I];
          if LToolItemVal is TJSONObject then
          begin
            LToolItemObj := TJSONObject(LToolItemVal);
            LToolFuncVal := LToolItemObj.FindValue('function');
            if LToolFuncVal is TJSONObject then
            begin
              LToolFuncObj := TJSONObject(LToolFuncVal);
              LToolDeclObj := TJSONObject.Create;
              LToolDeclObj.AddPair('name', LToolFuncObj.GetValue<string>('name', EmptyStr));
              LToolDeclObj.AddPair('description', LToolFuncObj.GetValue<string>('description', EmptyStr));

              if LToolFuncObj.FindValue('parameters') is TJSONObject then
              begin
                LToolParamObj := TJSONObject(LToolFuncObj.FindValue('parameters'));
                LToolDeclObj.AddPair('parameters', ConvertSchemaTypesToUppercase(LToolParamObj));
              end;

              LToolDeclsArr.AddElement(LToolDeclObj);
            end;
          end;
        end;

        LToolWrapObj := TJSONObject.Create;
        LToolWrapObj.AddPair('functionDeclarations', LToolDeclsArr);

        LToolsArr := TJSONArray.Create;
        LToolsArr.AddElement(LToolWrapObj);
        LBody.AddPair('tools', LToolsArr);
      finally
        LToolsRawArr.Free;
      end;
    end;

    // Verificacao defensiva: Gemini API rejeita sumariamente 'tools' e 'responseMimeType' juntos no mesmo payload
    if (LBody.FindValue('tools') <> nil) and (LBody.FindValue('generationConfig') is TJSONObject) then
    begin
      LGCDef := TJSONObject(LBody.FindValue('generationConfig'));
      if LGCDef.FindValue('responseMimeType') <> nil then
        LBody.RemovePair('tools').Free;
    end;

    Result := LBody.ToJSON;
  finally
    if (LSysParts <> nil) and (not LHasSystem or (LBody.FindValue('systemInstruction') = nil)) then
      LSysParts.Free;
    LBody.Free;
  end;
end;

function TGeminiProvider.ExtractErrorMessage(const AErrorJSON: string): string;
var
  LVal, LErrVal, LMsgVal, LStatusVal: TJSONValue;
  LObj, LErr: TJSONObject;
  LMsg, LStatus: string;
begin
  Result := AErrorJSON;
  LVal := TJSONObject.ParseJSONValue(AErrorJSON);
  if LVal is TJSONObject then
  begin
    LObj := TJSONObject(LVal);
    try
      LErrVal := LObj.FindValue('error');
      if LErrVal is TJSONObject then
      begin
        LErr := TJSONObject(LErrVal);
        LMsgVal := LErr.FindValue('message');
        LStatusVal := LErr.FindValue('status');

        LMsg := EmptyStr;
        if LMsgVal is TJSONString then
          LMsg := LMsgVal.Value;

        LStatus := EmptyStr;
        if LStatusVal is TJSONString then
          LStatus := LStatusVal.Value;

        if not LStatus.IsEmpty and not LMsg.IsEmpty then
          Result := Format('%s: %s', [LStatus, LMsg])
        else if not LMsg.IsEmpty then
          Result := LMsg
        else
          Result := LErr.ToJSON;
      end
      else if LErrVal is TJSONString then
        Result := LErrVal.Value;
    finally
      LObj.Free;
    end;
  end
  else if Assigned(LVal) then
    LVal.Free;
end;

function TGeminiProvider.ExecuteRequest(const ABodyJSON: string;
  out ARawJSON: string): string;
var
  LResp: IHTTPResponse;
  LSResp, LURL: string;
  LStream: TStringStream;
  LVal: TJSONValue;
  LJSON, LCandidate, LContent, LPartObj, LFuncCallObj, LUsageObj: TJSONObject;
  LCandidates, LParts: TJSONArray;
  LCandidatesVal, LContentVal, LPartsVal, LUsageVal, LFuncCallVal, LTextVal, LArgsVal: TJSONValue;
  I: Integer;
  LId, LName, LArgs: string;
  LCalls: TLLMToolCallList;
begin
  Result := EmptyStr;
  ARawJSON := EmptyStr;
  SetLastToolCalls([]);

  FHttpClient.ConnectionTimeout := FTimeout;
  FHttpClient.ResponseTimeout := FTimeout;
  PrepareHeaders(FHttpClient);

  LURL := GetGenerateContentURL;

  LStream := TStringStream.Create(ABodyJSON, TEncoding.UTF8);
  try
    LResp := FHttpClient.Post(LURL, LStream);
  finally
    LStream.Free;
  end;

  DoAfterReceiveResponse(LResp);

  LSResp := LResp.ContentAsString(TEncoding.UTF8);
  ARawJSON := LSResp;

  if LResp.StatusCode <> 200 then
    raise ELLMAPIError.CreateFmt('Erro API Gemini [%d]: %s',
      [LResp.StatusCode, ExtractErrorMessage(LSResp)]);

  LVal := TJSONObject.ParseJSONValue(LSResp);
  if not (LVal is TJSONObject) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    raise Exception.Create('A resposta retornada pelo Gemini nao e um JSON valido.');
  end;

  LJSON := TJSONObject(LVal);
  try
    // Leitura do consumo de tokens
    LUsageVal := LJSON.FindValue('usageMetadata');
    if LUsageVal is TJSONObject then
    begin
      LUsageObj := TJSONObject(LUsageVal);
      FPromptTokenCount := LUsageObj.GetValue<Integer>('promptTokenCount', 0);
      FCandidatesTokenCount := LUsageObj.GetValue<Integer>('candidatesTokenCount', 0);
      FTotalTokenCount := LUsageObj.GetValue<Integer>('totalTokenCount', 0);
    end;

    LCandidatesVal := LJSON.FindValue('candidates');
    if not (LCandidatesVal is TJSONArray) or (TJSONArray(LCandidatesVal).Count = 0) then
      raise Exception.Create('Nenhum candidato retornado pelo Gemini.');

    LCandidates := TJSONArray(LCandidatesVal);
    if not (LCandidates.Items[0] is TJSONObject) then
      raise Exception.Create('Primeiro candidato nao e um objeto JSON.');

    LCandidate := TJSONObject(LCandidates.Items[0]);
    LContentVal := LCandidate.FindValue('content');
    if not (LContentVal is TJSONObject) then
      raise Exception.Create('Objeto "content" ausente no candidato retornado pelo Gemini.');

    LContent := TJSONObject(LContentVal);
    LPartsVal := LContent.FindValue('parts');
    if not (LPartsVal is TJSONArray) then
      Exit;

    LParts := TJSONArray(LPartsVal);
    SetLength(LCalls, 0);

    for I := 0 to LParts.Count - 1 do
    begin
      if LParts.Items[I] is TJSONObject then
      begin
        LPartObj := TJSONObject(LParts.Items[I]);

        // Verifica chamada de funcao
        LFuncCallVal := LPartObj.FindValue('functionCall');
        if LFuncCallVal is TJSONObject then
        begin
          LFuncCallObj := TJSONObject(LFuncCallVal);
          LName := LFuncCallObj.GetValue<string>('name', EmptyStr);
          LId := LFuncCallObj.GetValue<string>('id', EmptyStr);
          if LId.IsEmpty then
            LId := Format('call_gemini_%d_%s', [I, FormatDateTime('hhnnsszzz', Now)]);

          LArgs := '{}';
          LArgsVal := LFuncCallObj.FindValue('args');
          if LArgsVal is TJSONObject then
            LArgs := LArgsVal.ToJSON
          else if LArgsVal is TJSONString then
            LArgs := LArgsVal.Value
          else if Assigned(LArgsVal) then
            LArgs := LArgsVal.ToJSON;

          SetLength(LCalls, Length(LCalls) + 1);
          LCalls[High(LCalls)] := TLLMToolCall.Create(LId, LName, LArgs);
        end;

        // Texto regular
        LTextVal := LPartObj.FindValue('text');
        if (LTextVal <> nil) and not (LTextVal is TJSONNull) then
        begin
          if Result.IsEmpty then
            Result := LTextVal.Value
          else
            Result := Result + sLineBreak + LTextVal.Value;
        end;
      end;
    end;

    if Length(LCalls) > 0 then
      SetLastToolCalls(LCalls);
  finally
    LJSON.Free;
  end;
end;

procedure TGeminiProvider.AppendAssistantToolCallsToHistory(const ARawJSON: string);
var
  LVal: TJSONValue;
  LJSON, LCandidate, LContent, LPartObj, LFuncCallObj: TJSONObject;
  LCandidates, LParts, LToolCallsArr: TJSONArray;
  LCandidatesVal, LContentVal, LPartsVal, LFuncCallVal, LTextVal, LArgsVal: TJSONValue;
  I: Integer;
  LId, LName, LArgs, LTextStr: string;
  LAssistantMsg, LCallItem, LFuncItem: TJSONObject;
begin
  LVal := TJSONObject.ParseJSONValue(ARawJSON);
  if not (LVal is TJSONObject) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    Exit;
  end;

  LJSON := TJSONObject(LVal);
  try
    LCandidatesVal := LJSON.FindValue('candidates');
    if not (LCandidatesVal is TJSONArray) or (TJSONArray(LCandidatesVal).Count = 0) then
      Exit;

    LCandidates := TJSONArray(LCandidatesVal);
    if not (LCandidates.Items[0] is TJSONObject) then
      Exit;

    LCandidate := TJSONObject(LCandidates.Items[0]);
    LContentVal := LCandidate.FindValue('content');
    if not (LContentVal is TJSONObject) then
      Exit;

    LContent := TJSONObject(LContentVal);
    LPartsVal := LContent.FindValue('parts');
    if not (LPartsVal is TJSONArray) then
      Exit;

    LParts := TJSONArray(LPartsVal);
    LToolCallsArr := TJSONArray.Create;
    LTextStr := EmptyStr;

    for I := 0 to LParts.Count - 1 do
    begin
      if LParts.Items[I] is TJSONObject then
      begin
        LPartObj := TJSONObject(LParts.Items[I]);

        LFuncCallVal := LPartObj.FindValue('functionCall');
        if LFuncCallVal is TJSONObject then
        begin
          LFuncCallObj := TJSONObject(LFuncCallVal);
          LName := LFuncCallObj.GetValue<string>('name', EmptyStr);
          LId := LFuncCallObj.GetValue<string>('id', EmptyStr);
          if LId.IsEmpty then
            LId := Format('call_gemini_%d_%s', [I, FormatDateTime('hhnnsszzz', Now)]);

          LArgs := '{}';
          LArgsVal := LFuncCallObj.FindValue('args');
          if LArgsVal is TJSONObject then
            LArgs := LArgsVal.ToJSON
          else if LArgsVal is TJSONString then
            LArgs := LArgsVal.Value
          else if Assigned(LArgsVal) then
            LArgs := LArgsVal.ToJSON;

          LCallItem := TJSONObject.Create;
          LCallItem.AddPair('id', LId);
          LCallItem.AddPair('type', 'function');

          LFuncItem := TJSONObject.Create;
          LFuncItem.AddPair('name', LName);
          LFuncItem.AddPair('arguments', LArgs);
          LCallItem.AddPair('function', LFuncItem);

          LToolCallsArr.AddElement(LCallItem);
        end;

        LTextVal := LPartObj.FindValue('text');
        if (LTextVal <> nil) and not (LTextVal is TJSONNull) then
        begin
          if LTextStr.IsEmpty then
            LTextStr := LTextVal.Value
          else
            LTextStr := LTextStr + sLineBreak + LTextVal.Value;
        end;
      end;
    end;

    LAssistantMsg := TJSONObject.Create;
    LAssistantMsg.AddPair('role', 'assistant');
    if not LTextStr.IsEmpty then
      LAssistantMsg.AddPair('content', LTextStr)
    else
      LAssistantMsg.AddPair('content', TJSONNull.Create);

    if LToolCallsArr.Count > 0 then
      LAssistantMsg.AddPair('tool_calls', LToolCallsArr)
    else
      LToolCallsArr.Free;

    FMessages.AddElement(LAssistantMsg);
  finally
    LJSON.Free;
  end;
end;

function TGeminiProvider.GetModelsURL: string;
var
  LBase: string;
begin
  LBase := FBaseURL.TrimRight(['/']);

  if LBase.EndsWith('/chat/completions', True) then
    LBase := LBase.Substring(0, LBase.Length - Length('/chat/completions')).TrimRight(['/']);
  if LBase.EndsWith('/openai', True) then
    LBase := LBase.Substring(0, LBase.Length - Length('/openai')).TrimRight(['/']);
  if LBase.EndsWith('/v1', True) then
    LBase := LBase.Substring(0, LBase.Length - Length('/v1')).TrimRight(['/']);

  if LBase.Contains('/models') then
    LBase := LBase.Substring(0, Pos('/models', LBase) - 1).TrimRight(['/']);

  if LBase.Contains('api.openai.com') or LBase.Contains('api.groq.com') or
     LBase.Contains('localhost:11434') or LBase.Contains('127.0.0.1:11434') or
     LBase.IsEmpty then
  begin
    LBase := GEMINI_DEFAULT_URL;
  end
  else if not LBase.Contains('/v1') and not LBase.Contains('/v1beta') then
  begin
    LBase := LBase + '/v1beta';
  end;

  Result := Format('%s/models', [LBase]);
  if not FApiKey.Trim.IsEmpty and not Result.Contains('key=') then
  begin
    if Result.Contains('?') then
      Result := Result + '&key=' + FApiKey.Trim
    else
      Result := Result + '?key=' + FApiKey.Trim;
  end;
end;

function TGeminiProvider.ListModels: TArray<string>;
var
  LClient: THTTPClient;
  LResp: IHTTPResponse;
  LVal, LModelsVal, LItemVal, LNameVal: TJSONValue;
  LRoot: TJSONObject;
  LModelsArr: TJSONArray;
  I: Integer;
  LName: string;
begin
  SetLength(Result, 0);
  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := 5000;
    LClient.ResponseTimeout := 10000;
    PrepareHeaders(LClient);
    try
      LResp := LClient.Get(GetModelsURL);
      if LResp.StatusCode <> 200 then
        Exit;

      LVal := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8));
      if LVal is TJSONObject then
      begin
        LRoot := TJSONObject(LVal);
        try
          LModelsVal := LRoot.FindValue('models');
          if LModelsVal is TJSONArray then
          begin
            LModelsArr := TJSONArray(LModelsVal);
            SetLength(Result, LModelsArr.Count);
            for I := 0 to LModelsArr.Count - 1 do
            begin
              LItemVal := LModelsArr.Items[I];
              if LItemVal is TJSONObject then
              begin
                LNameVal := TJSONObject(LItemVal).FindValue('name');
                if LNameVal is TJSONString then
                begin
                  LName := LNameVal.Value;
                  if LName.StartsWith('models/') then
                    LName := LName.Substring(7);
                  Result[I] := LName;
                end
                else
                  Result[I] := EmptyStr;
              end;
            end;
          end;
        finally
          LRoot.Free;
        end;
      end
      else if Assigned(LVal) then
        LVal.Free;
    except
      SetLength(Result, 0);
    end;
  finally
    LClient.Free;
  end;
end;

end.
