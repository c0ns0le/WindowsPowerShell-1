Import-Module `
	-Name ITG.RegExps `
	-MinimumVersion '1.1' `
	-ErrorAction Stop `
;

$PSLocRM = New-Object `
	-Type 'System.Resources.ResourceManager' `
	-ArgumentList `
		'HelpDisplayStrings' `
		, ( [System.Reflection.Assembly]::Load('System.Management.Automation') ) `
;

Function Import-ReadmeLocalizedData {
	<#
		.Synopsis
			��������� �������������� ��������� �������.
	#>

	param (
		# ��������, ��� ������� ��������� �������
		[Parameter(
			Mandatory=$false
		)]
		[System.Globalization.CultureInfo]
		$UICulture = ( Get-Culture )
	)

	$loc = Import-LocalizedData @PSBoundParameters;
	$PSloc = $PSLocRM.GetResourceSet( $UICulture, $true, $true );
	$PSloc `
	| % {
		if ( -not $loc.ContainsKey( $_.Name ) ) {
			$loc.Add( $_.Name, $_.Value.Trim() );
		};
	};
	return $loc;
}

$loc = Import-ReadmeLocalizedData;

$Translator = @{
	RegExp = $null;
	RuleType = @();
	RegExpResults = @{};
	RegExpIds = @();
	Refs = @{};
	Rules = @{};
	TokenRules = @{};
};

$reDotNetTokenChar = '[a-zA-Z0-9_]';
$reTokenFirstChar = '[a-zA-Z]';
$reTokenChar = '[-a-zA-Z0-9_]';
$reTokenLastChar = '[a-zA-Z0-9_]';
$reToken = "${reTokenFirstChar}(?:${reTokenChar}*$reTokenLastChar)?";
$reBeforeToken = "(?<!${reTokenChar}|^\t+.*?)";
$reAfterToken = "(?!${reTokenChar})";
$reBeforeURL = "(?<!${reTokenChar}|^\t+.*?|\(<?|<)";

$reRegExpId = New-Object System.Text.RegularExpressions.Regex -ArgumentList `
	'(?<=\(\?\<)(?<id>\w+)(?=\>)' `
	, ( [System.Text.RegularExpressions.RegexOptions]::IgnoreCase `
		-bor [System.Text.RegularExpressions.RegexOptions]::Multiline `
	) `
;

$reEOLCheck = New-Object System.Text.RegularExpressions.Regex -ArgumentList `
	'(?<crlf>\r?\n)' `
	, ( [System.Text.RegularExpressions.RegexOptions]::Singleline ) `
;

$reOnlineHelpLinkCheck = New-Object System.Text.RegularExpressions.Regex -ArgumentList `
	"^${reURL}`$" `
	, ( [System.Text.RegularExpressions.RegexOptions]::Singleline ) `
;

Filter ConvertTo-TranslateRule {
	<#
		.Synopsis
			����������� ������� ��������� ������� ������, ���������� �� ��������� � ��������� ��������, � ��������������� ������
			��� ����������� ������������� ����������� `$Translator` (����� Use-TranslateRule).
	#>
	param (
		[Parameter(
			Mandatory = $false
			, ValueFromPipeline = $true
		)]
		[Hashtable]
		$TranslateRule
	,
		[Parameter(
			Mandatory = $false
			, ValueFromPipelineByPropertyName = $true
		)]
		[String]
		$ruleCategory = 'token'
	,
		[Parameter(
			Mandatory = $false
			, ValueFromPipelineByPropertyName = $true
		)]
		[String]
		$ruleType
	,
		[Parameter(
			Mandatory = $true
			, ValueFromPipeline = $true
			, ValueFromPipelineByPropertyName = $true
		)]
		[String]
		[Alias('Name')]
		$template
	,
		[Parameter(
			Mandatory = $false
			, ValueFromPipeline = $true
		)]
		[System.Management.Automation.CommandInfo]
		$FunctionInfo
	,
		[Parameter(
			Mandatory = $false
			, ValueFromPipeline = $true
		)]
		[PSModuleInfo]
		$ModuleInfo
	,
		# ������������ ������� ��� ������������ ������ ��� �� ������� �������� ������
		[Parameter(
			Mandatory = $false
			, ValueFromPipelineByPropertyName = $true
		)]
		[switch]
		$AsExternalModule
	,
		[Parameter(
			Mandatory = $false
			, ValueFromPipelineByPropertyName = $true
		)]
		[String]
		$ModuleName
	,
		[Parameter(
			Mandatory = $false
			, ValueFromPipelineByPropertyName = $true
		)]
		[PSModuleInfo]
		$Module
	,
		[Parameter(
			Mandatory = $false
			, ValueFromPipelineByPropertyName = $true
		)]
		[String]
		$id
	,
		[Parameter(
			Mandatory = $false
			, ValueFromPipelineByPropertyName = $true
		)]
		[String]
		$expression
	,
		[Parameter(
			Mandatory = $false
			, ValueFromPipelineByPropertyName = $true
		)]
		[String]
		$url
	,
		[Parameter(
			Mandatory = $false
			, ValueFromPipelineByPropertyName = $true
		)]
		[String]
		$title
	)
	
	if ( $TranslateRule ) {
		$null = $PSBoundParameters.Remove( 'TranslateRule' );
		$null = $PSBoundParameters.Remove( 'template' );
		return `
			New-Object PSObject -Property $TranslateRule `
			| ConvertTo-TranslateRule @PSBoundParameters `
		;
	} elseif ( $ModuleInfo ) {
		$ModuleInfo `
		| % {
			$_ | Get-FunctionsReferenceTranslateRules -AsExternalModule:$AsExternalModule;
			$_ | Get-TagReferenceTranslateRules;
		} `
		| ConvertTo-TranslateRule `
			-AsExternalModule:$AsExternalModule `
		;
	} else {
		$PSBoundParameters.ruleCategory = $ruleCategory;
		if ( $FunctionInfo ) {
			$PSBoundParameters.ruleType = 'func';
		};
		if ( $ruleCategory -eq 'regExp' ) {
			if ( $template -match $reRegExpId ) {
				$PSBoundParameters.id = $Matches['id'];
			};
		};
		return New-Object PSObject -Property $PSBoundParameters;
	};
}

Function Add-EndReference {
	<#
		.Synopsis
			��������� � `$Translator` �������� ������, ���������� ������� ��������� � �������������� ������.
	#>
	param (
		[Parameter(
			Mandatory = $false
			, ValueFromPipeline = $true
		)]
		[Hashtable]
		$EndReference
	,
		[Parameter(
			Mandatory = $false
			, ValueFromPipelineByPropertyName = $true
		)]
		[String]
		$id
	,
		[Parameter(
			Mandatory = $false
			, ValueFromPipelineByPropertyName = $true
		)]
		[String]
		$url
	,
		[Parameter(
			Mandatory = $false
			, ValueFromPipelineByPropertyName = $true
		)]
		[String]
		$title
	,
		[Parameter(
			Mandatory = $false
			, ValueFromPipelineByPropertyName = $true
		)]
		[String]
		$refType
	)
	
	process {
		if ( $EndReference ) {
			New-Object PSObject -Property $EndReference `
			| Add-EndReference `
			;
		} else {
			if ( -not $Translator.Refs.$id ) {
				$Translator.Refs.Add(
					$id
					, ( New-Object PSObject `
						-Property @{
							id = $id;
							refType = $refType;
							url = $url;
							title = $title;
						}
					)
				)
			};
		};
	}
}

Function Get-EndReference {
	<#
		.Synopsis
			���������� ������ ����������� � `$Translator` �������� ������ ��� ��������� � readme.
	#>
	$Translator.Refs.Values `
	| Group-Object -Property refType `
	| Sort-Object -Property Name `
	| % {
@"

"@
		$_.Group `
		| Sort-Object -Property id `
		| % {
			"[$( $_.id )]: $( $_.url )" `
			, ( & { if ( $_.title ) { "`"$( $_.title )`"" }; } ) `
			-join ' '
		};
	};
};

Function Use-TranslateRule {
	<#
		.Synopsis
			�������������� ������ `$Translator` ������� ������ ����������, ����������� �� ���������.
	#>
	param (
		# �������� ������� (������ ������� - � ��� �����)
		[Parameter(
			Mandatory=$true
			, ValueFromPipeline=$true
		)]
		[PSObject]
		$TranslateRule
	)

	begin {
		$Translator.RegExp = $null;
		$Translator.RuleType = @();
		$Translator.RegExpResults = @{};
		$Translator.RegExpIds = @();
		$Translator.Refs = @{};
		$Translator.Rules = @{};
		$Translator.TokenRules = @{};

		$Rules = @();
	}
	process {
		$Rules += $TranslateRule;
	}
	end {
		$Translator.Rules = 
			$Rules `
			| Group-Object `
				-Property ruleCategory `
				-AsHashTable `
				-AsString `
		;
		$TokenRules = `
			$Translator.Rules.token `
			| Group-Object `
				-Property ruleType `
				-AsHashTable `
				-AsString `
		;
		foreach ( $ruleType in $TokenRules.Keys ) {
			$Translator.TokenRules.Add(
				$ruleType
				, (
					$TokenRules.$ruleType `
					| Group-Object `
						-Property template `
					| ForEach-Object `
						-Begin {
							$res = @{};
						} `
						-Process {
							$res.Add( $_.Name, $_.Group[0] );
						} `
						-End {
							$res;
						} `
				)
			);
		};
		$Translator.RegExp = New-Object `
			-TypeName System.Text.RegularExpressions.Regex `
			-ArgumentList `
				(
					(
						@( $Translator.Rules.regexp | Select-Object -ExpandProperty template ) `
						+ (
							$reBeforeToken `
							, '(?<token>' `
							, (
								(
									$Translator.Rules.token `
									| Group-Object -Property ruleType `
									| % {
										"(?<$( $_.Name )>$( ( $_.Group | % { $_.template } ) -join '|' ))";
									} `
								) -join '|' `
							) `
							, ')' `
							, $reAfterToken `
							-join '' `
						) `
					) -join '|' `
				) `
				, (
					[System.Text.RegularExpressions.RegexOptions]::IgnoreCase `
					-bor [System.Text.RegularExpressions.RegexOptions]::Multiline `
					-bor [System.Text.RegularExpressions.RegexOptions]::ExplicitCapture `
				)
		;
		$Translator.RuleType = `
			$Translator.Rules.token `
			| Select-Object -ExpandProperty ruleType -Unique `
		;
		$Translator.RegExpIds = `
			$Translator.Rules.regexp `
			| Select-Object -ExpandProperty id -Unique `
		;
		$Translator.RegExpResults = `
			$Translator.Rules.regexp `
			| ? { $_.id } `
			| Group-Object `
				-Property id `
			| ForEach-Object `
				-Begin {
					$res = @{};
				} `
				-Process {
					$res.Add( $_.Name, $_.Group[0] );
				} `
				-End {
					$res;
				} `
		;
	}
}

Filter Expand-Definitions {
	<#
		.Synopsis
			������ ������� �������� ����������� �� ��������������� readme � ��������� �� � ������������ �� 
			�������, �������������� ��� ���������� �����������.
	#>
	
	param (
		# ���������������� ����� readme
		[Parameter(
			Mandatory=$true
			, ValueFromPipeline=$true
		)]
		[String]
		[AllowEmptyString()]
		$InputObject
	)

	if ( -not [String]::IsNullOrEmpty( $InputObject ) ) {
		$Translator.RegExp.Replace(
			( $reEOLCheck.Replace( $InputObject, "`r`n" ) ) `
			, {
				param( [System.Text.RegularExpressions.Match] $Match)
				foreach ( $RuleType in $Translator.RegExpIds ) {
					if ( $Match.Groups[$RuleType].Success ) {
						if ( $Translator.RegExpResults.$RuleType.expression -eq $null ) {
							return ( & "MatchEvaluatorFor$RuleType" $Match );
						} else {
							return $Match.Result( $Translator.RegExpResults.$RuleType.expression );
						};
					}
				};
				foreach ( $RuleType in $Translator.RuleType ) {
					if ( $Match.Groups[$RuleType].Success ) {
						return ( & "MatchEvaluatorFor$RuleType" $Match );
					}
				};
			}
		);
	};
};

