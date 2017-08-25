$password = Read-Host "Enter ServiceCenter Administrator password:"
# $password ='nullvalue'
$proxy = New-WebServiceProxy -Uri http://127.0.0.1/ServiceCenter/Monitor.asmx?WSDL
$controllerDeploymentStatus = 0
$controllerLogStatus = 0
$controllerLogQueueSize = 0
$proxy.GetNodesStatus($password,[ref]$controllerDeploymentStatus, [ref]$controllerLogStatus, [ref]$controllerLogQueueSize) | Export-Clixml .\servicestatus.xml
$results = "C:\Users\Administrator\Desktop\servicestatus.xml"
$ErrorOutput = "Error"
$ServiceName = "OutSystems Deployment Service"
$arrService = Get-Service -Name $ServiceName
if ($arrService.Status -eq "running" -and  (Get-Content $results | Where-Object { $_.Contains("$ErrorOutput")} ))
{

Add-Type -Path "C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.5\System.IO.Compression.FileSystem.dll"

 #create zip file function
function ZipFiles( $zipfilename, $sourcedir ) 
{
   Add-Type -Assembly System.IO.Compression.FileSystem
   $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
   [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcedir,
        $zipfilename, $compressionLevel, $false)
}

function Expand-ZIPFile($file, $destination)
{
	$shell = new-object -com shell.application
	$zip = $shell.NameSpace($file)
	foreach($item in $zip.items())
	{
		$shell.Namespace($destination).copyhere($item)
	}
}

function Export-EventLog($logName,$destination)
{
   $eventLogSession = New-Object System.Diagnostics.Eventing.Reader.EventLogSession
   $eventLogSession.ExportLogAndMessages($logName,"LogName","*",$destination)
}

$basepath = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

$url = "https://download.sysinternals.com/files/Procdump.zip"
$output = "$basepath\Procdump.zip"

(New-Object System.Net.WebClient).DownloadFile($url, $output)

Expand-ZIPFile -file $output -destination $basepath

1..3 | ForEach-Object -process {
	.\procdump.exe -accepteula DeployService.exe
	.\procdump.exe -accepteula CompilerService.exe
	.\procdump.exe -accepteula SandboxManager.exe
	if ($_ -lt 3) { Start-Sleep -s 60 }
}

New-Item -path $basepath\dumps -type directory

Move-Item -path $basepath\*.dmp -destination dumps\

Copy-Item -Path "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\clr.dll" -destination dumps\
Copy-Item -Path "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\mscordacwks.dll" -destination dumps\
Copy-Item -Path "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\SOS.dll" -destination dumps\
Copy-Item -Path "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\mscordbi.dll" -destination dumps\
Copy-Item -Path "C:\Program Files\OutSystems\SandboxManager\SandboxManager.log" -destination dumps\

Export-EventLog -logName "Application" -destination $basepath\dumps\EventLog_Application.evtx 

$date_tag = Get-Date -format 'yyyymmdd_hh\hmm\m'
$final_filename = $env:computername + "_" + $date_tag + "_dumps.zip"
ZipFiles -zipfilename $basepath\$final_filename -sourcedir $basepath\dumps

Move-Item -path $basepath\$final_filename -destination C:\inetpub\wwwroot

$Acl = Get-Acl C:\inetpub\wwwroot\$final_filename
$Ar = New-Object system.security.accesscontrol.filesystemaccessrule("Everyone","FullControl","Allow")
$Acl.SetAccessRule($Ar)
Set-Acl C:\inetpub\wwwroot\$final_filename $Acl

Remove-Item * -include procdump* -force
Remove-Item Eula.txt
Remove-Item dumps -recurse

set-executionpolicy ByPass # in order to allow us to run this script we must execute this command 

Set-AWSCredentials -AccessKey nullvalue -SecretKey nullvalue -StoreAs $AWS_Profile; # add access keys process to access aws account and S3 
$AWS_Bucket = "s3bucket"  # AWS S3 backup folder
$source_dir = ":\inetpub\wwwroot\"  #  folder where zip is saved
$file_ext = "*.zip"
$datefolder = $((Get-Date).ToString('yyyy-MM-dd')) #provides internal date
$alldumpfilesziped = Get-ChildItem $source_dir -Recurse -Include $file_ext  #show all files with .zip

foreach ($path in $alldumpfilesziped) {
	Write-Host $path
	$dumpfiles = [System.IO.Path]::GetFileName($path)
	Write-S3Object -BucketName $AWS_Bucket -File $path -Key $env:computername/$datefolder/$dumpfiles  -StoredCredentials $AWS_Profile; # process to copy zip from folder to S3
}

Remove-Item $alldumpfilesziped

}

else {
    
    Write-Host "No Deadlock Detected"
}


Remove-AWSCredentialProfile -ProfileName $AWS_Profile #remove keys
