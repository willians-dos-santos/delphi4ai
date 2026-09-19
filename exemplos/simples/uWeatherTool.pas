unit uWeatherTool;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.NetEncoding,
  LLM.Tools.Attributes;

type
  TWeatherAPI = class
  private
    // Variavel de classe para injetarmos a API Key facilmente
    class var APIKey: string;
  public
    [TLLMTool('get_current_weather',
      'Retorna a temperatura atual e a condicao climatica de uma cidade.')]
    function GetWeather([TLLMParam('O nome da cidade, ex: Bauru')] City: string;
      [TLLMParam('A sigla do pais com duas letras, ex: BR')] CountryCode: string): string;
  end;

implementation

uses
  System.IniFiles;

{ TWeatherAPI }

function TWeatherAPI.GetWeather(City, CountryCode: string): string;
var
  Client: THTTPClient;
  Response: IHTTPResponse;
  URL: string;
  JSONResponse, MainObj, WeatherObj, ResultObj: TJSONObject;
  WeatherArray: TJSONArray;
  Temp: Double;
  Condition: string;
begin
  // Se esquecermos de passar a chave, avisa a IA
  if APIKey.Trim.IsEmpty then
    Exit('{"error": "API Key do OpenWeatherMap nao configurada no sistema."}');

  Client := THTTPClient.Create;
  try
    // Monta a URL da API.
    // units=metric: Traz em Graus Celsius
    // lang=pt_br: Traz a descricao (ex: 'nublado', 'chuva leve') em Portugues
    URL := Format
      ('https://api.openweathermap.org/data/2.5/weather?q=%s,%s&units=metric&lang=pt_br&appid=%s',
      [TNetEncoding.URL.Encode(City.Trim),
      TNetEncoding.URL.Encode(CountryCode.Trim), APIKey]);

    try
      // Faz a requisicao GET na API
      Response := Client.Get(URL);

      if Response.StatusCode = 200 then
      begin
        // Faz o Parse da resposta do OpenWeather
        JSONResponse := TJSONObject.ParseJSONValue
          (Response.ContentAsString(TEncoding.UTF8)) as TJSONObject;
        try
          // Pega a temperatura
          MainObj := JSONResponse.GetValue<TJSONObject>('main');
          Temp := MainObj.GetValue<Double>('temp');

          // Pega a descricao climatica (Fica dentro de um array 'weather')
          WeatherArray := JSONResponse.GetValue<TJSONArray>('weather');
          WeatherObj := WeatherArray.Items[0] as TJSONObject;
          Condition := WeatherObj.GetValue<string>('description');

          // Monta um JSON limpo e mastigado para devolver a nossa LLM
          ResultObj := TJSONObject.Create;
          try
            ResultObj.AddPair('city', City);
            ResultObj.AddPair('country', CountryCode);
            ResultObj.AddPair('temperature_celsius', TJSONNumber.Create(Temp));
            ResultObj.AddPair('condition', Condition);

            Result := ResultObj.ToJSON;
          finally
            ResultObj.Free;
          end;
        finally
          JSONResponse.Free;
        end;
      end
      else
      begin
        // Se a API retornar erro (ex: 404 Cidade nao encontrada), informamos a IA
        Result := Format
          ('{"error": "Falha na API de clima. StatusCode: %d. Talvez a cidade nao exista."}',
          [Response.StatusCode]);
      end;
    except
      on E: Exception do
        Result := Format('{"error": "Erro de conexao: %s"}', [E.Message]);
    end;
  finally
    Client.Free;
  end;
end;

procedure Init;
var
  LDir: string;
  LIni: TIniFile;
  LApiKey: string;
begin
  LDir := ExtractFileDir(ParamStr(0));
  LIni := TIniFile.Create(LDir + '\weather_tool\env.ini');
  try
    LApiKey := LIni.ReadString('weather_tool', 'api_key', EmptyStr);
    TWeatherAPI.APIKey := LApiKey;
  finally
    LIni.Free;
  end;
end;

initialization

Init;

end.