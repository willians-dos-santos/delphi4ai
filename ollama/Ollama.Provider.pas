unit Ollama.Provider;

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

type
  

  /// <summary>
  /// Provedor nativo para integracao com o Ollama (API /api/chat)
  /// </summary>
  TOllamaProvider = class(TLLMProviderBase, IOllamaProvider)
  private
    function GetTagsURL: string;
  protected
    procedure PrepareHeaders(AClient: THTTPClient); override;
    function BuildBodyJSON(const AModel: string; ATemp: Double;
      AMaxTok: Integer; AMsgs: TJSONArray): string; override;
    function ExecuteRequest(const ABodyJSON: string;
      out ARawJSON: string): string; override;
    procedure AppendAssistantToolCallsToHistory(const ARawJSON: string); override;
  public
    constructor Create(const AModel: string = 'llama3.2';
      const ABaseURL: string = 'http://localhost:11434/api/chat';
      const AApiKey: string = '');

    function ListModels: TArray<string>;
    function IsServerRunning: Boolean;
  end;

implementation

uses
  LLM.Exceptions;

{ TOllamaProvider }

constructor TOllamaProvider.Create(const AModel, ABaseURL, AApiKey: string);
var
  LURL, LModel: string;
begin
  LURL := ABaseURL;
  if LURL.Trim.IsEmpty then
    LURL := 'http://localhost:11434/api/chat';

  LModel := AModel;
  if LModel.Trim.IsEmpty then
    LModel := 'llama3.2';

  inherited Create(AApiKey, LURL, LModel);
end;

procedure TOllamaProvider.PrepareHeaders(AClient: THTTPClient);
begin
  if not FApiKey.Trim.IsEmpty then
    AClient.CustomHeaders['Authorization'] := 'Bearer ' + FApiKey;
  AClient.CustomHeaders['Content-Type'] := 'application/json';
end;

function TOllamaProvider.BuildBodyJSON(const AModel: string; ATemp: Double;
  AMaxTok: Integer; AMsgs: TJSONArray): string;
var
  LBody, LOptions: TJSONObject;
  LOldOwned: Boolean;
  LToolsArray: TJSONArray;
begin
  LBody := TJSONObject.Create;
  LOldOwned := AMsgs.Owned;
  try
    LBody.AddPair('model', AModel);

    // Impede que LBody.Free destrua o array AMsgs compartilhado
    AMsgs.Owned := False;
    LBody.AddPair('messages', AMsgs);

    LBody.AddPair('stream', False);

    // No Ollama, temperatura e tokens sao passados dentro do objeto "options"
    if (ATemp >= 0) or (AMaxTok > 0) then
    begin
      LOptions := TJSONObject.Create;
      if ATemp >= 0 then
        LOptions.AddPair('temperature', TJSONNumber.Create(ATemp));
      if AMaxTok > 0 then
        LOptions.AddPair('num_predict', TJSONNumber.Create(AMaxTok));
      LBody.AddPair('options', LOptions);
    end;

    // Suporte nativo a tools / function calling no Ollama
    if Assigned(FTools) and (FTools.Count > 0) then
    begin
      LToolsArray := FTools.ToJSONArray;
      LBody.AddPair('tools', LToolsArray);
    end;

    Result := LBody.ToJSON;
  finally
    LBody.Free;
    AMsgs.Owned := LOldOwned;
  end;
end;

function TOllamaProvider.ExecuteRequest(const ABodyJSON: string;
  out ARawJSON: string): string;
var
  LResp: IHTTPResponse;
  LSResp: string;
  LStream: TStringStream;
  LVal: TJSONValue;
  LJSON, LMsg: TJSONObject;
  LMsgVal, LToolsVal, LContentVal, LFuncVal: TJSONValue;
  LToolCallsArr: TJSONArray;
  I: Integer;
  LCallObj, LFuncObj: TJSONObject;
  LId, LName, LArgs: string;
  LCalls: TLLMToolCallList;
  LArgsVal: TJSONValue;
