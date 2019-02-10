Get-ChildItem $PSScriptRoot\Private -Filter '*.ps1' | Foreach-Object {. $_.FullName}
Get-ChildItem $PSScriptRoot\Public  -Filter '*.ps1' | Foreach-Object {. $_.FullName}
