unit LLM.Tools;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections;

type
  /// <summary>
  /// Callback de execucao de ferramenta recebendo argumentos como string JSON
  /// </summary>
  TToolCallback = reference to function(const AArgumentsJSON: string): string;

  /// <summary>
  /// Callback de execucao de ferramenta recebendo argumentos como TJSONObject
  /// </summary>
  TToolJSONCallback = reference to function(const AArguments: TJSONObject): string;

  /// <summary>
  /// Representa uma solicitacao de chamada de ferramenta gerada pelo modelo LLM
  /// </summary>
  TLLMToolCall = record
    Id: string;
    Name: string;
    Arguments: string;
    class function Create(const AId, AName, AArguments: string): TLLMToolCall; static;
  end;

  TLLMToolCallList = TArray<TLLMToolCall>;

  /// <summary>
  /// Evento disparado antes da execucao de uma ferramenta
  /// </summary>
  TOnBeforeExecuteToolEvent = reference to procedure(const AToolCall: TLLMToolCall);

  /// <summary>
  /// Evento disparado apos a execucao de uma ferramenta
  /// </summary>
  TOnAfterExecuteToolEvent = reference to procedure(const AToolCall: TLLMToolCall; const AResult: string; const ASuccess: Boolean);

  /// <summary>
  /// Interface que representa uma ferramenta/funcao executavel
  /// </summary>
  ILLMTool = interface
    ['{F67C8241-7A39-44BF-B01D-3C843A678FE1}']
    function GetName: string;
    function GetDescription: string;
    function GetParametersSchema: TJSONObject;
    function Execute(const AArgumentsJSON: string): string;
    function ToJSONObject: TJSONObject;

    property Name: string read GetName;
    property Description: string read GetDescription;
    property ParametersSchema: TJSONObject read GetParametersSchema;
  end;

  /// <summary>
  /// Interface do registro de ferramentas disponiveis para o modelo
  /// </summary>
  ILLMToolRegistry = interface
    ['{884CE2B4-998C-4D2A-A81E-47C5E9028FE2}']
    procedure RegisterTool(const ATool: ILLMTool); overload;
    procedure RegisterTool(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolCallback); overload;
    procedure RegisterTool(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolCallback); overload;
    procedure RegisterTool(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolJSONCallback); overload;
    procedure RegisterTool(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolJSONCallback); overload;

    procedure RegisterFunction(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolCallback); overload;
    procedure RegisterFunction(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolCallback); overload;
    procedure RegisterFunction(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolJSONCallback); overload;
    procedure RegisterFunction(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolJSONCallback); overload;

    procedure Unregister(const AName: string);
    function Find(const AName: string; out ATool: ILLMTool): Boolean;
    function Contains(const AName: string): Boolean;
    function Count: Integer;
    function GetNames: TArray<string>;
    procedure Clear;
    function ToJSONArray: TJSONArray;

    property Names: TArray<string> read GetNames;
  end;

  /// <summary>
  /// Implementacao padrao de ILLMTool
  /// </summary>
  TLLMTool = class(TInterfacedObject, ILLMTool)
  private
    FName: string;
    FDescription: string;
    FParametersSchema: TJSONObject;
    FHandler: TToolCallback;
    FJSONHandler: TToolJSONCallback;
    procedure SetSchemaFromJSON(const AJSON: string);
  protected
    function GetName: string;
    function GetDescription: string;
    function GetParametersSchema: TJSONObject;
  public
    constructor Create(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolCallback); overload;
    constructor Create(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolCallback); overload;
    constructor Create(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolJSONCallback); overload;
    constructor Create(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolJSONCallback); overload;
    destructor Destroy; override;

    function Execute(const AArgumentsJSON: string): string;
    function ToJSONObject: TJSONObject;

    property Name: string read GetName;
    property Description: string read GetDescription;
    property ParametersSchema: TJSONObject read GetParametersSchema;
  end;

  /// <summary>
  /// Implementacao padrao de ILLMToolRegistry
  /// </summary>
  TLLMToolRegistry = class(TInterfacedObject, ILLMToolRegistry)
  private
    FTools: TDictionary<string, ILLMTool>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure RegisterTool(const ATool: ILLMTool); overload;
    procedure RegisterTool(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolCallback); overload;
    procedure RegisterTool(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolCallback); overload;
    procedure RegisterTool(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolJSONCallback); overload;
    procedure RegisterTool(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolJSONCallback); overload;

    procedure RegisterFunction(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolCallback); overload;
    procedure RegisterFunction(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolCallback); overload;
    procedure RegisterFunction(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolJSONCallback); overload;
    procedure RegisterFunction(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolJSONCallback); overload;

    procedure Unregister(const AName: string);
    function Find(const AName: string; out ATool: ILLMTool): Boolean;
    function Contains(const AName: string): Boolean;
    function Count: Integer;
    function GetNames: TArray<string>;
    procedure Clear;
    function ToJSONArray: TJSONArray;

    property Names: TArray<string> read GetNames;
  end;

