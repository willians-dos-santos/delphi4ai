unit LLM.Exceptions;

interface

uses
  System.SysUtils;

type
  /// <summary>
  /// Excecao base da biblioteca Delphi4AI
  /// </summary>
  ELLMException = class(Exception);

  /// <summary>
  /// Excecao disparada quando uma chamada a API de LLM falha
  /// </summary>
  ELLMAPIError = class(ELLMException);

  /// <summary>
  /// Excecao base para erros relacionados a Tools e Function Calling
  /// </summary>
  ELLMToolException = class(ELLMException);

  /// <summary>
  /// Disparada quando o modelo requisita uma ferramenta que nao foi registrada
  /// </summary>
  ELLMToolNotFoundException = class(ELLMToolException);

  /// <summary>
  /// Disparada quando ocorre um erro na execucao do callback da ferramenta
  /// </summary>
  ELLMToolExecutionException = class(ELLMToolException);

  /// <summary>
  /// Disparada quando o loop de chamadas de ferramentas excede o limite configurado
  /// </summary>
  ELLMMaxToolIterationsException = class(ELLMToolException);

implementation

end.