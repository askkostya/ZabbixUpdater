set "newupdate=C:\zabbix\lastrelease.zip"
if exist "%newupdate%" (
	sc stop "Zabbix Agent"
	C:\zabbix\files\7zip\7za.exe x C:\zabbix\lastrelease.zip -y -oC:\zabbix
	sc start "Zabbix Agent"
	DEL /F /S /Q /A "%newupdate%"
)	