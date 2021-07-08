#Function: this is to deploy scripts based on one config file
#$log_file, $central_svr and $IniFile, also @mycompany.com need to be changed
 
import-module sqlserver;
$PSRootPath = $(Get-Location)
$log_file ="$($PSRootPath)\log\log_$((get-date).ToString('yyyyMMdd_HHmm')).txt" # deployment log
$IniFile = "$($PSRootPath)\config.ini"; #requestor prepares this deployment request file
$ListSqlFilesPath = "$($PSRootPath)\listSqlFiles.txt"; #sql files listing file path

$deploy_status = 'SUCCEEDED';
$regex = "\.[sql]+$"; #regex for sql files only within ListSqlFilesPath


# Functions goes here
Function Test-FileEmpty {

    Param ([Parameter(Mandatory = $true)][string]$file)
  
    if ((Test-Path -LiteralPath $file) -and !((Get-Content -LiteralPath $file -Raw) -match '\S')) {return $true} else {return $false}
  
  }

if (test-path -Path $log_file)
{ remove-item -Path $log_file; }
 
if (-not (test-path -Path $IniFile))
{ throw "[$IniFile] does not exist, please double check";}

if (-not (test-path -Path $ListSqlFilesPath))
{ throw "[$ListSqlFilesPath] does not exist, please double check";}

if( Test-FileEmpty $ListSqlFilesPath )
{ throw "[$ListSqlFilesPath] is empty";}

$dtbl = new-object System.Data.DataTable;
$dc = new-object System.Data.DataColumn ('InitFile', [System.string]);
$dtbl.Columns.add($dc);
 
$dc = new-object System.Data.DataColumn ('InitFileDate', [System.DateTime]);
$dtbl.Columns.add($dc);
 
$dc = new-object System.Data.DataColumn ('TargetServer', [System.string])
$dtbl.Columns.add($dc);

$dc = new-object System.Data.DataColumn ('TargetServerDatabaseName', [System.string])
$dtbl.Columns.add($dc);

$dc = new-object System.Data.DataColumn ('TargetServerUserName', [System.string])
$dtbl.Columns.add($dc);

$dc = new-object System.Data.DataColumn ('ScriptPath', [System.string])
$dtbl.Columns.add($dc);
 
$dc = new-object System.Data.DataColumn ('Requestor', [System.string]);
$dtbl.Columns.add($dc);
 
$dc = new-object System.Data.DataColumn ('Tag', [System.string]);
$dtbl.Columns.add($dc);
 
#read the Config.ini file
$ini = @{};
switch -Regex -file $IniFile
{
    "\[(.+)\]=\[(.+)\]"
    {
        $name, $value = $matches[1..2];
        $ini[$name]=$value;
    }
}
 
# make it mandatory the [Requestor] has a valid email address
if ($ini.Requestor -notmatch '@sisystems.com' -or $ini.tag -eq '' -or $ini.ScriptPath -eq 'the sql script path in a shared folder' -or $ini.DBACentralServer -eq 'DBA sql server name' -or $ini.TargetServer -eq 'sql server name' -or $ini.TargetServerDatabaseName -eq 'database name' -or $ini.TargetServerUserName -eq 'db server user name' -or $ini.TargetServerPassword -eq 'db server password')
{
    write-host $($ini.Requestor -notmatch '@mycompany.com');
   write-host 'nothing to run';
   return;
}
 
$c = get-content -Path $IniFile | ? { $_ -match '^\s?\[.+'}; # excluding comment and only extracting the key data
$FileDate = dir -Path $IniFile | Select-Object -Property LastWriteTime;
 
$c | out-file -FilePath $log_file -Encoding ascii -Append;
 
"`r`n`r`nImplementation starts at$(get-date)..`r`n `r`nDeployment Starts" | out-file -FilePath $log_file -Encoding ascii -Append;
 
# when an error is encountered, the script will stop, you can rerun the whole script, and it will skip the failed script and contine to next one
 
[string]$ScriptPath = $ini.ScriptPath;
[string]$tag = $ini.Tag;

$central_svr = $ini.DBACentralServer;
$target_server = $ini.TargetServer;
$target_server_username = $ini.TargetServerUserName;
$target_server_password = $ini.TargetServerPassword;
$target_server_databasename = $ini.TargetServerDatabaseName;
 
