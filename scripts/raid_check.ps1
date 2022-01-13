
Param(
		[parameter(Position=0,Mandatory=$true)]
		[ValidateSet("pdisk", "vdisk", "bbu", "adapter")]
		[alias("m")]
		[String]
        $mode
	,		
		[parameter()]
		[ValidateNotNullOrEmpty()]
		[alias("p","item")]
        [string]
        $mode_item	
	,
		[parameter(Mandatory=$true)]
		[ValidateRange(0,5)]
		[alias("a","adp")]
        [int]
        $adapter
	,			
		[parameter()]
		[ValidateRange(0,1024)]
		[alias("e","enc")]
        [int]
        $enclosure_id
	,			
		[parameter()]
		[ValidateRange(0,256)]
		[alias("pdisk")]
        [int]
        $disk_id
	,			
		[parameter()]
		[ValidateRange(0,256)]
		[alias("vdisk")]
        [int]
        $vdisk_id
)

$CLI = 'C:\zabbix\files\CmdTool2_64.exe'

function pdisk_item($item,$adapter,$enclosure_id,$disk_id) {
	$regex = ''	
	switch ($item) {
		'firmware_state' 	{ $regex = "Firmware state:\s(.*)" }
		'predictive_errors'	{ $regex = "Predictive Failure Count:\s(.*)" }
		'media_errors'		{ $regex = "Media Error Count:\s(.*)" }		
	}
	
	if ($enclosure_id -eq 2989) {
		$output = (& $CLI -pdinfo -PhysDrv[:"$disk_id"] -a $adapter | Select-String $regex -AllMatches | % { $_.Matches } | % { $_.groups[1].value })
	} else {
		$output = (& $CLI -pdinfo -PhysDrv["$enclosure_id":"$disk_id"] -a $adapter | Select-String $regex -AllMatches | % { $_.Matches } | % { $_.groups[1].value })
	}
	write-host $output
}

function vdisk_item($item,$adapter,$vd) {
	$regex = ''
	switch ($item) {
		'vd_state' 			{ $regex = "^State\s+:\s(.*)$" }

	}
	
	$output = (& $CLI -LDinfo -L $vd -a $adapter | Select-String $regex -AllMatches | % { $_.Matches } | % { $_.groups[1].value })
	write-host $output
}

function bbu_item($item,$adapter){
	$regex 		= ''
	$command 	= ''
	switch ($item) {
		'bbu_state' 		{ $command = '-GetBbuStatus';$regex = "Battery State\s*:\s(.*)$" }

	}
	
	$output = (& $CLI -AdpBbuCmd $command -a $adapter | Select-String $regex | % {$_.Matches} | % { $_.groups[1].value })
	write-host $output
}

function adapter_item($item,$adapter){
	$regex 		= ''	
	switch ($item) {
		'fw_version' 		{ $regex = "^\s*FW\sPackage\sBuild:\s(.*)$" }
		'product_name'		{ $regex = "^\s*Product\sName\s*:\s(.*)$" }
	}
	
	$output = (& $CLI -AdpAllInfo -a $adapter | Select-String $regex  | % {$_.Matches} | % { $_.groups[1].value })
	write-host $output
}

### Start doing our job

switch ($mode) {
	"pdisk" 	{ pdisk_item $mode_item $adapter $enclosure_id $disk_id }
	"vdisk" 	{ vdisk_item $mode_item $adapter $vdisk_id }
	"bbu"		{ bbu_item $mode_item $adapter }
	"adapter"	{ adapter_item $mode_item $adapter }
}

