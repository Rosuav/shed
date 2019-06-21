//-- include-above -- chocfactory.js
//DO NOT EDIT ABOVE THIS LINE

//Interpret choc.DIV(attr, chld) as choc("DIV", attr, chld)
//This is basically what Python would do as choc.__getattr__()
export default new Proxy(choc, {get: function(obj, prop) {
	if (prop in obj) return obj[prop];
	return obj[prop] = (a, c) => obj(prop, a, c);
}});
