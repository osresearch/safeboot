import requests
import os

form_data = {
    'ekpub': ('ek.pub', open(os.environ.get('TPM_EKPUB'), 'rb')),
    'hostname': (None, os.environ.get('ENROLL_HOSTNAME'))
}

response = requests.post(os.environ.get('ENROLL_URL'), files=form_data)

print(response.content)
