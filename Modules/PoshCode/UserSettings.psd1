# You can edit this file using the ConfigData commands: Get-ConfigData and Set-ConfigData
# For a list of valid {SpecialFolder} tokens, run Get-SpecialFolder
# Note that the default InstallPaths here are the ones recommended by Microsoft:
# http://msdn.microsoft.com/en-us/library/windows/desktop/dd878350
#
# Repositories: must be an array of hashtables with Type and Root
#   Optionally, Repositories may have a name (useful for filtering Find-Module)
#   and may include settings/parameters for the Repository's FindModule command

@{
  InstallPaths = @{
    CommonPath = 'C:\Program Files\WindowsPowerShell\Modules'
    UserPath = 'C:\users\pbritton\skydrive\documents\windowspowershell\Modules'
  }
  Repositories = @(@{
    Root = 'PoshCodeRegistry'
    Name = 'Registry'
    Type = 'FileSystem'
    SearchByDefault = $True
  },@{
    Root = '\\PoshCode.org\Modules'
    Name = 'PoshCode.org'
    Type = 'FileSystem'
  },@{
    Root = 'https://api.github.com/search/code'
    Type = 'GitHub'
  })
}
