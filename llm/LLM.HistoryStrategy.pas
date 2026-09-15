unit LLM.HistoryStrategy;

interface
type
  /// <summary>
  /// Estratégia de gestão e poda do histórico de mensagens
  /// </summary>
  THistoryStrategy = (
    hsNone,          // Histórico cresce livremente (sem poda)
    hsSlidingWindow, // Descarta as mensagens mais antigas (preserva o System prompt)
    hsSummarize      // Condensa as mensagens antigas em um resumo via API
  );

implementation

end.
