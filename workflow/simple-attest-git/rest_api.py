import flask
from flask import request, abort
import subprocess
import json
import sys
from markupsafe import escape

app = flask.Flask(__name__)
app.config["DEBUG"] = True


@app.route('/', methods=['GET'])
def home():
    return '''
<h1>Attestation server orchestration API</h1>
<hr>

<h2>To add a new host entry;</h2>
<form method="post" action="/v1/add">
<table>
<tr><td>ekpubhash</td><td><input type=text name=ekpubhash></td></tr>
<tr><td>hostname</td><td><input type=text name=hostname></td></tr>
<tr><td>hostblob</td><td><input type=text name=hostblob></td></tr>
</table>
<input type="submit" value="Submit">
</form>

<h2>To query host entries;</h2>
<form method="get" action="/v1/query">
<table>
<tr><td>ekpubhash prefix</td><td><input type=text name=ekpubhash></td></tr>
</table>
<input type="submit" value="Submit">
</form>

<h2>To delete host entries;</h2>
<form method="post" action="/v1/delete">
<table>
<tr><td>ekpubhash prefix</td><td><input type=text name=ekpubhash></td></tr>
</table>
<input type="submit" value="Submit">
</form>

<h2>To find host entries by hostname suffix;</h2>
<form method="get" action="/v1/find">
<table>
<tr><td>hostname suffix</td><td><input type=text name=hostname_suffix></td></tr>
</table>
<input type="submit" value="Submit">
</form>
'''

@app.route('/v1/add', methods=['POST'])
def my_add():
    c = subprocess.run(['/op_add.sh',
                    request.form['ekpubhash'],
                    request.form['hostname'],
                    request.form['hostblob']])
    if (c.returncode != 0):
        abort(409)
    return {
        "returncode": c.returncode
    }

@app.route('/v1/query', methods=['GET'])
def my_query():
    c = subprocess.run(['/op_query.sh',
                       request.args['ekpubhash']],
                       stdout=subprocess.PIPE, text=True)
    if (c.returncode != 0):
        abort(500)
    j = json.loads(c.stdout)
    return j

@app.route('/v1/delete', methods=['POST'])
def my_delete():
    c = subprocess.run(['/op_delete.sh',
                       request.form['ekpubhash']],
                       stdout=subprocess.PIPE, text=True)
    if (c.returncode != 0):
        abort(500)
    j = json.loads(c.stdout)
    if (len(j["entries"]) == 0):
        abort(404)
    return j

@app.route('/v1/find', methods=['GET'])
def my_find():
    c = subprocess.run(['/op_find.sh',
                       request.args['hostname_suffix']],
                       stdout=subprocess.PIPE, text=True)
    if (c.returncode != 0):
        abort(500)
    j = json.loads(c.stdout)
    # TODO: we should check that j exists and has an "entries" field, rather
    # than returning it blindly...
    return j

if __name__ == "__main__":
    app.run()
