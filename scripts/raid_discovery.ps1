$CLI			= 'C:\zabbix\files\CmdTool2_64.exe'
$sender			= 'C:\zabbix\zabbix_sender.exe'
$agent_config	= 'C:\zabbix\zabbix_agentd.conf'

$number_of_adapters = [int](& $CLI -adpCount | Select-String "Controller Count: (\d+)" -AllMatches | % {$_.Matches} | % {$_.groups[1].value})
$physical_drives = @{}
$virtual_drives = @{}
$battery_units = @{}
$adapters = @{}
for ($adapter = 0; $adapter -lt $number_of_adapters;$adapter++) {
	$number_of_disks = [int](& $CLI -pdGetNum -a $adapter | Select-String "Number of Physical Drives on Adapter $adapter\: (\d)" -AllMatches | % {$_.Matches} | % {$_.groups[1].value})
	if ($number_of_disks -eq 0) {
		write-host "No disk found on adapter $adapter"
		Continue
	}
	$enclosure_number = [int](& $CLI -EncInfo -a $adapter | Select-String "Number of enclosures on adapter $adapter -- (\d)" -AllMatches | % {$_.Matches} | % {$_.groups[1].value})
	$enclosures = @{}
	if ($enclosure_number -eq 0) {
		write-host "No enclosures detected, skipping adapter"
		Continue
	} else {
		$tmp_file = Join-Path ${env:temp} "raid_enclosures-$(Get-Date -Format yyyy-MM-dd-HH-mm-ss).tmp"
		& $CLI -EncInfo -a $adapter | Out-File $tmp_file
		$current_enc_id = -1;
		$reader = [System.IO.File]::OpenText($tmp_file)
		try {
			for(;;) {
				$line = $reader.ReadLine()
				if ($line -eq $null) { break }
				[regex]$regex = '\s+Device ID\s+:\s(\d+).*'
				if (($regex.isMatch($line)) -eq $True) {
					$current_enc_id = $regex.Matches($line) | % {$_.groups[1].value}
				}
				[regex]$regex = '\s+Number\sof\sPhysical\sDrives\s+:\s(\d+).*'
				if (($regex.isMatch($line)) -eq $True) {
					$number_of_drives = $regex.Matches($line) | % {$_.groups[1].value}
					if ($number_of_drives -eq 0) {
						write-host -foregroundcolor red "Found enclosure $current_enc_id, but Number of drives is 0"
					}
					if (($current_enc_id -ne -1) -and ($number_of_drives -ne 0)) {
						$enclosures.Add($current_enc_id,$number_of_drives)
					}
				}
			}
		}
		finally {
			$reader.Close()
		}
		remove-item $tmp_file
	}

	foreach ($enclosure_id in $enclosures.Keys) {
		if (!($adapters.ContainsKey($adapter))) {
			$adapters.Add($adapter,"{ `"{#ADAPTER_ID}`":`"$adapter`" }")
		}
		$number_of_disks = $enclosures.Item($enclosure_id)
		for ($disk = 0;$disk -lt $number_of_disks;$disk++) {
			$physical_drives.Add($disk,"{ `"{#ENCLOSURE_ID}`":`"$enclosure_id`", `"{#PDRIVE_ID}`":`"$disk`", `"{#ADAPTER_ID}`":`"$adapter`" }")
		}
		$number_of_lds = [int](& $CLI -LDGetNum -a $adapter | Select-String "Number of Virtual Drives Configured on Adapter $adapter\:\s(\d+)" -AllMatches | % {$_.Matches} | % {$_.groups[1].value})
		if ($number_of_lds -eq 0) {
			write-host "No virtual disks found on adapter $adapter"
			Continue
		}
		for ($vd = 0;$vd -lt $number_of_lds;$vd++) {
			$virtual_drives.Add($vd,"{ `"{#VDRIVE_ID}`":`"$vd`", `"{#ADAPTER_ID}`":`"$adapter`" }")
		}
		# BBU
		$bbu_is_missing = (& $CLI -AdpBbuCmd -GetBbuStatus -a $adapter | Select-String ".*Get BBU Status Failed.*" | % {$_.Matches})
		if (!$bbu_is_missing) {
			$battery_units.Add($adapter,"{ `"{#ADAPTER_ID}`":`"$adapter`" }")
		}
	}
}

# create file with json
$zsend_data = Join-Path $(Split-Path -Parent $CLI) 'zsend_data.txt'

if (($physical_drives.Count -ne 0) -and ($virtual_drives.Count -ne 0)) {
	$writer = new-object io.streamwriter($zsend_data,$False)
	$i = 1
	$writer.Write('- intel.raid.discovery.pdisks { "data":[')
	foreach ($physical_drive in $physical_drives.Keys) {
		if ($i -lt $physical_drives.Count) {
			$string = "$($physical_drives.Item($physical_drive)),"
		} else {
			$string = "$($physical_drives.Item($physical_drive)) ]}"
		}
		$i++
		$writer.Write($string)
	}
	$writer.WriteLine('')
	$writer.Write('- intel.raid.discovery.vdisks { "data":[')
	$i = 1
	foreach ($virtual_drive in $virtual_drives.Keys) {
		if ($i -lt $virtual_drives.Count) {
			$string = "$($virtual_drives.Item($virtual_drive)),"
		} else {
			$string = "$($virtual_drives.Item($virtual_drive)) ]}"
		}
		$i++
		$writer.Write($string)
	}
	$writer.WriteLine('')
	$i = 1
	if ($battery_units.Count -ne 0) {
		$writer.Write('- intel.raid.discovery.bbu { "data":[')
		foreach ($battery_unit in $battery_units.Keys) {
			if ($i -lt $battery_units.Count) {
				$string = "$($battery_units.Item($battery_unit)),"
			} else {
				$string = "$($battery_units.Item($battery_unit)) ]}"
			}
			$i++
			$writer.Write($string)
		}
	}
	$writer.WriteLine('')
	$i = 1
	if ($adapters.Count -ne 0) {
		$writer.Write('- intel.raid.discovery.adapters { "data":[')
		foreach ($adapter in $adapters.Keys) {
			if ($i -lt $adapters.Count) {
				$string = "$($adapters.Item($adapter)),"
			} else {
				$string = "$($adapters.Item($adapter)) ]}"
			}
			$i++
			$writer.Write($string)
		}
	}
	$writer.WriteLine('')
	$writer.Close()
}

& $sender -c $agent_config -i $zsend_data