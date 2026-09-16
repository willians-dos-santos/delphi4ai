unit LLM.Exceptions;

interface

uses
  System.SysUtils;

type
  /// <summary>
  /// Exceção base da biblioteca Delphi4AI
  /// </summary>
  ELLMException = class(Exception);

  /// <summary>
  /// Exceção disparada quando uma chamada à API de LLM falha
  /// </summary>
  ELLMAPIError = class(ELLMException);

implementation

end.
