library saltcorn;

import "package:http/http.dart" as http;

import "dart:convert" show jsonEncode, utf8;
import "dart:convert" as dconv show jsonDecode;

import "dart:js_interop" show JSArray;

import "types.dart";

Uri serverURI([string httpPath = ""]) {
    return Uri.http("iris.local:17010", httpPath);
}

JSON jsonDecode(string source, {Object? reviver(Object? key, Object? value)?}) {
    var json = dconv.jsonDecode(source, reviver: reviver);
    if (json is JSArray) {
        return {"jsarr": json};
    } else {
        return json;
    }
}


Future<JSON> data(string table) async {
    http.Response response = await http.get(serverURI("api/" + table));
    JSON j = jsonDecode(utf8.decode(response.bodyBytes));
    return j;
}

/// Adds new rows to table
Future<JSON> add(string table, Map<string, dynamic> row) async {
    http.Response response = await http.post(serverURI("api/" + table), headers: {"Content-Type": "application/json"}, body: jsonEncode(row));
    JSON j = jsonDecode(utf8.decode(response.bodyBytes));
    return j;
}

/// Updates single object
Future<JSON> update(string table, string objectID, Map<string, dynamic> properties) async {
    http.Response response = await http.post(serverURI("api/" + table + "/" + objectID), headers: {"Content-Type": "application/json"}, body: jsonEncode(properties));
    JSON j = jsonDecode(utf8.decode(response.bodyBytes));
    return j;
}

/// Deletes single object
Future<JSON> delete(string table, string objectID) async {
    http.Response response = await http.delete(serverURI("api/" + table + "/" + objectID));
    JSON j = jsonDecode(utf8.decode(response.bodyBytes));
    return j;
}

