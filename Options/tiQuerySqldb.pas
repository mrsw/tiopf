{
  This unit implements the base classes for the Free Pascal SQLDB persistence
  layer.

  Initial Author:  Michael Van Canneyt (michael@freepascal.org) - Aug 2008
}

unit tiQuerySqldb;

{$I tiDefines.inc}

{ For debug purposes only }
{.$Define LOGSQLDB}


interface

uses
  Classes,
  SysUtils,
  DB,
  sqldb,
  tiQuery,
  tiQueryDataset,
  tiPersistenceLayers;

type

  TtiPersistenceLayerSqldDB = class(TtiPersistenceLayer)
    function GetQueryClass: TtiQueryClass; override;
  end;


  TtiDatabaseSQLDB = class(TtiDatabaseSQL)
  private
    FDatabase: TSQLConnection;
    FTransaction: TSQLTransaction;
  protected
    procedure SetConnected(AValue: Boolean); override;
    function GetConnected: Boolean; override;
    class function CreateSQLConnection: TSQLConnection; virtual; abstract;
    function HasNativeLogicalType: Boolean; virtual;
  public
    constructor Create; override;
    destructor Destroy; override;
    class function DatabaseExists(const ADatabaseName, AUserName, APassword: string): Boolean; override;
    class procedure CreateDatabase(const ADatabaseName, AUserName, APassword: string); override;
    class procedure DropDatabase(const ADatabaseName, AUserName, APassword: string); override;
    property SQLConnection: TSQLConnection read FDatabase write FDatabase;
    procedure StartTransaction; override;
    function InTransaction: Boolean; override;
    procedure Commit; override;
    procedure RollBack; override;
    function Test: Boolean; override;
    function TIQueryClass: TtiQueryClass; override;
  end;


  TtiQuerySQLDB = class(TtiQueryDataset)
  private
    FSQLQuery: TSQLQuery;
    FbActive: Boolean;
    procedure Prepare;
  protected
    procedure CheckPrepared; override;
    procedure SetActive(const AValue: Boolean); override;
    function GetSQL: TStrings; override;
    procedure SetSQL(const AValue: TStrings); override;
  public
    constructor Create; override;
    destructor Destroy; override;
    function ExecSQL: integer; override;
    procedure AttachDatabase(ADatabase: TtiDatabase); override;
    procedure DetachDatabase; override;
    procedure Reset; override;
    function HasNativeLogicalType: Boolean; override;
  end;


implementation

uses
  tiUtils,
  tiLog,
  TypInfo,
  tiConstants,
  tiExcept,
  Variants;


{ TtiQuerySQLDB }

constructor TtiQuerySQLDB.Create;
begin
  inherited;
  FSQLQuery  := TSQLQuery.Create(nil);
  Dataset := FSQLQuery;
  Params  := FSQLQuery.Params;
  FSupportsRowsAffected := True;
end;

destructor TtiQuerySQLDB.Destroy;
begin
  Params  := nil;
  Dataset := nil;
  FSQLQuery.Free;
  inherited;
end;

function TtiQuerySQLDB.ExecSQL: integer;
begin
  Log(ClassName + ': [Prepare] ' + tiNormalizeStr(self.SQLText), lsSQL);
  Prepare;
  LogParams;
  FSQLQuery.ExecSQL;
  Result := FSQLQuery.RowsAffected;
end;

function TtiQuerySQLDB.GetSQL: TStrings;
begin
  Result := FSQLQuery.SQL;
end;

procedure TtiQuerySQLDB.SetActive(const AValue: Boolean);
begin
{$ifdef LOGSQLDB}
  log('>>> TtiQuerySQLDB.SetActive');
{$endif}
  Assert(Database.TestValid(TtiDatabase), CTIErrorInvalidObject);
  if AValue then
  begin
    {$ifdef LOGSQLDB}
    Log('Open Query');
    {$endif}
    FSQLQuery.Open;
    FbActive := True;
  end
  else
  begin
    {$ifdef LOGSQLDB}
    Log('Closing Query');
    {$endif}
    FSQLQuery.Close;
    FbActive := False;
  end;
{$ifdef LOGSQLDB}
  log('<<< TtiQuerySQLDB.SetActive');
{$endif}
end;

