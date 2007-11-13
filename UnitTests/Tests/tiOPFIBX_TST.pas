unit tiOPFIBX_TST;

{$I tiDefines.inc}

interface
uses
   tiQuery_TST
  ,tiQuerySQL_TST
  ,tiOPFTestManager
  ,tiAutoMap_TST
  ,tiOID_tst
  ,tiAutomapCriteria_TST
 ;

type

  TTestTIPersistenceLayersIBX = class(TTestTIPersistenceLayers)
  protected
    procedure SetUp; override;
  end;

  TTestTIDatabaseIBX = class(TTestTIDatabase)
  protected
    procedure SetUp; override;
  published
    procedure DatabaseExists; override;
    procedure CreateDatabase; override;
  end;

  TTestTIQueryIBX = class(TTestTIQuerySQL)
  protected
    procedure SetUp; override;
  end;

  TTestTIAutoMapOperationIBX = class(TTestTIAutoMapOperation)
  protected
    procedure   SetUp; override;
  end;

  TTestAutomappingCriteriaIBX = class(TTestAutomappingCriteria)
  protected
    procedure   SetUp; override;
  end;

  TTestTIOIDManagerIBX = class(TTestTIOIDManager)
  protected
    procedure   SetUp; override;
  end;

procedure RegisterTests;

implementation
uses
  tiConstants
  {$IFDEF FPC}
  ,tiFPCUnitUtils
  {$ELSE}
  ,TestFramework
  {$ENDIF}
  ,SysUtils
  ,tiUtils
  ,tiTestDependencies
 ;
  
procedure RegisterTests;
begin
  if gTIOPFTestManager.ToRun(cTIPersistIBX) then
  begin
    RegisterTest(PersistentSuiteName(cTIPersistIBX), TTestTIPersistenceLayersIBX.Suite);
    RegisterTest(PersistentSuiteName(cTIPersistIBX), TTestTIDatabaseIBX.Suite);
    RegisterTest(PersistentSuiteName(cTIPersistIBX), TTestTIQueryIBX.Suite);
    RegisterTest(PersistentSuiteName(cTIPersistIBX), TTestTIOIDManagerIBX.Suite);
    RegisterTest(PersistentSuiteName(cTIPersistIBX), TTestTIAutoMapOperationIBX.Suite);
    RegisterTest(PersistentSuiteName(cTIPersistIBX), TTestAutomappingCriteriaIBX.Suite);
  end;
end;

{ TTestTIDatabaseIBX }

procedure TTestTIDatabaseIBX.CreateDatabase;
var
  lDB : string;
  lDBExists : boolean;
begin
  lDB := ExpandFileName(PerFrameworkSetup.DBName);
  lDB := tiSwapExt(lDB, 'tmp');
  if FileExists(lDB) then
  begin
    tiDeleteFile(lDB);
    if FileExists(lDB) then
      Fail('Can not remove old database file');
  end;

  Check(not FileExists(lDB), 'Database exists when it should not');
  FDatabaseClass.CreateDatabase(
    lDB,
    PerFrameworkSetup.Username,
    PerFrameworkSetup.Password);
  Check(FileExists(lDB), 'Database not created');

  lDBExists :=
    FDatabaseClass.DatabaseExists(
      lDB,
      PerFrameworkSetup.Username,
      PerFrameworkSetup.Password);

  Check(lDBExists, 'Database does not exist when it should do');
  tiDeleteFile(lDB);
end;

procedure TTestTIDatabaseIBX.DatabaseExists;
var
  lDB : string;
  lDBExists : boolean;
begin
  lDB := PerFrameworkSetup.DBName;
  Check(FileExists(lDB), 'Database file not found so test can not be performed');
  lDBExists :=
    FDatabaseClass.DatabaseExists(
      PerFrameworkSetup.DBName,
      PerFrameworkSetup.Username,
      PerFrameworkSetup.Password);
  Check(lDBExists, 'DBExists returned false when it should return true');
  Check(not FileExists(lDB + 'Tmp'), 'Database file found so test can not be performed');
  lDBExists :=
    FDatabaseClass.DatabaseExists(
      PerFrameworkSetup.DBName + 'Tmp',
      PerFrameworkSetup.Username,
      PerFrameworkSetup.Password);
  Check(not lDBExists, 'DBExists returned true when it should return false');
end;

procedure TTestTIDatabaseIBX.SetUp;
begin
  PerFrameworkSetup:= gTIOPFTestManager.FindByPerLayerName(cTIPersistIBX);
  inherited;
end;

{ TTestTIPersistenceLayersIBX }

procedure TTestTIPersistenceLayersIBX.SetUp;
begin
  PerFrameworkSetup:= gTIOPFTestManager.FindByPerLayerName(cTIPersistIBX);
  inherited;
end;

{ TTestTIQueryIBX }

procedure TTestTIQueryIBX.SetUp;
begin
  PerFrameworkSetup:= gTIOPFTestManager.FindByPerLayerName(cTIPersistIBX);
  inherited;
end;

{ TTestTIAutoMapOperationIBX }

procedure TTestTIAutoMapOperationIBX.SetUp;
begin
  PerFrameworkSetup:= gTIOPFTestManager.FindByPerLayerName(cTIPersistIBX);
  inherited;
end;

{ TTestTIOIDManagerIBX }

procedure TTestTIOIDManagerIBX.SetUp;
begin
  PerFrameworkSetup:= gTIOPFTestManager.FindByPerLayerName(cTIPersistIBX);
  inherited;
end;

{ TTestAutomappingCriteriaIBX }

procedure TTestAutomappingCriteriaIBX.SetUp;
begin
  PerFrameworkSetup:= gTIOPFTestManager.FindByPerLayerName(cTIPersistIBX);
  inherited;
end;

end.