implementation

{ TLLMToolCall }

class function TLLMToolCall.Create(const AId, AName, AArguments: string): TLLMToolCall;
begin
  Result.Id := AId;
  Result.Name := AName;
  Result.Arguments := AArguments;
end;

{ TLLMTool }

procedure TLLMTool.SetSchemaFromJSON(const AJSON: string);
var
  LVal: TJSONValue;
begin
  if AJSON.Trim.IsEmpty then
    LVal := TJSONObject.ParseJSONValue('{"type":"object","properties":{}}')
  else
    LVal := TJSONObject.ParseJSONValue(AJSON);

  if LVal is TJSONObject then
    FParametersSchema := TJSONObject(LVal)
  else
  begin
    if Assigned(LVal) then
      LVal.Free;
    FParametersSchema := TJSONObject.Create;
    FParametersSchema.AddPair('type', 'object');
    FParametersSchema.AddPair('properties', TJSONObject.Create);
  end;
end;

constructor TLLMTool.Create(const AName, ADescription: string;
  const AParametersSchema: TJSONObject; const AHandler: TToolCallback);
begin
  inherited Create;
  FName := AName;
  FDescription := ADescription;
  FHandler := AHandler;
  FJSONHandler := nil;
  if Assigned(AParametersSchema) then
    FParametersSchema := AParametersSchema.Clone as TJSONObject
  else
    SetSchemaFromJSON(EmptyStr);
end;

constructor TLLMTool.Create(const AName, ADescription,
  AParametersSchemaJSON: string; const AHandler: TToolCallback);
begin
  inherited Create;
  FName := AName;
  FDescription := ADescription;
  FHandler := AHandler;
  FJSONHandler := nil;
  SetSchemaFromJSON(AParametersSchemaJSON);
end;

constructor TLLMTool.Create(const AName, ADescription: string;
  const AParametersSchema: TJSONObject; const AHandler: TToolJSONCallback);
begin
  inherited Create;
  FName := AName;
  FDescription := ADescription;
  FHandler := nil;
  FJSONHandler := AHandler;
  if Assigned(AParametersSchema) then
    FParametersSchema := AParametersSchema.Clone as TJSONObject
  else
    SetSchemaFromJSON(EmptyStr);
end;

constructor TLLMTool.Create(const AName, ADescription,
  AParametersSchemaJSON: string; const AHandler: TToolJSONCallback);
begin
  inherited Create;
  FName := AName;
  FDescription := ADescription;
  FHandler := nil;
  FJSONHandler := AHandler;
  SetSchemaFromJSON(AParametersSchemaJSON);
end;

destructor TLLMTool.Destroy;
begin
  FParametersSchema.Free;
  inherited;
end;

function TLLMTool.Execute(const AArgumentsJSON: string): string;
var
  LVal: TJSONValue;
  LObj: TJSONObject;
begin
  if Assigned(FHandler) then
    Result := FHandler(AArgumentsJSON)
  else if Assigned(FJSONHandler) then
  begin
    LVal := TJSONObject.ParseJSONValue(AArgumentsJSON);
    if LVal is TJSONObject then
      LObj := TJSONObject(LVal)
    else
    begin
      if Assigned(LVal) then
        LVal.Free;
      LObj := TJSONObject.Create;
    end;
    try
      Result := FJSONHandler(LObj);
    finally
      LObj.Free;
    end;
  end
  else
    Result := '{"status":"ok"}';
end;

function TLLMTool.GetDescription: string;
begin
  Result := FDescription;
end;

function TLLMTool.GetName: string;
begin
  Result := FName;
end;

function TLLMTool.GetParametersSchema: TJSONObject;
begin
  Result := FParametersSchema;
end;

