unit PascalScriptTests;

interface

uses
  System.SysUtils, TestFramework,
  uPSCompiler, uPSComponent, uPSRuntime, uPSUtils;

type
  TPascalScriptTests = class(TTestCase)
  type
    TPSPluginClass = class of TPSPlugin;
    TExecute<T> = function: T of object;
  private
    FScripter: TPSScript;
    procedure OnCompImport(Sender: TObject; x: TPSPascalCompiler);
    procedure OnExecImport(Sender: TObject; se: TPSExec; x:
            TPSRuntimeClassImporter);
    function Execute<T>(aScript: string): T;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Test_cd5664c2;
    procedure Test_179;
    procedure Test_Format;
    procedure Test_CreateOleObject;
    procedure Test_BadVariableType;
    procedure Test_Event;
    procedure Test_Event_Abort;
    procedure Test_277;
    procedure Script_CreateOleVariantArray;
    procedure Script_FindKeyByRef;
    procedure SQLAcc_FindKeyByRef;
  end;

implementation

uses
  Winapi.ActiveX, System.Win.ComObj,
  uPSC_classes, uPSC_comobj, uPSComponent_Default, uPSR_classes, uPSR_comobj;

procedure TPascalScriptTests.SetUp;
begin
  inherited;
  FScripter := TPSScript.Create(nil);

  for var c in [TPSImport_Classes] do
    (FScripter.Plugins.Add as TPSPluginItem).Plugin := TPSPluginClass(c).Create(FScripter);

  FScripter.OnCompImport := OnCompImport;
  FScripter.OnExecImport := OnExecImport;
end;

function TPascalScriptTests.Execute<T>(aScript: string): T;
begin
  FScripter.Script.Text := aScript;
  FScripter.CompilerOptions := FScripter.CompilerOptions + [icAllowNoBegin, icAllowNoEnd];

  if not FScripter.Compile then begin
    var A: TArray<string>;
    for var i := 0 to FScripter.CompilerMessageCount - 1 do
      A := A + [string(FScripter.CompilerMessages[i].MessageToString)];
    Status(string.Join(sLineBreak, A));
  end;

  var Execute := TExecute<T>(FScripter.GetProcMethod('Execute'));
  Result := Execute;
end;

procedure TPascalScriptTests.OnCompImport(Sender: TObject;
  x: TPSPascalCompiler);
begin
  x.AddDelphiFunction('procedure Abort');
  x.AddDelphiFunction('function Format(const Format: string; const Args: array of const): string');
  SIRegister_Classes(x, True);
  SIRegister_ComObj(x);
end;

procedure TPascalScriptTests.OnExecImport(Sender: TObject; se: TPSExec;
  x: TPSRuntimeClassImporter);
begin
  se.RegisterDelphiFunction(@Abort, 'Abort', cdRegister);
  se.RegisterDelphiFunction(@Format, 'Format', cdRegister);
  RIRegister_Classes(x, True);
  RIRegister_ComObj(se);
end;

procedure TPascalScriptTests.TearDown;
begin
  FScripter.Free;
  inherited;
end;

procedure TPascalScriptTests.Test_cd5664c2;
begin
  CheckEquals(
    10
  , Execute<Integer>('''
    function Execute: Integer;
    var B: TStringList;
    begin
      B := TStringList.Create;
      try
        while B.Count < 10 do
          B.Add('B');
        Result := B.Count;
      finally
        B.Free;
      end;
    end;
  ''')
  );
end;

procedure TPascalScriptTests.Test_179;
begin
  StartExpectingException(EAbort);
  CheckEquals(
    ''
  , Execute<string>('''
    function Execute: string;
    begin
      Abort;
    end;
    ''')
  );
end;

procedure TPascalScriptTests.Test_CreateOleObject;
begin
  CoInitialize(nil);
  try
    CheckEquals(
      'True'
    , Execute<string>('''
      function Execute: string;
      var o: Variant;
      begin
        o := CreateOleObject('Schedule.Service.1');
        o.Connect('');
        Result := o.Connected;
      end;
      ''')
      );
  finally
    CoUninitialize;
  end;
end;

