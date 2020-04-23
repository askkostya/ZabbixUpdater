$smartctl = "C:\zabbix\files\smartctl.exe"
$disks = GET-WMIOBJECT -query "SELECT * from win32_diskdrive"
$idx = 0

[char[]] $abc_array = ([char]'a'..[char]'z')

write-host "{"
write-host " `"data`":[`n"
foreach ($disk in $disks)
{
 
$m_type=""
    $smartctl_disk_name = "/dev/hd" + $abc_array[$idx]
    $smart_enabled = & $smartctl "-i" $smartctl_disk_name | select-string "SMART.+Enabled$"
    $m_type = & $smartctl "-i" $smartctl_disk_name | select-string "SSD"
    $device_model = & $smartctl "-i" $smartctl_disk_name | select-string "Device Model.+iSCSI"
    
    
    
             if($smart_enabled) {            
                $smart_enabled = 1
            } else {            
                $smart_enabled = 0
            }
            
       
             if($device_model) {            
                $smart_enabled = 0
            
            }



			 if($m_type) {            
                $m_type = "SSD"
            } else {            
                $m_type = "HDD"
            }
			
    
    if ($idx -lt $disks.Count-1)
    {
        $line= "`t{`n " + "`t`t`"{#DISKNAME}`":`""+$smartctl_disk_name+"`""+ ",`n" + "`t`t`"{#SMART_ENABLED}`":`""+$smart_enabled+"`", `n`t`t" +"`"{#MEDIA_TYPE}`":`""+$m_type+"`"`n`t},`n"
        write-host $line
    
}
    elseif ($idx -ge $disks.Count-1)
    {
     
        $line= "`t{`n " + "`t`t`"{#DISKNAME}`":`""+$smartctl_disk_name+"`""+ ",`n" + "`t`t`"{#SMART_ENABLED}`":`""+$smart_enabled+"`", `n`t`t" +"`"{#MEDIA_TYPE}`":`""+$m_type+"`"`n`t}"
        write-host $line
    }
    $idx++;
}
write-host
write-host " ]"
write-host "}"