program libgit2_demo;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  FastMM4,
  libgit2,
  System.SysUtils,
  System.IOUtils,
  libgit2_wrapper in '..\src\libgit2_wrapper.pas';

type
  TLibTest = class
  public
    procedure Run(const aRepo, aUser, aPassword, aFolder: String);
    procedure DoLog(Sender: TObject; const aText: string);
  end;

{ TLibTest }

procedure TLibTest.DoLog(Sender: TObject; const aText: string);
begin
  Writeln(aText);
end;

procedure TLibTest.Run(const aRepo, aUser, aPassword, aFolder: String);
var
  Git: TLibGit2;
begin
  Git := TLibGit2.Create;
  try
    if not Git.Init(aFolder) then
    begin
      Writeln('Git.Init() error: ', Git.LastErrorText);
      Exit;
    end;

    if Git.IsGitRepo(aFolder) then
      Writeln(aFolder ,' is a valid git repository')
    else
      Writeln(aFolder ,' is NOT a valid git repository');

    if TDirectory.Exists(aFolder) then
    begin
      Writeln('WARNING ! ', sLineBreak, aFolder, ' is going to be deleted.', sLineBreak,
        'Press <CTRL>+<C> to terminate, or <ENTER> to continue.');
      Readln;
      TDirectory.Delete(aFolder, True);
    end;

    Git.OnLog := DoLog;
    Git.Props.Username := aUser;
    Git.Props.Password := aPassword;
    Git.Props.Options := [lgoIgnoreCertificateErrors, lgoVerboseGitProgress];

    if not Git.Clone(aRepo, aFolder) then
    begin
      Writeln('Git.Clone() error: ', Git.LastErrorText);
      Exit();
    end;

    if Git.ExistsRemoteBranch(aFolder, 'origin', 'some-test-branch') then
      Writeln('Branch exists.')
    else
      Writeln('Branch does not exist.');
  finally
    Git.Free;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  if ParamCount <> 4 then
  begin
    Writeln('usage: libgit2_demo [repo-url] [username] [password/token] [root-test-folder]');
    Halt(1);
  end;

  with TLibTest.Create do
  try
    Run(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4));
  finally
    Free;
  end;
end.