Function MatchEvaluatorForAbout( [System.Text.RegularExpressions.Match] $Match ) {
	$id = `
		$PowerShellAboutTopics.Keys `
		| ? { $_ -ieq ($Match.Groups['about'].Value) } `
	;
	if ( $id ) {
		Add-EndReferenceForAbout( $id );
		return "[${id}][]";
	} else {
		Write-Warning `
			-Message @"
$( $loc.WarningUnknownAboutTerm )

	$( $Match.Groups['about'].Value )
	
"@ `
		;
		return ( $Match.Groups['about'].Value );
	};
};

Function Add-EndReferenceForAbout( [String] $Id ) {
	$aboutTopic = Get-Help `
		-Category HelpFile `
		-Name $id `
		-Full `
		-ErrorAction SilentlyContinue `
	;
	$title = $aboutTopic.Synopsis;
	if ( $title -match '[^.]\s*$' ) {
		$title += '...';
	};
	switch -exact ( $PowerShellAboutTopics[ $id ].GetType().Name ) {
		'Uri' {
			$url = $PowerShellAboutTopics[ $id ];
		}
		'String' {
			$url = "http://go.microsoft.com/fwlink/?LinkID=$( $PowerShellAboutTopics[ $id ] )";
		}
		'Int32' {
			$url = "http://go.microsoft.com/fwlink/?LinkID=$( $PowerShellAboutTopics[ $id ] )";
		}
	};
	Add-EndReference `
		-id $id `
		-url $url `
		-title $title `
	;
};

Function MatchEvaluatorForAboutCP( [System.Text.RegularExpressions.Match] $Match ) {
	Add-EndReferenceForAbout( 'about_CommonParameters' );
	return '[about_CommonParameters][]';
};

$PowerShellAboutTopicsTranslateRules = @(
	"about_$reFirstChar(?:[-a-zA-Z0-9_.]*$reTokenLastChar)?" `
	| ConvertTo-TranslateRule -ruleType 'about' `
);

Function MatchEvaluatorForPSType( [System.Text.RegularExpressions.Match] $Match ) {
	$PSType = $Match.Groups['pstype'].Value;
	foreach ( $_ in `
		'System.Management.Automation' `
		, 'mscorlib' `
		, 'System' `
		, 'System.XML' `
		, 'Microsoft.ActiveDirectory.Management' `
	) {
		$PSTypeInfo = [System.Reflection.Assembly]::LoadWithPartialName( $_ ).GetType( $PSType );
		if ( $PSTypeInfo ) {
			Add-EndReference `
				-id ( $PSTypeInfo.FullName ) `
				-url "<http://msdn.microsoft.com/ru-ru/library/$( $PSTypeInfo.FullName.ToLower() ).aspx>" `
				-title "$( $PSTypeInfo.Name ) Class ($( $PSTypeInfo.Namespace ))" `
			;
			return "[$( $PSTypeInfo.FullName )][]";
		};
	};
	;
	return $PSType;
};

$PowerShellTypes = @(
	"System\.Management\.Automation(?:\.$reDotNetTokenChar+)*" `
	, "System(?:\.$reDotNetTokenChar+)+" `
	, "Microsoft\.PowerShell(?:\.$reDotNetTokenChar+)*" `
	, "Microsoft\.ActiveDirectory\.Management(?:\.$reDotNetTokenChar+)*" `
	-join '|' `
	| ConvertTo-TranslateRule -ruleType 'pstype' `
	;
);

# [test]: <http://novgaro.ru> "��������� �����"
$reMDRefTitle = "(?:'(?<title>.+?)'|`"(?<title>.+?)`"|\((?<title>.+?)\))";
$reMDRef = New-Object System.Text.RegularExpressions.Regex -ArgumentList `
	"(?<=^\s*)(?<mdRef>\[(?<id>.+?)\]:\s+(?:<$reURL>|$reURL)(?:\s+$reMDRefTitle)?)(?=\s*$)" `
	, ( [System.Text.RegularExpressions.RegexOptions]::IgnoreCase `
		-bor [System.Text.RegularExpressions.RegexOptions]::Multiline `
	) `
;
$reMDLink = New-Object System.Text.RegularExpressions.Regex -ArgumentList `
	"(?<mdLink>\[(?<id>.+?)\]\((?:<$reURL>|$reURL)\))" `
	, ( [System.Text.RegularExpressions.RegexOptions]::IgnoreCase `
		-bor [System.Text.RegularExpressions.RegexOptions]::Multiline `
	) `
;

Function Get-ReadmeUrl {
	<#
		.Synopsis
			������ ������� ���������� `ReadmeURL` ��� ���������� ������
	#>

	[CmdletBinding(
	)]

	param (
		# ��������� ������
		[Parameter(
			Mandatory = $false
			, ValueFromPipeline = $true
		)]
		[System.Management.Automation.PSModuleInfo]
		$ModuleInfo = $null
	)

	process {
		if ( -not $ModuleInfo ) { return [System.Uri] ''; };
		[System.Uri] $ModuleReadmeURL = $ModuleInfo.PrivateData.ReadmeURL;
		if ( -not $ModuleReadmeURL ) {
			Write-Warning `
				-Message @"
$( [String]::Format( $loc.WarningUnknownModuleReadmeURL, $ModuleInfo.Name ) )

PrivateData = @{
	ReadmeURL = 'https://github.com/$( $ModuleInfo.CompanyName )/$( $ModuleInfo.Name )';
}
	
"@ `
			;
			$ModuleReadmeURL = "https://github.com/IT-Service/$( $ModuleInfo.Name )";
		};
		return $ModuleReadmeURL;
	}
}

Function New-HelpUri {
	<#
		.Synopsis
			������ ������� ���������� `HelpUri` ��� ��������� �������
	#>

	[CmdletBinding(
	)]

	param (
		# ��������� �������
		[Parameter(
			Mandatory=$true
			, ValueFromPipeline=$true
		)]
		[System.Management.Automation.CommandInfo]
		$FunctionInfo
	)

	process {
		$ModuleReadmeURL = Get-ReadmeUrl ( $FunctionInfo.Module );
		$HelpUri = [System.Uri] "$( $ModuleReadmeURL.AbsoluteUri )#$( $FunctionInfo.Name.ToLower() )";
		return $HelpUri;
	}
}

Function Get-HelpUri {
	<#
		.Synopsis
			������ ������� ���������� `HelpUri` ���� ���������� ��� ��� ����������
	#>

	[CmdletBinding(
	)]

	param (
		# ��������� �������
		[Parameter(
			Mandatory=$true
			, ValueFromPipeline=$true
		)]
		[System.Management.Automation.CommandInfo]
		$FunctionInfo
	,
		# ������������ �� HelpUri ��� ��� ����������
		[switch]
		$Force
	,
		# ���������� ������ ������������ `ReadmeURL`�� �����������
		[switch]
		$Relative

	)

	process {
		[System.Uri] $HelpUri = $FunctionInfo.HelpUri;
		$Help = Get-Help -Name $FunctionInfo.Name -Full;
		## ! ������� ���������, ��� ������� ����������� � Get-Help �� ������ ������ � �����
		if ( -not $HelpUri ) {
			Write-Warning `
				-Message ( [String]::Format( $loc.WarningCommandHelpUriNotDefined, $id ) ) `
			;
			$HelpUri = `
				$Help.relatedLinks.navigationLink `
				| ? { $_.uri } `
				| Select-Object `
					-ExpandProperty uri `
					-First `
			;
			if ( -not $HelpUri ) {
				Write-Warning `
					-Message ( [String]::Format( $loc.WarningCommandHelpUriAndLinkNotDefined, $id ) ) `
				;
				if ( $Force ) { $HelpUri = New-HelpUri $FunctionInfo; };
			};
		};
		if ( $Relative ) {
			$ModuleReadmeURL = Get-ReadmeUrl ( $FunctionInfo.Module );
			if ( $ModuleReadmeURL.IsAbsoluteUri ) {
				$HelpUri = $ModuleReadmeURL.MakeRelativeUri( $HelpUri );
			};
		};
		return $HelpUri;
	}
}

Function MatchEvaluatorForFunc( [System.Text.RegularExpressions.Match] $Match ) {
	$id = $Match.Groups['func'].Value;
	$HelpUri = Get-HelpUri `
		-FunctionInfo ( Get-Command $id ) `
		-Force:( -not $Translator.TokenRules.func.$id.AsExternalModule ) `
		-Relative:( -not $Translator.TokenRules.func.$id.AsExternalModule ) `
	;
	$Help = Get-Help -Name $id -Full;
	## ! ������� ���������, ��� ������� ����������� � Get-Help �� ������ ������ � �����
	$title = ( $Help.Synopsis -split '\s*\r?\n' ) -join ' ';
	Add-EndReference `
		-id $id `
		-url "<$( $HelpUri.OriginalString.ToLower() )>" `
		-title $title `
	;
	return "[${id}][]";
};