procedure TtiQuerySQLDB.SetSQL(const AValue: TStrings);
begin
{$ifdef LOGSQLDB}
  log('>>>> SetSQL: ' + AValue.Text);
{$endif}
  FSQLQuery.SQL.Assign(AValue);
{$ifdef LOGSQLDB}
  log('<<<< SetSQL');
{$endif}
end;

procedure TtiQuerySQLDB.CheckPrepared;
begin
{$ifdef LOGSQLDB}
  Log('>>> TtiQuerySQLDB.CheckPrepared');
{$endif}
  inherited CheckPrepared;
  if not FSQLQuery.Prepared then
    Prepare;
{$ifdef LOGSQLDB}
  Log('<<< TtiQuerySQLDB.CheckPrepared');
{$endif}
end;

procedure TtiQuerySQLDB.Prepare;
begin
{$ifdef LOGSQLDB}
  Log('>>> TtiQuerySQLDB.Prepare');
{$endif}
  if FSQLQuery.Prepared then
    Exit; //==>
  FSQLQuery.Prepare;
{$ifdef LOGSQLDB}
  Log('<<< TtiQuerySQLDB.Prepare');
{$endif}
end;

procedure TtiQuerySQLDB.AttachDatabase(ADatabase: TtiDatabase);
begin
  inherited AttachDatabase(ADatabase);
  if (Database is TtiDatabaseSQLDB) then
  begin
    FSQLQuery.Database    := TtiDatabaseSQLDB(Database).SQLConnection;
    FSQLQuery.Transaction := TtiDatabaseSQLDB(Database).SQLConnection.Transaction;
  end;
end;

procedure TtiQuerySQLDB.DetachDatabase;
begin
  inherited DetachDatabase;
  if FSQLQuery.Active then
    FSQLQuery.Close;
  FSQLQuery.Transaction := nil;
  FSQLQuery.Database    := nil;
end;

procedure TtiQuerySQLDB.Reset;
begin
  Active := False;
  FSQLQuery.SQL.Clear;
end;

function TtiQuerySQLDB.HasNativeLogicalType: Boolean;
begin
  if not Assigned(Database) then
    Result := True
  else
    Result := TtiDatabaseSQLDB(Database).HasNativeLogicalType;
end;


{ TtiDatabaseSQLDB }

constructor TtiDatabaseSQLDB.Create;
begin
  inherited Create;
  FDatabase           := CreateSQLConnection;
  FDatabase.LoginPrompt := False;
  FTransaction        := TSQLTransaction.Create(nil);
  FTransaction.DataBase := FDatabase;
  FDatabase.Transaction := FTransaction;
  FTransaction.Active := False;
end;

destructor TtiDatabaseSQLDB.Destroy;
begin
  try
    FTransaction.Active   := False;
    FDatabase.Connected   := False;
    FDatabase.Transaction := nil;
    FTransaction.Database := nil;
    FTransaction.Free;
    FDatabase.Free;
  except
    {$ifdef logsqldb}
    on e: Exception do
      LogError(e.message);
    {$endif}
  end;
  inherited;
end;

procedure TtiDatabaseSQLDB.Commit;
begin
  if not InTransaction then
    raise EtiOPFInternalException.Create('Attempt to commit but not in a transaction.');

  Log(ClassName + ': [Commit Trans]', lsSQL);
  //  FTransaction.CommitRetaining;
  FTransaction.Commit;
end;

function TtiDatabaseSQLDB.InTransaction: Boolean;
begin
  //  Result := False;
  Result := FTransaction.Active;
  //  Result := (FTransaction.Handle <> NIL);
end;

procedure TtiDatabaseSQLDB.RollBack;
begin
  Log(ClassName + ': [RollBack Trans]', lsSQL);
  //  FTransaction.RollbackRetaining;
  FTransaction.RollBack;
end;

procedure TtiDatabaseSQLDB.StartTransaction;
begin
  if InTransaction then
    raise EtiOPFInternalException.Create(
      'Attempt to start a transaction but transaction already exists.');

  Log(ClassName + ': [Start Trans]', lsSQL);
  FTransaction.StartTransaction;
end;

function TtiDatabaseSQLDB.GetConnected: Boolean;
begin
  Result := FDatabase.Connected;
end;

procedure TtiDatabaseSQLDB.SetConnected(AValue: Boolean);
var
  lMessage: string;
