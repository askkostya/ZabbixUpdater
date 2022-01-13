import subprocess
import json

smartexepath = 'C:\\Zabbix\\files\\smartctl.exe '

#Todo
def return_smart_enabled(outinfo_json, media_type):
	return "1"


def return_media_type(outinfo_json):
	device_type = outinfo_json["device"]["protocol"]
	# smartctl ошибочно находит nvme диски несколько раз
	# один раз как /dev/sd[x], второй раз как /dev/nvme[x]
	# уберем из списка nvme записи
	if str(outinfo_json["device"]["name"]).find('nvme') >= 1:
		return 0
	#if str(outinfo_json["device"]["name"]).find('csmi') >= 1:
	#	return 0
	if device_type == "NVMe":
		return "NVM"
	elif device_type == "SCSI": #это iSCSI или RAID
		return 0
	elif device_type == "ATA":
		try:
			if outinfo_json["rotation_rate"] == 0:
				return "SSD"
			else:
				return "HDD"
		except KeyError:  # Как правило старые диски не содержат rotation_rate
			return "HDD"


def main():
	jsondeviceid = ''
	# Сканирование дисков установленных в системе
	out_scandrives = subprocess.run(smartexepath + '--scan-open --json=c', stdout=subprocess.PIPE, universal_newlines=True)
	scandrives_json = json.loads(out_scandrives.stdout)
	# Попытка включения SMART для диска
	for i in scandrives_json["devices"]:
		subprocess.run(smartexepath + '--smart=on −−offlineauto=on --saveauto=on ' + i["name"], stdout=subprocess.PIPE, universal_newlines=True)
	for i in scandrives_json["devices"]:
		outinfo = subprocess.run(smartexepath + '-i ' + i["name"] + ' --json=c', stdout=subprocess.PIPE, universal_newlines=True)
		outinfo_json = json.loads(outinfo.stdout)
		# print(outinfo_json)
		media_type = return_media_type(outinfo_json)
		if media_type == 0:
			continue
		else:
			smart_enabled = return_smart_enabled(outinfo_json, media_type)
		jsondevicefind = ('{"{#DISKNAME}":"' + str(i["name"]) + '","{#SMART_ENABLED}":"' + smart_enabled + '","{#MEDIA_TYPE}":"' + media_type + '"')
		jsondeviceid = jsondevicefind + '},' + jsondeviceid
	jsondeviceid = jsondeviceid[0:-1]
	print('{"data":[' + jsondeviceid + ']}')


main()