begin
  Result := EmptyStr;
  ARawJSON := EmptyStr;
  SetLastToolCalls([]);

  FHttpClient.ConnectionTimeout := FTimeout;
  FHttpClient.ResponseTimeout := FTimeout;
  PrepareHeaders(FHttpClient);

  LStream := TStringStream.Create(ABodyJSON, TEncoding.UTF8);
  try
    LResp := FHttpClient.Post(FBaseURL, LStream);
  finally
    LStream.Free;
  end;

  LSResp := LResp.ContentAsString(TEncoding.UTF8);
  ARawJSON := LSResp;

  if LResp.StatusCode <> 200 then
    raise ELLMAPIError.CreateFmt('Erro API Ollama [%d]: %s',
      [LResp.StatusCode, ExtractErrorMessage(LSResp)]);

  LVal := TJSONObject.ParseJSONValue(LSResp);
  if not (LVal is TJSONObject) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    raise Exception.Create('A resposta retornada pelo Ollama nao e um JSON valido.');
  end;

  LJSON := TJSONObject(LVal);
  try
    LMsgVal := LJSON.FindValue('message');
    if not (LMsgVal is TJSONObject) then
      raise Exception.Create('Objeto "message" ausente na resposta do Ollama.');

    LMsg := TJSONObject(LMsgVal);

    // Verifica solicitacoes de tool_calls
    LToolsVal := LMsg.FindValue('tool_calls');
    if (LToolsVal is TJSONArray) and (TJSONArray(LToolsVal).Count > 0) then
    begin
      LToolCallsArr := TJSONArray(LToolsVal);
      SetLength(LCalls, LToolCallsArr.Count);
      for I := 0 to LToolCallsArr.Count - 1 do
      begin
        if LToolCallsArr.Items[I] is TJSONObject then
        begin
          LCallObj := TJSONObject(LToolCallsArr.Items[I]);
          LId := LCallObj.GetValue<string>('id', EmptyStr);
          if LId.IsEmpty then
            LId := Format('call_ollama_%d_%s', [I, FormatDateTime('hhnnsszzz', Now)]);

          LName := EmptyStr;
          LArgs := EmptyStr;

          LFuncVal := LCallObj.FindValue('function');
          if LFuncVal is TJSONObject then
          begin
            LFuncObj := TJSONObject(LFuncVal);
            LName := LFuncObj.GetValue<string>('name', EmptyStr);

            // Suporta argumentos tanto como JSON object quanto como string JSON
            LArgsVal := LFuncObj.FindValue('arguments');
            if LArgsVal is TJSONObject then
              LArgs := LArgsVal.ToJSON
            else if LArgsVal is TJSONString then
              LArgs := LArgsVal.Value
            else if Assigned(LArgsVal) then
              LArgs := LArgsVal.ToJSON;
          end;

          LCalls[I] := TLLMToolCall.Create(LId, LName, LArgs);
        end;
      end;
      SetLastToolCalls(LCalls);
    end;

    LContentVal := LMsg.FindValue('content');
    if (LContentVal <> nil) and not (LContentVal is TJSONNull) then
      Result := LContentVal.Value
    else
      Result := EmptyStr;
  finally
    LJSON.Free;
  end;
end;

procedure TOllamaProvider.AppendAssistantToolCallsToHistory(const ARawJSON: string);
var
  LVal, LMsgVal: TJSONValue;
  LJSON: TJSONObject;
begin
  LVal := TJSONObject.ParseJSONValue(ARawJSON);
  if LVal is TJSONObject then
  begin
    LJSON := TJSONObject(LVal);
    try
      LMsgVal := LJSON.FindValue('message');
      if LMsgVal is TJSONObject then
        FMessages.AddElement(LMsgVal.Clone as TJSONObject);
    finally
      LJSON.Free;
    end;
  end;
end;

function TOllamaProvider.GetTagsURL: string;
var
  LURI: TURI;
begin
  try
    LURI := TURI.Create(FBaseURL);
    if (LURI.Port = 0) or
       ((LURI.Port = 80) and SameText(LURI.Scheme, 'http')) or
       ((LURI.Port = 443) and SameText(LURI.Scheme, 'https')) then
      Result := Format('%s://%s/api/tags', [LURI.Scheme, LURI.Host])
    else
      Result := Format('%s://%s:%d/api/tags', [LURI.Scheme, LURI.Host, LURI.Port]);
  except
    if FBaseURL.EndsWith('/api/chat', True) then
      Result := FBaseURL.Substring(0, FBaseURL.Length - 9) + '/api/tags'
    else
      Result := 'http://localhost:11434/api/tags';
  end;
end;

function TOllamaProvider.ListModels: TArray<string>;
var
  LClient: THTTPClient;
  LResp: IHTTPResponse;
  LJSONVal, LModelsVal, LItemVal, LNameVal: TJSONValue;
  LRoot: TJSONObject;
  LModelsArr: TJSONArray;
  I: Integer;
begin
  SetLength(Result, 0);
  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := 5000;
    LClient.ResponseTimeout := 10000;
    PrepareHeaders(LClient);
    try
      LResp := LClient.Get(GetTagsURL);
      if LResp.StatusCode <> 200 then
        Exit;

      LJSONVal := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8));
      if LJSONVal is TJSONObject then
      begin
        LRoot := TJSONObject(LJSONVal);
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
                  Result[I] := LNameVal.Value
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

function TOllamaProvider.IsServerRunning: Boolean;
var
  LClient: THTTPClient;
  LResp: IHTTPResponse;
begin
  Result := False;
  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := 2000;
    LClient.ResponseTimeout := 2000;
    try
      LResp := LClient.Get(GetTagsURL);
      Result := (LResp.StatusCode = 200);
    except
      Result := False;
    end;
  finally
    LClient.Free;
  end;
end;

end.
