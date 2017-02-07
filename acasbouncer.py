from flask import Flask, request, jsonify
import requests
app = Flask(__name__)

@app.route("/pet.find")
def petfind():
	r = requests.get("http://api.petfinder.com" + request.full_path)
	resp = jsonify(r.json())
	resp.headers.add('Access-Control-Allow-Origin', '*')
	return resp

if __name__ == "__main__":
	import logging
	logging.basicConfig(level=logging.DEBUG)
	app.run(host='0.0.0.0')
