program libgit2_demo;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  FastMM4,
  libgit2,
  System.SysUtils,
  libgit2_wrapper in '..\src\libgit2_wrapper.pas';

function LibGit2Test: Boolean;
var
  statusRepository : integer;
  repoPP : Pgit_repository;
  gitError : Pgit_error;
const
  repoPath : PAnsiChar = 'C:/src/4prax.git/backend/Tests';
begin
  Result := False;
  try
    InitLibgit2;  //with this setup in "LibGit2.pas" you can only init a single repository at a time... (Singleton Pattern)
    statusRepository := git_repository_init(@repoPP, repoPath, 0); //function git_repository_init(out_: PPgit_repository; path: PAnsiChar; is_bare: Cardinal): Integer; cdecl; external libgit2_dll;
    if statusRepository <> 0 then begin
      gitError := git_error_last(); //message: invalid argument: "out"
    end;
    //How to look into the repo?
      //ToDo
    ShutdownLibgit2;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  //keep console open
  readln;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    Libgit2Test;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
