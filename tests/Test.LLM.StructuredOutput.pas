unit Test.LLM.StructuredOutput;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.TypInfo,
  TestFramework,
  LLM.Interfaces,
  LLM.Base,
  LLM.Schema,
  Ollama.Provider,
  LLM.MockProvider,
  Test.Ollama.Provider;

type
  /// <summary>
  /// Enum de teste para demonstrar geracao de enum no schema
  /// </summary>
  TClimaCondicao = (ccEnsolarado, ccNublado, ccChuvoso);

  /// <summary>
  /// Record de teste para demonstrar Saidas Estruturadas com Records (zero memory management)
  /// </summary>
  [TLLMSchema('PrevisaoTempo', 'Dados meteorologicos estruturados')]
  TPrevisaoTempoRecord = record
    [TLLMProperty('Nome da cidade')]
    Cidade: string;

    [TLLMProperty('Temperatura em Celsius')]
    Temperatura: Double;

    [TLLMProperty('Umidade relativa do ar (0 a 100)')]
    Umidade: Integer;

    [TLLMProperty('Indica se esta chovendo')]
    Chovendo: Boolean;

    [TLLMProperty('Condicao atual do ceu')]
    Condicao: TClimaCondicao;
  end;

  /// <summary>
  /// Classe de teste para demonstrar Saidas Estruturadas com Classes
  /// </summary>
  [TLLMSchema('UsuarioInfo', 'Dados cadastrais de usuario')]
  TUsuarioClass = class
  private
    FNome: string;
    FIdade: Integer;
    FAtivo: Boolean;
  published
    [TLLMProperty('Nome completo')]
    property Nome: string read FNome write FNome;

    [TLLMProperty('Idade em anos')]
    property Idade: Integer read FIdade write FIdade;

    [TLLMProperty('Status de ativacao da conta')]
    property Ativo: Boolean read FAtivo write FAtivo;
  end;

  /// <summary>
  /// Suite de testes unitarios para Saidas Estruturadas (Structured Output)
  /// </summary>
  TTestLLMStructuredOutput = class(TTestCase)
  private
    FOpenAIProvider: TMockLLMProvider;
    FOllamaProvider: TMockOllamaProvider;
    FOpenAIIntf: ILLMProvider;
    FOllamaIntf: ILLMProvider;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSchemaGenerator_FromRecord;
    procedure TestSchemaGenerator_FromClass;
    procedure TestDeserializer_ToRecord;
    procedure TestDeserializer_ToClass;
    procedure TestOpenAI_BuildBodyJSON_JSONObject;
    procedure TestOpenAI_BuildBodyJSON_JSONSchema;
    procedure TestOllama_BuildBodyJSON_JSONObject;
    procedure TestOllama_BuildBodyJSON_JSONSchema;
    procedure TestSendAsJSON_ParsesAndCleansMarkdown;
    procedure TestSendAs_GenericRecord;
    procedure TestSendAs_GenericClass;
  end;

implementation

{ TTestLLMStructuredOutput }

procedure TTestLLMStructuredOutput.SetUp;
begin
  inherited;
  FOpenAIProvider := TMockLLMProvider.Create('test-key', 'https://api.openai.com/v1/chat/completions', 'gpt-4o-mini');
  FOpenAIIntf := FOpenAIProvider;
  FOllamaProvider := TMockOllamaProvider.Create('llama3.2', 'http://localhost:11434/api/chat', '');
  FOllamaIntf := FOllamaProvider;
end;

procedure TTestLLMStructuredOutput.TearDown;
begin
  FOpenAIIntf := nil;
  FOllamaIntf := nil;
  FOpenAIProvider := nil;
  FOllamaProvider := nil;
  inherited;
end;

procedure TTestLLMStructuredOutput.TestSchemaGenerator_FromRecord;
var
  LSchema: TJSONObject;
  LName: string;
  LProps, LCidadeProp, LCondicaoProp: TJSONObject;
  LReq: TJSONArray;
