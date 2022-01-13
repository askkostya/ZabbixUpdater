import requests
import sys

LastVersionURL = 'http://zabbix server/getlastversion.php'
LastReleaseFile = 'http://zabbix server/lastrelease.zip'


def getlastversion(getURL):
	try:
		user_agent = {'User-Agent': 'Mozilla/5.0'}
		urlcontent = requests.get(getURL, headers=user_agent, stream=True)
		return urlcontent
	except requests.exceptions.RequestException:
		# Timeout or ConnectionError
		sys.exit()


with open('C:\\zabbix\\version.txt') as file:
	versiononpc = file.read()
	versiononsite = getlastversion(LastVersionURL).text
	if versiononsite != versiononpc:
		df = open('C:\\zabbix\\lastrelease.zip', "wb")
		for chunk in getlastversion(LastReleaseFile).iter_content(chunk_size=1024):
			if chunk:
				df.write(chunk)
	print(versiononpc)