if (test-path $ScriptPath)
{
    $script_folder = $ScriptPath
}
else
{
    # invoke-sqlcmd -ServerInstance $central_svr -Database msdb -Query "exec dbo.sp_send_dbmail @recipients='$($requestor)' ,@subject='Cannot find Script folder', @Body='[$($ScriptPath)] is invalid'";
    throw "Invalid Folder [$ScriptPath]"
}
 
#check whether the $Target_server is correct
try
{
  invoke-sqlcmd -ServerInstance $target_server -Username $target_server_username -Password $target_server_password -Database $target_server_databasename -query "select getdate()" | Out-Null
}
catch
{
    # invoke-sqlcmd -ServerInstance $central_svr -Database msdb -Query "exec dbo.sp_send_dbmail @recipients='$($requestor)', @subject='Cannot connect to$($target_server)', @Body='The server$($target_server) cannot be accessed'";
 
  throw "The server$target_server cannot be accessed";
}
 
#check whether the $Tag is already there, if so, we need to change it
 
    $qry = @"
   if exists (select * from dbo.DeploymentHistory where Tag='$($Tag)')
       select isTagInside = 1;
   else
       select isTagInside = 0;
"@
 
    $result = invoke-sqlcmd -ServerInstance $central_svr -Database dba -Query $qry -OutputAs DataRows;
if ($result.isTagInside -eq 0)
{
    #we save the DeploymentConfig.txt 
    $r = $dtbl.NewRow();
    $r.InitFile = $c -join "`r`n";
    $r.InitFileDate = $FileDate.LastWriteTime ;
 
    $r.TargetServer = $ini.TargetServer;
    $r.TargetServerDatabaseName = $ini.TargetServerDatabaseName;
    $r.TargetServerUserName = $ini.TargetServerUserName;
    $r.ScriptPath = $ini.ScriptPath;
    $r.Requestor = $ini.Requestor;
    $r.tag = $ini.tag;
    $dtbl.Rows.Add($r);
 
    Write-SqlTableData -ServerInstance $central_svr -Database dba -SchemaName dbo -TableName DeploymentConfig -InputData $dtbl;
}

[string]$deployment_name = $ini.tag; # choose your own name if needed,my pattern is: Application_Date_VerNum
 
$continue = 'N'; #adding another layer of protection in case the prod server is used...
IF ($target_server -in ('prod1', 'prod2', 'prod3')) #adding your prod list here so that this will not run accidentally in prod environment
{ 
   $continue = 'n' ;
   throw "we do not allow to deploy to production [$target_server] at this time";
}
else
{ $continue ='y';}
 
if ($continue -ne 'y')
{ throw "you are going to deploy to prod, not continuing";}

$dt = New-Object System.Data.DataTable;
$col = New-Object System.Data.DataColumn('FullPath', [system.string]);
$dt.Columns.Add($col);
$col = New-Object System.Data.DataColumn('Tag', [system.string]);
$dt.Columns.add($col);
$col = New-Object System.Data.DataColumn('TargetServer', [system.string]);
$dt.Columns.add($col);
$col = New-Object System.Data.DataColumn('TargetServerDatabaseName', [system.string]);
$dt.Columns.add($col);
$col = New-Object System.Data.DataColumn('TargetServerUserName', [system.string]);
$dt.Columns.add($col);
 
dir *.sql -Path $Scriptpath -Recurse -File  | 
Sort-Object { [regex]::replace($_.FullName, '\d+', { $args[0].value.padleft(10, '0')})}  | 
ForEach-Object {
    $FileName = Split-Path $_.FullName -leaf;
    foreach($line in Get-Content $ListSqlFilesPath) {
        if(($line -match $regex) -and ($line.ToLower() -eq $FileName.ToLower())){
            $r = $dt.NewRow(); 
            $r.FullPath = $_.FullName;
            $r.Tag = $deployment_name;
            $r.TargetServer = $target_server;
            $r.TargetServerDatabaseName = $target_server_databasename;
            $r.TargetServerUserName = $target_server_username;
            $dt.Rows.add($r);  
        }
    }    
}
   
#check whether we need to populate the table again
$qry = @"
if exists (select * from dbo.DeploymentHistory where Tag='$($deployment_name)')
   select isRunBefore = 1;
else
   select isRunBefore = 0;
"@
 