function TLLMTool.ToJSONObject: TJSONObject;
var
  LFuncObj: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'function');

  LFuncObj := TJSONObject.Create;
  LFuncObj.AddPair('name', FName);
  if not FDescription.IsEmpty then
    LFuncObj.AddPair('description', FDescription);

  if Assigned(FParametersSchema) then
    LFuncObj.AddPair('parameters', FParametersSchema.Clone as TJSONObject)
  else
  begin
    var LDefaultParams := TJSONObject.Create;
    LDefaultParams.AddPair('type', 'object');
    LDefaultParams.AddPair('properties', TJSONObject.Create);
    LFuncObj.AddPair('parameters', LDefaultParams);
  end;

  Result.AddPair('function', LFuncObj);
end;

{ TLLMToolRegistry }

constructor TLLMToolRegistry.Create;
begin
  inherited Create;
  FTools := TDictionary<string, ILLMTool>.Create;
end;

destructor TLLMToolRegistry.Destroy;
begin
  FTools.Free;
  inherited;
end;

procedure TLLMToolRegistry.Clear;
begin
  FTools.Clear;
end;

function TLLMToolRegistry.Contains(const AName: string): Boolean;
begin
  Result := FTools.ContainsKey(AName);
end;

function TLLMToolRegistry.Count: Integer;
begin
  Result := FTools.Count;
end;

function TLLMToolRegistry.GetNames: TArray<string>;
begin
  Result := FTools.Keys.ToArray;
end;

function TLLMToolRegistry.Find(const AName: string; out ATool: ILLMTool): Boolean;
begin
  Result := FTools.TryGetValue(AName, ATool);
end;

procedure TLLMToolRegistry.RegisterTool(const ATool: ILLMTool);
begin
  if not Assigned(ATool) then
    Exit;
  FTools.AddOrSetValue(ATool.Name, ATool);
end;

procedure TLLMToolRegistry.RegisterTool(const AName, ADescription,
  AParametersSchemaJSON: string; const AHandler: TToolCallback);
begin
  RegisterTool(TLLMTool.Create(AName, ADescription, AParametersSchemaJSON, AHandler));
end;

procedure TLLMToolRegistry.RegisterTool(const AName, ADescription: string;
  const AParametersSchema: TJSONObject; const AHandler: TToolCallback);
begin
  RegisterTool(TLLMTool.Create(AName, ADescription, AParametersSchema, AHandler));
end;

procedure TLLMToolRegistry.RegisterTool(const AName, ADescription,
  AParametersSchemaJSON: string; const AHandler: TToolJSONCallback);
begin
  RegisterTool(TLLMTool.Create(AName, ADescription, AParametersSchemaJSON, AHandler));
end;

procedure TLLMToolRegistry.RegisterTool(const AName, ADescription: string;
  const AParametersSchema: TJSONObject; const AHandler: TToolJSONCallback);
begin
  RegisterTool(TLLMTool.Create(AName, ADescription, AParametersSchema, AHandler));
end;

procedure TLLMToolRegistry.RegisterFunction(const AName, ADescription,
  AParametersSchemaJSON: string; const AHandler: TToolCallback);
begin
  RegisterTool(AName, ADescription, AParametersSchemaJSON, AHandler);
end;

procedure TLLMToolRegistry.RegisterFunction(const AName, ADescription: string;
  const AParametersSchema: TJSONObject; const AHandler: TToolCallback);
begin
  RegisterTool(AName, ADescription, AParametersSchema, AHandler);
end;

procedure TLLMToolRegistry.RegisterFunction(const AName, ADescription,
  AParametersSchemaJSON: string; const AHandler: TToolJSONCallback);
begin
  RegisterTool(AName, ADescription, AParametersSchemaJSON, AHandler);
end;

procedure TLLMToolRegistry.RegisterFunction(const AName, ADescription: string;
  const AParametersSchema: TJSONObject; const AHandler: TToolJSONCallback);
begin
  RegisterTool(AName, ADescription, AParametersSchema, AHandler);
end;

procedure TLLMToolRegistry.Unregister(const AName: string);
begin
  FTools.Remove(AName);
end;

function TLLMToolRegistry.ToJSONArray: TJSONArray;
var
  LTool: ILLMTool;
begin
  Result := TJSONArray.Create;
  for LTool in FTools.Values do
    Result.AddElement(LTool.ToJSONObject);
end;

end.