Function Get-FunctionsReferenceTranslateRules {
	<#
		.Synopsis
			������ ������� ���������� ������� ������������ ������ �� ������� ������ ��
			��������� ������.
	#>
	
	param (
		# ��������� ������
		[Parameter(
			Mandatory=$true
			, ValueFromPipeline=$true
		)]
		[PSModuleInfo]
		$ModuleInfo
	,
		# ������������ ������� ��� ������������ ������ ��� �� ������� �������� ������
		[switch]
		$AsExternalModule
	)

	process {
		$ModuleInfo.ExportedCommands.Values `
		| ConvertTo-TranslateRule `
			-AsExternalModule:$AsExternalModule `
		;
	}
}

Function MatchEvaluatorForTag( [System.Text.RegularExpressions.Match] $Match ) {
	$id = $Match.Value;
	Add-EndReference `
		-id $id `
		-url $Translator.TokenRules.tag.$id.url `
		-title $Translator.TokenRules.tag.$id.title `
	;
	return "[${id}][]";
};

Function Get-TagReferenceTranslateRules {
	<#
		.Synopsis
			������ ������� ���������� ������� ������ �������� �� ������ [tag][] �� ���������
			������������ ���� `[test]: <http://novgaro.ru> "��������� �����"`
	#>

	[CmdletBinding(
		DefaultParametersetName='ModuleInfo'
	)]

	param (
		# ��������� ������
		[Parameter(
			Mandatory=$true
			, ValueFromPipeline=$true
			, ParameterSetName='ModuleInfo'
		)]
		[PSModuleInfo]
		$ModuleInfo
	,
		# ��������� �������� ��������
		[Parameter(
			Mandatory=$true
			, ValueFromPipeline=$true
			, ParameterSetName='ExternalScriptInfo'
		)]
		[System.Management.Automation.ExternalScriptInfo]
		$ExternalScriptInfo
	,
		# ��������� �������
		[Parameter(
			Mandatory=$true
			, ValueFromPipeline=$true
			, ParameterSetName='FunctionInfo'
		)]
		[System.Management.Automation.CommandInfo]
		$FunctionInfo
	,
		# ����� ��� ������ ������
		[Parameter(
			Mandatory=$false
			, ValueFromPipeline=$true
			, ParameterSetName='StringInfo'
		)]
		[String]
		$Text = ''
	)

	process {
		switch ( $PsCmdlet.ParameterSetName ) {
			'StringInfo' {
				$reMDRef.Matches( $Text ) `
				| % {
					@{
						template = ( $_.Groups['id'].Value );
						url = ( $_.Groups['url'].Value );
						title = ( $_.Groups['title'].Value );
					};
				} `
				| ConvertTo-TranslateRule `
					-ruleType 'tag' `
				;
			}
			'ModuleInfo' {
				$ModuleInfo.Description `
				| Get-TagReferenceTranslateRules;
				$ModuleInfo.ExportedCommands.Values `
				| Get-TagReferenceTranslateRules;
			}
			'ExternalScriptInfo' {
			}
			'FunctionInfo' {
				$Help = $FunctionInfo | Get-Help -Full;
				$Help.Description `
				| Select-Object -ExpandProperty Text `
				| Get-TagReferenceTranslateRules `
				;
				$Help.relatedLinks `
				| Select-Object -ExpandProperty navigationLink `
				| ? { $_.LinkText } `
				| Select-Object -ExpandProperty LinkText `
				| Get-TagReferenceTranslateRules `
			};
		};
	}
}

$GetReadmeStatus = @{
	level = 0;
};

Function Get-Readme {
	<#
		.Synopsis
			���������� readme � MarkDown ��������� �� ������ ������ � ������������ � ��� ��������. 
		.Description
			���������� readme � MarkDown ��������� �� ������ ������ � ������������ � ��� ��������. 
			������������, � ���������, ��� ���������� � ������������ github. ��� ���������� � ����
			����������� Set-Readme.
			�������� ����� ���� ������������� �������� Get-Readme ��� ������, �������, �������� ��������.
		.Functionality
			Readme
		.Role
			Everyone
		.Notes
		.Inputs
			System.Management.Automation.PSModuleInfo.
			��������� �������, ��� ������� ����� ������������ readme.md. 
			�������� ��������� ����� ���� ����� Get-Module.
		.Inputs
			System.Management.Automation.ExternalScriptInfo.
			��������� ���������, ��� ������� ����� ������������ readme.md. 
		.Inputs
			System.Management.Automation.CmdletInfo.
			��������� ���������, ��� ������� ����� ������������ readme.md. 
			�������� ��������� ����� ���� ����� Get-Command.
		.Inputs
			System.Management.Automation.CommandInfo.
			��������� �������, ��� ������� ����� ������������ readme.md. 
			�������� ��������� ����� ���� ����� Get-Command.
		.Outputs
			String.
			���������� readme.md.
		.Link
			https://github.com/IT-Service/ITG.Readme#Get-Readme
		.Link
			[MarkDown]: <http://daringfireball.net/projects/markdown/syntax> "MarkDown (md) Syntax"
		.Link
			about_comment_based_help
		.Link
			[��������� ������� ��� �����������](http://go.microsoft.com/fwlink/?LinkID=123415)
		.Example
			Get-Module 'ITG.Yandex.DnsServer' | Get-Readme | Out-File -Path 'readme.md' -Encoding 'UTF8' -Width 1024;
			��������� readme.md ����� ��� ������ `ITG.Yandex.DnsServer` 
			� ������� ��������.
		.Example
			Get-Module 'ITG.Yandex.DnsServer' | Get-Readme -ReferencedModules @( 'ITG.Yandex', 'ITG.Utils', 'ITG.WinAPI.UrlMon', 'ITG.WinAPI.User32' | Get-Module )
			��������� readme ��� ������ `ITG.Yandex.DnsServer`, ��� ���� ��� ����������
			������� ������� `ITG.Yandex`, `ITG.Utils`, `ITG.WinAPI.UrlMon`,
			`ITG.WinAPI.User32` ��� �� ����� �������� ������������ ��������
			�� readme.md ��������� �������.
	#>
	
	[CmdletBinding(
		DefaultParametersetName = 'ModuleInfo'
		, HelpUri = 'https://github.com/IT-Service/ITG.Readme#Get-Readme'
	)]

	param (
		# ��������� ������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='ModuleInfo'
		)]
		[PSModuleInfo]
		[Alias('Module')]
		$ModuleInfo
	,
		# ��������� �������� ��������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='ExternalScriptInfo'
		)]
		[System.Management.Automation.ExternalScriptInfo]
		$ExternalScriptInfo
	,
		# ��������� �������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='FunctionInfo'
		)]
		[System.Management.Automation.CommandInfo]
		$FunctionInfo
	,
		# ��������, ��� ������� ������������ ������.
		[Parameter(
			Mandatory=$false
		)]
		[System.Globalization.CultureInfo]
		$UICulture = ( Get-Culture )
	,
		# ������������ ������ ������� ��������
		[switch]
		[Alias('Short')]
		$ShortDescription
	,
		# �������� �������, ���������� ������� ������� ����� �������� �� ������
		[Parameter(
			Mandatory=$false
		)]
		[PSModuleInfo[]]
		[Alias('RequiredModules')]
		$ReferencedModules = @()
	,
		# ������� ��� ��������� readme ����������� �����������
		[Parameter(
			Mandatory=$false
		)]
		[Array]
		$TranslateRules = @()
	)

	process {
		if ( -not $GetReadmeStatus.level ) {
			$loc = Import-ReadmeLocalizedData `
				-UICulture $UICulture `
			;

			if ( $PsCmdlet.ParameterSetName -eq 'ModuleInfo' ) {
				$ReferencedModules += $ModuleInfo.RequiredModules;
			};
			$TranslateRules += & {
				$ReferencedModules `
				| Sort-Object `
					-Unique `
					-Property Name `
				| ConvertTo-TranslateRule `
					-AsExternalModule `
				;
				switch ( $PsCmdlet.ParameterSetName ) {
					'ModuleInfo' {
						$ModuleInfo `
						| ConvertTo-TranslateRule `
						;
					}
					'ExternalScriptInfo' {
					}
					'FunctionInfo' {
					};
				};
			};
			$TranslateRules = `
				@(
					$TranslateRules `
					| ConvertTo-TranslateRule `
				) `
				+ $BasicTranslateRules `
			;

			$TranslateRules `
			| Use-TranslateRule `
			;
			$res = $PSBoundParameters.Remove( 'TranslateRules' );
			$res = $PSBoundParameters.Remove( 'ReferencedModules' );
		};
		$GetReadmeStatus.level++;
		
		switch ( $PsCmdlet.ParameterSetName ) {
			'ModuleInfo' {
				$ReadMeContent = & { `
@"
$( $ModuleInfo.Name )
$( $ModuleInfo.Name -replace '.','=' )

$( $ModuleInfo.Description | Expand-Definitions )

$( $loc.ModuleVersion ): **$( $ModuleInfo.Version.ToString() )**
"@
					if ( $ModuleInfo.ExportedVariables.Count ) {
@"

$( $loc.Variables )
$( $loc.Variables -replace '.','-')
"@
						$ModuleInfo.ExportedVariables.Values `
						| % {
@"

### $($_.Name)

$( $_.Description | Expand-Definitions )
"@
						};
					};

					if ( $ModuleInfo.ExportedCommands.Count ) {
@"

$( $loc.CmdletsSupportedCaps )
$( $loc.CmdletsSupportedCaps -replace '.','-')
"@
						# ��������� �������� �������� �������
						$ModuleInfo.ExportedCommands.Values `
						| ? { $_.CommandType -ne [System.Management.Automation.CommandTypes]::Alias } `
						| Sort-Object -Property `
							@{ Expression={ ( $_.Name -split '-' )[1] } } `
							, @{ Expression={ ( $_.Name -split '-' )[0] } } `
						| Group-Object -Property `
							@{ Expression={ ( $_.Name -split '-' )[1] } } `
						| % {
							if ( $_.Name ) {
@"

### $( $_.Name )
"@
							};
							$_.Group `
							| % {
								$_ `
								| Get-Readme `
									-ShortDescription `
								;
							};
						};

						if ( -not $ShortDescription ) {
@"

$( $loc.DetailedDescription )
$( $loc.DetailedDescription -replace '.','-')
"@
							$ModuleInfo.ExportedCommands.Values `
							| ? { $_.CommandType -ne [System.Management.Automation.CommandTypes]::Alias } `
							| Sort-Object -Property `
								@{ Expression={ ( $_.Name -split '-' )[1] } } `
								, @{ Expression={ ( $_.Name -split '-' )[0] } } `
							| Get-Readme `
							;
						};
					};
				} `
				| Out-String `
				;
				$ReadMeContent;
			}
			'ExternalScriptInfo' {
			}
			'FunctionInfo' {
				$ReadMeContent = & { `
					$Help = ( $FunctionInfo | Get-Help -Full );
					if ( $Help.Syntax ) {
						$Syntax = (
							$Help.Syntax.SyntaxItem `
							| % {
								,$_.Name `
								+ ( 
									$_.Parameter `
									| % {
										#MamlCommandHelpInfo#parameter
										$name="-$($_.Name)";
										if ( $_.position -ne 'named' ) {
											$name="[$name]";
										};
										if ( $_.parameterValue ) {
											$param = "$name <$($_.parameterValue)>";
										} else {
											$param = "$name";
										};
										if ( $_.required -ne 'true' ) {
											$param = "[$param]";
										};
										$param;
									}
								) `
								+ ( & {
									if ( $FunctionInfo.CmdletBinding ) { '<CommonParameters>' }
								} ) `
								-join ' '
							}
						);
					} else {
						$Syntax = $Help.Synopsis;
					};
					if ( $ShortDescription ) {
@"

#### $( $loc.ShortDescription ) $( $FunctionInfo.Name | Expand-Definitions )

"@
						$Help.Synopsis `
						| Expand-Definitions `
						;
						if ( $Help.Syntax ) {
							$Syntax `
							| % {
@"

	$_
"@
							};
						};
					} else {
@"

#### $( $FunctionInfo.Name )

"@
						if ( $Help.Description ) {
							$Help.Description `
							| Select-Object -ExpandProperty Text `
							| Expand-Definitions `
							;
						} else {
							$Help.Synopsis `
							| Expand-Definitions `
							;
						};
						$Aliases = Get-Alias `
							-Definition ( $FunctionInfo.Name ) `
							-ErrorAction SilentlyContinue `
						;
						if ( $Aliases ) {
@"

##### $( $loc.AliasesSection )

$( $Aliases -join ', ' )
"@
						};
@"

##### $( $loc.Syntax )
"@
						$Syntax `
						| % {
@"

	$_
"@
						};
						if ( $Help.Component ) {
@"

##### $( $loc.Component )

$( $Help.Component )
"@
						};
						if ( $Help.Functionality ) {
@"

##### $( $loc.Capabilities )

$( $Help.Functionality )
"@
						};
						if ( $Help.Role ) {
@"

##### $( $loc.Role )

$( [String]::Format( $loc.RoleDetails, "**$( $Help.Role )**", "``$( $FunctionInfo.Name )``" ) )
"@
						};
						if ( $Help.inputTypes ) {
@"

##### $( $loc.InputType )

"@
							$Help.inputTypes.inputType `
							| % {
								$Description = `
									$_.type.name `
									| Expand-Definitions `
								;
@"
- $Description
"@
							};
						};
						if ( $Help.returnValues ) {
@"

##### $( $loc.ReturnType )

"@
							$Help.returnValues.returnValue `
							| % {
								$Description = `
									$_.type.name `
									| Expand-Definitions `
								;
@"
- $Description
"@
							};
						};
						if ( ( $Help.Parameters ) -or ( $FunctionInfo.CmdletBinding ) ) {
@"

##### $( $loc.Parameters )
"@
							$Description = `
								@(
									$Help.Parameters.parameter `
									| % {
										$Param = $FunctionInfo.Parameters[( $_.Name )];
@"

- ``[$( $Param.ParameterType.Name )] $( $_.name )``
"@
										if ( $_.description ) {
											(
												$_.description.text `
												| Expand-Definitions `
											) `
											-replace '(?m)^\s*', "`t" `
											-replace '(?m)\s+$', '' `
										};
										(
										& {
											$ParamDefs = & {
												if ( -not $Param.SwitchParameter ) {
													@{
														Attr = ( $loc.TypeColon );
														Value = ( $Param.ParameterType.FullName | Expand-Definitions );
													};
												};
												if ( $Param.Aliases ) {
													@{
														Attr = ( $loc.AliasesColon );
														Value = ( $Param.Aliases -join ', ' );
													};
												};
												if ( -not $Param.SwitchParameter ) {
													@{
														Attr = ( $loc.ParameterRequired );
														Value = ( $loc."$( $_.required )Short" );
													};
												};
												if ( -not $Param.SwitchParameter ) {
													@{
														Attr = ( $loc.ParameterPosition );
														Value = ( $_.position );
													};
												};
												if ( ( -not $Param.SwitchParameter ) -and ( $_.defaultValue ) ) {
													@{
														Attr = ( $loc.ParameterDefaultValue );
														Value = "``$( $_.defaultValue )``";
													};
												};
												if ( ( -not $Param.SwitchParameter ) -or ( -not $_.pipelineInput.ToLower().Equals( 'false' ) ) ) {
													@{
														Attr = ( $loc.AcceptsPipelineInput );
														Value = ( $_.pipelineInput );
													};
												};
												if ( -not $Param.SwitchParameter ) {
													@{
														Attr = ( $loc.AcceptsWildCardCharacters );
														Value = ( $loc."$( $_.globbing )Short" );
													};
												};
											};
<#
											"<table>"
											$ParamDefs `
											| % {
												$_.RB = '<tr><td>';
												$_.CD = '</td><td>';
												$_.RE = '</td></tr>';
												New-Object `
													-TypeName PSObject `
													-Property $_ `
												;
											} `
											| Format-Table `
												-AutoSize `
												-HideTableHeaders `
												-Property RB, Attr, CD, Value, RE `
											;
											"</table>";
#>
											$ParamDefs `
											| % {
@"
	* $( $_.Attr ) $( $_.Value )
"@
											} `
										} `
										| Out-String `
										) `
										-replace '((\r?\n)\s*){2,}', "`r`n" `
										-replace '(?s)(\s*\r?\n\s*$)', '' `
										-replace '(?m)^\s*', "`t" `
									} `
								) `
								+ ( & {
									if ( $FunctionInfo.CmdletBinding ) {
@"

- ``$( $loc.CommonParameters )``
$(
	$loc.BaseCmdletInformation `
		-replace '(?m)^\s*', "`t" `
)
"@ `
										| Expand-Definitions `
										;
									};
								} )`
								| Out-String `
							;
@"
$Description
"@
						};
						if ( $Help.Examples ) {
							$Help.Examples.Example `
							| % -Begin {
								$ExNum=0;
@"

##### $( $loc.Examples )
"@
							} `
							-Process {
								++$ExNum;
								$Comment = (
									(
										$_.remarks `
										| Select-Object -ExpandProperty Text `
										| ? { $_ } `
									) -join ' ' `
								).Trim( ' ', (("`t").Normalize()) ) `
								| Expand-Definitions `
								;
								if ( $Comment ) {
@"

$ExNum. $Comment
"@
								} else {
@"

$ExNum. $( [String]::Format( $loc.Example, $ExNum ) )
"@
								};
@"

		$($_.code)
"@
							};
						};
						if ( $Help.alertSet ) {
@"

##### $( $loc.Notes )

"@
							(
								$Help.alertSet.alert `
								| Select-Object -ExpandProperty Text `
								| Out-String `
								| Expand-Definitions `
							) -replace "(`r`n)+$", '';
						};
						if ( $Help.relatedLinks ) {
@"

##### $( $loc.RelatedLinks )

"@
							$Help.relatedLinks.navigationLink `
							| ? { $_.uri } `
							| % {
								# ������������ ������ �� online ������ �������
								if ( $_.uri -match $reOnlineHelpLinkCheck ) {
@"
- [$( & { if ( $_.LinkText ) { $_.LinkText } else { $( $loc.OnlineHelp ) } } )]($( $_.uri ))
"@
								} else {
									Write-Warning `
										-Message @"
$( [String]::Format( $loc.WarningLinkError, $FunctionInfo.Name ) )

	$( $_.uri )
	
"@ `
									;
								};
							};
							$Help.relatedLinks.navigationLink `
							| ? { -not $_.uri } `
							| % { $_.LinkText } `
							| % {
								# ������������ ������ ������
								$Link = `
									$_ `
									| Expand-Definitions `
								;
@"
- $Link
"@
							};
						};
					};
				};
				$ReadMeContent;
			};
		};
		$GetReadmeStatus.level--;
		if ( -not $GetReadmeStatus.level ) {
			Get-EndReference;
		};
	}
}

