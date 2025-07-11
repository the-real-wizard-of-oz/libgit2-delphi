unit libgit2_wrapper;

interface

uses
  System.SysUtils,
  System.Classes,
  libgit2;

const
  UNLIMITED_CLONE_DEPTH = -1;

type
  TLibGit2LogEvent = procedure(Sender: TObject; const aText: string) of object;

  TLibGit2Option = (lgoIgnoreCertificateErrors, lgoVerboseGitProgress);

  TLibGit2Options = set of TLibGit2Option;

  TLibGit2Properties = class(TPersistent)
  private
    FUsername: String;
    FPassword: String;
    FOptions: TLibGit2Options;
  published
    property Username: String read FUsername write FUsername;
    property Password: String read FPassword write FPassword;
    property Options: TLibGit2Options read FOptions write FOptions;
  end;

  {$M+}
  TLibGit2 = class
  private
    FLastErrorText: String;
    FProps: TLibGit2Properties;
    FOnLog: TLibGit2LogEvent;
    procedure SetLastErrorFromGit;

    procedure DoLog(const aText: String; const aArgs: array of const); overload;

    function HttpsCredentialCallback(
      out cred: Pgit_credential;
      url, username_from_url: PAnsiChar;
      allowed_types: Cardinal;
      payload: Pointer): Integer; cdecl;

    function AcceptAnyCertificateCallback(cert: Pgit_cert;
      valid: Integer;
      host: PAnsiChar;
      payload: Pointer): Integer; cdecl;

    function TransferProgressCallback(stats: Pgit_indexer_progress;
      payload: Pointer): Integer; cdecl;

    function SidebandProgressCallback(str: PAnsiChar;
      len: Size_t;
      payload: Pointer): Integer; cdecl;

  public
    constructor Create;

    destructor Destroy; override;

    function Init(const aRepoPath: TFileName): Boolean;

    function Clone(const aUrl: String;
      const aLocalPath: TFileName;
      const aBranchName: String = '';
      const aDepth: Integer = UNLIMITED_CLONE_DEPTH): Boolean;

    function IsGitRepo(const aPath: TFileName): Boolean;

    function ExistsRemoteBranch(const aRepoPath, aRemoteName, aBranchName: String): Boolean;

    property LastErrorText: String read FLastErrorText;

    property Props: TLibGit2Properties read FProps write FProps;

    property OnLog: TLibGit2LogEvent read FOnLog write FOnLog;
  end;

implementation

function Static_CredentialsCallback(out cred: Pgit_credential;
  url, username_from_url: PAnsiChar;
  allowed_types: Cardinal;
  payload: Pointer): Integer; cdecl;
begin
  Result := TLibGit2(payload).HttpsCredentialCallback(
    cred, url, username_from_url, allowed_types, payload);
end;

function Static_CertificateCheckCallback(cert: Pgit_cert;
  valid: Integer;
  host: PAnsiChar;
  payload: Pointer): Integer; cdecl;
begin
  Result := TLibGit2(payload).AcceptAnyCertificateCallback(cert, valid, host, payload);
end;

function Static_TransferProgressCallback(progress: Pgit_indexer_progress;
  payload: Pointer): Integer; cdecl;
begin
  Result := TLibGit2(payload).TransferProgressCallback(progress, payload);
end;

function Static_SidebandProgressCallback(str: PAnsiChar;
  len: Size_t;
  payload: Pointer): Integer; cdecl;
begin
  Result := TLibGit2(payload).SidebandProgressCallback(str, len, payload);
end;

{ TLibGit2 }

constructor TLibGit2.Create;
begin
  FProps := TLibGit2Properties.Create;
  InitLibgit2;
  FOnLog := nil;
end;

destructor TLibGit2.Destroy;
begin
  ShutdownLibgit2;
  FProps.Free;
  inherited;
end;

type
  PRemoteHeadArray = ^TRemoteHeadArray;
  TRemoteHeadArray = array[0..(High(Integer) div SizeOf(Pgit_remote_head))-1] of Pgit_remote_head;

function TLibGit2.ExistsRemoteBranch(const aRepoPath, aRemoteName, aBranchName: string): Boolean;
var
  Repo: Pgit_repository;
  Remote: Pgit_remote;
  Count, I: Size_t;
  RefName: AnsiString;
  Callbacks: git_remote_callbacks;
  RefsPtr: ^PPgit_remote_head;