begin
  LSchema := TLLMSchemaGenerator.GenerateSchemaFromTypeInfo(TypeInfo(TPrevisaoTempoRecord), LName);
  try
    CheckNotNull(LSchema, 'Schema do record nao pode ser nulo');
    CheckEquals('PrevisaoTempo', LName, 'Nome do schema extraido do atributo [TLLMSchema]');
    CheckEquals('object', LSchema.GetValue<string>('type', ''), 'Tipo raiz deve ser object');
    CheckFalse(LSchema.GetValue<Boolean>('additionalProperties', True), 'additionalProperties deve ser false');

    LProps := LSchema.FindValue('properties') as TJSONObject;
    CheckNotNull(LProps, 'No properties deve existir');
    CheckNotNull(LProps.FindValue('cidade'), 'Propriedade cidade deve existir');
    CheckNotNull(LProps.FindValue('temperatura'), 'Propriedade temperatura deve existir');
    CheckNotNull(LProps.FindValue('umidade'), 'Propriedade umidade deve existir');
    CheckNotNull(LProps.FindValue('chovendo'), 'Propriedade chovendo deve existir');
    CheckNotNull(LProps.FindValue('condicao'), 'Propriedade condicao deve existir');

    LCidadeProp := LProps.FindValue('cidade') as TJSONObject;
    CheckEquals('string', LCidadeProp.GetValue<string>('type', ''));
    CheckEquals('Nome da cidade', LCidadeProp.GetValue<string>('description', ''));

    // Verifica se o enum gerou array enum com os nomes
    LCondicaoProp := LProps.FindValue('condicao') as TJSONObject;
    CheckEquals('string', LCondicaoProp.GetValue<string>('type', ''));
    CheckTrue(LCondicaoProp.FindValue('enum') is TJSONArray, 'Enum deve possuir array enum');
    CheckEquals(3, TJSONArray(LCondicaoProp.FindValue('enum')).Count, 'Enum TClimaCondicao tem 3 valores');

    LReq := LSchema.FindValue('required') as TJSONArray;
    CheckNotNull(LReq, 'required array deve existir');
    CheckEquals(5, LReq.Count, 'Todos os 5 campos devem ser required por padrao');
  finally
    LSchema.Free;
  end;
end;

procedure TTestLLMStructuredOutput.TestSchemaGenerator_FromClass;
var
  LSchema: TJSONObject;
  LName: string;
  LProps: TJSONObject;
begin
  LSchema := TLLMSchemaGenerator.GenerateSchemaFromClass(TUsuarioClass, LName);
  try
    CheckNotNull(LSchema, 'Schema da classe nao pode ser nulo');
    CheckEquals('UsuarioInfo', LName, 'Nome do schema extraido da classe');
    CheckEquals('object', LSchema.GetValue<string>('type', ''));

    LProps := LSchema.FindValue('properties') as TJSONObject;
    CheckNotNull(LProps.FindValue('nome'), 'Propriedade nome deve existir');
    CheckNotNull(LProps.FindValue('idade'), 'Propriedade idade deve existir');
    CheckNotNull(LProps.FindValue('ativo'), 'Propriedade ativo deve existir');
  finally
    LSchema.Free;
  end;
end;

procedure TTestLLMStructuredOutput.TestDeserializer_ToRecord;
var
  LJSON: TJSONObject;
  LRecord: TPrevisaoTempoRecord;
begin
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('cidade', 'Curitiba');
    LJSON.AddPair('temperatura', TJSONNumber.Create(18.5));
    LJSON.AddPair('umidade', TJSONNumber.Create(80));
    LJSON.AddPair('chovendo', False);
    LJSON.AddPair('condicao', 'ccNublado');

    LRecord := Default(TPrevisaoTempoRecord);
    TLLMJSONDeserializer.DeserializeRecord(LJSON, TypeInfo(TPrevisaoTempoRecord), LRecord);

    CheckEquals('Curitiba', LRecord.Cidade, 'Cidade incorreta');
    CheckEquals(18.5, LRecord.Temperatura, 0.01, 'Temperatura incorreta');
    CheckEquals(80, LRecord.Umidade, 'Umidade incorreta');
    CheckFalse(LRecord.Chovendo, 'Chovendo deve ser False');
    CheckTrue(LRecord.Condicao = ccNublado, 'Condicao enum incorreta');
  finally
    LJSON.Free;
  end;
