unit libgit2_wrapper;

interface

uses
  libgit2;

type
  {$M+}
  TLibGit2 = class
  private
  public
    constructor Create;
    destructor Destroy; override;
  published
  end;

implementation

{ TLibGit2 }

constructor TLibGit2.Create;
begin
  InitLibgit2;
end;

destructor TLibGit2.Destroy;
begin
  ShutdownLibgit2;
  inherited;
end;

end.
