// prettyPrintJson.js
// ------------------------------------------------------------------
//
// Pretty print the JSON response.
// This is done only for demonstration purposes.
//

var c = JSON.parse(response.content);
response.content = JSON.stringify(c,null,2) + '\n';