end;

procedure TTestLLMStructuredOutput.TestDeserializer_ToClass;
var
  LJSON: TJSONObject;
  LUser: TUsuarioClass;
begin
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('nome', 'Carlos Eduardo');
    LJSON.AddPair('idade', TJSONNumber.Create(28));
    LJSON.AddPair('ativo', True);

    LUser := TLLMJSONDeserializer.DeserializeClass(LJSON, TUsuarioClass) as TUsuarioClass;
    try
      CheckNotNull(LUser, 'Instancia criada nao pode ser nula');
      CheckEquals('Carlos Eduardo', LUser.Nome);
      CheckEquals(28, LUser.Idade);
      CheckTrue(LUser.Ativo);
    finally
      LUser.Free;
    end;
  finally
    LJSON.Free;
  end;
end;

procedure TTestLLMStructuredOutput.TestOpenAI_BuildBodyJSON_JSONObject;
var
  LMsgs: TJSONArray;
  LBodyStr: string;
  LRoot, LRespFmt: TJSONObject;
begin
  FOpenAIProvider.ResponseFormat.SetJSONObject;
  LMsgs := TJSONArray.Create;
  try
    LBodyStr := FOpenAIProvider.TestBuildBodyJSON('gpt-4o-mini', 0.7, 0, LMsgs);
    LRoot := TJSONObject.ParseJSONValue(LBodyStr) as TJSONObject;
    try
      CheckNotNull(LRoot, 'JSON deve ser valido');
      LRespFmt := LRoot.FindValue('response_format') as TJSONObject;
      CheckNotNull(LRespFmt, 'response_format deve existir no payload OpenAI');
      CheckEquals('json_object', LRespFmt.GetValue<string>('type', ''));
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestLLMStructuredOutput.TestOpenAI_BuildBodyJSON_JSONSchema;
var
  LMsgs: TJSONArray;
  LBodyStr: string;
  LRoot, LRespFmt, LSchemaObj: TJSONObject;
begin
  FOpenAIProvider.ResponseFormat.SetSchema(TypeInfo(TPrevisaoTempoRecord));
  LMsgs := TJSONArray.Create;
  try
    LBodyStr := FOpenAIProvider.TestBuildBodyJSON('gpt-4o-mini', 0.7, 0, LMsgs);
    LRoot := TJSONObject.ParseJSONValue(LBodyStr) as TJSONObject;
    try
      CheckNotNull(LRoot, 'JSON deve ser valido');
      LRespFmt := LRoot.FindValue('response_format') as TJSONObject;
      CheckNotNull(LRespFmt, 'response_format deve existir');
      CheckEquals('json_schema', LRespFmt.GetValue<string>('type', ''));

      LSchemaObj := LRespFmt.FindValue('json_schema') as TJSONObject;
      CheckNotNull(LSchemaObj, 'json_schema wrapper deve existir');
      CheckEquals('PrevisaoTempo', LSchemaObj.GetValue<string>('name', ''));
      CheckTrue(LSchemaObj.GetValue<Boolean>('strict', False), 'strict deve ser True');
      CheckNotNull(LSchemaObj.FindValue('schema'), 'schema interno deve existir');
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestLLMStructuredOutput.TestOllama_BuildBodyJSON_JSONObject;
var
  LMsgs: TJSONArray;
  LBodyStr: string;
  LRoot: TJSONObject;
begin
  FOllamaProvider.ResponseFormat.SetJSONObject;
  LMsgs := TJSONArray.Create;
  try
    LBodyStr := FOllamaProvider.TestBuildBodyJSON('llama3.2', 0.7, 0, LMsgs);
    LRoot := TJSONObject.ParseJSONValue(LBodyStr) as TJSONObject;
    try
      CheckNotNull(LRoot, 'JSON deve ser valido');
      CheckEquals('json', LRoot.GetValue<string>('format', ''),
        'Ollama deve receber format: "json"');
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestLLMStructuredOutput.TestOllama_BuildBodyJSON_JSONSchema;
var
  LMsgs: TJSONArray;
  LBodyStr: string;
  LRoot, LFormatObj: TJSONObject;
