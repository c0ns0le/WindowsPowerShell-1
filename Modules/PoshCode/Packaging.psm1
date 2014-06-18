# We're not using Requires because it just gets in the way on PSv2
#!Requires -Version 2 -Modules "Installation" # Just the Copy-Stream function
#!Requires -Version 2 -Modules "ModuleInfo" 
###############################################################################
## Copyright (c) 2013 by Joel Bennett, all rights reserved.
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
###############################################################################
## Packaging.psm1 defines the core Compress-Module command for creating Module packages:
## Install-Module and Expand-ZipFile and Expand-Package
## It depends on the Installation module for the Copy-Stream function
## It depends on the ModuleInfo module for the Update-ModuleInfo command


# FULL # BEGIN FULL: Don't include this in the installer script
$PoshCodeModuleRoot = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { $_.Value }
if(!$PoshCodeModuleRoot) {
  $PoshCodeModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

. $PoshCodeModuleRoot\Constants.ps1
# FULL # END FULL

function Compress-Module {
   #.Synopsis
   #   Create a new psmx package for a module
   #.Description
   #   Create a module package based on a .psd1 metadata module. 
   #.Notes
   #   If the FileList is set in the psd1, only those files are packed
   #   If present, a ${Module}.png image will be used as a thumbnail
   #   HelpInfoUri will be parsed for urls
   [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium")]
   param(
      # The name of the module to package
      [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
      [ValidateNotNullOrEmpty()]
      $Module,
      
      # The folder where packages should be placed (defaults to the current FileSystem working directory)
      [Parameter()]
      [string]$OutputPath = $(Get-Location -PSProvider FileSystem),
      
      # If set, overwrite existing packages without prompting
      [switch]$Force
   )
   begin {
      # If Module isn't set in Begin, we'll get it from the pipeline (or fail)
      $Piped = !$PsBoundParameters.ContainsKey("Module")
      
      $RejectAllOverwrite = $false;
      $ConfirmAllOverwrite = $false;
   }
   process {
      Write-Verbose "Compress-Module $Module to $OutputPath"
      if($Module -isnot [System.Management.Automation.PSModuleInfo]) {
         # Hypothetically, could it be faster to select -first, now that pipelines are interruptable?
         [String]$ModuleName = $Module
         ## Workaround PowerShell Bug https://connect.microsoft.com/PowerShell/feedback/details/802030
         Push-Location $Script:EmptyPath
         if($PSVersionTable.PSVersion -lt "3.0") {
            $Module = Import-Module $ModuleName -PassThru  | Update-ModuleInfo
         } else {
            if(Get-Module $ModuleName) {
               $Module = Get-Module $ModuleName
            } else {   
               $Module = Get-Module $ModuleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
            }
            Write-Verbose "$($Module  | % FileList | Out-String)"
            $Module = $Module | Update-ModuleInfo
         }

         Pop-Location
      }
      Write-Verbose "$($Module  | % { $_.FileList } | Out-String)"
      Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Validating Inputs" -Id 0    

      # If the Module.Path isn't a PSD1, then there is none, so we can't package this module
      if( $Module -isnot [System.Management.Automation.PSModuleInfo] -and [IO.Path]::GetExtension($Module.Path) -ne ".psd1" ) {
         $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord (New-Object System.IO.InvalidDataException "Module metadata file (.psd1) not found for $($PsBoundParameters["Module"])"), "Unexpected Exception", "InvalidResult", $_) )
      }

      # Our packages are ModuleName.psmx (for now, $ModulePackageExtension = .psmx)
      $PackageName = $Module.Name
      if($Module.Version -gt "0.0") {
         $PackageVersion = $Module.Version
      } else {
         Write-Warning "Module Version not specified properly: using 1.0"
         $PackageVersion = "1.0"
      }
   
      # .psmx
      if($OutputPath.EndsWith($ModulePackageExtension)) {
         Write-Verbose "Specified OutputPath include the Module name (ends with $ModulePackageExtension)"
         $OutputPath = Split-Path $OutputPath
      }
      if(Test-Path $OutputPath -ErrorAction Stop) {
         $PackagePath = Join-Path $OutputPath "${PackageName}-${PackageVersion}${ModulePackageExtension}"
         $PackageInfoPath = Join-Path $OutputPath "${PackageName}${ModuleInfoExtension}"
      }

      Write-Verbose "Creating Module in $OutputPath"
      Write-Verbose "Package File Path: $PackagePath"
      Write-Verbose "Package Manifest : $PackageInfoPath"

      if($PSCmdlet.ShouldProcess("Package the module '$($Module.ModuleBase)' to '$PackagePath'", "Package '$($Module.ModuleBase)' to '$PackagePath'?", "Packaging $($Module.Name)" )) {
         if($Force -Or !(Test-Path $PackagePath -ErrorAction SilentlyContinue) -Or $PSCmdlet.ShouldContinue("The package '$PackagePath' already exists, do you want to replace it?", "Packaging $($Module.ModuleBase)", [ref]$ConfirmAllOverwrite, [ref]$RejectAllOverwrite)) {

            # If there's no ModuleInfo file, then we need to *create* one so that we can package this module
            $ModuleInfoPath = Join-Path (Split-Path $Module.Path) $ModuleInfoFile

            if(!(Test-Path $ModuleInfoPath))
            {
               $PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord (New-Object System.IO.FileNotFoundException "Can't find the Package Manifest File: ${ModuleInfoPath}"), "Manifest Not Found", "ObjectNotFound", $_) )
            } else {
               Copy-Item $ModuleInfoPath $PackageInfoPath -ErrorVariable CantWrite
               if($CantWrite) {
                  $PSCmdlet.ThrowTerminatingError( $CantWrite[0] )
               }
            }
            Get-Item $PackageInfoPath

            Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Preparing File List" -Id 0    

            $MetadataName = "${PackageName}.psd1"
            $MetadataPath = Join-Path $Module.ModuleBase $MetadataName
            $ModuleRootRex = [regex]::Escape((Split-Path $Module.ModuleBase))

            [String[]]$FileList = Get-ChildItem $Module.ModuleBase -Recurse | 
               Where-Object {-not $_.PSIsContainer} | 
               Select-Object -Expand FullName

            # Warn about discrepacies between the Module.FileList and actual files
            # $Module.FileList | Resolve-Path 
            if($Module.FileList.Count -gt 0) {
               foreach($mf in $Module.FileList){
                  if($FileList -notcontains $mf) {
                     Write-Warning "Missing File (specified in Module FileList): $mf"
                  }
               }
               foreach($f in $FileList){
                  if($Module.FileList -notcontains $mf) {
                     Write-Warning "File in module folder not specified in Module FileList: $mf"
                  }
               }
               # Now that we've warned you about missing files, let's not try to pack them:
               $FileList = Get-ChildItem $Module.FileList | 
                  Where-Object {-not $_.PSIsContainer} | 
                  Select-Object -Expand FullName
               if(($FileList -notcontains $ModuleInfoPath) -and (Test-Path $ModuleInfoPath)) {
                  $FileList += $ModuleInfoPath
               }

            } else {
               Write-Warning "FileList not set in module metadata (.psd1) file. Packing all files from path: $($Module.ModuleBase)"
            }

            # Create the package
            $Package = [System.IO.Packaging.Package]::Open( $PackagePath, [IO.FileMode]::Create )
            Set-PackageProperties $Package.PackageProperties $Module

            try {
               # Now pack up all the files we've found:
               $Target = $FileList.Count
               $Count = 0
               foreach($file in $FileList) {
                  $Count += 1
                  Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Packing File $Count of $Target" -Id 0 -PercentComplete ((($count-1)/$target)*100)

                  $FileRelativePath = $File -replace $ModuleRootRex, ""
                  $FileUri = [System.IO.Packaging.PackUriHelper]::CreatePartUri( $FileRelativePath )

                  Write-Verbose "Packing $file to ${PackageName}$ModulePackageExtension::$FileUri"

                  # TODO: add MimeTypes for specific powershell types (would let us extract just one type of file)
                  switch -regex ([IO.Path]::GetExtension($File)) {
                     "\.(?:psd1|psm1|ps1|cs)" {
                        # Add a text file part to the Package ( [System.Net.Mime.MediaTypeNames+Text]::Xml )
                        $part = $Package.CreatePart( $FileUri, "text/plain", "Maximum" ); 
                        Write-Verbose "    as text/plain"
                        break;
                     }
                     "\.ps1xml|\.xml" {
                        $part = $Package.CreatePart( $FileUri, "text/xml", "Maximum" ); 
                        Write-Verbose "    as text/xml"
                        break
                     } 
                     "\.xaml" {
                        $part = $Package.CreatePart( $FileUri, "text/xaml", "Maximum" ); 
                        Write-Verbose "    as text/xaml"
                        break
                     } 
                     default {
                        $part = $Package.CreatePart( $FileUri, "application/octet-stream", "Maximum" ); 
                        Write-Verbose "    as application/octet-stream"
                     }
                  }

                  # Copy the data to the Document Part 
                  try {
                    $reader = [IO.File]::Open($File, "Open", "Read", "Read")
                     $writer = $part.GetStream()
                     Copy-Stream $reader $writer -Length (Get-Item $File).Length -Activity "Packing $file"
                  } catch [Exception]{
                     $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
                  } finally {
                     if($writer) {
                        $writer.Close()
                     }
                     if($reader) {
                        $reader.Close()
                     }
                  }


                  # Add a Package Relationship to the Document Part
                  switch -regex ($File) {
                     ([regex]::Escape($MetadataName)) {
                        $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $ModuleMetadataType)
                        Write-Verbose "    Added Relationship: $ModuleMetadataType"
                        break
                     } 

                     ([regex]::Escape($ModuleInfoFile) + '$') {
                        $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $ManifestType)
                        Write-Verbose "    Added Relationship: $ManifestType"
                        break
                     }

                     # I'm not sure there's any benefit to pointing out the RootModule, but it can't hurt
                     # OMG - If I ever get a chance to clue-bat the person that OK'd this change to "RootModule":
                     ([regex]::Escape($(if($module.RootModule){$module.RootModule}else{$module.ModuleToProcess})) + '$') {
                        $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $ModuleRootType)
                        Write-Verbose "    Added Relationship: $ModuleRootType"
                        break
                     }

                     ([regex]::Escape($PackageName + "\.(png|gif|jpg)") + '$') {
                        $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $PackageThumbnailType)
                        Write-Verbose "    Added Relationship: $PackageThumbnailType"
                        break
                     }

                     default {
                        $relationship = $Package.CreateRelationship( $part.Uri, "Internal", $ModuleContentType)
                        Write-Verbose "    Added Relationship: $ModuleContentType"
                     }
                  }
               }

               if($Module.HelpInfoUri) {
                  $null = $Package.CreateRelationship( $Module.HelpInfoUri, "External", $ModuleHelpInfoType )
               }
               if($Module.PackageManifestUri) {
                  $null = $Package.CreateRelationship( $Module.PackageManifestUri, "External", $ModuleReleaseType )
               }
               if($Module.LicenseUri) {
                  $null = $Package.CreateRelationship( $Module.LicenseUri, "External", $ModuleLicenseType )
               }
               if($Module.DownloadUri) {
                  $null = $Package.CreateRelationship( $Module.DownloadUri, "External", $ModuleReleaseType )
               }

            } catch [Exception] {
               $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $_.Exception, "Unexpected Exception", "InvalidResult", $_) )
            } finally {
               if($Package) { 
                  Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Writing Package" -Id 0            
                  $Package.Close()
               }
            }

            Write-Progress -Activity "Packaging Module '$($Module.Name)'" -Status "Complete" -Id 0 -Complete

            # Write out the FileInfo for the package
            Get-Item $PackagePath

            # TODO: once the URLs are mandatory, print the full URL here
            Write-Host "You should now copy the $ModuleInfoExtension and $ModulePackageExtension files to the locations specified by the PackageManifestUri and DownloadUri"  
         }
      }
   }
}

