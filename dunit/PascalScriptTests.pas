unit PascalScriptTests;

interface

uses
  System.SysUtils, TestFramework,
  uPSCompiler, uPSComponent, uPSRuntime;

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
  end;

implementation

uses
  uPSC_classes, uPSComponent_Default, uPSR_classes;

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
  SIRegister_Classes(x, True);
end;

procedure TPascalScriptTests.OnExecImport(Sender: TObject; se: TPSExec;
  x: TPSRuntimeClassImporter);
begin
  RIRegister_Classes(x, True);
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

initialization
  RegisterTest(TPascalScriptTests.Suite);
end.