Function Set-Readme {
	<#
		.Synopsis
			���������� readme ���� � MarkDown ��������� �� ������ ������ � ������������ � ��� ��������. 
			���� ������������, � ���������, ��� ���������� � ������������ github.
		.Description
			���������� readme ���� � MarkDown ��������� �� ������ ������ � ������������ � ��� ��������. 
			���� ������������, � ���������, ��� ���������� � ������������ github.
			� ���������� � ����������� Get-Readme ��������� ��������� � ����, ����������� ����������
			`-PSPath`.
		.Functionality
			Readme
		.Role
			Everyone
		.Notes
		.Inputs
			System.Management.Automation.PSModuleInfo.
			��������� �������, ��� ������� ����� ������������ readme.md. 
			�������� ��������� ����� ���� ����� Get-Module.
		.Inputs
			System.Management.Automation.ExternalScriptInfo.
			��������� ���������, ��� ������� ����� ������������ readme.md. 
		.Inputs
			System.Management.Automation.CmdletInfo.
			��������� ���������, ��� ������� ����� ������������ readme.md. 
			�������� ��������� ����� ���� ����� Get-Command.
		.Inputs
			System.Management.Automation.CommandInfo.
			��������� �������, ��� ������� ����� ������������ readme.md. 
			�������� ��������� ����� ���� ����� Get-Command.
		.Link
			https://github.com/IT-Service/ITG.Readme#Set-Readme
		.Link
			Get-Readme
		.Link
			[MarkDown]: <http://daringfireball.net/projects/markdown/syntax> "MarkDown (md) Syntax"
		.Link
			about_comment_based_help
		.Link
			[��������� ������� ��� �����������](http://go.microsoft.com/fwlink/?LinkID=123415)
		.Example
			Get-Module 'ITG.Yandex.DnsServer' | Set-Readme;
			��������� readme.md ����� ��� ������ `ITG.Yandex.DnsServer` 
			� �������� ������.
		.Example
			Get-Module 'ITG.Yandex.DnsServer' | Set-Readme -ReferencedModules @( 'ITG.Yandex', 'ITG.Utils', 'ITG.WinAPI.UrlMon', 'ITG.WinAPI.User32' | Get-Module )
			��������� readme.md ����� ��� ������ `ITG.Yandex.DnsServer` 
			� �������� ������ `ITG.Yandex.DnsServer`, ��� ���� ��� ����������
			������� ������� `ITG.Yandex`, `ITG.Utils`, `ITG.WinAPI.UrlMon`,
			`ITG.WinAPI.User32` ��� �� ����� �������� ������������ ��������
			�� readme.md ����� ��������� �������.
	#>
	
	[CmdletBinding(
		DefaultParametersetName = 'ModuleInfo'
		, SupportsShouldProcess = $true
		, ConfirmImpact = 'Low'
		, HelpUri = 'https://github.com/IT-Service/ITG.Readme#Set-Readme'
	)]

	param (
		# ��������� ������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='ModuleInfo'
		)]
		[PSModuleInfo]
		[Alias('Module')]
		$ModuleInfo
	,
		# ��������� �������� ��������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='ExternalScriptInfo'
		)]
		[System.Management.Automation.ExternalScriptInfo]
		$ExternalScriptInfo
	,
		# ��������� �������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='FunctionInfo'
		)]
		[System.Management.Automation.CommandInfo]
		$FunctionInfo
	,
		# ��������, ��� ������� ������������ ������.
		[Parameter(
			Mandatory=$false
		)]
		[System.Globalization.CultureInfo]
		$UICulture = ( Get-Culture )
	,
		# ���� ��� readme �����. �� ��������� - `readme.md` � �������� ������
		[Parameter(
			ParameterSetName='ModuleInfo'
			, Mandatory=$false
		)]
		[String]
		[Alias('Path')]
		$PSPath = ''
	,
		# ������������ ������ ������� ��������
		[switch]
		[Alias('Short')]
		$ShortDescription
	,
		# �������� �������, ���������� ������� ������� ����� �������� �� ������
		[Parameter(
			Mandatory=$false
		)]
		[PSModuleInfo[]]
		[Alias('RequiredModules')]
		$ReferencedModules = @()
	,
		# ������� ��� ��������� readme ����������� �����������
		[Parameter(
			Mandatory=$false
		)]
		[Array]
		$TranslateRules = @()
	,
		# ���������� ���������� �� ��������� ��������� ������
		[switch]
		$PassThru
	)

	process {
		if ( -not $PSPath ) {
			$PSPath = `
				$ModuleInfo.ModuleBase `
				| Join-Path -ChildPath 'readme.md' `
			;
		};
		Write-Verbose `
			-Message ( [String]::Format( $loc.VerboseWriteReadme, $ModuleInfo.Name, $PSPath ) ) `
		;
		$null = $PSBoundParameters.Remove( 'PSPath' );
		$null = $PSBoundParameters.Remove( 'PassThru' );
		$null = $PSBoundParameters.Remove( 'WhatIf' );
		$null = $PSBoundParameters.Remove( 'Confirm' );

		$loc = Import-ReadmeLocalizedData `
			-UICulture $UICulture `
		;

		switch ( $PsCmdlet.ParameterSetName ) {
			'ModuleInfo' {
				( Get-Readme @PSBoundParameters ) `
				, (
@"

---------------------------------------

$( [String]::Format( $loc.GeneratorAbout, 'ITG.Readme', 'https://github.com/IT-Service/ITG.Readme' ) )
"@ `
				) `
				| Out-String `
				| Set-Content `
					-LiteralPath $PSPath `
					-Encoding 'UTF8' `
					-Force `
				;
			}
			'ExternalScriptInfo' {
			}
			default {
			};
		};
		
		if ( $PassThru ) { return $input };
	}
}

Function Get-AboutModule {
	<#
		.Synopsis
			���������� ���������� ����� `about_$(ModuleInfo.Name).txt` � MarkDown ���������
			�� ������ ������ � ������������ � ��� ��������. 
		.Description
			���������� ���������� ����� `about_$(ModuleInfo.Name).txt` � MarkDown ���������
			�� ������ ������ � ������������ � ��� ��������.
			��� ���������� � ���� ����������� Set-AboutModule.
		.Functionality
			Readme
		.Role
			Everyone
		.Notes
		.Inputs
			System.Management.Automation.PSModuleInfo.
			��������� �������, ��� ������� ����� ������������ about.txt. 
			�������� ��������� ����� ���� ����� Get-Module.
		.Outputs
			String.
			���������� about.txt.
		.Link
			https://github.com/IT-Service/ITG.Readme#Get-AboutModule
		.Link
			[MarkDown]: <http://daringfireball.net/projects/markdown/syntax> "MarkDown (md) Syntax"
		.Link
			about_comment_based_help
		.Link
			[��������� ������� ��� �����������](http://go.microsoft.com/fwlink/?LinkID=123415)
		.Example
			Get-Module 'ITG.Yandex.DnsServer' | Get-AboutModule;
			��������� ����������� about.txt ����� ��� ������ `ITG.Yandex.DnsServer`.
	#>
	
	[CmdletBinding(
		DefaultParametersetName = 'ModuleInfo'
		, HelpUri = 'https://github.com/IT-Service/ITG.Readme#Get-AboutModule'
	)]

	param (
		# ��������� ������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='ModuleInfo'
		)]
		[PSModuleInfo]
		[Alias('Module')]
		$ModuleInfo
	,
		# ��������, ��� ������� ������������ ������.
		[Parameter(
			Mandatory=$false
		)]
		[System.Globalization.CultureInfo]
		$UICulture = ( Get-Culture )
	,
		# �������� �������, ���������� ������� ������� ����� �������� �� ������
		[Parameter(
			Mandatory=$false
		)]
		[PSModuleInfo[]]
		[Alias('RequiredModules')]
		$ReferencedModules = @()
	)

	process {
		switch ( $PsCmdlet.ParameterSetName ) {
			'ModuleInfo' {
				return Get-Readme `
					@PSBoundParameters `
					-ShortDescription `
				;
			}
		}
	}
}

New-Alias `
	-Name Get-About `
	-Value Get-AboutModule `
	-Force `
;

Function Set-AboutModule {
	<#
		.Synopsis
			���������� ���� `about_$(ModuleInfo.Name).txt` � MarkDown ���������
			�� ������ ������ � ������������ � ��� ��������.
		.Description
			���������� ���� `about_$(ModuleInfo.Name).txt` � MarkDown ���������
			�� ������ ������ � ������������ � ��� �������� � ����������� ���������
			�������� � �������� ������ ��� � ������������ � ��������� ���������
			��������� `Path`.
		.Functionality
			Readme
		.Role
			Everyone
		.Notes
		.Inputs
			System.Management.Automation.PSModuleInfo.
			��������� �������, ��� ������� ����� ������������ readme.md. 
			�������� ��������� ����� ���� ����� Get-Module.
		.Link
			https://github.com/IT-Service/ITG.Readme#Set-AboutModule
		.Link
			Get-AboutModule
		.Link
			[MarkDown]: <http://daringfireball.net/projects/markdown/syntax> "MarkDown (md) Syntax"
		.Link
			about_comment_based_help
		.Link
			[��������� ������� ��� �����������](http://go.microsoft.com/fwlink/?LinkID=123415)
		.Example
			Get-Module 'ITG.Yandex.DnsServer' | Set-AboutModule;
			��������� `about_ITG.Yandex.DnsServer.txt` ����� ��� ������ `ITG.Yandex.DnsServer` 
			� ����������� ������� �������� � �������� ������.
	#>
	
	[CmdletBinding(
		DefaultParametersetName='ModuleInfo'
		, SupportsShouldProcess = $true
		, ConfirmImpact = 'Low'
		, HelpUri = 'https://github.com/IT-Service/ITG.Readme#Set-AboutModule'
	)]

	param (
		# ��������� ������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='ModuleInfo'
		)]
		[PSModuleInfo]
		[Alias('Module')]
		$ModuleInfo
	,
		# ��������, ��� ������� ������������ ������.
		[Parameter(
			Mandatory=$false
		)]
		[System.Globalization.CultureInfo]
		$UICulture = ( Get-Culture )
	,
		# ���� ��� about.txt �����. �� ��������� - � ����������� ��������� ��������.
		[Parameter(
			ParameterSetName='ModuleInfo'
			, Mandatory=$false
		)]
		[String]
		[Alias('Path')]
		$PSPath = ''
	,
		# �������� �������, ���������� ������� ������� ����� �������� �� ������
		[Parameter(
			Mandatory=$false
		)]
		[PSModuleInfo[]]
		[Alias('RequiredModules')]
		$ReferencedModules = @()
	,
		# ���������� ���������� �� ��������� ��������� ������
		[switch]
		$PassThru
	)

	process {
		$loc = Import-ReadmeLocalizedData `
			-UICulture $UICulture `
		;
		if ( -not $PSPath ) {
			$PSPath = `
				$ModuleInfo.ModuleBase `
				| Join-Path -ChildPath ( $UICulture.Name ) `
				| Join-Path -ChildPath "about_$( $ModuleInfo.Name ).help.txt" `
			;
		};
		Write-Verbose `
			-Message ( [String]::Format( $loc.VerboseWriteAbout, $ModuleInfo.Name, $PSPath ) ) `
		;
		$Dir = Split-Path -Path ( $PSPath ) -Parent;
		if ( -not ( Test-Path -LiteralPath $Dir ) ) {
			$null = New-Item -Path $Dir -ItemType Directory;
		};
		$null = $PSBoundParameters.Remove( 'PSPath' );
		$null = $PSBoundParameters.Remove( 'PassThru' );
		$null = $PSBoundParameters.Remove( 'WhatIf' );
		$null = $PSBoundParameters.Remove( 'Confirm' );

		switch ( $PsCmdlet.ParameterSetName ) {
			'ModuleInfo' {
				( Get-AboutModule @PSBoundParameters ) `
				, (
@"

---------------------------------------

$( [String]::Format( $loc.GeneratorAbout, 'ITG.Readme', 'https://github.com/IT-Service/ITG.Readme' ) )
"@ `
				) `
				| Out-String `
				| Set-Content `
					-LiteralPath $PSPath `
					-Encoding 'UTF8' `
					-Force `
				;
			}
		};
		
		if ( $PassThru ) { return $input };
	}
}

