Function Get-AboutTestFunction {
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
	}
}

New-Alias `
	-Name Get-AboutTest `
	-Value Get-AboutTestFunction `
;

Export-ModuleMember `
	-Function `
		Get-AboutTestFunction `
	-Alias `
		Get-AboutTest `
;