$result = invoke-sqlcmd -ServerInstance $central_svr -Database dba -Query $qry -OutputAs DataRows;

if ($result.isRunBefore -eq 0) # the deployment never run before
{
    Write-SqlTableData -ServerInstance $central_svr -Database dba -SchemaName dbo -TableName DeploymentHistory -InputData $dt;
}
 
$qry = @"
select FullPath, id, TargetServer, Tag, [Status] from dbo.DeploymentHistory
where Tag = '$($deployment_name)' and [Status] = 'not started' --'success'
order by id asc
"@;
 
$rslt = Invoke-Sqlcmd -ServerInstance $central_svr -Database dba -Query $qry -OutputAs DataRows;


foreach ($dr in $rslt)
{   
  #  Write-Host $($dr.TargetServerDatabaseName);
    try 
    {
        write-host "Processing [$($dr.FullPath)] with id=$($dr.id)" -ForegroundColor Green;
       "Processing [$($dr.FullPath)] with id=$($dr.id)" | Out-File -FilePath $log_file -Encoding ascii -Append 
        [string]$pth = $dr.FullPath;

        invoke-sqlcmd -ServerInstance $dr.TargetServer -Database $target_server_databasename -Username $target_server_username -Password $target_server_password -InputFile $dr.FullPath  -QueryTimeout 7200 -ConnectionTimeout 7200 -ea Stop ;
 
        [string]$myqry = "update dbo.DeploymentHistory set [Status]='Success' where id =$($dr.id);"
        invoke-sqlcmd -ServerInstance $central_svr -Database dba -Query $myqry;
    }
    catch
    {
        $e = $error[0].Exception.Message;
        $e = $e.replace("'", '"');
       # [string]$myqry = "update dbo.DeploymentHistory set [Status]='Error', [Message]='$($e)' where id = $($dr.id);"
        if ($e.Length -gt 6000)
        { $e = $e.Substring(1, 6000);}
        [string]$myqry ="update dbo.DeploymentHistory set [Status]='Error', [Message]='" + $e + "' where id =$($dr.id);" 
        write-host "Error found on id=$($dr.id) with message =`r`n [$e]";
        "`r`nError occurred `r`n`r`n$($e)"| out-file -filepath $log_file -Encoding ascii -Append;
 
        $deploy_status = 'FAILED';
        invoke-sqlcmd -ServerInstance $central_svr -Database dba -Query $myqry  -QueryTimeout 7200 -ConnectionTimeout 7200;
        write-host "error found, plese get out of here";
        break;
    }
}

$qry = @"
set nocount on;
UPDATE h set ConfigID = c.id
from dba.dbo.DeploymentHistory h
inner join dba.dbo.DeploymentConfig c
on h.Tag = c.Tag
where h.ConfigID is null;
"@;
 
invoke-sqlcmd -ServerInstance $central_svr -Database DBA -Query $qry;
 
#move the origina Config to an archive folder for later verification
Move-Item -Path $IniFile -Destination "$($PSRootPath)\config_archive\Config_$((get-date).tostring('yyyyMMdd_hhmm')).txt";
 
$txt = @"
#config file, please fill the [] on the equation right side WITHOUT any quotes
#[DBACentralServer] should be the sql instance name which holds DBA database
#[TargetServer] should be the sql instance name, such as [MyQA_1], [PreProd_2] etc
#[ScriptPath] is where you put the sql script, such as [\\<share_folder>\Deployment\2020Aug20_QA\]
#[Requestor] should be the requestor's email, so once the deployment is done, an notification email will be sent out
#[Tag] this is more like a deployment name, can be anything to indicate the deployment, for example [QA_V1.2.3]

[DBACentralServer]=[DBA sql server name] 
[TargetServer]=[sql server name]
[TargetServerDatabaseName]=[database name]
[TargetServerUserName]=[db server user name]
[TargetServerPassword]=[db server password]
[ScriptPath]=[the sql script path in a shared folder]
[Requestor]=[your email addr]
[Tag]=[]
"@;
#re-generate the Config.ini
$txt | out-file -FilePath $IniFile  -Encoding ascii; 

Write-Host "BUILD $deploy_status" -ForegroundColor Red

"`r`n`r`nImplementation ends at$(get-date)..`r`n `r`n" | out-file -FilePath $log_file -Encoding ascii -Append;
  