# internal function for setting the PackageProperties of a psmx file
function Set-PackageProperties {
  #.Synopsis
  #   Sets PackageProperties from a PSModuleInfo
  PARAM(
    # The PackageProperties object to set
    [Parameter(Mandatory=$true, Position=0)]
    [System.IO.Packaging.PackageProperties]$PackageProperties,

    # The ModuleInfo to get values from
    [Parameter(Mandatory=$true, Position=1)]
    $ModuleInfo
  )
  process {
    $PackageProperties.Title = $ModuleInfo.Name
    $PackageProperties.Identifier = $ModuleInfo.GUID
    $PackageProperties.Version = $ModuleInfo.Version
    $PackageProperties.Creator = $ModuleInfo.Author
    $PackageProperties.Description = $ModuleInfo.Description
    $PackageProperties.Subject = $ModuleInfo.HelpInfoUri
    $PackageProperties.ContentStatus = "PowerShell " + $ModuleInfo.PowerShellVersion
    $PackageProperties.Created = Get-Date

  }
}


# SIG # Begin signature block
# MIIarwYJKoZIhvcNAQcCoIIaoDCCGpwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUq1/z+Sr1vKTYFwwB8S2jNGSp
# CO6gghXlMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggahMIIFiaADAgECAhADS1DyPKUAAEvdY0qN2NEFMA0GCSqGSIb3DQEBBQUAMG8x
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xLjAsBgNVBAMTJURpZ2lDZXJ0IEFzc3VyZWQgSUQgQ29k
# ZSBTaWduaW5nIENBLTEwHhcNMTMwMzE5MDAwMDAwWhcNMTQwNDAxMTIwMDAwWjBt
# MQswCQYDVQQGEwJVUzERMA8GA1UECBMITmV3IFlvcmsxFzAVBgNVBAcTDldlc3Qg
# SGVucmlldHRhMRgwFgYDVQQKEw9Kb2VsIEguIEJlbm5ldHQxGDAWBgNVBAMTD0pv
# ZWwgSC4gQmVubmV0dDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMPj
# sSDplpNPrcGhb5o977Z7VdTm/BdBokBbRRD5hGF+E7bnIOEK2FTB9Wypgp+9udd7
# 6nMgvZpj4gtO6Yj+noUcK9SPDMWgVOvvOe5JKKJArRvR5pDuHKFa+W2zijEWUjo5
# DcqU2PGDralKrBZVfOonity/ZHMUpieezhqy98wcK1PqDs0Cm4IeRDcbNwF5vU1T
# OAwzFoETFzPGX8n37INVIsV5cFJ1uGFncvRbAHVbwaoR1et0o01Jsb5vYUmAhb+n
# qL/IA/wOhU8+LGLhlI2QL5USxnLwxt64Q9ZgO5vu2C2TxWEwnuLz24SAhHl+OYom
# tQ8qQDJQcfh5cGOHlCsCAwEAAaOCAzkwggM1MB8GA1UdIwQYMBaAFHtozimqwBe+
# SXrh5T/Wp/dFjzUyMB0GA1UdDgQWBBRfhbxO+IGnJ/yiJPFIKOAXo+DUWTAOBgNV
# HQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwcwYDVR0fBGwwajAzoDGg
# L4YtaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL2Fzc3VyZWQtY3MtMjAxMWEuY3Js
# MDOgMaAvhi1odHRwOi8vY3JsNC5kaWdpY2VydC5jb20vYXNzdXJlZC1jcy0yMDEx
# YS5jcmwwggHEBgNVHSAEggG7MIIBtzCCAbMGCWCGSAGG/WwDATCCAaQwOgYIKwYB
# BQUHAgEWLmh0dHA6Ly93d3cuZGlnaWNlcnQuY29tL3NzbC1jcHMtcmVwb3NpdG9y
# eS5odG0wggFkBggrBgEFBQcCAjCCAVYeggFSAEEAbgB5ACAAdQBzAGUAIABvAGYA
# IAB0AGgAaQBzACAAQwBlAHIAdABpAGYAaQBjAGEAdABlACAAYwBvAG4AcwB0AGkA
# dAB1AHQAZQBzACAAYQBjAGMAZQBwAHQAYQBuAGMAZQAgAG8AZgAgAHQAaABlACAA
# RABpAGcAaQBDAGUAcgB0ACAAQwBQAC8AQwBQAFMAIABhAG4AZAAgAHQAaABlACAA
# UgBlAGwAeQBpAG4AZwAgAFAAYQByAHQAeQAgAEEAZwByAGUAZQBtAGUAbgB0ACAA
# dwBoAGkAYwBoACAAbABpAG0AaQB0ACAAbABpAGEAYgBpAGwAaQB0AHkAIABhAG4A
# ZAAgAGEAcgBlACAAaQBuAGMAbwByAHAAbwByAGEAdABlAGQAIABoAGUAcgBlAGkA
# bgAgAGIAeQAgAHIAZQBmAGUAcgBlAG4AYwBlAC4wgYIGCCsGAQUFBwEBBHYwdDAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEwGCCsGAQUFBzAC
# hkBodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURD
# b2RlU2lnbmluZ0NBLTEuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQEFBQAD
# ggEBABv8O1PicJ3pbsLtls/jzFKZIG16h2j0eXdsJrGZzx6pBVnXnqvL4ZrF6dgv
# puQWr+lg6wL+Nxi9kJMeNkMBpmaXQtZWuj6lVx23o4k3MQL5/Kn3bcJGpdXNSEHS
# xRkGFyBopLhH2We/0ic30+oja5hCh6Xko9iJBOZodIqe9nITxBjPrKXGUcV4idWj
# +ZJtkOXHZ4ucQ99f7aaM3so30IdbIq/1+jVSkFuCp32fisUOIHiHbl3nR8j20YOw
# ulNn8czlDjdw1Zp/U1kNF2mtZ9xMYI8yOIc2xvrOQQKLYecricrgSMomX54pG6uS
# x5/fRyurC3unlwTqbYqAMQMlhP8wggajMIIFi6ADAgECAhAPqEkGFdcAoL4hdv3F
# 7G29MA0GCSqGSIb3DQEBBQUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdp
# Q2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0Rp
# Z2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xMTAyMTExMjAwMDBaFw0yNjAy
# MTAxMjAwMDBaMG8xCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xLjAsBgNVBAMTJURpZ2lDZXJ0IEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBLTEwggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQCcfPmgjwrKiUtTmjzsGSJ/DMv3SETQPyJumk/6zt/G0ySR/6hS
# k+dy+PFGhpTFqxf0eH/Ler6QJhx8Uy/lg+e7agUozKAXEUsYIPO3vfLcy7iGQEUf
# T/k5mNM7629ppFwBLrFm6aa43Abero1i/kQngqkDw/7mJguTSXHlOG1O/oBcZ3e1
# 1W9mZJRru4hJaNjR9H4hwebFHsnglrgJlflLnq7MMb1qWkKnxAVHfWAr2aFdvftW
# k+8b/HL53z4y/d0qLDJG2l5jvNC4y0wQNfxQX6xDRHz+hERQtIwqPXQM9HqLckvg
# VrUTtmPpP05JI+cGFvAlqwH4KEHmx9RkO12rAgMBAAGjggNDMIIDPzAOBgNVHQ8B
# Af8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMwggHDBgNVHSAEggG6MIIBtjCC
# AbIGCGCGSAGG/WwDMIIBpDA6BggrBgEFBQcCARYuaHR0cDovL3d3dy5kaWdpY2Vy
# dC5jb20vc3NsLWNwcy1yZXBvc2l0b3J5Lmh0bTCCAWQGCCsGAQUFBwICMIIBVh6C
# AVIAQQBuAHkAIAB1AHMAZQAgAG8AZgAgAHQAaABpAHMAIABDAGUAcgB0AGkAZgBp
# AGMAYQB0AGUAIABjAG8AbgBzAHQAaQB0AHUAdABlAHMAIABhAGMAYwBlAHAAdABh
# AG4AYwBlACAAbwBmACAAdABoAGUAIABEAGkAZwBpAEMAZQByAHQAIABDAFAALwBD
# AFAAUwAgAGEAbgBkACAAdABoAGUAIABSAGUAbAB5AGkAbgBnACAAUABhAHIAdAB5
# ACAAQQBnAHIAZQBlAG0AZQBuAHQAIAB3AGgAaQBjAGgAIABsAGkAbQBpAHQAIABs
# AGkAYQBiAGkAbABpAHQAeQAgAGEAbgBkACAAYQByAGUAIABpAG4AYwBvAHIAcABv
# AHIAYQB0AGUAZAAgAGgAZQByAGUAaQBuACAAYgB5ACAAcgBlAGYAZQByAGUAbgBj
# AGUALjASBgNVHRMBAf8ECDAGAQH/AgEAMHkGCCsGAQUFBwEBBG0wazAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0Eu
# Y3J0MIGBBgNVHR8EejB4MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsNC5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMB0GA1UdDgQW
# BBR7aM4pqsAXvkl64eU/1qf3RY81MjAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYun
# pyGd823IDzANBgkqhkiG9w0BAQUFAAOCAQEAe3IdZP+IyDrBt+nnqcSHu9uUkteQ
# WTP6K4feqFuAJT8Tj5uDG3xDxOaM3zk+wxXssNo7ISV7JMFyXbhHkYETRvqcP2pR
# ON60Jcvwq9/FKAFUeRBGJNE4DyahYZBNur0o5j/xxKqb9to1U0/J8j3TbNwj7aqg
# TWcJ8zqAPTz7NkyQ53ak3fI6v1Y1L6JMZejg1NrRx8iRai0jTzc7GZQY1NWcEDzV
# sRwZ/4/Ia5ue+K6cmZZ40c2cURVbQiZyWo0KSiOSQOiG3iLCkzrUm2im3yl/Brk8
# Dr2fxIacgkdCcTKGCZlyCXlLnXFp9UH/fzl3ZPGEjb6LHrJ9aKOlkLEM/zGCBDQw
# ggQwAgEBMIGDMG8xCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xLjAsBgNVBAMTJURpZ2lDZXJ0IEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBLTECEANLUPI8pQAAS91jSo3Y0QUwCQYF
# Kw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkD
# MQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJ
# KoZIhvcNAQkEMRYEFM7Ff1BbZHb0otbisyUkzYzZj1prMA0GCSqGSIb3DQEBAQUA
# BIIBAD6Is61bOAqCpJlAVMd8DhrUYufZ8z8hlm5Fcz6nRzEN5jSPMgE1frFZpYTu
# us7pgmVZqi33d2AFXKfY95VdUzIIluQlJ7UpIfaL6VmfktMu5grkUqVT4gkVrusk
# mwwYLLDmglTow/0jwb2G9zD4LZwL620Ap0TDo8hxN2SIPOlVSCE9YuVNb9weOQTu
# AbAL3uGbJS12GYt9XjoUClJMhXKS60oxLFAl8mz2NMobt1hghf1gf2hj2NDaOoHZ
# sul8xHGbSODOZ2hmY0KEFsSBckDzhHDi3KVVJaU92Iv+LftDIXv/1i1aDIpl+mrK
# 8UijISdUxWKh5GTecM/Rnh53nBuhggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQC
# AQEwcjBeMQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRp
# b24xMDAuBgNVBAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0Eg
# LSBHMgIQDs/0OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkD
# MQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTMxMTA0MDcxOTM4WjAjBgkq
# hkiG9w0BCQQxFgQUveuma7MZTdCBYHjvZL+1RpdE8MIwDQYJKoZIhvcNAQEBBQAE
# ggEAYu44mlc6djmnUxQjH3R3AeQoNayNgPV7oJmQPXjEnDXvVKuxh0uR9ThgyLRJ
# 3zwRVYDJFQF4vYn+ilzI4X5jrT5FL1/De6S0zPqHTIzSPriSNnj0yB/z/7MpN/QA
# qRJwSyXDRaPzY6HgQbZ8/euLlvPYspRi8mMTxnaqwCfjZxk0JkKzA0hgO6gME6Ut
# CtK+/x7IKWbWqgEpEjRgGghzy0R1+JD+AOdVW02A5MIY9TmEwPBT6o3pG8sdDHWK
# L68zVPziO/05OrmLRuHivE9exScz0LZPQa+LhS3l3kv9/sMQZGjI3BrqchPc1wzd
# qeysRp1wDQwr7dJn9zZbT+NLXQ==
# SIG # End signature block