New-Alias `
	-Name Set-About `
	-Value Set-AboutModule `
	-Force `
;

Filter Split-Para {
	<#
		.Synopsis
			����� ���������� ����� �� ������ �� �������� MarkDown. � �������� �������
			������� - ������ ������. ����� � �������� ������ ���������� � ���� ������.
	#>
	param (
		[Parameter(
			Mandatory = $true
			, ValueFromPipeline = $true
		)]
		[String]
		[AllowEmptyString()]
		[Alias('Text')]
		$InputObject
	)
	
	$InputObject -split '(?:[ \t]*\r?\n[ \t]*){2,}' `
	| % {
		$_ -replace '(?:[ \t]*\r?\n[ \t]*)', ' ' `
		 	-replace '[ \t]+$', '' `
		;
	};
}

$HelpXMLNS = @{
	msh='http://msh';
	maml='http://schemas.microsoft.com/maml/2004/10';
	command='http://schemas.microsoft.com/maml/dev/command/2004/10';
	dev='http://schemas.microsoft.com/maml/dev/2004/10';
	MSHelp='http://msdn.microsoft.com/mshelp';
	HelpInfo='http://schemas.microsoft.com/powershell/help/2010/05';
};

Function DoTextElement( $HelpContent, $Root, $Prefix, $El, $NS, $Txt ) {
	if ( $Txt ) {
		$null = $Root.AppendChild(
			$HelpContent.CreateElement( $Prefix, $El, $NS )
		).AppendChild(
			$HelpContent.CreateTextNode( $Txt )
		);
	};
};

Function DoNameElement( $HelpContent, $Root, $Txt ) {
	DoTextElement $HelpContent $Root 'maml' 'name' ( $HelpXMLNS.maml ) $Txt;
};

Function DoCustomParaElement( $HelpContent, $Root, $El, $ParaEl, $Description ) {
	if ( $Description ) {
		$DescriptionEl = $Root.AppendChild(
			$HelpContent.CreateElement( 'maml', $El, ( $HelpXMLNS.maml ) )
		);
		$Description `
		| Split-Para `
		| % {
			DoTextElement $HelpContent $DescriptionEl 'maml' $ParaEl ( $HelpXMLNS.maml ) $_;
		};
	};
};

Function DoParaElement( $HelpContent, $Root, $El, $Description ) {
	DoCustomParaElement $HelpContent $Root $El 'para' $Description;
};

Function DoDescription( $HelpContent, $Root, $Description ) {
	DoParaElement $HelpContent $Root 'description' $Description;
};

Function DoValuesList( $HelpContent, $Root, $Help, $ListId, $ListItemId ) {
	if ( $Help.$ListId ) {
		$List = $Root.AppendChild(
			$HelpContent.CreateElement( '', $ListId, ( $HelpXMLNS.command ) )
		);
		$Help.$ListId.$ListItemId `
		| % {
			$Txt = @( $_.type.name -split '\r?\n' );
			$TypeName = $Txt[0];

			$null = $List.AppendChild(
				( $ItemEl = $HelpContent.CreateElement( '', $ListItemId, ( $HelpXMLNS.command ) ) )
			).AppendChild(
				( $DevType = $HelpContent.CreateElement( 'dev', 'type', ( $HelpXMLNS.dev ) ) )
			);
			DoTextElement $HelpContent $DevType 'maml' 'name' ( $HelpXMLNS.maml ) $TypeName;
			DoTextElement $HelpContent $DevType 'maml' 'uri' ( $HelpXMLNS.maml ) ( $_.type.uri );

			if ( $_.type.description ) {
				$TypeDescription = $_.type.description | Select-Object -ExpandProperty Text;
			} elseif ( $Txt.Count -gt 1 ) {
				$TypeDescription = $Txt[1..( $Txt.Count-1 )] | Out-String;
			} else {
				$TypeDescription = '';
			};
			DoDescription $HelpContent $DevType $TypeDescription;

			if ( $_.Description ) {
				$TypeDescription = $_.Description | Select-Object -ExpandProperty Text;
			};
			DoDescription $HelpContent $ItemEl $TypeDescription;
		};
	};
};

