echo Install Zabbix service
zabbix_agentd -i -c C:\zabbix\zabbix_agentd.conf
echo Create task for ZabbixUpdater
SCHTASKS /CREATE /RU posobmen /RP pass /SC DAILY /ST 15:00 /TN ZabbixUpdater /TR C:\zabbix\setupdate.cmd