begin
  try
    if (not AValue) then
    begin
      {$ifdef LOGSQLDB}
      Log('Disconnecting from %s', [DatabaseName], lsConnectionPool);
      {$endif}
      FDatabase.Connected := False;
      Exit; //==>
    end;

    if tiNumToken(DatabaseName, ':') > 1 then
    begin
      // Assumes tiOPF's "databasehost:databasename" format.
      FDatabase.HostName      := tiToken(DatabaseName, ':', 1);
      FDatabase.DatabaseName  := tiToken(DatabaseName, ':', 2);
    end
    else
      FDatabase.DatabaseName := DatabaseName;

    FDatabase.Params.Assign(Params);
    FDatabase.UserName     := Username;
    FDatabase.Password     := Password;

    { Assign some well known extra parameters if they exist. }
    if Params.Values['ROLE'] <> '' then
      FDatabase.Role := Params.Values['ROLE'];
    { charset is a db neutral property we defined for tiOPF. }
    if Params.Values['CHARSET'] <> '' then
      FDatabase.CharSet := Params.Values['CHARSET'];
    { lc_ctype is native to Interface/Firebird databases. }
    if Params.Values['LC_CTYPE'] <> '' then
      FDatabase.CharSet := Params.Values['LC_CTYPE'];

    FDatabase.Connected    := True;
  except
    // ToDo: Must come up with a better solution that this:
    //       Try several times before raising an exception.
    //       Rather than calling 'Halt', just terminate this database connection,
    //       unless this is the first connection.
    on e: EDatabaseError do
    begin
      // Invalid username / password error
      //      if (EIBError(E).IBErrorCode = 335544472) then
      //        raise EtiOPFDBExceptionUserNamePassword.Create(cTIPersistIBX, DatabaseName, UserName, Password)
      //      else
      //      begin
      lMessage :=
        'Error attempting to connect to database.' + Cr + e.Message;
      raise EtiOPFDBExceptionUserNamePassword.Create(
        cTIPersistSqldbIB, DatabaseName, UserName, Password, lMessage);
      //      end;
    end
    else
      raise EtiOPFDBException.Create(cTIPersistSqldbIB, DatabaseName, UserName, Password)
  end;
end;

class procedure TtiDatabaseSQLDB.CreateDatabase(const ADatabaseName, AUserName, APassword: string);
var
  DB: TSQLConnection;
begin
  if (ADatabaseName <> '') or (AUserName <> '') or (APassword <> '') then
  begin
    DB := CreateSQLConnection;
    try
      DB.DatabaseName := ADatabasename;
      DB.UserName := AUsername;
      DB.Password := APassword;
      DB.CreateDB;
    finally
      DB.Free;
    end;
  end;
end;

class procedure TtiDatabaseSQLDB.DropDatabase(const ADatabaseName, AUserName, APassword: string);
var
  DB: TSQLConnection;
begin
  if (ADatabaseName <> '') or (AUserName <> '') or (APassword <> '') then
  begin
    DB := CreateSQLConnection;
    try
      DB.DatabaseName := ADatabasename;
      DB.UserName := AUsername;
      DB.Password := APassword;
      DB.DropDB;
    finally
      DB.Free;
    end;
  end;
end;

class function TtiDatabaseSQLDB.DatabaseExists(const ADatabaseName, AUserName, APassword: string): Boolean;
var
  DB: TSQLConnection;
begin
  Result := False;
  if (ADatabaseName <> '') or (AUserName <> '') or (APassword <> '') then
  begin
    DB := CreateSQLConnection;
    try
      DB.DatabaseName := ADatabaseName;
      DB.UserName := AUserName;
      DB.Password := APassword;
      try
        DB.Connected := True;
        Result := True;
      except
        on e: Exception do
          Result := False;
      end;
      DB.Connected := False;
    finally
      DB.Free;
    end;
  end;
end;

function TtiDatabaseSQLDB.Test: Boolean;
begin
  Result := False;
  Assert(False, 'Under construction');
end;

function TtiDatabaseSQLDB.TIQueryClass: TtiQueryClass;
begin
  Result := TtiQuerySQLDB;
end;

function TtiDatabaseSQLDB.HasNativeLogicalType: Boolean;
begin
  Result := True;
end;

function TtiPersistenceLayerSqldDB.GetQueryClass: TtiQueryClass;
begin
  Result := TtiQuerySqldb;
end;


end.

