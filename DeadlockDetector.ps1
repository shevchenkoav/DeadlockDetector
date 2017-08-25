$password = Read-Host "Enter ServiceCenter Administrator password:"
$proxy = New-WebServiceProxy -Uri http://127.0.0.1/ServiceCenter/Monitor.asmx?WSDL #scurl
$controllerDeploymentStatus = 0
$controllerLogStatus = 0
$controllerLogQueueSize = 0
$proxy.GetNodesStatus($password,[ref]$controllerDeploymentStatus, [ref]$controllerLogStatus, [ref]$controllerLogQueueSize) | Export-Clixml .\servicestatus.xml #copying webservice response to a xml
$results = "C:\Users\Administrator\Desktop\servicestatus.xml"
$ErrorOutput = "Error"
$ServiceName = "OutSystems Deployment Service"
$arrService = Get-Service -Name $ServiceName
if ($arrService.Status -eq "running" -and  (Get-Content $results | Where-Object { $_.Contains("$ErrorOutput")} )) #if Deployment Service is running and not in the SC
{

Write-Host "Deadlock Detected"


}

else {
    
    Write-Host "No Deadlock Detected"
}