begin
  Result := False;
  if git_repository_open(@Repo, PAnsiChar(AnsiString(aRepoPath))) <> 0 then
  begin
    SetLastErrorFromGit;
    Exit;
  end;

  if git_remote_lookup(@Remote, Repo, PAnsiChar(AnsiString(aRemoteName))) <> 0 then
  begin
    SetLastErrorFromGit;
    git_repository_free(Repo);
    Exit;
  end;

  git_remote_init_callbacks(@Callbacks, GIT_REMOTE_CALLBACKS_VERSION);
  Callbacks.certificate_check := @Static_CertificateCheckCallback;
  Callbacks.credentials := @Static_CredentialsCallback;
  Callbacks.payload := Self;

  if git_remote_connect(Remote, GIT_DIRECTION_FETCH, @Callbacks, nil, nil) = 0 then
  begin
    if git_remote_ls(@RefsPtr, @Count, Remote) = 0 then
    begin
      for I := 0 to Count - 1 do
      begin
        if RefsPtr = nil then
          Break;
        RefName := AnsiString(PRemoteHeadArray(RefsPtr)^[I]^.name_);
        if RefName = 'refs/heads/' + AnsiString(aBranchName) then
        begin
          Result := True;
          Break;
        end;
      end;
    end else
      SetLastErrorFromGit;
    git_remote_disconnect(Remote);
  end else
    SetLastErrorFromGit;

  git_remote_free(Remote);
  git_repository_free(Repo);
end;

procedure TLibGit2.DoLog(const aText: String; const aArgs: array of const);
begin
  if not Assigned(FOnLog) then
    Exit;
  FOnLog(Self, Format(aText, aArgs));
end;

procedure TLibGit2.SetLastErrorFromGit;
var
  gitError : Pgit_error;
begin
  gitError := git_error_last();
  FLastErrorText := Format('%s.  (klass=%d)', [gitError.message, gitError.klass]);
end;

function TLibGit2.Init(const aRepoPath: TFileName): Boolean;
var
  Repo : Pgit_repository;
begin
  Result := git_repository_init(@Repo, PAnsiChar(AnsiString(aRepoPath)), 0) = 0;
  if not Result then
    SetLastErrorFromGit
  else
    git_repository_free(Repo);
end;

function TLibGit2.IsGitRepo(const aPath: TFileName): Boolean;
var
  Repo: Pgit_repository;
begin
  Result := git_repository_open(@Repo, PAnsiChar(AnsiString(aPath))) = 0;
  if Result then
    git_repository_free(Repo);
end;

function TLibGit2.HttpsCredentialCallback(out cred: Pgit_credential;
  url, username_from_url: PAnsiChar;
  allowed_types: Cardinal;
  payload: Pointer): Integer; cdecl;
begin
  Result := git_credential_userpass_plaintext_new(
    @cred,
    PAnsiChar(AnsiString(FProps.Username)),
    PAnsiChar(AnsiString(FProps.Password))
  );
end;

function TLibGit2.AcceptAnyCertificateCallback(cert: Pgit_cert;
  valid: Integer;
  host: PAnsiChar;
  payload: Pointer): Integer; cdecl;
begin
  Result := 0
end;

function TLibGit2.TransferProgressCallback(stats: Pgit_indexer_progress;
  payload: Pointer): Integer; cdecl;
begin
  Result := 0; // 0 = continue.
  if not (lgoVerboseGitProgress in FProps.Options) then
    Exit;

  if stats^.total_deltas = 0 then
    DoLog('  git: %d/%d objects received (%d Bytes, %d objects indexed).',
      [stats^.received_objects, stats^.total_objects, stats^.received_bytes, stats^.indexed_objects,
      stats^.local_objects]
    )
  else
    DoLog(
      '  git: %d/%d deltas processed (%d objects indexed).',
      [stats^.indexed_deltas, stats^.total_deltas, stats^.indexed_objects]
    );
end;

function TLibGit2.SidebandProgressCallback(str: PAnsiChar; len: Size_t; payload: Pointer): Integer; cdecl;
begin
  Result := 0; // 0 = continue.
  if not (lgoVerboseGitProgress in FProps.Options) then
    Exit;
  DoLog('  git: %s', [Copy(str, 1, len)]);
end;

function TLibGit2.Clone(const aUrl: String;
  const aLocalPath: TFileName;
  const aBranchName: String;
  const aDepth: Integer): Boolean;
var
  Repo: Pgit_repository;
  Options: git_clone_options;
begin
  Result := (git_clone_options_init(@Options, GIT_CLONE_OPTIONS_VERSION) = 0);

  if not Result then
  begin
    FLastErrorText := 'Error while initializing git clone options.';
    Exit;
  end;

  options.fetch_opts.callbacks.payload := Self;
  options.fetch_opts.callbacks.credentials := @Static_CredentialsCallback;
  options.fetch_opts.callbacks.sideband_progress := @Static_SidebandProgressCallback;
  options.fetch_opts.callbacks.transfer_progress := @Static_TransferProgressCallback;

  if lgoIgnoreCertificateErrors in FProps.Options then
    options.fetch_opts.callbacks.certificate_check := @Static_CertificateCheckCallback;

  if aDepth <> UNLIMITED_CLONE_DEPTH then
    options.fetch_opts.depth := aDepth;

  if aBranchName <> '' then
    options.checkout_branch := PAnsiChar(AnsiString(aBranchName));

  Result := git_clone(@repo, PAnsiChar(AnsiString(aUrl)), PAnsiChar(AnsiString(aLocalPath)), @options) = 0;
  if not Result then
  begin
    SetLastErrorFromGit;
    Exit;
  end else
    git_repository_free(Repo);
end;

end.
