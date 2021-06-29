import flask
from flask import request, abort
import subprocess
import json
import sys
from markupsafe import escape
from werkzeug.utils import secure_filename
import tempfile
import os

app = flask.Flask(__name__)
app.config["DEBUG"] = True


@app.route('/', methods=['GET'])
def home():
    return '''
<h1>Attestation server orchestration API</h1>
<hr>

<h2>To add a new host entry;</h2>
<form method="post" enctype="multipart/form-data" action="/v1/add">
<table>
<tr><td>ekpub</td><td><input type=file name=ekpub></td></tr>
<tr><td>hostname</td><td><input type=text name=hostname></td></tr>
</table>
<input type="submit" value="Enroll">
</form>

<h2>To query host entries;</h2>
<form method="get" action="/v1/query">
<table>
<tr><td>ekpubhash prefix</td><td><input type=text name=ekpubhash></td></tr>
</table>
<input type="submit" value="Query">
</form>

<h2>To delete host entries;</h2>
<form method="post" action="/v1/delete">
<table>
<tr><td>ekpubhash prefix</td><td><input type=text name=ekpubhash></td></tr>
</table>
<input type="submit" value="Delete">
</form>

<h2>To find host entries by hostname suffix;</h2>
<form method="get" action="/v1/find">
<table>
<tr><td>hostname suffix</td><td><input type=text name=hostname_suffix></td></tr>
</table>
<input type="submit" value="Find">
</form>
'''

@app.route('/v1/add', methods=['POST'])
def my_add():
    if 'ekpub' not in request.files:
        return { "error": "ekpub not in request" }
    if 'hostname' not in request.form:
        return { "error": "hostname not in request" }
    f = request.files['ekpub']
    tf = tempfile.TemporaryDirectory()
    p = os.path.join(tf.name, secure_filename(f.filename))
    f.save(p)
    h = request.form['hostname']
    c = subprocess.run(['/op_add.sh', p, h])
    return {
        "returncode": c.returncode
    }

@app.route('/v1/query', methods=['GET'])
def my_query():
    if 'ekpubhash' not in request.args:
        return { "error": "ekpubhash not in request" }
    h = request.args['ekpubhash']
    c = subprocess.run(['/op_query.sh', h],
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