Function DoParaList( $HelpContent, $Root, $Help, $ListId, $ListItemId ) {
	if ( $Help.$ListId ) {
		$List = $Root.AppendChild(
			$HelpContent.CreateElement( 'maml', $ListId, ( $HelpXMLNS.maml ) )
		);
		$Help.$ListId.$ListItemId `
		| % {
			DoParaElement $HelpContent $List $ListItemId ( $_.Text );
		};
	};
};

Function New-HelpXML {
	<#
		.Synopsis
			���������� XML ������� ��� ����������� ������, �������, ����������.
		.Description
			���������� XML ������� ��� ����������� ������, �������, ����������.
			
			��� ��������� / ���������� .xml ����� ������� � �������� ������
			����������� Set-HelpXML.
		.Role
			Everyone
		.Inputs
			System.Management.Automation.PSModuleInfo
			��������� �������. ������ ��� ��� � ����� ������������� XML �������. 
			�������� ��������� ����� ���� ����� `Get-Module`.
		.Inputs
			System.Management.Automation.CommandInfo
			��������� �������. ������ ��� ��� � ����� ������������� XML �������. 
			�������� ��������� ����� ���� ����� `Get-Command`.
		.Outputs
			System.Xml.XmlDocument
			���������� XML �������.
		.Link
			https://github.com/IT-Service/ITG.Readme#New-HelpXML
		.Link
			about_Comment_Based_Help
		.Link
			about_Updatable_Help
		.Link
			[Creating the Cmdlet Help File](http://msdn.microsoft.com/en-us/library/bb525433.aspx)
		.Example
			Get-Module 'ITG.Yandex.DnsServer' | New-HelpXML;
			��������� xml ������� ��� ������ `ITG.Yandex.DnsServer`.
	#>

	[CmdletBinding(
		DefaultParametersetName = 'ModuleInfo'
		, HelpUri = 'https://github.com/IT-Service/ITG.Readme#New-HelpXML'
	)]

	param (
		# ��������� ������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='ModuleInfo'
		)]
		[PSModuleInfo]
		[Alias('Module')]
		$ModuleInfo
	,
		# ��������� �������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='FunctionInfo'
		)]
		[System.Management.Automation.CommandInfo]
		$FunctionInfo
	)

	process {
		trap {
			break;
		};
		switch ( $PsCmdlet.ParameterSetName ) {
			'ModuleInfo' {
				[System.Xml.XmlDocument]$HelpContent = @"
<!-- $( [String]::Format( $loc.GeneratorXmlAbout, 'ITG.Readme', 'https://github.com/IT-Service/ITG.Readme' ) ) -->
<helpItems
	xmlns="$( $HelpXMLNS.msh )"
	xmlns:maml="$( $HelpXMLNS.maml )"
	xmlns:command="$( $HelpXMLNS.command )" 
	xmlns:dev="$( $HelpXMLNS.dev )"
	xmlns:MSHelp="$( $HelpXMLNS.MSHelp )"
	schema="maml"
/>
"@
				if ( $ModuleInfo.ExportedCommands ) {
					$ModuleInfo.ExportedCommands.Values `
					| ? { $_.CommandType -ne [System.Management.Automation.CommandTypes]::Alias } `
					| New-HelpXML `
					| % {
						$null = $HelpContent.DocumentElement.AppendChild( $HelpContent.ImportNode( $_.DocumentElement, $true ) );
					};
				};
				return $HelpContent;
			}
			'FunctionInfo' {
				$ModuleManifestPath = Join-Path `
					-Path ( $FunctionInfo.Module.ModuleBase ) `
					-ChildPath "$( $FunctionInfo.Module.Name ).psd1" `
				;
				if ( -not ( Test-Path -LiteralPath $ModuleManifestPath ) ) {
					Write-Error `
						-Message ( [String]::Format( $loc.ErrorModuleManifestPathMessage, $ModuleManifestPath ) ) `
						-Category ResourceUnavailable `
						-CategoryActivity ( $loc.ErrorModuleManifestPathActivity ) `
						-CategoryReason ( $loc.ErrorModuleManifestPathReason ) `
						-CategoryTargetName ( $FunctionInfo.Module.Name ) `
						-TargetObject ( $FunctionInfo.Module ) `
						-RecommendedAction ( $loc.ErrorModuleManifestPathRecommendedAction ) `
					;
					return;
				};
				$Module = Invoke-Expression ( ( Get-Content -LiteralPath $ModuleManifestPath -ReadCount 0 ) -join "`r`n" ) ;
				
				[xml]$HelpContent = @"
<command
	xmlns:msh="$( $HelpXMLNS.msh )"
	xmlns:maml="$( $HelpXMLNS.maml )"
	xmlns="$( $HelpXMLNS.command )" 
	xmlns:dev="$( $HelpXMLNS.dev )"
	xmlns:MSHelp="$( $HelpXMLNS.MSHelp )"
/>
"@
				$Command = $HelpContent.DocumentElement;
				
				$Details = $Command.AppendChild(
					$HelpContent.CreateElement( '', 'details', ( $HelpXMLNS.command ) )
				);
				DoTextElement $HelpContent $Details '' 'name' ( $HelpXMLNS.command ) ( $FunctionInfo.Name );

				$NameParts = @( $FunctionInfo.Name -split '-' );
				if ( $NameParts.Count -eq 2 ) {
					DoTextElement $HelpContent $Details '' 'verb' ( $HelpXMLNS.command ) ( $NameParts[0] );
					DoTextElement $HelpContent $Details '' 'noun' ( $HelpXMLNS.command ) ( $NameParts[1] );
				};

				$Help = $( $FunctionInfo | Get-Help -Full );

				DoDescription $HelpContent $Details ( $Help.Synopsis );
				DoParaElement $HelpContent $Details 'copyright' ( $Module.Copyright );
				DoTextElement $HelpContent $Details 'dev' 'version' ( $HelpXMLNS.dev ) ( $Module.ModuleVersion );
				DoTextElement $HelpContent $Command 'maml' 'component' ( $HelpXMLNS.maml ) ( $Help.Component );
				DoTextElement $HelpContent $Command 'maml' 'functionality' ( $HelpXMLNS.maml ) ( $Help.Functionality );
				DoTextElement $HelpContent $Command 'maml' 'role' ( $HelpXMLNS.maml ) ( $Help.Role );
				DoDescription $HelpContent $Command ( $Help.Description | Select-Object -ExpandProperty Text );

				if ( $Help.Syntax ) {
					$null = $Command.AppendChild(
						( $Syntax = $HelpContent.CreateElement( '', 'syntax', ( $HelpXMLNS.command ) ) )
					);
					$Help.Syntax.SyntaxItem `
					| % {
						$SyntaxItem = $Syntax.AppendChild(
							$HelpContent.CreateElement( '', 'syntaxItem', ( $HelpXMLNS.command ) )
						);
						DoNameElement $HelpContent $SyntaxItem ( $FunctionInfo.Name );
						
						$_.Parameter `
						| % {
							$Parameter = $SyntaxItem.AppendChild(
								$HelpContent.CreateElement( '', 'parameter', ( $HelpXMLNS.command ) )
							);
							DoNameElement $HelpContent $Parameter ( $_.Name );
							$Parameter.SetAttribute( 'required', ( $_.Required ) );
							$Parameter.SetAttribute( 'position', ( $_.Position ) );
							$Parameter.SetAttribute( 'pipelineInput', ( $_.PipelineInput ) );
							if ( $_.variableLength ) {
								$Parameter.SetAttribute( 'variableLength', ( $_.variableLength ) );
							};
							if ( $_.globbing ) {
								$Parameter.SetAttribute( 'globbing', ( $_.globbing ) );
							};

							if ( $_.parameterValue ) {
								$null = $Parameter.AppendChild(
									( $ParameterValue = $HelpContent.CreateElement( '', 'parameterValue', ( $HelpXMLNS.command ) ) )
								).AppendChild(
									$HelpContent.CreateTextNode( ( $_.parameterValue ) )
								);
								$ParameterValue.SetAttribute( 'required', ( $_.Required ) );
								if ( $_.variableLength ) {
									$ParameterValue.SetAttribute( 'variableLength', ( $_.variableLength ) );
								};
							};
						};
					};
				};

				if ( $Help.Parameters ) {
					$Parameters = $Command.AppendChild(
						$HelpContent.CreateElement( '', 'parameters', ( $HelpXMLNS.command ) )
					);
					$Help.Parameters.Parameter `
					| % {
						$Parameter = $Parameters.AppendChild(
							$HelpContent.CreateElement( '', 'parameter', ( $HelpXMLNS.command ) )
						);
						DoNameElement $HelpContent $Parameter ( $_.Name );

						$Parameter.SetAttribute( 'required', ( $_.Required ) );
						$Parameter.SetAttribute( 'position', ( $_.Position ) );
						$Parameter.SetAttribute( 'pipelineInput', ( $_.PipelineInput ) );
						if ( $_.variableLength ) {
							$Parameter.SetAttribute( 'variableLength', ( $_.variableLength ) );
						};
						if ( $_.globbing ) {
							$Parameter.SetAttribute( 'globbing', ( $_.globbing ) );
						};

						DoDescription $HelpContent $Parameter ( $_.Description | Select-Object -ExpandProperty Text );
						
						if ( $_.parameterValue ) {
							$null = $Parameter.AppendChild(
								( $ParameterValue = $HelpContent.CreateElement( '', 'parameterValue', ( $HelpXMLNS.command ) ) )
							).AppendChild(
								$HelpContent.CreateTextNode( ( $_.parameterValue ) )
							);
							$ParameterValue.SetAttribute( 'required', $true );
							if ( $_.variableLength ) {
								$ParameterValue.SetAttribute( 'variableLength', ( $_.variableLength ) );
							};
						};
						
						DoTextElement $HelpContent $Parameter '' 'defaultValue' ( $HelpXMLNS.command ) ( $_.defaultValue );
						
						if ( $_.possibleValues ) {
							$PossibleValues = $Command.AppendChild(
								$HelpContent.CreateElement( 'dev', 'possibleValues', ( $HelpXMLNS.dev ) )
							);
							$_.possibleValues.possibleValue `
							| % {
								$PossibleValue = $PossibleValues.AppendChild(
									$HelpContent.CreateElement( 'dev', 'possibleValue', ( $HelpXMLNS.dev ) )
								);
								DoTextElement $HelpContent $PossibleValue 'dev' 'value' ( $HelpXMLNS.dev ) ( $_.value );
								DoDescription $HelpContent $PossibleValue ( $_.Description | Select-Object -ExpandProperty Text );
							};
						};
					};
				};

				DoValuesList $HelpContent $Command $Help 'inputTypes' 'inputType';
				DoValuesList $HelpContent $Command $Help 'returnValues' 'returnValue';
				DoParaList $HelpContent $Command $Help 'alertSet' 'alert';

				if ( $Help.Examples ) {
					$Examples = $Command.AppendChild(
						$HelpContent.CreateElement( '', 'examples', ( $HelpXMLNS.command ) )
					);
					$Help.Examples.Example `
					| % {
						$Example = $Examples.AppendChild(
							$HelpContent.CreateElement( '', 'example', ( $HelpXMLNS.command ) )
						);
						DoTextElement $HelpContent $Example 'maml' 'title' ( $HelpXMLNS.maml ) ( $_.title );
						$Prompt = $Example.AppendChild(
							$HelpContent.CreateElement( 'maml', 'introduction', ( $HelpXMLNS.maml ) )
						);
						$_.introduction `
						| % { $_.Text -replace '^\s+|\s+$', '' } `
						| Out-String `
						| Split-Para `
						| % {
							DoTextElement $HelpContent $Prompt 'maml' 'paragraph' ( $HelpXMLNS.maml ) $_;
						};
						DoTextElement $HelpContent $Example 'dev' 'code' ( $HelpXMLNS.dev ) ( $_.code );
						DoParaElement $HelpContent $Example 'remarks' (
							$_.remarks `
							| % { $_.Text -replace '(?m)^\s+|\s+$', '' } `
							| Out-String `
						);
					};
				};

				if ( $Help.relatedLinks ) {
					$ListEl = $Command.AppendChild(
						$HelpContent.CreateElement( 'maml', 'relatedLinks', ( $HelpXMLNS.maml ) )
					);
					$Help.relatedLinks.navigationLink `
					| % {
						$ListItemEl = $ListEl.AppendChild(
							$HelpContent.CreateElement( 'maml', 'navigationLink', ( $HelpXMLNS.maml ) )
						);
						DoTextElement $HelpContent $ListItemEl 'maml' 'uri' ( $HelpXMLNS.maml ) ( $_.uri );
						DoTextElement $HelpContent $ListItemEl 'maml' 'linkText' ( $HelpXMLNS.maml ) ( $_.linkText );
					};
				};

				return $HelpContent;
			};
		};
	};
}

Function Get-HelpXML {
	<#
		.Synopsis
			��������� XML ���������� xml ����� ������� ��� ����������� ������.
		.Description
			��������� XML ���������� xml ����� ������� ��� ����������� ������.
		.Role
			Everyone
		.Inputs
			System.Management.Automation.PSModuleInfo
			��������� �������. ������ ��� ��� � ����� ������������� XML �������. 
			�������� ��������� ����� ���� ����� `Get-Module`.
		.Outputs
			System.Xml.XmlDocument
			���������� XML �������.
		.Link
			https://github.com/IT-Service/ITG.Readme#Get-HelpXML
		.Link
			about_Updatable_Help
		.Link
			[Creating the Cmdlet Help File](http://msdn.microsoft.com/en-us/library/bb525433.aspx)
		.Example
			Get-Module 'ITG.Yandex.DnsServer' | Get-HelpXML;
			���������� ���������� xml ����� ������� ��� ������ `ITG.Yandex.DnsServer` 
			� ���� XML ���������.
	#>
	
	[CmdletBinding(
		DefaultParametersetName = 'ModuleInfo'
		, HelpUri = 'https://github.com/IT-Service/ITG.Readme#Get-HelpXML'
	)]

	param (
		# ��������� ������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='ModuleInfo'
		)]
		[PSModuleInfo]
		[Alias('Module')]
		$ModuleInfo
	,
		# ��������, ��� ������� ������� ������.
		[Parameter(
			Mandatory=$false
		)]
		[System.Globalization.CultureInfo]
		$UICulture = ( Get-Culture )
	,
		# ���� ��� xml ����� �������
		[Parameter(
			ParameterSetName='ModuleInfo'
			, Mandatory=$false
		)]
		[String]
		[Alias('Path')]
		$PSPath = ''
	)

	process {
		trap {
			break;
		};
		$loc = Import-ReadmeLocalizedData `
			-UICulture $UICulture `
		;
		switch ( $PsCmdlet.ParameterSetName ) {
			'ModuleInfo' {
				if ( -not $PSPath ) {
					$PSPath = `
						$ModuleInfo.ModuleBase `
						| Join-Path -ChildPath ( $UICulture.Name ) `
						| Join-Path -ChildPath "$( $ModuleInfo.Name )-help.xml" `
					;
				};
				if ( Test-Path $PSPath ) {
					return ( [xml](
						Get-Content `
							-LiteralPath $PSPath `
							-ReadCount 0 `
					));
				} else {
					return [xml] @"
<!-- $( [String]::Format( $loc.GeneratorXmlAbout, 'ITG.Readme', 'https://github.com/IT-Service/ITG.Readme' ) ) -->
<helpItems
	xmlns="$( $HelpXMLNS.msh )"
	xmlns:maml="$( $HelpXMLNS.maml )"
	xmlns:command="$( $HelpXMLNS.command )" 
	xmlns:dev="$( $HelpXMLNS.dev )"
	xmlns:MSHelp="$( $HelpXMLNS.MSHelp )"
	schema="maml"
/>
"@
				};
			}
		};
	}
}

Function Set-HelpXML {
	<#
		.Synopsis
			���������� XML ���� ������� ��� ����������� ������, �������, ����������.
		.Description
			���������� XML ���� ������� ��� ����������� ������, �������, ����������.
			
			����� ����, ������
			������� ������� XML ���� ������� � �������� ������ (������ - �
			����������� ��������, ��� ���� � ������� ���������� PowerShell, �
			��������� - `Get-Help`).
		.Notes
			���������� �������������� ������������ �� PowerShell 3.
		.Role
			Everyone
		.Inputs
			System.Management.Automation.PSModuleInfo
			��������� �������. ������ ��� ��� � ����� ������������� XML �������. 
			�������� ��������� ����� ���� ����� `Get-Module`.
		.Inputs
			System.Management.Automation.CommandInfo
			��������� �������. ������ ��� ��� � ����� ������������� XML �������. 
			�������� ��������� ����� ���� ����� `Get-Command`.
		.Link
			https://github.com/IT-Service/ITG.Readme#Set-HelpXML
		.Link
			Get-HelpXML
		.Link
			about_Updatable_Help
		.Link
			[Creating the Cmdlet Help File](http://msdn.microsoft.com/en-us/library/bb525433.aspx)
		.Example
			Get-Module 'ITG.Yandex.DnsServer' | Set-HelpXML;
			��������� xml ����� ������� ��� ������ `ITG.Yandex.DnsServer` 
			� �������� ������.
	#>
	
	[CmdletBinding(
		DefaultParametersetName = 'ModuleInfo'
		, SupportsShouldProcess = $true
		, ConfirmImpact = 'Low'
		, HelpUri = 'https://github.com/IT-Service/ITG.Readme#Set-HelpXML'
	)]

	param (
		# ��������� ������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='ModuleInfo'
		)]
		[PSModuleInfo]
		[Alias('Module')]
		$ModuleInfo
	,
		# ��������� �������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='FunctionInfo'
		)]
		[System.Management.Automation.CommandInfo]
		$FunctionInfo
	,
		# ��������, ��� ������� ������������ ������.
		[Parameter(
			Mandatory=$false
		)]
		[System.Globalization.CultureInfo]
		$UICulture = ( Get-Culture )
	,
		# ���� ��� xml ����� �������
		[Parameter(
			ParameterSetName='ModuleInfo'
			, Mandatory=$false
		)]
		[String]
		[Alias('Path')]
		$PSPath = ''
	,
		# ��������� ���� ������ - ��������� � ���� ������ � ����������� � �������� ������ 
		# ������ ���� `.ExternalHelp ITG.Readme-help.xml`
		[Parameter(
			ParameterSetName='ModuleInfo'
		)]
		[switch]
		$UpdateModule
	,
		# ������������ / ��������� ��� ��� .cab ����
		[Parameter(
			ParameterSetName='ModuleInfo'
		)]
		[switch]
		$Cab
	,
		# ���� � .cab �����
		[Parameter(
			ParameterSetName='ModuleInfo'
			, Mandatory=$false
		)]
		[String]
		[Alias('$CabPath')]
		$PSCabPath = ''
	,
		# ���������� ���������� �� ��������� ��������� ������
		[switch]
		$PassThru
	)

	process {
		trap {
			break;
		};
		$loc = Import-ReadmeLocalizedData `
			-UICulture $UICulture `
		;
		switch ( $PsCmdlet.ParameterSetName ) {
			'ModuleInfo' {
				if ( -not $PSPath ) {
					$PSPath = `
						$ModuleInfo.ModuleBase `
						| Join-Path -ChildPath ( $UICulture.Name ) `
						| Join-Path -ChildPath "$( $ModuleInfo.Name )-help.xml" `
					;
				};
				if ( -not $PSCabPath ) {
					$PSCabPath = `
						$ModuleInfo.ModuleBase `
						| Join-Path -ChildPath 'help.cab' `
						| Join-Path -ChildPath "$( $ModuleInfo.Name )_$( $ModuleInfo.GUID )_$( $UICulture )_HelpContent.cab" `
					;
				};
				Write-Verbose `
					-Message ( [String]::Format( $loc.VerboseWriteHelpXML, $ModuleInfo.Name, $PSPath, $PSCabPath ) ) `
				;

				[System.Xml.XmlDocument]$HelpContent = New-HelpXML -ModuleInfo $ModuleInfo;

				$TempHelpXmlFile = [System.IO.Path]::GetTempFileName();
				$Writer = [System.Xml.XmlWriter]::Create(
					$TempHelpXmlFile `
					, ( New-Object `
						-TypeName System.Xml.XmlWriterSettings `
						-Property @{
							Indent = $true;
							OmitXmlDeclaration = $false;
							NamespaceHandling = [System.Xml.NamespaceHandling]::OmitDuplicates;
							NewLineOnAttributes = $false;
							CloseOutput = $true;
							IndentChars = "`t";
						} `
					) `
				);
				$HelpContent.WriteTo( $Writer );
				$Writer.Close();
				Copy-Item `
					-LiteralPath $TempHelpXmlFile `
					-Destination $PSPath `
					-Force `
				;

				if ( $Cab ) {
					$TempCabFile = [System.IO.Path]::GetTempFileName();
					$MakeCabProcess = Start-Process `
						-FilePath 'makecab' `
						-ArgumentList "`"$( $TempHelpXmlFile )`"", "`"$( $TempCabFile )`"" `
						-NoNewWindow `
						-Wait `
						-PassThru `
					;
					if ( $MakeCabProcess.ExitCode ) {
						Write-Error `
							-Message ( [String]::Format( $loc.ErrorMakeCabMessage, $MakeCabProcess.ExitCode ) ) `
						;
					};
					$PSCabDir = ( Split-Path -Path $PSCabPath -Parent );
					if ( -not ( Test-Path -Path $PSCabDir ) ) {
						New-Item `
							-Path ( Split-Path -Path $PSCabDir -Parent ) `
							-Name ( Split-Path -Path $PSCabDir -Leaf ) `
							-ItemType Directory `
						;
					};
					Copy-Item `
						-LiteralPath $TempCabFile `
						-Destination $PSCabPath `
						-Force `
					;
					$null = [System.IO.File]::Delete( $TempCabFile );
				};

				$null = [System.IO.File]::Delete( $TempHelpXmlFile );

				if ( $UpdateModule ) {
					$reFuncHeaders = 
						'(?m)' `
						, '(?<=^(Function|Filter)\s+(' `
						, (
							(
								$ModuleInfo.ExportedCommands.Values `
								| % { $_.Name } `
							) `
							-join '|' `
						) `
						, ')\s*\{)(\s*$)?' `
						-join '' `
					;
					$ModulePath = $ModuleInfo.Path;
					( Get-Content `
						-LiteralPath $ModulePath `
						-ReadCount 0 `
					) `
					-join "`r`n" `
					-replace `
						$reFuncHeaders `
						, "`r`n#`t.ExternalHelp $HelpXMLFileName`r`n" `
					| Set-Content `
						-LiteralPath $ModulePath `
						-Encoding 'UTF8' `
						-Force `
					;
				};
			}
		};
		
		if ( $PassThru ) { return $input };
	}
}

Function New-HelpInfo {
	<#
		.Synopsis
			���������� HelpInfo XML ��� ����������� ������.
		.Description
			���������� HelpInfo XML ��� ����������� ������, ��� ������ � ����. 
			HelpInfo.XML �� ���� �������� ���������� ��� xml ������� ������.
		.Notes
			��� ������ HelpInfo.xml ����� ����������� Set-HelpInfo.
		.Role
			Everyone
		.Inputs
			System.Management.Automation.PSModuleInfo
			��������� �������. ������ ��� ��� � ����� ������������ �������� XML ������� (HelpInfo.xml). 
			�������� ��������� ����� ���� ����� `Get-Module`.
		.Outputs
			System.Xml.XmlDocument
			���������� XML ��������� (HelpInfo.xml) �������.
		.Link
			https://github.com/IT-Service/ITG.Readme#New-HelpInfo
		.Link
			about_Updatable_Help
		.Link
			Set-HelpInfo
		.Link
			[HelpInfo XML Sample File](http://msdn.microsoft.com/en-us/library/windows/desktop/hh852750.aspx)
		.Example
			Get-Module 'ITG.Yandex.DnsServer' | New-HelpInfo;
			��������� xml ��������� ������� ��� ������ `ITG.Yandex.DnsServer`.
	#>
	
	[CmdletBinding(
		DefaultParametersetName = 'ModuleInfo'
		, HelpUri = 'https://github.com/IT-Service/ITG.Readme#New-HelpInfo'
	)]

	param (
		# ��������� ������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='ModuleInfo'
		)]
		[PSModuleInfo]
		[Alias('Module')]
		$ModuleInfo
	,
		# ������ ��� �������� ����������� �������. �������� about_Updatable_Help.
		# �������� �� ��������� - url � ����������� ������� �� github.
		[Parameter(
			ParameterSetName='ModuleInfo'
			, Mandatory=$false
		)]
		[System.Uri]
		$HelpContentUri = $null
	)

	process {
		trap {
			break;
		};
		switch ( $PsCmdlet.ParameterSetName ) {
			'ModuleInfo' {
				if ( -not $HelpContentUri ) {
					$HelpContentURI = "http://raw.github.com/IT-Service/$( $ModuleInfo.Name )/$( $ModuleInfo.Version )/help.cab";
				};
				$HelpInfoContent = New-Object -TypeName System.Xml.XmlDocument;
				$HelpInfo = $HelpInfoContent.AppendChild(
					$HelpInfoContent.CreateElement( '', 'HelpInfo', ( $HelpXMLNS.HelpInfo ) )
				);
				DoTextElement $HelpInfoContent $HelpInfo '' 'HelpContentURI' ( $HelpXMLNS.HelpInfo ) (
					$HelpContentUri
				);
				$SupportedUICultures = $HelpInfo.AppendChild(
					$HelpInfoContent.CreateElement( '', 'SupportedUICultures', ( $HelpXMLNS.HelpInfo ) )
				);
				Get-Culture `
				| % {
					$UICulture = $SupportedUICultures.AppendChild(
						$HelpInfoContent.CreateElement( '', 'UICulture', ( $HelpXMLNS.HelpInfo ) )
					);
					DoTextElement $HelpInfoContent $UICulture '' 'UICultureName' ( $HelpXMLNS.HelpInfo ) ( $_.Name );
					DoTextElement $HelpInfoContent $UICulture '' 'UICultureVersion' ( $HelpXMLNS.HelpInfo ) ( $ModuleInfo.Version );
				};
				return $HelpInfoContent;
			}
		};
	}
}

Function Get-HelpInfo {
	<#
		.Synopsis
			���������� HelpInfo.xml (��� xml) ��� ���������� ������.
		.Description
			��������� ������������ � ��������� HelpInfo.xml ����� ��� ���������� ������
			� ���������� ��� ����������. ���� ���� �� ��������� - ���������� ������
			xml "���������" HelpInfo.xml, �� ��������.
		.Role
			Everyone
		.Inputs
			System.Management.Automation.PSModuleInfo
			��������� �������. ������ ��� ��� � ����� ��������� �������� XML ������� (HelpInfo.xml). 
			�������� ��������� ����� ���� ����� `Get-Module`.
		.Outputs
			System.Xml.XmlDocument
			���������� XML ��������� (HelpInfo.xml) �������.
		.Link
			https://github.com/IT-Service/ITG.Readme#Get-HelpInfo
		.Link
			about_Updatable_Help
		.Link
			Set-HelpInfo
		.Link
			New-HelpInfo
		.Link
			[How to Name a HelpInfo XML File](http://msdn.microsoft.com/en-us/library/windows/desktop/hh852748.aspx)
		.Link
			[HelpInfo XML Sample File](http://msdn.microsoft.com/en-us/library/windows/desktop/hh852750.aspx)
		.Example
			Get-Module 'ITG.Yandex.DnsServer' | Get-HelpInfo;
			���������� xml �������� ������� ��� ������ `ITG.Yandex.DnsServer`.
	#>
	
	[CmdletBinding(
		DefaultParametersetName = 'ModuleInfo'
		, HelpUri = 'https://github.com/IT-Service/ITG.Readme#Get-HelpInfo'
	)]

	param (
		# ��������� ������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='ModuleInfo'
		)]
		[PSModuleInfo]
		[Alias('Module')]
		$ModuleInfo
	)

	process {
		trap {
			break;
		};
		switch ( $PsCmdlet.ParameterSetName ) {
			'ModuleInfo' {
				$HelpInfoPath = ( Join-Path `
					-Path ( Split-Path -Path ( $ModuleInfo.Path ) -Parent ) `
					-ChildPath "$( $ModuleInfo.Name )_$( $ModuleInfo.GUID )_HelpInfo.xml" `
				);
				if ( Test-Path $HelpInfoPath ) {
					return ( [xml](
						Get-Content `
							-LiteralPath $HelpInfoPath `
							-ReadCount 0 `
					));
				} else {
					return [xml] @"
<HelpInfo xmlns="$( $HelpXMLNS.HelpInfo )">
	<SupportedUICultures/>
</HelpInfo>
"@
				};
			}
		};
	}
}

Function Set-HelpInfo {
	<#
		.Synopsis
			���������� HelpInfo XML ��� ���������� ������.
		.Description
			���������� HelpInfo XML ��� ����������� ������, �
			������ ��������� (� ����� ������� ��������) � ������������ ����
			HelpInfo.xml � �������� ������, ���� ������ ����� ����.
		.Role
			Everyone
		.Inputs
			System.Management.Automation.PSModuleInfo
			��������� �������. ������ ��� ��� � ����� ������������ �������� XML ������� (HelpInfo.xml). 
			�������� ��������� ����� ���� ����� `Get-Module`.
		.Outputs
			None.
		.Link
			https://github.com/IT-Service/ITG.Readme#Set-HelpInfo
		.Link
			about_Updatable_Help
		.Link
			Get-HelpInfo
		.Link
			New-HelpInfo
		.Link
			[HelpInfo XML Sample File](http://msdn.microsoft.com/en-us/library/windows/desktop/hh852750.aspx)
		.Example
			Set-HelpInfo -ModuleInfo ( Get-Module 'ITG.Yandex.DnsServer' );
			�������� / ����������� HelpInfo.xml ����� ��� ������ `ITG.Yandex.DnsServer` � �������� ������.
	#>
	
	[CmdletBinding(
		DefaultParametersetName = 'ModuleInfo'
		, SupportsShouldProcess = $true
		, ConfirmImpact = 'Medium'
		, HelpUri = 'https://github.com/IT-Service/ITG.Readme#Set-HelpInfo'
	)]

	param (
		# ��������� ������
		[Parameter(
			Mandatory=$true
			, Position=0
			, ValueFromPipeline=$true
			, ParameterSetName='ModuleInfo'
		)]
		[PSModuleInfo]
		[Alias('Module')]
		$ModuleInfo
	,
		# ������ ��� �������� ����������� �������. �������� about_Updatable_Help.
		# �������� �� ��������� - url � ����������� ������� �� github.
		[Parameter(
			ParameterSetName='ModuleInfo'
			, Mandatory=$false
		)]
		[System.Uri]
		$HelpContentUri = $null
	,
		# ��������� ��� ��� �������� ������. ���� ��� � �������� / ���������� ��������� 
		# HelpInfoURI � ���������, ������� ��� ��� � ������ ��������� �� HelpInfo.xml ����
		[Parameter(
			ParameterSetName='ModuleInfo'
		)]
		[switch]
		$UpdateManifest
	,
		# ������������ ������ ���������
		# � `UpdateManifest`. �������� �� ��������� - url � ����������� ������� �� github.
		[Parameter(
			ParameterSetName='ModuleInfo'
			, Mandatory=$false
		)]
		[System.Uri]
		$HelpInfoUri = $null
	,
		# ���������� ���������� �� ��������� ��������� ������
		[switch]
		$PassThru
	)

	process {
		trap {
			break;
		};
		switch ( $PsCmdlet.ParameterSetName ) {
			'ModuleInfo' {
				if ( -not $HelpContentUri ) {
					$HelpContentURI = "http://raw.github.com/IT-Service/$( $ModuleInfo.Name )/$( $ModuleInfo.Version )/help.cab";
				};
				if ( -not $HelpInfoUri ) {
					$HelpInfoURI = "http://raw.github.com/IT-Service/$( $ModuleInfo.Name )/$( $ModuleInfo.Version )/$( $ModuleInfo.Name )_$( $ModuleInfo.GUID )_HelpInfo.xml";
				};
				$HelpInfoContent = Get-HelpInfo `
					-ModuleInfo $ModuleInfo `
				;
				$NewHelpInfoContent = New-HelpInfo `
					-ModuleInfo $ModuleInfo `
					-HelpContentUri $HelpContentUri `
				;

				$HelpInfoNS = [System.Xml.XmlNamespaceManager] ($NewHelpInfoContent.NameTable);
 				$HelpInfoNS.AddNamespace( 'hi', $HelpXMLNS.HelpInfo );

				$HelpContentURIEl = $HelpInfoContent.SelectSingleNode(
					'/hi:HelpInfo/hi:HelpContentURI'
					, $HelpInfoNS
				);
				if ( $HelpContentURIEl ) {
					$null = $HelpInfoContent.HelpInfo.RemoveChild( $HelpContentURIEl );
				};
				$null = $HelpInfoContent.HelpInfo.PrependChild(
					$HelpInfoContent.ImportNode(
						$NewHelpInfoContent.SelectSingleNode(
							'/hi:HelpInfo/hi:HelpContentURI'
							, $HelpInfoNS
						)
						, $true 
					)
				);
				$SupportedUICultures = $HelpInfoContent.SelectSingleNode(
					'/hi:HelpInfo/hi:SupportedUICultures'
					, $HelpInfoNS
				);
				$NewSupportedUICultures = $NewHelpInfoContent.HelpInfo.SupportedUICultures;
				$NewSupportedUICultures.UICulture `
				| % {
					$UICultureEl = $HelpInfoContent.SelectSingleNode(
						"/hi:HelpInfo/hi:SupportedUICultures/hi:UICulture[hi:UICultureName/text()='$( $_.UICultureName )']"
						, $HelpInfoNS
					);
					if ( $UICultureEl ) {
						$null = $SupportedUICultures.ReplaceChild(
							$HelpInfoContent.ImportNode( $_, $true )
							, $UICultureEl
						);
					} else {
						$null = $SupportedUICultures.AppendChild(
							$HelpInfoContent.ImportNode( $_, $true )
						);
					};
				};

				$HelpInfoPath = ( Join-Path `
					-Path ( Split-Path -Path ( $ModuleInfo.Path ) -Parent ) `
					-ChildPath "$( $ModuleInfo.Name )_$( $ModuleInfo.GUID )_HelpInfo.xml" `
				);
				Write-Verbose `
					-Message ( [String]::Format( $loc.VerboseWriteHelpInfo, $ModuleInfo.Name, $HelpInfoPath ) ) `
				;
				$TempHelpInfoFile = [System.IO.Path]::GetTempFileName();
				$Writer = [System.Xml.XmlWriter]::Create(
					$TempHelpInfoFile `
					, ( New-Object `
						-TypeName System.Xml.XmlWriterSettings `
						-Property @{
							Indent = $true;
							OmitXmlDeclaration = $false;
							NamespaceHandling = [System.Xml.NamespaceHandling]::OmitDuplicates;
							NewLineOnAttributes = $false;
							CloseOutput = $true;
							IndentChars = "`t";
						} `
					) `
				);
				$HelpInfoContent.WriteTo( $Writer );
				$Writer.Close();
				Copy-Item `
					-LiteralPath $TempHelpInfoFile `
					-Destination $HelpInfoPath `
					-Force `
				;
				$null = [System.IO.File]::Delete( $TempHelpInfoFile );

				if ( $UpdateManifest ) {
					$ModuleManifestPath = Join-Path `
						-Path ( $ModuleInfo.ModuleBase ) `
						-ChildPath "$( $ModuleInfo.Name ).psd1" `
					;
					if ( -not ( Test-Path -LiteralPath $ModuleManifestPath ) ) {
						Write-Error `
							-Message ( [String]::Format( $loc.ErrorModuleManifestPathMessage, $ModuleManifestPath ) ) `
							-Category ResourceUnavailable `
							-CategoryActivity ( $loc.ErrorModuleManifestPathActivity ) `
							-CategoryReason ( $loc.ErrorModuleManifestPathReason ) `
							-CategoryTargetName ( $FunctionInfo.Module.Name ) `
							-TargetObject ( $FunctionInfo.Module ) `
							-RecommendedAction ( $loc.ErrorModuleManifestPathRecommendedAction ) `
						;
						return;
					};
					( Get-Content `
						-LiteralPath $ModuleManifestPath `
						-ReadCount 0 `
					) `
					-join "`r`n" `
					-replace `
						"(?s)`r?`nHelpInfoUri\s*=\s*['`"].*?['`"]\s+|(?<!HelpInfoUri.*)(?=})" `
						, "`r`nHelpInfoUri = '$HelpInfoUri'`r`n`r`n" `
					| Set-Content `
						-LiteralPath $ModuleManifestPath `
						-Encoding 'UTF8' `
						-Force `
					;
				};
			}
		};
		
		if ( $PassThru ) { return $input };
	}
}

$PowerShellAboutTopics = @{
	'about_Aliases' = 113207
	'about_Arithmetic_Operators' = 113208
	'about_Arrays' = 113209
	'about_Assignment_Operators' = 113210
	'about_Automatic_Variables' = 113212
	'about_Break' = 113213
	'about_Command_Precedence' = 113214
	'about_Command_Syntax' = 113215
	'about_Comment_Based_Help' = 144309
	'about_CommonParameters' = 113216
	'about_Comparison_Operators' = 113217
	'about_Continue' = 113218
	'about_Core_Commands' = 113219
	'about_Data_Sections' = 113220
	'about_Debuggers' = 113221
	'about_Do' = 135169
	'about_Environment_Variables' = 113222
	'about_Escape_Characters' = 113223
	'about_EventLogs' = 113224
	'about_Execution_Policies' = 135170
	'about_For' = 113228
	'about_Foreach' = 113229
	'about_Format.ps1xml' = 113230
	'about_Functions' = 113231
	'about_Functions_Advanced' = 144511
	'about_Functions_Advanced_Methods' = 135172
	'about_Functions_Advanced_Parameters' = 135173
	'about_Functions_CmdletBindingAttribute' = 135174
	'about_Hash_Tables' = 135175
	'about_History' = 113233
	'about_If' = 113234
	'about_Job_Details' = 135176
	'about_jobs' = 113251
	'about_Join' = 113235
	'about_Language_Keywords' = 136588
	'about_Line_Editing' = 113236
	'about_Locations' = 113237
	'about_Logical_Operators' = 113238
	'about_Methods' = 113239
	'about_Modules' = 144311
	'about_Objects' = 113241
	'about_Operators' = 113242
	'about_Parameters' = 113243
	'about_Parsing' = 113244
	'about_Path_Syntax' = 113245
	'about_Pipelines' = 113246
	'about_Preference_Variables' = 113248
	'about_Profiles' = 113729
	'about_Prompts' = 135179
	'about_Properties' = 113249
	'about_Providers' = 113250
	'about_PSSession_Details' = 135180
	'about_PSSessions' = 135181
	'about_PSsnapins' = 113252
	'about_Quoting_Rules' = 113253
	'about_Redirection' = 113254
	'about_Ref' = 113255
	'about_Regular_Expressions' = 113256
	'about_Remote' = 135182
	'about_Remote_FAQ' = 135183
	'about_Remote_Jobs' = 135184
	'about_Remote_Output' = 135185
	'about_Remote_Requirements' = 135187
	'about_Remote_Troubleshooting' = 135188
	'about_Requires' = 135190
	'about_Reserved_Words' = 113258
	'about_Return' = 136587
	'about_Scopes' = 113260
	'about_Script_Blocks' = 113261
	'about_Script_Internationalization' = 113262
	'about_Scripts' = 144310
	'about_Session_Configurations' = 145152
	'about_Signing' = 113268
	'about_Special_Characters' = 113269
	'about_Split' = 113270
	'about_Switch' = 113271
	'about_Throw' = 145153
	'about_Transactions' = 135192
	'about_Trap' = 136586
	'about_Try_Catch_Finally' = 113444
	'about_Type_Operators' = 113273
	'about_Types.ps1xml' = 113274
	'about_Updatable_Help' = 235801
	'about_Variables' = 157591
	'about_While' = 113275
	'about_Wildcards' = 113276
	'about_Windows_Powershell_2.0' = 113247
	'about_Windows_PowerShell_ISE' = 135178
	'about_WMI_Cmdlets' = 145766
	'about_WS-Management_Cmdlets' = 145774
	'about_ActiveDirectory' = [System.Uri]'http://technet.microsoft.com/library/hh531529.aspx'
	'about_ActiveDirectory_Filter' = [System.Uri]'http://technet.microsoft.com/library/hh531527.aspx'
	'about_ActiveDirectory_Identity' = [System.Uri]'http://technet.microsoft.com/library/hh531526.aspx'
	'about_ActiveDirectory_ObjectModel' = [System.Uri]'http://technet.microsoft.com/library/hh531528.aspx'
};

$BasicTranslateRules = `
	(
		  @{ template='(?<ts>[ \t]+)(?=\r?$)'; expression='' } `
		, @{ template='(?<=(\r?\n))(?<eol>(?:[ \t]*\r?\n)+)'; expression="`r`n" } `
		, @{ template='(?<code>`.*?`)'; expression='$0' } `
		, @{ template='(?<aboutCP>"get-help about_CommonParameters")' } `
		, @{ template='(?<aboutCP>about_CommonParameters(?:\s+[(].*?[)])?)' } `
		, @{ template="${reMDRef}"; expression='[${id}][]' } `
		, @{ template="${reMDLink}"; expression='[${id}](${url})' } `
		, @{ template="${reBeforeURL}(?<fullUrl>${reURL})"; expression='<${fullUrl}>' } `
		, @{ template="${reBeforeURL}(?<wwwUrl>${reURLShortHTTP})"; expression='<http://${wwwUrl}>' } `
		, @{ template="${reBeforeURL}(?<ftpUrl>${reURLShortFTP})"; expression='<ftp://${ftpUrl}>' } `
		| ConvertTo-TranslateRule -ruleCategory regExp `
	) `
	+ $PowerShellAboutTopicsTranslateRules `
	+ $PowerShellTypes `
	+ (
		Get-Module `
			-ListAvailable `
			-Name 'Microsoft.PowerShell.*' `
		| ConvertTo-TranslateRule -AsExternalModule `
	) `
	+ (
		Get-Command `
			-Module 'Microsoft.PowerShell.Core' `
		| ConvertTo-TranslateRule -AsExternalModule `
	) `
;

Export-ModuleMember `
	-Function `
		  Get-Readme `
		, Set-Readme `
		, Get-AboutModule `
		, Set-AboutModule `
		, New-HelpXML `
		, Get-HelpXML `
		, Set-HelpXML `
		, New-HelpInfo `
		, Get-HelpInfo `
		, Set-HelpInfo `
	-Alias `
		  Get-About `
		, Set-About `
;
