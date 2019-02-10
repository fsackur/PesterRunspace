@{
    Description       = 'Boilerplate inclusion for running pester tests in fresh runspaces.'
    ModuleVersion     = '0.0.0.0'
    GUID              = '4b029c59-8c01-498d-add8-762bffc1afc5'
    ModuleToProcess   = 'PesterRunspace.psm1'

    Author            = 'Freddie Sackur'
    CompanyName       = 'dustyfox.uk'
    Copyright         = '(c) 2019 Freddie Sackur. All rights reserved.'

    RequiredModules   = @()
    FunctionsToExport = @(
        '*'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()


    PrivateData       = @{
        PSData = @{
            LicenseUri = 'https://raw.githubusercontent.com/fsackur/PesterRunspace/master/LICENSE'
            ProjectUri = 'https://fsackur.github.io/PesterRunspace/'
            Tags       = @(
            )
        }
    }
}