procedure TPascalScriptTests.Test_Event;
begin
  CheckEquals(
    'Invoke OnChange'
  , Execute<string>('''
    var Response: string;

    procedure OnChange(Sender: TObject);
    begin
      Response := 'Invoke OnChange';
    end;

    function Execute: string;
    var s: TStringList;
    begin
      s := TStringList.Create;
      try
        s.OnChange := @OnChange;
        s.Add('test');
        Result := Response;
      finally
        s.Free;
      end;
    end;
    ''')
  );
end;

procedure TPascalScriptTests.Test_Event_Abort;
begin
  StartExpectingException(EAbort);

  CheckEquals(
    ''
  , Execute<string>('''
    var Response: string;

    procedure OnChange(Sender: TObject);
    begin
      Abort;
    end;

    function Execute: string;
    var s: TStringList;
    begin
      s := TStringList.Create;
      try
        s.OnChange := @OnChange;
        s.Add('test');
      finally
        s.Free;
      end;
    end;
    ''')
  );
end;

procedure TPascalScriptTests.Test_Format;
begin
  CheckEquals(
    'Print Hello World 123456'
  , Execute<string>('''
    function Execute: string;
    begin
      Result := Format('Print %s %d', ['Hello World', 123456]);
    end;
    ''')
  );
end;

procedure TPascalScriptTests.Test_BadVariableType;
begin
  CheckNotEquals(
    ''
  , Execute<string>('''
    function Execute: string;
    var o, F, T: Variant;
        R: string;
    begin
      o := CreateOleObject('Schedule.Service.1');
      o.Connect;

      F := o.GetFolder('\');
      T := F.GetTasks(0);

      R := T.Item[1].NextRunTime;
      Result := R;

      R := T.Item[1].Name;
      Result := Result + #13#10 + R;

      R := T.Item[1].NumberOfMissedRuns;
      Result := Result + #13#10 + R;

      R := T.Item[1].Enabled;
      Result := Result + #13#10 + R;
    end;
    ''')
  );
end;

procedure TPascalScriptTests.Test_277;
begin
  CheckEquals(
    'TEST'
  , Execute<string>('''
    function Execute: string;
    var V: Variant;
    begin
      V := 'Test';
      Result := UpperCase(V);
    end;
    ''')
  );
end;

procedure TPascalScriptTests.Script_CreateOleVariantArray;
begin
  CheckEquals(
    'Bingo'
  , Execute<string>('''
    function Execute: string;
    var o, a: Variant;
    begin
      o := CreateOleObject('SQLAcc.BizApp');
      a := o.CreateOleVariantArray(1);
      a.SetItem(0, 'hello');
      a.SetItem(1, '1234');
      a.AsOleVariant;
      Result := 'Bingo';
    end;
    ''')
  );
end;

procedure TPascalScriptTests.Script_FindKeyByRef;
begin
  {$ifndef PS_USECLASSICINVOKE}Check(False, 'Define PS_USECLASSICINVOKE for Win32 build');{$endif}

  CheckEquals(
    '1'
  , Execute<string>('''
    function Execute: string;
    var o, A, B, D, K1, K2: Variant;
    begin
      o := CreateOleObject('SQLAcc.BizApp');
      B := o.BizObjects.Find('AR_IV');
      D := B.DataSets.Find('MainDataSet');

      K1 := B.FindKeyByRef('DocNo;Code', ['IV-00001', '300-T0001']);

      A := o.CreateOleVariantArray(1);
      A.SetItem(0, 'IV-00001');
      A.SetItem(1, '300-T0001');
      K2 := B.FindKeyByRef('DocNo;Code', A.AsOleVariant);

      if K1 = K2 then Result := K2;
    end;
    ''')
  );
end;

procedure TPascalScriptTests.SQLAcc_FindKeyByRef;
begin
  var o: OleVariant;

  o := CreateOleObject('SQLAcc.BizApp');
  var B := o.BizObjects.Find('AR_IV');
  var D := B.DataSets.Find('MainDataSet');

  var a := o.CreateOleVariantArray(1);
  a.SetItem(0, 'IV-00001');
  a.SetItem(1, '300-T0001');

  var K := B.FindKeyByRef('DocNo;Code', a.AsOleVariant);
  CheckEquals(1, K);
end;

initialization
  RegisterTest(TPascalScriptTests.Suite);
end.
