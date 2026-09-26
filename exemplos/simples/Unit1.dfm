object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Delphi4AI - Exemplo Simples (Chat VCL)'
  ClientHeight = 600
  ClientWidth = 780
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlConfig: TPanel
    Left = 0
    Top = 0
    Width = 780
    Height = 177
    Align = alTop
    BevelOuter = bvNone
    Padding.Left = 8
    Padding.Top = 8
    Padding.Right = 8
    Padding.Bottom = 8
    TabOrder = 0
    ExplicitWidth = 778
    object grpConfig: TGroupBox
      Left = 8
      Top = 8
      Width = 764
      Height = 161
      Align = alClient
      Caption = ' Configura'#231#245'es do Provedor de IA '
      TabOrder = 0
      ExplicitWidth = 762
      object lblBaseURL: TLabel
        Left = 16
        Top = 56
        Width = 51
        Height = 15
        Caption = 'Base URL:'
      end
      object lblModel: TLabel
        Left = 472
        Top = 56
        Width = 44
        Height = 15
        Caption = 'Modelo:'
      end
      object lblApiKey: TLabel
        Left = 16
        Top = 84
        Width = 43
        Height = 15
        Caption = 'API Key:'
      end
      object lblStrategy: TLabel
        Left = 472
        Top = 84
        Width = 54
        Height = 15
        Caption = 'Estrat'#233'gia:'
      end
      object lblSystemPrompt: TLabel
        Left = 16
        Top = 112
        Width = 84
        Height = 15
        Caption = 'System Prompt:'
      end
      object lblInfo: TLabel
        Left = 256
        Top = 140
        Width = 457
        Height = 13
        Caption = 
          'Dica: voc'#234' tamb'#233'm pode usar Groq, Ollama (localhost:11434) ou qu' +
          'alquer API compat'#237'vel!'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object Label1: TLabel
        Left = 16
        Top = 24
        Width = 51
        Height = 15
        Caption = 'Provedor:'
      end
      object edtBaseURL: TEdit
        Left = 104
        Top = 53
        Width = 350
        Height = 23
        TabOrder = 0
        Text = 'http://localhost:11434/api/chat'
      end
      object edtModel: TEdit
        Left = 536
        Top = 53
        Width = 210
        Height = 23
        TabOrder = 1
        Text = 'gpt-oss:120b-cloud'
      end
      object edtApiKey: TEdit
        Left = 104
        Top = 81
        Width = 350
        Height = 23
        PasswordChar = '*'
        TabOrder = 2
        TextHint = 'Cole sua API Key aqui (sk-...)'
      end
      object cbbStrategy: TComboBox
        Left = 536
        Top = 81
        Width = 210
        Height = 23
        Style = csDropDownList
        ItemIndex = 0
        TabOrder = 3
        Text = 'Janela Deslizante (Sliding Window)'
        OnChange = cbbStrategyChange
        Items.Strings = (
          'Janela Deslizante (Sliding Window)'
          'Sumariza'#231#227'o (Summarize)'
          'Sem Poda (None)')
      end
      object edtSystemPrompt: TEdit
        Left = 104
        Top = 109
        Width = 642
        Height = 23
        TabOrder = 4
        Text = 'Voc'#234' '#233' um assistente prestativo e amig'#225'vel.'
      end
      object btnAplicar: TButton
        Left = 104
        Top = 136
        Width = 140
        Height = 24
        Caption = 'Reiniciar Conversa'
        TabOrder = 5
        OnClick = btnAplicarClick
      end
      object cbProvider: TComboBox
        Left = 104
        Top = 24
        Width = 145
        Height = 23
        Style = csDropDownList
        TabOrder = 6
      end
    end
  end
  object pnlClient: TPanel
    Left = 0
    Top = 177
    Width = 780
    Height = 345
    Align = alClient
    BevelOuter = bvNone
    Padding.Left = 8
    Padding.Right = 8
    TabOrder = 1
    ExplicitWidth = 778
    ExplicitHeight = 337
    object memChat: TMemo
      Left = 8
      Top = 0
      Width = 764
      Height = 345
      Align = alClient
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 0
      ExplicitWidth = 762
      ExplicitHeight = 337
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 522
    Width = 780
    Height = 78
    Align = alBottom
    BevelOuter = bvNone
    Padding.Left = 8
    Padding.Top = 4
    Padding.Right = 8
    Padding.Bottom = 8
    TabOrder = 2
    ExplicitTop = 514
    ExplicitWidth = 778
    object lblStatus: TLabel
      Left = 8
      Top = 46
      Width = 138
      Height = 15
      Caption = 'Mensagens no hist'#243'rico: 0'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object edtInput: TEdit
      Left = 8
      Top = 8
      Width = 556
      Height = 25
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      TextHint = 'Digite uma mensagem ou clique nos bot'#245'es de Sa'#237'da Estruturada...'
      OnKeyDown = edtInputKeyDown
    end
    object btnEnviar: TButton
      Left = 572
      Top = 8
      Width = 96
      Height = 25
      Caption = 'Enviar'
      Default = True
      TabOrder = 1
      OnClick = btnEnviarClick
    end
    object btnLimpar: TButton
      Left = 676
      Top = 8
      Width = 96
      Height = 25
      Caption = 'Limpar Chat'
      TabOrder = 2
      OnClick = btnLimparClick
    end
    object btnTestRecord: TButton
      Left = 410
      Top = 40
      Width = 175
      Height = 28
      Caption = #62667' Estruturado (Record)'
      TabOrder = 3
      OnClick = btnTestRecordClick
    end
    object btnTestClass: TButton
      Left = 597
      Top = 40
      Width = 175
      Height = 28
      Caption = #62427' Estruturado (Classe)'
      TabOrder = 4
      OnClick = btnTestClassClick
    end
  end
end
