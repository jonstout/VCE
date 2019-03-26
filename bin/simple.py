from influxdb import InfluxDBClient

import time
import json
import requests

username = ''
password = ''

simp_data = requests.get('https://jonstout-dev7.grnoc.iu.edu/simp/comp.cgi?method=interfaceGbps&host=mlxe16-2.sdn-test.grnoc.iu.edu')
simp_json = json.loads(simp_data.text)
simp = simp_json['results']

influx = []

for host in simp:
    for number in simp[host]:
        influx.append({
            "measurement": "intf",
            "tags": {
                "host":        host,
                "name":        simp[host][number]['intf'],
                "description": simp[host][number]['description'],
                "number":      int(number)
            },
            "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(int(simp[host][number]['time']))),
            "fields": {
                "tx": float(simp[host][number]['in']),
                "rx": float(simp[host][number]['out'])
            }
        })

client = InfluxDBClient('localhost', 8086, username, password, 'mydb')
client.write_points(influx)
