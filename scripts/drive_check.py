import json
import subprocess
import sys
from collections import OrderedDict

drive = sys.argv[1]
datatype = sys.argv[2]
try:
    smartdata = sys.argv[3]
except IndexError:
    smartdata = 0
smartdict = dict()
smartexepath = 'C:\\Zabbix\\files\\smartctl.exe '


def getJSONSmart(addprefix):
    result = subprocess.run(smartexepath + addprefix + drive + ' --json=c', stdout=subprocess.PIPE, stderr=subprocess.PIPE,universal_newlines=True).stdout
    #print(result) #For test only
    json_result = json.loads(result)
    return json_result


def getDeviceType(json_result):
    try:
        device_type = json_result["device"]["type"]
    except KeyError:
        device_type = None
    return device_type


def findSmartFromDict():
    fromkey = None
    sortsmartdict = OrderedDict(sorted(smartdict.items(), key=lambda t: t[1]))
    for key in sortsmartdict:
        # print(key+" "+str(sortsmartdict.get(key)))
        fromkey = key
        break
    return fromkey


def damerau_levenshtein_distance(s1, s2):
    d, len_s1, len_s2 = {}, len(s1), len(s2)
    for i in range(-1, len_s1 + 1):
        d[(i, -1)] = i + 1
    for j in range(-1, len_s2 + 1):
        d[(-1, j)] = j + 1
    for i in range(len_s1):
        for j in range(len_s2):
            if s1[i] == s2[j]:
                cost = 0
            else:
                cost = 1
            d[(i, j)] = min(
                d[(i - 1, j)] + 1,
                d[(i, j - 1)] + 1,
                d[(i - 1, j - 1)] + cost)
            if i and j and s1[i] == s2[j - 1] and s1[i - 1] == s2[j]:
                d[(i, j)] = min(d[(i, j)], d[i - 2, j - 2] + cost)
    return (d[len_s1 - 1, len_s2 - 1])


def healthStatus(json_result):
    if json_result["smart_status"]["passed"] == True:
        return 1


def getInfoData(json_result, device_type):
    try:
       return json_result[smartdata]
    except KeyError:
        return 0


def getSmartData(json_result, device_type):
     if device_type == 'ata' or device_type == 'sat':
         for i in json_result["ata_smart_attributes"]["table"]:
             d = damerau_levenshtein_distance(i["name"], smartdata)
             if d <= 11:
                smartdict[i["name"]] = d
         smartsearch = findSmartFromDict()
         for i in json_result["ata_smart_attributes"]["table"]:
            if i["name"] == smartsearch:
                valuestr = i["raw"]["string"]
                if valuestr.isdigit() == True:
                    return valuestr
                else:
                    ipnumstr = valuestr.find('(')
                    if ipnumstr == -1:
                        ipnumstr = valuestr.find('h')
                    valuedigit = (valuestr[0:ipnumstr])
                    return valuedigit
     elif device_type == 'nvme':
         for i in json_result["nvme_smart_health_information_log"]:
             d = damerau_levenshtein_distance(i, smartdata)
             smartdict[i] = d
         return json_result["nvme_smart_health_information_log"][findSmartFromDict()]


def getGBWritten(json_result, device_type):
    lba_written = 0
    try:
        block_size = json_result["logical_block_size"]
    except KeyError:
        block_size = 0
    if device_type == 'ata' or device_type == 'sat':
        for i in json_result["ata_smart_attributes"]["table"]:
            if i["name"] == "Total_LBAs_Written" or i["name"] == "Lifetime_Writes":
                lba_written = i["raw"]["value"]
                t = int(block_size * lba_written / 1073741824)
                return t
            if i["name"] == "Host_Writes_GiB" or i["name"] == "Lifetime_Writes_GiB":
                t = i["raw"]["value"]
                return t
    # Для nvme дисков считаем по другой формуле
    elif device_type == 'nvme':
        lba_written = (json_result["nvme_smart_health_information_log"]["data_units_written"])
        t = int(512000 * lba_written / 1073741824)
        return t


if datatype == "smart":
    addprefix = "-a "
    json_result = getJSONSmart(addprefix)
    device_type = getDeviceType(json_result)
    smartvalue = getInfoData(json_result, device_type)
    if smartvalue == 0:
            smartvalue = getSmartData(json_result, device_type)
    if smartvalue == None:
        smartvalue = 0
    print(smartvalue)
elif datatype == "gbwritten":
    addprefix = "-a "
    json_result = getJSONSmart(addprefix)
    device_type = getDeviceType(json_result)
    smartvalue = getGBWritten(json_result, device_type)
    print(smartvalue)
elif datatype == "health":
    addprefix = "-H "
    json_result = getJSONSmart(addprefix)
    device_type = getDeviceType(json_result)
    print(healthStatus(json_result))