begin
  FOllamaProvider.ResponseFormat.SetSchema(TypeInfo(TPrevisaoTempoRecord));
  LMsgs := TJSONArray.Create;
  try
    LBodyStr := FOllamaProvider.TestBuildBodyJSON('llama3.2', 0.7, 0, LMsgs);
    LRoot := TJSONObject.ParseJSONValue(LBodyStr) as TJSONObject;
    try
      CheckNotNull(LRoot, 'JSON deve ser valido');
      LFormatObj := LRoot.FindValue('format') as TJSONObject;
      CheckNotNull(LFormatObj, 'Ollama deve receber format como objeto JSON Schema');
      CheckEquals('object', LFormatObj.GetValue<string>('type', ''));
      CheckNotNull(LFormatObj.FindValue('properties'), 'properties deve estar em format');
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestLLMStructuredOutput.TestSendAsJSON_ParsesAndCleansMarkdown;
var
  LJSON: TJSONObject;
begin
  // Simula resposta da IA envolvida em markdown ```json ... ```
  FOpenAIProvider.SetMockResponse('```json' + sLineBreak + '{"resultado": "ok", "valor": 100}' + sLineBreak + '```');
  LJSON := FOpenAIProvider.SendAsJSON;
  try
    CheckNotNull(LJSON, 'JSON parseado nao pode ser nulo');
    CheckEquals('ok', LJSON.GetValue<string>('resultado', ''));
    CheckEquals(100, LJSON.GetValue<Integer>('valor', 0));
  finally
    LJSON.Free;
  end;
end;

procedure TTestLLMStructuredOutput.TestSendAs_GenericRecord;
var
  LPrevisao: TPrevisaoTempoRecord;
begin
  FOpenAIProvider.SetMockResponse(
    '{"cidade":"Porto Alegre","temperatura":24.2,"umidade":65,"chovendo":false,"condicao":"ccEnsolarado"}');

  // Testa SendAs<T> via TLLM<T>
  LPrevisao := TLLM<TPrevisaoTempoRecord>.SendAs(FOpenAIIntf);

  CheckEquals('Porto Alegre', LPrevisao.Cidade, 'Cidade incorreta');
  CheckEquals(24.2, LPrevisao.Temperatura, 0.01, 'Temperatura incorreta');
  CheckEquals(65, LPrevisao.Umidade, 'Umidade incorreta');
  CheckFalse(LPrevisao.Chovendo, 'Chovendo deve ser False');
  CheckTrue(LPrevisao.Condicao = ccEnsolarado, 'Condicao incorreta');

  // Testa tambem chamada nativa direta na interface SendAs(TypeInfo, Buffer)
  LPrevisao := Default(TPrevisaoTempoRecord);
  FOpenAIIntf.SendAs(TypeInfo(TPrevisaoTempoRecord), LPrevisao);
  CheckEquals('Porto Alegre', LPrevisao.Cidade, 'Chamada direta na interface');
end;

procedure TTestLLMStructuredOutput.TestSendAs_GenericClass;
var
  LUser: TUsuarioClass;
begin
  FOllamaProvider.SetMockResponse(
    '{"nome":"Mariana Rios","idade":32,"ativo":true}');

  // Testa SendAs<T> via TLLM<T>
  LUser := TLLM<TUsuarioClass>.SendAs(FOllamaIntf);
  try
    CheckNotNull(LUser, 'Objeto retornado nao pode ser nulo');
    CheckEquals('Mariana Rios', LUser.Nome);
    CheckEquals(32, LUser.Idade);
    CheckTrue(LUser.Ativo);
  finally
    LUser.Free;
  end;

  // Testa tambem chamada nativa direta na interface SendAs(TClass)
  LUser := FOllamaIntf.SendAs(TUsuarioClass) as TUsuarioClass;
  try
    CheckNotNull(LUser, 'Objeto via interface nao pode ser nulo');
    CheckEquals('Mariana Rios', LUser.Nome);
  finally
    LUser.Free;
  end;
end;

initialization
  RegisterTest(TTestLLMStructuredOutput.Suite);

end.
