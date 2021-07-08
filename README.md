# PowerShellRunScriptsSQL
A powershell tool through which scripts in a particular folder can be executed in sql server automatically

Note: This tool expects sql server instance only
Pre-requisite: Install Powershell if not already available in your system

One Time setup
------------------
Step 1: Download src folder or clone repo so that you will receive "src" folder locally
Step 2: Open powershell command in administrator mode and update set-executionpolicy unresticted ( this is to ensure PSRun.ps file execution and also to install sqlserver module )
Step 3: run command "Install-Module -Name SqlServer"


Tool Specific setup
--------------------
Step 1: Open config.ini file and update all the values ( self descriptive, will work with sql server instance only )
Step 2: Open /src/scripts and place your scripts files (*.sql ) to be executed in this folder
Step 3: Open listSqlFiles.txt file and provide the list of file names ( ex: First.sql ) on each line 
Step 4: Open powershell command and run PSRun.ps file

--- HAPPY CODING !!! ---


