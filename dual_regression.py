# Can you do two linear regressions at once to do pixel-to-pixel mappings?
import pandas as pd
from river import linear_model, preprocessing

xcoord = preprocessing.StandardScaler() | preprocessing.TargetStandardScaler(linear_model.LinearRegression())
ycoord = preprocessing.StandardScaler() | preprocessing.TargetStandardScaler(linear_model.LinearRegression())

source_points = [
	{"x": float(x), "y": float(y)} for y in range(1, 6) for x in range(1, 6)
]

def xfrm(p):
	return {"x": 2*p["x"] + 5, "y": 2*p["y"] }#+ p["x"]/10}

def scale(p):
	return {"x": p["x"] / 100.0, "y": p["y"] / 100.0}

for p in source_points:
	out = xfrm(p)
	print(p, out)
	xcoord.learn_one(scale(p), scale(out)["x"])
	ycoord.learn_one(scale(p), scale(out)["y"])

p = {"x": 2.5, "y": 2.5}
print(xcoord.predict_one(scale(p)) * 100.0, ycoord.predict_one(scale(p)) * 100.0)
print(p, xfrm(p))
